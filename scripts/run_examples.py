"""Build and execute all nine executable examples with observable assertions."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
NAMES = ["memory_44100_to_48000", "speech_48000_to_16000", "chunked_equivalence", "channel_isolation", "wav_convert", "multichannel_6ch", "quality_tradeoff", "bounded_stream", "consumer_from_mooncakes"]


def binary(folder, name):
    return next(path for path in (folder / f"{name}.exe", folder / name) if path.is_file())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    subprocess.run(["moon", "build", "--target", "native", "--release"], cwd=ROOT, check=True)
    results = []
    build = (ROOT / "_build").resolve()
    with tempfile.TemporaryDirectory(prefix="moonsrc-examples-", dir=build) as directory:
        work = Path(directory).resolve()
        assert work.is_relative_to(build)
        for name in NAMES:
            exe = binary(build / "native/release/build/examples" / name, name)
            command = [str(exe)]
            if name == "wav_convert":
                source, output = work / "source.wav", work / "output.wav"
                command += [str(source), str(output)]
            result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=True)
            assert result.stdout.strip(), name
            expected = {
                "multichannel_6ch": ["channels=6", "isolated=6"],
                "quality_tradeoff": ["quality=low", "quality=balanced", "quality=high", "elapsed_seconds="],
                "bounded_stream": ["frames_out=960000", "peak_history_frames=193"],
                "consumer_from_mooncakes": ["public_api_consumer frames=480"],
            }
            assert all(token in result.stdout for token in expected.get(name, [])), result.stdout
            results.append({"example": name, "stdout": result.stdout.strip(), "status": "pass"})
        with wave.open(str(output), "rb") as wav:
            assert (wav.getframerate(), wav.getnchannels(), wav.getnframes()) == (48000, 2, 480)
        cli = binary(build / "native/release/build/cmd/main", "main")
        cli_output = work / "cli.wav"
        subprocess.run([str(cli), "convert", str(source), str(cli_output), "--rate", "48000"], cwd=ROOT, check=True, capture_output=True)
        assert cli_output.read_bytes() == output.read_bytes(), "library example and CLI disagree"
    report = {"status": "pass", "count": len(results), "library_cli_byte_identical": True, "results": results}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
