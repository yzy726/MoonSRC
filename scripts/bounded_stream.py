"""Run real 1/10-minute input streams and report fixed storage plus process RSS."""
import argparse
import json
from pathlib import Path
import platform
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    subprocess.run(["moon", "build", "--target", "native", "--release"], cwd=ROOT, check=True)
    folder = ROOT / "_build/native/release/build/tools/bounded_stream"
    exe = next((folder / name for name in ("bounded_stream.exe", "bounded_stream") if (folder / name).is_file()), None)
    assert exe is not None, "bounded stream probe not implemented"
    measurements = []
    for seconds, input_rate, output_rate, channels in [(60, 48000, 16000, 1), (600, 48000, 16000, 1), (60, 44100, 48000, 2)]:
        started = time.perf_counter()
        run = subprocess.run([str(exe), str(seconds), str(input_rate), str(output_rate), str(channels)], cwd=ROOT, capture_output=True, text=True, check=True, timeout=240)
        result = json.loads(run.stdout)
        result["wall_seconds_including_process_start"] = time.perf_counter() - started
        assert result["input_frames"] == seconds * input_rate
        assert result["output_frames"] == (seconds * input_rate * output_rate + input_rate - 1) // input_rate
        assert result["peak_history_frames"] <= 193
        assert result["coefficient_samples"] <= 160 * 193
        assert result["input_block_frames"] == 257 and result["output_capacity_frames"] == 128
        measurements.append(result)
    short, long, fractional = measurements
    for key in ("internal_samples", "coefficient_samples", "history_capacity_samples", "peak_history_frames"):
        assert short[key] == long[key], f"internal storage grows with duration: {key}"
    report = {
        "status": "pass", "backend": "native-release", "warmup_input_frames": 48000,
        "storage_definition": "Double payload slots in coefficient table and ring, excluding caller buffers and runtime object headers",
        "process_memory_definition": "OS-reported current and peak resident working set; includes process/runtime overhead",
        "allocation_note": "Core sample arrays are fixed at construction; Progress/Result/Stats may allocate. Runtime allocation counts were not instrumented; this is not a zero-allocation guarantee.",
        "measurements": measurements, "platform": platform.platform(), "python": platform.python_version(),
        "toolchain": subprocess.check_output(["moon", "version", "--all"], cwd=ROOT, text=True).splitlines(),
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
