"""Independent measurements of actual MoonBit f64 exports, never product DSP."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import platform
import shutil
import struct
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
PRESETS={"low":(32,.90,-45),"balanced":(96,.94,-50),"high":(192,.97,-70)}


def projection(values,frequency,rate,trim):
    period=rate//math.gcd(rate,int(frequency)) if frequency else 1
    count=((len(values)-2*trim)//period)*period
    assert count>0,(len(values),trim,period)
    indices=range(trim,trim+count)
    rms=math.sqrt(math.fsum(values[i]**2 for i in indices)/count)
    if frequency==0:
        amplitude=abs(math.fsum(values[i] for i in indices)/count)
    else:
        sine=math.fsum(values[i]*math.sin(2*math.pi*frequency*i/rate) for i in indices)
        cosine=math.fsum(values[i]*math.cos(2*math.pi*frequency*i/rate) for i in indices)
        amplitude=2*math.hypot(sine,cosine)/count
    return amplitude,rms,count


def db(value):
    return 20*math.log10(max(abs(value),1e-300))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--report",type=Path)
    parser.add_argument("--keep-raw",type=Path)
    parser.add_argument("--fixed-only",action="store_true")
    args=parser.parse_args()
    subprocess.run(["moon","build","--target","native","--release"],cwd=ROOT,check=True)
    folder=ROOT/"_build/native/release/build/tools/quality"
    exe=next(p for p in (folder/"quality.exe",folder/"quality") if p.is_file())
    presets={};grid=[];invariants=[]
    with tempfile.TemporaryDirectory(prefix="quality-020-",dir=ROOT/"_build") as temp:
        work=Path(temp)
        def export(fin,fout,q,signal,frames=None):
            frames=fin if frames is None else frames
            path=work/(str(len(list(work.iterdir())))+".f64")
            run=subprocess.run([str(exe),"export",str(path),str(fin),str(fout),q,str(signal),str(frames),"1"],cwd=ROOT,capture_output=True,text=True,check=True)
            raw=path.read_bytes()
            expected=(frames*fout+fin-1)//fin
            assert len(raw)==expected*8
            values=struct.unpack("<"+str(expected)+"d",raw)
            assert all(math.isfinite(v) for v in values)
            return values,raw,run.stdout.strip()
        for q,(_,_,limit) in PRESETS.items():
            passed,pass_raw,pass_log=export(48000,16000,q,1000)
            stopped,stop_raw,stop_log=export(48000,16000,q,12000)
            pa,pr,n=projection(passed,1000,16000,256)
            sa,sr,_=projection(stopped,4000,16000,256)
            error=db(pa/.5);folded=db(sa/pa)
            assert abs(error)<=.5 and folded<=limit,(q,error,folded)
            hashes={"passband.f64":hashlib.sha256(pass_raw).hexdigest(),"alias.f64":hashlib.sha256(stop_raw).hexdigest()}
            presets[q]={"quality":q,"passband_amplitude":pa,"passband_error_db":error,"alias_amplitude":sa,"alias_relative_db":folded,"passband_rms":pr,"alias_rms":sr,"window_frames":n,"trim_each_end_frames":256,"limits":{"absolute_passband_error_db":.5,"maximum_alias_relative_db":limit},"sha256":hashes,"export_log":[pass_log,stop_log]}
            if args.keep_raw:
                args.keep_raw.mkdir(parents=True,exist_ok=True)
                (args.keep_raw/(q+"-passband.f64")).write_bytes(pass_raw)
                (args.keep_raw/(q+"-alias.f64")).write_bytes(stop_raw)
            print(q,"passband_db",error,"alias_db",folded,flush=True)
        if not args.fixed_only:
            pairs=[(44100,48000),(48000,44100),(48000,16000),(16000,48000),(44100,16000),(96000,44100),(8000,192000),(192000,8000),(48000,48000)]
            for fin,fout in pairs:
                for q,(base,rolloff,_) in PRESETS.items():
                    radius=0 if fin==fout else base*max(1,(fin+3*fout-1)//(3*fout))
                    trim=(radius*fout+fin-1)//fin+8
                    dc,_,_=export(fin,fout,q,"dc")
                    dc_error=max(abs(v-.25) for v in dc[trim:-trim])
                    assert dc_error<1e-10,(fin,fout,q,dc_error)
                    impulse,_,_=export(fin,fout,q,"impulse")
                    peak=max(range(len(impulse)),key=lambda i:abs(impulse[i]))
                    ideal=(fin//2)*fout/fin
                    assert abs(peak-ideal)<=1,(fin,fout,q,peak,ideal)
                    invariants.append({"input_rate":fin,"output_rate":fout,"quality":q,"radius":radius,"output_lookahead_frames":(radius*fout+fin-1)//fin,"dc_max_error":dc_error,"impulse_peak_frame":peak,"ideal_impulse_frame":ideal})
                    frequencies=[int(min(fin,fout)*x) for x in (.05,.20,.35,.45)]
                    if fin>fout: frequencies.append((fin+fout)//4)
                    for f in frequencies:
                        values,raw,_=export(fin,fout,q,f)
                        folded=f%fout
                        folded=min(folded,fout-folded)
                        amplitude,rms,count=projection(values,folded,fout,trim)
                        grid.append({"input_rate":fin,"output_rate":fout,"quality":q,"input_frequency_hz":f,"output_frequency_hz":folded,"region":"folded_alias" if f>fout/2 else "response","relative_amplitude_db":db(amplitude/.5),"rms":rms,"trim_each_end_frames":trim,"coherent_window_frames":count,"sha256":hashlib.sha256(raw).hexdigest()})
                    print("grid",fin,fout,q,"ok",flush=True)
    old=json.loads((ROOT/"docs/evidence/quality.json").read_text())
    result={"status":"pass","backend":"native-release","input_rate":48000,"output_rate":16000,"input_frames":48000,"output_frames":16000,"amplitude":.5,"presets":presets,"response_grid":grid,"invariants":invariants,"legacy_balanced_bitwise_equal":presets['balanced']['sha256']==old['sha256'],"method":"0.5 sine, coherent rectangular projection with Python math.fsum; fixed test trims 256 output frames; grid trims full radius+8 and uses complete periods; DC=.25 and centered unit impulse; grid points are measurements, not all-band guarantees","toolchain":subprocess.check_output(['moon','version','--all'],cwd=ROOT,text=True).splitlines(),"platform":platform.platform(),"python":platform.python_version()}
    result.update({k:v for k,v in presets['balanced'].items() if k not in ('quality',)})
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(result,indent=2)+"\n",encoding='utf-8')
    print(json.dumps({"status":result['status'],"presets":len(presets),"grid_points":len(grid),"invariants":len(invariants),"legacy_balanced_bitwise_equal":result['legacy_balanced_bitwise_equal']},indent=2))


if __name__=="__main__":main()
