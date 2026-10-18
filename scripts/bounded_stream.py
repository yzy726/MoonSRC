"""Repeated native processing measurements; no zero-allocation claim."""
import argparse
import json
import math
from pathlib import Path
import platform
import os
import statistics
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]
PRESETS={"low":32,"balanced":96,"high":192}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--report",type=Path)
    parser.add_argument("--repeats",type=int,default=3)
    parser.add_argument("--matrix-only",action="store_true")
    args=parser.parse_args()
    assert 1<=args.repeats<=10
    subprocess.run(["moon","build","--target","native","--release"],cwd=ROOT,check=True)
    folder=ROOT/"_build/native/release/build/tools/bounded_stream"
    exe=next(p for p in (folder/"bounded_stream.exe",folder/"bounded_stream") if p.is_file())
    cases=[]
    if not args.matrix_only:
        cases += [(seconds,48000,16000,1,q,"long_stream") for q in PRESETS for seconds in (60,600)]
        cases.append((60,44100,48000,2,"balanced","long_fractional"))
    pairs=[(44100,48000),(48000,44100),(48000,16000),(16000,48000),(44100,16000),(96000,44100),(8000,192000),(192000,8000),(48000,48000)]
    cases += [(1,fin,fout,ch,q,"matrix") for fin,fout in pairs for ch in (1,8) for q in PRESETS]
    measurements=[];summary=[]
    for seconds,fin,fout,ch,q,kind in cases:
        rows=[]
        for repeat in range(args.repeats):
            started=time.perf_counter()
            run=subprocess.run([str(exe),str(seconds),str(fin),str(fout),str(ch),q],cwd=ROOT,capture_output=True,text=True,check=True,timeout=240)
            row=json.loads(run.stdout)
            row.update({"trial":repeat+1,"kind":kind,"wall_seconds_including_process_start":time.perf_counter()-started})
            assert row["quality"]==q
            assert row["initialization_seconds"]>=0
            assert row["input_frames"]==seconds*fin and row["output_frames"]==seconds*fout
            assert row["input_block_frames"]==257 and row["output_capacity_frames"]==128
            assert row["elapsed_seconds"]>0 and math.isfinite(row["checksum"])
            radius=0 if fin==fout else PRESETS[q]*max(1,(fin+3*fout-1)//(3*fout))
            phases=fout//math.gcd(fin,fout)
            expected_coeff=0 if radius==0 else phases*(2*radius+1)
            expected_ring=0 if radius==0 else (2*radius+8)*ch
            assert row["coefficient_samples"]==expected_coeff
            assert row["history_capacity_samples"]==expected_ring
            assert row["internal_samples"]==expected_coeff+expected_ring
            assert row["peak_history_frames"]<=2*radius+1
            rows.append(row);measurements.append(row)
        times=[row["elapsed_seconds"] for row in rows]
        item={"kind":kind,"audio_seconds":seconds,"input_rate":fin,"output_rate":fout,"channels":ch,"quality":q,"trials":args.repeats,"median_elapsed_seconds":statistics.median(times),"minimum_elapsed_seconds":min(times),"maximum_elapsed_seconds":max(times),"median_initialization_seconds":statistics.median(r["initialization_seconds"] for r in rows),"internal_samples":rows[0]["internal_samples"],"peak_history_frames":rows[0]["peak_history_frames"]}
        summary.append(item)
        print(json.dumps(item),flush=True)
    for q in PRESETS:
        rows=[r for r in summary if r["kind"]=="long_stream" and r["quality"]==q]
        if rows:
            assert len(rows)==2
            for key in ("internal_samples","peak_history_frames"):
                assert rows[0][key]==rows[1][key],(q,key)
    report={"status":"pass","backend":"native-release","repeats_per_case":args.repeats,"warmup_input_seconds":.1,"input":"constant .25, all channels; actual process/finish output checksum","timing":"monotonic native wall clock; initialization records table/ring construction separately; processing excludes initialization/startup; each trial runs in a fresh process; min/median/max retained","storage_definition":"fixed coefficient/ring Double payload slots, excludes object headers/caller buffers; runtime allocations not instrumented","process_memory_definition":"OS RSS/current and peak include runtime and process overhead; -1 means unsupported","measurements":measurements,"summary":summary,"platform":platform.platform(),"processor":platform.processor(),"logical_processors":os.cpu_count(),"python":platform.python_version(),"toolchain":subprocess.check_output(["moon","version","--all"],cwd=ROOT,text=True).splitlines()}
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_bytes((json.dumps(report,indent=2)+"\n").encode())
    print(json.dumps({"status":"pass","configurations":len(summary),"trials":len(measurements)}))


if __name__=="__main__":main()
