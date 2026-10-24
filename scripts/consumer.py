"""Verify isolated local archives or an explicitly pinned Mooncakes registry version."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[1]
PUBLIC_SOURCE=ROOT/"examples/consumer_from_mooncakes/main.mbt"
EXTENDED='''///|
fn verify_extended() -> Unit {
  let c=@src.Config::with_quality(44100,16000,8,HighQuality).unwrap()
  if c.quality()!=HighQuality {abort("quality metadata")}
  let input=Array::makei(441*8,i=>if i%8==0 {0.25} else {0.0})
  let output=FixedArray::make(160*8+8,9.0)
  if @src.resample_into(c,input[:],output).unwrap()!=160 {abort("caller output count")}
  for i in (160*8)..<output.length() {if output[i]!=9.0 {abort("caller output tail")}}
  let encoded=@wav.encode_float32(16000,8,output[0:160*8]).unwrap()
  let audio=@wav.decode(encoded.bytes).unwrap()
  if audio.rate!=16000 || audio.channels!=8 || audio.samples.length()!=160*8 {abort("float32 WAV metadata")}
  for i in 0..<audio.samples.length() {if (audio.samples[i]-output[i]).abs()>1.0e-7 {abort("float32 conversion")}}
  println("extended_api quality=high channels=8 frames=160 float32=pass caller_output=pass")
}
'''


def run(command,cwd):
    result=subprocess.run(command,cwd=cwd,text=True,capture_output=True,encoding="utf-8",errors="replace")
    if result.returncode:
        (ROOT/"_build/consumer-failure.log").write_text(result.stdout+result.stderr,encoding="utf-8")
        print(result.stdout+result.stderr)
        raise subprocess.CalledProcessError(result.returncode,command)
    return result


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--report",type=Path)
    parser.add_argument("--registry-version")
    args=parser.parse_args()
    local_version=re.search(r'^version\s*=\s*"([^"\n]+)"',(ROOT/"moon.mod").read_text(),re.M).group(1)
    version=args.registry_version or local_version
    assert re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+",version)
    registry=args.registry_version is not None
    if not registry:
        run(["moon","package"],ROOT)
        archive=ROOT/f"_build/publish/Ag108-MoonSRC-{version}.zip"
        assert archive.is_file()
    original_work=(ROOT/"moon.work").read_bytes() if (ROOT/"moon.work").exists() else None
    targets=[];source_hashes={}
    with tempfile.TemporaryDirectory(prefix="moonsrc-consumer-",dir=ROOT/"_build") as directory:
        work=Path(directory).resolve();consumer=work/"consumer";consumer.mkdir()
        assert work.is_relative_to((ROOT/"_build").resolve())
        members=['./consumer']
        if not registry:
            library=work/"library";library.mkdir();members.insert(0,'./library')
            with zipfile.ZipFile(archive) as bundle:
                private={".git",".agent-workplace","_build",".mooncakes","AGENTS.md","goal.md","项目申报书.md","FINAL_LOCAL_ACCEPTANCE.md","LOCAL_ACCEPTANCE.md"}
                for member in bundle.infolist():
                    name=member.filename.replace("\\","/")
                    assert not any(part in private for part in name.split("/")),name
                    path=(library/name).resolve();assert path.is_relative_to(library)
                    if member.is_dir():path.mkdir(parents=True,exist_ok=True)
                    else:
                        path.parent.mkdir(parents=True,exist_ok=True);data=bundle.read(member);path.write_bytes(data)
                        if name.endswith((".mbt",".mbti","moon.mod","moon.pkg")):source_hashes[name]=hashlib.sha256(data).hexdigest()
            assert (library/"moon.mod").is_file()
        (work/"moon.work").write_bytes(('members = '+json.dumps(members)+'\n').encode())
        (consumer/"moon.mod").write_bytes((f'name = "local/moonsrc_consumer"\nversion = "0.1.0"\nimport {{ "Ag108/MoonSRC@{version}", }}\n').encode())
        (consumer/"moon.pkg").write_bytes(b'import { "Ag108/MoonSRC" @src, "Ag108/MoonSRC/wav", "Ag108/MoonSRC/pcm", }\npkgtype(kind: "executable")\n')
        source=PUBLIC_SOURCE.read_text()
        if not registry:source=source.replace('  println(','  verify_extended()\n  println(',1)+"\n"+EXTENDED
        (consumer/"main.mbt").write_bytes(source.encode())
        if registry:run(["moon","update"],consumer)
        for target in ("native","js","wasm-gc"):
            run(["moon","check","--target",target,"--deny-warn"],consumer)
            result=run(["moon","run","--target",target,"."],consumer)
            assert "public_api_consumer frames=480 channels=2 lookahead_in=96" in result.stdout
            if not registry:assert "extended_api quality=high channels=8 frames=160 float32=pass caller_output=pass" in result.stdout
            targets.append({"target":target,"status":"pass","stdout":result.stdout.strip().splitlines()})
            print(target,version,"registry" if registry else "local archive","pass",flush=True)
        tree=run(["moon","tree"],consumer).stdout
        assert "Ag108/MoonSRC" in tree and version in tree
    after=(ROOT/"moon.work").read_bytes() if (ROOT/"moon.work").exists() else None
    assert after==original_work,"consumer leaked workspace configuration"
    report={"status":"pass","source":"Mooncakes registry, explicitly pinned, no local library member" if registry else "local moon package ZIP, extracted into a fresh isolated workspace","library_version":version,"registry_install":registry,"published":registry,"targets":targets,"dependency_tree":tree.strip(),"private_files_excluded":True if not registry else None,"archive_source_hashes":source_hashes if not registry else None,"root_workspace_unchanged":True}
    if args.report:args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_bytes((json.dumps(report,indent=2)+"\n").encode())
    print(json.dumps({k:v for k,v in report.items() if k not in ("archive_source_hashes","dependency_tree")},indent=2))


if __name__=="__main__":main()
