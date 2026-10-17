"""Native CLI end-to-end checks; only Python standard-library dependencies."""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import struct
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]


def executable() -> Path:
    subprocess.run(["moon", "build", "--target", "native", "--release"], cwd=ROOT, check=True)
    folder = ROOT / "_build/native/release/build/cmd/main"
    for name in ("main.exe", "main"):
        path = folder / name
        if path.is_file():
            return path
    raise RuntimeError(f"native executable missing under {folder}")


def run(exe: Path, *args: object, ok: bool = True) -> subprocess.CompletedProcess:
    result = subprocess.run([str(exe), *map(str, args)], cwd=ROOT, text=True, capture_output=True)
    if ok and result.returncode != 0:
        raise AssertionError(result.stdout + result.stderr)
    if not ok and result.returncode == 0:
        raise AssertionError(f"unexpected success: {args}")
    return result


def read(path: Path):
    with wave.open(str(path), "rb") as wav:
        assert wav.getsampwidth() == 2
        channels, rate, frames = wav.getnchannels(), wav.getframerate(), wav.getnframes()
        raw = wav.readframes(frames)
    return channels, rate, frames, list(struct.unpack(f"<{len(raw)//2}h", raw))


def quantize(value: float) -> int:
    limited = min(32767 / 32768, max(-1.0, value)) * 32768
    return math.floor(limited + 0.5) if limited >= 0 else math.ceil(limited - 0.5)


def reference(samples: list[int], in_rate: int, out_rate: int, channels: int) -> list[int]:
    """Independent direct sinc evaluation; never used to convert product audio."""
    count = len(samples) // channels
    frames = (count * out_rate + in_rate - 1) // in_rate
    cutoff = 0.94 * min(1.0, out_rate / in_rate)
    result = []
    for m in range(frames):
        center, remainder = divmod(m * in_rate, out_rate)
        fraction = remainder / out_rate
        weights = []
        for tap in range(-96, 97):
            x = tap - fraction
            z = math.pi * cutoff * x
            window = 0.42 + 0.5 * math.cos(math.pi * x / 96) + 0.08 * math.cos(2 * math.pi * x / 96)
            weights.append(0.0 if abs(x) >= 96 else cutoff * (1.0 if abs(z) < 1e-12 else math.sin(z) / z) * window)
        norm = sum(weights)
        for channel in range(channels):
            value = sum(w / norm * samples[(center + tap) * channels + channel] / 32768
                        for tap, w in zip(range(-96, 97), weights)
                        if 0 <= center + tap < count)
            result.append(quantize(value))
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", type=Path)
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    exe = args.exe.resolve() if args.exe else executable()
    checks = []
    assert "moonsrc convert" in run(exe, "--help").stdout
    checks.append("help")
    if args.smoke:
        print("CLI help smoke passed")
        return
    build = (ROOT / "_build").resolve()
    build.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="moonsrc-e2e-", dir=build) as directory:
        work = Path(directory).resolve()
        assert work.is_relative_to(build)
        source, up, identity, speech, down = [work / x for x in ("stereo.wav", "up.wav", "identity.wav", "speech.wav", "down.wav")]
        run(exe, "fixture", source, "--rate", 44100, "--channels", 2, "--frames", 441)
        channels, rate, frames, samples = read(source)
        assert (channels, rate, frames) == (2, 44100, 441)
        checks.append("synthetic_fixture")
        report = run(exe, "convert", source, up, "--rate", 48000).stdout
        assert "frames_out=480" in report
        oc, of, on, output = read(up)
        assert (oc, of, on) == (2, 48000, 480)
        assert all(x == 0 for x in output[1::2])
        checks.append("stereo_44100_to_48000_channel_isolation")
        run(exe, "convert", source, identity, "--rate", 44100)
        assert identity.read_bytes() == source.read_bytes()
        checks.append("identity_exact")
        run(exe, "fixture", speech, "--rate", 48000, "--channels", 1, "--frames", 4800)
        run(exe, "convert", speech, down, "--rate", 16000)
        assert read(down)[:3] == (1, 16000, 1600)
        checks.append("mono_48000_to_16000")
        run(exe, "convert", source, up, "--rate", 48000, ok=False)
        assert read(up)[2] == 480
        checks.append("existing_output_preserved")
        malformed, rejected = work / "bad.wav", work / "rejected.wav"
        malformed.write_bytes(b"RIFF\xff\xff\xff\xffWAVEdata")
        run(exe, "convert", malformed, rejected, "--rate", 48000, ok=False)
        assert not rejected.exists()
        checks.append("malformed_input_no_output")
        for extra in (("--rate", "no"), ("--rate", "8000"), ("--rate", "48000", "--rate", "16000")):
            run(exe, "convert", source, rejected, *extra, ok=False)
            assert not rejected.exists()
        run(exe, "convert", work / "missing.wav", rejected, "--rate", 48000, ok=False)
        run(exe, "convert", source, source, "--rate", 48000, ok=False)
        checks.append("arguments_missing_file_and_same_path")
        small, reference_out = work / "reference.wav", work / "reference-output.wav"
        with wave.open(str(small), "wb") as wav:
            wav.setparams((2, 2, 44100, 0, "NONE", "not compressed"))
            data = [((i * 337 + 17) % 20001) - 10000 for i in range(128)]
            wav.writeframes(struct.pack("<128h", *data))
        run(exe, "convert", small, reference_out, "--rate", 48000)
        expected = reference(data, 44100, 48000, 2)
        actual = read(reference_out)[3]
        assert len(actual) == len(expected)
        assert max(abs(a-b) for a, b in zip(actual, expected)) <= 1
        checks.append("independent_direct_sinc_reference_within_one_pcm16_lsb")
        unicode_in, unicode_out = work / "测试 音频.wav", work / "转换 输出.wav"
        run(exe, "fixture", unicode_in, "--rate", 48000, "--channels", 1, "--frames", 48)
        run(exe, "convert", unicode_in, unicode_out, "--rate", 16000)
        assert read(unicode_out)[:3] == (1, 16000, 16)
        checks.append("unicode_paths")
        oversized = work / "oversized.wav"
        with oversized.open("wb") as stream:
            stream.truncate(33554477)
        run(exe, "convert", oversized, rejected, "--rate", 48000, ok=False)
        run(exe, "convert", work, rejected, "--rate", 48000, ok=False)
        assert not rejected.exists()
        checks.append("oversized_and_nonregular_input_rejected_before_allocation")
        run(exe, "fixture", rejected, "--rate", 48000, "--frames", 1000001, ok=False)
        assert not rejected.exists()
        checks.append("fixture_resource_budget")
    result = {"status": "pass", "flows": len(checks), "checks": checks}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
