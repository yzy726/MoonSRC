"""Verify a clean independent consumer of the local package, without publishing."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = '''///|
fn main {
  let config = @src.Config::new(44100, 48000, 2).unwrap()
  let input = Array::make(882, 0.25)
  let converted = @src.resample(config, input[:]).unwrap()
  if converted.length() != 960 { abort("wrong batch frame count") }
  let encoded = @wav.encode(48000, 2, converted[:]).unwrap()
  let decoded = @wav.decode(encoded.bytes).unwrap()
  if decoded.rate != 48000 || decoded.channels != 2 || decoded.samples.length() != 960 { abort("WAV metadata mismatch") }
  if @pcm.encode([0.25][:]).unwrap().bytes != b"\\x00\\x20" { abort("PCM quantization mismatch") }
  let stream = @src.Resampler::new(config)
  let buffer = FixedArray::make(14, 0.0)
  let mut consumed = 0
  while consumed < input.length() {
    let progress = stream.process(input[consumed:], buffer).unwrap()
    if progress.consumed_frames == 0 && progress.produced_frames == 0 { abort("no progress") }
    consumed += progress.consumed_frames * 2
  }
  while !stream.is_finished() { ignore(stream.finish(buffer).unwrap()) }
  if stream.stats().output_frames != 480L { abort("wrong stream frame count") }
  println("local_consumer frames=480 channels=2 lookahead_in=\\{stream.latency().input_frames}")
}
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    subprocess.run(["moon", "package"], cwd=ROOT, check=True)
    archive = ROOT / "_build/publish/Ag108-MoonSRC-0.1.0.zip"
    assert archive.is_file()
    build = (ROOT / "_build").resolve()
    results = []
    with tempfile.TemporaryDirectory(prefix="moonsrc-consumer-", dir=build) as directory:
        work = Path(directory).resolve()
        assert work.is_relative_to(build)
        library, consumer = work / "library", work / "consumer"
        library.mkdir()
        consumer.mkdir()
        with zipfile.ZipFile(archive) as bundle:
            names = bundle.namelist()
            assert not any(part in (".git", ".agent-workplace", "_build", ".mooncakes", "AGENTS.md", "goal.md") for name in names for part in name.replace("\\", "/").split("/"))
            for member in bundle.infolist():
                path = library / member.filename.replace("\\", "/")
                assert path.resolve().is_relative_to(library.resolve())
                if member.is_dir():
                    path.mkdir(parents=True, exist_ok=True)
                else:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(bundle.read(member))
        assert (library / "moon.mod").is_file(), names[:5]
        (consumer / "moon.mod").write_text('name = "local/moonsrc_consumer"\nversion = "0.1.0"\nimport { "Ag108/MoonSRC@0.1.0", }\n', encoding="utf-8")
        (consumer / "moon.pkg").write_text('import { "Ag108/MoonSRC" @src, "Ag108/MoonSRC/wav", "Ag108/MoonSRC/pcm", }\npkgtype(kind: "executable")\n', encoding="utf-8")
        (consumer / "main.mbt").write_text(SOURCE, encoding="utf-8")
        (work / "moon.work").write_text('members = ["./library", "./consumer"]\n', encoding="utf-8")
        for backend in ("native", "js", "wasm-gc"):
            subprocess.run(["moon", "check", "--target", backend, "--deny-warn"], cwd=consumer, check=True)
            result = subprocess.run(["moon", "run", "--target", backend, "."], cwd=consumer, text=True, capture_output=True, check=True)
            assert "local_consumer frames=480 channels=2 lookahead_in=96" in result.stdout
            results.append({"target": backend, "status": "pass", "stdout": result.stdout.strip().splitlines()[-1]})
    report = {"status": "pass", "source": "local moon package ZIP, extracted into a fresh temporary workspace", "registry_install": False, "published": False, "targets": results}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
