"""Black-box full-buffer comparison with official libsamplerate; never product DSP."""
from __future__ import annotations
import argparse
import ctypes
import ctypes.util
import hashlib
import json
import math
from pathlib import Path
import platform
import os
import statistics
import struct
import subprocess
import tempfile
import time
import urllib.request
import zipfile
from e2e import independent_float_wav, read_any
from quality import projection, db

ROOT=Path(__file__).resolve().parents[1]
URL="https://github.com/libsndfile/libsamplerate/releases/download/0.2.2/libsamplerate-0.2.2-win64.zip"
ARCHIVE_SHA256="35686fa4cae633a7418e40eb4cc520c4d9c53438cbdd75007b10859e468bc5da"


class SrcData(ctypes.Structure):
    _fields_=[("data_in",ctypes.POINTER(ctypes.c_float)),("data_out",ctypes.POINTER(ctypes.c_float)),("input_frames",ctypes.c_long),("output_frames",ctypes.c_long),("input_frames_used",ctypes.c_long),("output_frames_gen",ctypes.c_long),("end_of_input",ctypes.c_int),("src_ratio",ctypes.c_double)]


def reference_library(args):
    default=ROOT/"_build/reference/libsamplerate-0.2.2/libsamplerate-0.2.2-win64/bin/samplerate.dll"
    if args.fetch_reference:
        assert platform.system()=="Windows","On other platforms provide --library for an installed libsamplerate."
        base=ROOT/"_build/reference";base.mkdir(parents=True,exist_ok=True)
        archive=base/"libsamplerate-0.2.2-win64.zip"
        if not archive.exists():urllib.request.urlretrieve(URL,archive)
        assert hashlib.sha256(archive.read_bytes()).hexdigest()==ARCHIVE_SHA256,"Reference archive hash mismatch"
        target=base/"libsamplerate-0.2.2";target.mkdir(exist_ok=True)
        with zipfile.ZipFile(archive) as z:
            for member in z.infolist():
                path=(target/member.filename).resolve()
                assert path.is_relative_to(target.resolve())
                if member.is_dir():path.mkdir(parents=True,exist_ok=True)
                else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(z.read(member))
    name=str(args.library) if args.library else str(default) if default.is_file() else ctypes.util.find_library("samplerate")
    if not name:raise RuntimeError("Provide --library or use --fetch-reference on Windows")
    lib=ctypes.CDLL(name)
    lib.src_get_version.argtypes=[];lib.src_get_version.restype=ctypes.c_char_p
    lib.src_get_name.argtypes=[ctypes.c_int];lib.src_get_name.restype=ctypes.c_char_p
    lib.src_strerror.argtypes=[ctypes.c_int];lib.src_strerror.restype=ctypes.c_char_p
    lib.src_simple.argtypes=[ctypes.POINTER(SrcData),ctypes.c_int,ctypes.c_int];lib.src_simple.restype=ctypes.c_int
    metadata={"version":lib.src_get_version().decode(),"converter":lib.src_get_name(0).decode(),"converter_id":0,"api":"src_simple, full input once, end_of_input=1","source_release":"https://github.com/libsndfile/libsamplerate/releases/tag/0.2.2","api_documentation":"https://libsndfile.github.io/libsamplerate/api_simple.html","official_archive_url":URL if args.fetch_reference else None,"official_archive_sha256":ARCHIVE_SHA256 if args.fetch_reference else None,"binary_sha256":hashlib.sha256(Path(name).read_bytes()).hexdigest() if Path(name).is_file() else None,"ctypes_long_bytes":ctypes.sizeof(ctypes.c_long),"ctypes_src_data_bytes":ctypes.sizeof(SrcData)}
    return lib,metadata


def convert_reference(lib,values,fin,fout,channels,repeats):
    frames=len(values)//channels;capacity=(frames*fout+fin-1)//fin+4096
    incoming=(ctypes.c_float*len(values))(*values)
    outgoing=(ctypes.c_float*(capacity*channels))()
    times=[]
    for _ in range(repeats):
        data=SrcData(incoming,outgoing,frames,capacity,0,0,1,fout/fin)
        start=time.perf_counter();error=lib.src_simple(ctypes.byref(data),0,channels);times.append(time.perf_counter()-start)
        if error:raise RuntimeError(lib.src_strerror(error).decode())
        assert data.input_frames_used==frames and 0<=data.output_frames_gen<=capacity
    result=list(outgoing)[:data.output_frames_gen*channels]
    assert all(math.isfinite(v) for v in result)
    return result,data.output_frames_gen,times


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--library",type=Path)
    parser.add_argument("--fetch-reference",action="store_true")
    parser.add_argument("--report",type=Path)
    parser.add_argument("--repeats",type=int,default=3)
    args=parser.parse_args();assert 1<=args.repeats<=10
    lib,metadata=reference_library(args)
    subprocess.run(["moon","build","--target","native","--release"],cwd=ROOT,check=True)
    folder=ROOT/"_build/native/release/build/cmd/main"
    exe=next(p for p in (folder/"main.exe",folder/"main") if p.is_file())
    rows=[]
    with tempfile.TemporaryDirectory(prefix="reference-020-",dir=ROOT/"_build") as temp:
        work=Path(temp)
        for fin,fout,ch in [(48000,16000,1),(44100,48000,2),(48000,44100,1),(96000,44100,1),(192000,8000,1)]:
            stop=12000 if (fin,fout)==(48000,16000) else (fin+fout)//4 if fin>fout else int(fin*.4)
            signals=[("impulse",None),("dc",0),("pass",1000),("stop",stop)]
            data_by_signal={}
            for label,f in signals:
                values=[(1.0 if i//ch==fin//2 else 0.0) if label=="impulse" else .25 if label=="dc" else .5*math.sin(2*math.pi*f*(i//ch)/fin) for i in range(fin*ch)]
                if ch>1:values=[v if i%ch==0 else 0.0 for i,v in enumerate(values)]
                raw=independent_float_wav(fin,ch,values)
                source=work/(str(fin)+"-"+str(fout)+"-"+label+".wav");source.write_bytes(raw)
                ref,ref_frames,ref_times=convert_reference(lib,values,fin,fout,ch,args.repeats)
                data_by_signal[label]={"source":source,"ref":ref,"ref_frames":ref_frames,"times":ref_times,"frequency":f,"input_sha256":hashlib.sha256(raw).hexdigest()}
            ref_impulse=data_by_signal["impulse"]["ref"][::ch]
            ref_peak=max(range(len(ref_impulse)),key=lambda i:abs(ref_impulse[i]))
            ref_support=max(abs(i-ref_peak) for i,v in enumerate(ref_impulse) if v!=0)
            for q,base in (("low",32),("balanced",96),("high",192)):
                radius=base*max(1,(fin+3*fout-1)//(3*fout))
                trim=max(ref_support,(radius*fout+fin-1)//fin)+32
                results={}
                for label,_ in signals:
                    item=data_by_signal[label];times=[]
                    for repeat in range(args.repeats):
                        target=work/(str(fin)+"-"+str(fout)+"-"+q+"-"+label+"-"+str(repeat)+".wav")
                        started=time.perf_counter()
                        subprocess.run([str(exe),"convert",str(item["source"]),str(target),"--rate",str(fout),"--quality",q,"--format","float32"],cwd=ROOT,check=True,capture_output=True,text=True)
                        times.append(time.perf_counter()-started)
                    channels,rate,frames,values,kind=read_any(target)
                    assert (channels,rate,frames,kind)==(ch,fout,fout,3)
                    if ch>1:assert all(v==0.0 for i,v in enumerate(values) if i%ch!=0)
                    results[label]={"values":values[::ch],"wall_times":times}
                moon_impulse=results["impulse"]["values"]
                moon_peak=max(range(len(moon_impulse)),key=lambda i:abs(moon_impulse[i]))
                lag=moon_peak-ref_peak
                for label,_ in signals:
                    item=data_by_signal[label];moon=results[label]["values"];ref=item["ref"][::ch]
                    begin=max(trim,trim+lag);end=min(len(moon)-trim,len(ref)+lag-trim)
                    assert end>begin
                    rmse=math.sqrt(math.fsum((moon[i]-ref[i-lag])**2 for i in range(begin,end))/(end-begin))
                    row={"input_rate":fin,"output_rate":fout,"channels":ch,"quality":q,"signal":label,"input_sha256":item["input_sha256"],"moon_output_frames":fout,"reference_output_frames":item["ref_frames"],"frame_count_delta":fout-item["ref_frames"],"moon_impulse_peak":moon_peak,"reference_impulse_peak":ref_peak,"alignment_lag_frames":lag,"trim_each_end_frames":trim,"aligned_rmse":rmse,"moon_cli_wall_seconds":results[label]["wall_times"],"reference_src_simple_seconds":item["times"],"moon_cli_median_seconds":statistics.median(results[label]["wall_times"]),"reference_src_simple_median_seconds":statistics.median(item["times"])}
                    if label!="impulse":
                        folded=item["frequency"]%fout;folded=min(folded,fout-folded)
                        ma,_,_=projection(moon,folded,fout,trim)
                        ra,_,_=projection(ref,folded,fout,trim)
                        expected=.25 if label=="dc" else .5
                        row.update({"input_frequency_hz":item["frequency"],"measured_frequency_hz":folded,"moon_relative_amplitude_db":db(ma/expected),"reference_relative_amplitude_db":db(ra/expected)})
                        if label=="dc":assert abs(ma-.25)<1e-5 and abs(ra-.25)<1e-5
                        if label=="pass":assert abs(row["moon_relative_amplitude_db"])<=.5
                    rows.append(row)
                print("reference comparison",fin,fout,ch,q,"lag",lag,"ok",flush=True)
    report={"status":"pass","reference":metadata,"cases":rows,"input_precision":"Identical IEEE float32 input values for both implementations; MoonSRC computes in Double then writes float32; libsamplerate API uses float32. One second per signal, channel zero active, other channels silent.","alignment":"A centered unit impulse determines integer output-time lag for each implementation. Both complete boundary supports plus 32 output frames are excluded. Aligned RMS differences describe different kernels, not samplewise compatibility requirements.","timing":"Each entry retains three trials by default. MoonSRC timing is CLI process wall time including startup, WAV parsing, table construction, conversion and output. Reference timing is an in-process src_simple call including its internal construction, excluding Python buffers and I/O. These scopes differ; no relative speedup is claimed. Comparable MoonSRC core timings are reported separately by bounded_stream.py.","limitations":"No universal quality parity claim; finite signal set and one reference converter setting. Published version is not changed by this script.","platform":platform.platform(),"processor":platform.processor(),"logical_processors":os.cpu_count(),"python":platform.python_version(),"toolchain":subprocess.check_output(["moon","version","--all"],cwd=ROOT,text=True).splitlines()}
    if args.report:args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_bytes((json.dumps(report,indent=2)+"\n").encode())
    print(json.dumps({"status":"pass","reference":metadata["version"],"cases":len(rows),"maximum_integer_alignment_lag":max(abs(row["alignment_lag_frames"]) for row in rows)},indent=2))


if __name__=="__main__":main()
