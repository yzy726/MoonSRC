"""Measure actual MoonBit output using independent Python coherent projection."""
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

ROOT = Path(__file__).resolve().parents[1]


def amplitude(samples, frequency):
    trimmed = list(enumerate(samples))[256:-256]
    assert len(trimmed) == 15488
    sine = math.fsum(value * math.sin(2 * math.pi * frequency * i / 16000) for i, value in trimmed)
    cosine = math.fsum(value * math.cos(2 * math.pi * frequency * i / 16000) for i, value in trimmed)
    return 2 * math.hypot(sine, cosine) / len(trimmed)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path)
    parser.add_argument("--keep-raw", type=Path)
    args = parser.parse_args()
    subprocess.run(["moon", "build", "--target", "native", "--release"], cwd=ROOT, check=True)
    folder = ROOT / "_build/native/release/build/tools/quality"
    exe = next((folder / name for name in ("quality.exe", "quality") if (folder / name).is_file()), None)
    assert exe is not None, folder
    build = (ROOT / "_build").resolve()
    with tempfile.TemporaryDirectory(prefix="moonsrc-quality-", dir=build) as directory:
        work = Path(directory).resolve()
        assert work.is_relative_to(build)
        paths = [work / "passband.f64", work / "alias.f64"]
        run = subprocess.run([str(exe), *map(str, paths)], cwd=ROOT, capture_output=True, text=True, check=True)
        raw = [path.read_bytes() for path in paths]
        assert all(len(data) == 16000 * 8 for data in raw)
        passed, alias = [struct.unpack("<16000d", data) for data in raw]
        assert all(math.isfinite(value) for values in (passed, alias) for value in values)
        pass_amplitude, alias_amplitude = amplitude(passed, 1000), amplitude(alias, 4000)
        error_db = 20 * math.log10(pass_amplitude / 0.5)
        alias_db = 20 * math.log10(alias_amplitude / pass_amplitude)
        rms = lambda data: math.sqrt(math.fsum(x*x for x in data[256:-256]) / 15488)
        result = {
            "status": "pass" if abs(error_db) <= 0.5 and alias_db <= -50 else "fail",
            "backend": "native-release", "input_rate": 48000, "output_rate": 16000,
            "input_frames": 48000, "output_frames": 16000, "amplitude": 0.5,
            "trim_each_end_frames": 256, "window": "rectangular, coherent 15488-frame interval",
            "passband_frequency_hz": 1000, "stopband_input_hz": 12000, "alias_output_hz": 4000,
            "passband_amplitude": pass_amplitude, "passband_error_db": error_db,
            "alias_amplitude": alias_amplitude, "alias_relative_db": alias_db,
            "passband_rms": rms(passed), "alias_rms": rms(alias),
            "limits": {"absolute_passband_error_db": 0.5, "maximum_alias_relative_db": -50},
            "sha256": {path.name: hashlib.sha256(data).hexdigest() for path, data in zip(paths, raw)},
            "toolchain": subprocess.check_output(["moon", "version", "--all"], cwd=ROOT, text=True).splitlines(),
            "platform": platform.platform(), "python": platform.python_version(),
            "export_log": run.stdout.splitlines(),
        }
        if args.keep_raw:
            args.keep_raw.mkdir(parents=True, exist_ok=True)
            for path in paths:
                shutil.copyfile(path, args.keep_raw / path.name)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    assert result["status"] == "pass", "initial acceptance quality threshold failed"


if __name__ == "__main__":
    main()
