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


def reference(samples: list[int], in_rate: int, out_rate: int, channels: int, quality: str = "balanced") -> list[int]:
    """Independent direct sinc evaluation; never used to convert product audio."""
    count = len(samples) // channels
    frames = (count * out_rate + in_rate - 1) // in_rate
    base, rolloff = {"low": (32, .90), "balanced": (96, .94), "high": (192, .97)}[quality]
    radius = base * max(1, (in_rate + 3*out_rate - 1)//(3*out_rate))
    cutoff = rolloff * min(1.0, out_rate / in_rate)
    result = []
    for m in range(frames):
        center, remainder = divmod(m * in_rate, out_rate)
        fraction = remainder / out_rate
        weights = []
        for tap in range(-radius, radius + 1):
            x = tap - fraction
            z = math.pi * cutoff * x
            window = 0.42 + 0.5 * math.cos(math.pi * x / radius) + 0.08 * math.cos(2 * math.pi * x / radius)
            weights.append(0.0 if abs(x) >= radius else cutoff * (1.0 if abs(z) < 1e-12 else math.sin(z) / z) * window)
        norm = sum(weights)
        for channel in range(channels):
            value = sum(w / norm * samples[(center + tap) * channels + channel] / 32768
                        for tap, w in zip(range(-radius, radius + 1), weights)
                        if 0 <= center + tap < count)
            result.append(quantize(value))
    return result


def read_any(path: Path):
    raw=path.read_bytes()
    assert raw[:4]==b"RIFF" and raw[8:12]==b"WAVE"
    assert struct.unpack_from("<I",raw,4)[0]+8==len(raw)
    chunks={}; offset=12
    while offset<len(raw):
        tag=raw[offset:offset+4]; length=struct.unpack_from("<I",raw,offset+4)[0]
        chunks[tag]=raw[offset+8:offset+8+length]; offset+=8+length+(length&1)
    fmt=chunks[b"fmt "]
    tag,ch,rate,byte_rate,align,bits=struct.unpack_from("<HHIIHH",fmt)
    if tag==65534:
        assert len(fmt)==40 and struct.unpack_from("<H",fmt,16)[0]==22
        assert fmt[28:40]==bytes.fromhex("00001000800000aa00389b71")
        tag=struct.unpack_from("<I",fmt,24)[0]
    assert (tag,bits) in ((1,16),(3,32))
    assert align==ch*bits//8 and byte_rate==rate*align
    data=chunks[b"data"]; assert len(data)%align==0
    values=list(struct.unpack("<"+str(len(data)//(bits//8))+("h" if tag==1 else "f"),data))
    if tag==1: values=[v/32768 for v in values]
    assert all(math.isfinite(v) for v in values)
    return ch,rate,len(data)//align,values,tag


def independent_float_wav(rate: int, channels: int, values: list[float]):
    payload=struct.pack("<"+str(len(values))+"f",*values)
    fmt=struct.pack("<HHIIHHH",3,channels,rate,rate*channels*4,channels*4,32,0)
    if channels>2:
        fmt=struct.pack("<HHIIHHHHI",65534,channels,rate,rate*channels*4,channels*4,32,22,32,0)+bytes.fromhex("0300000000001000800000aa00389b71")
    chunks=b"fmt "+struct.pack("<I",len(fmt))+fmt+b"fact"+struct.pack("<II",4,len(values)//channels)+b"data"+struct.pack("<I",len(payload))+payload
    return b"RIFF"+struct.pack("<I",len(chunks)+4)+b"WAVE"+chunks


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
        for extra in (("--rate", "no"), ("--rate", "7999"), ("--rate", "48000", "--rate", "16000")):
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
        six = work / "six.wav"
        six_out = work / "six-out.wav"
        run(exe,"fixture",six,"--rate",44100,"--channels",6,"--frames",441)
        assert read_any(six)[:3]==(6,44100,441)
        run(exe,"convert",six,six_out,"--rate",16000,"--quality","high","--format","float32")
        sc,sr,sn,sv,st=read_any(six_out)
        assert (sc,sr,sn,st)==(6,16000,160,3)
        assert all(v==0 for i,v in enumerate(sv) if i%6!=0)
        checks.append("six_channel_extensible_pcm_to_float32")
        eight=work/"independent-eight.wav"
        eight_out=work/"independent-eight-out.wav"
        values=[2.0 if i%8==0 else .25 if i%8==7 else 0.0 for i in range(96*8)]
        eight.write_bytes(independent_float_wav(96000,8,values))
        run(exe,"convert",eight,eight_out,"--rate",96000,"--quality","low","--format","float32")
        assert read_any(eight_out)==read_any(eight)
        assert eight_out.read_bytes()==eight.read_bytes()
        checks.append("independent_eight_channel_float_identity_no_clipping")
        clipped=work/"eight-pcm.wav"
        run(exe,"convert",eight,clipped,"--rate",96000,"--format","pcm16")
        assert read_any(clipped)[3][0]==32767/32768
        checks.append("float_to_pcm16_explicit_saturation")
        for quality in ("low","balanced","high"):
            qout=work/(quality+".wav")
            info=run(exe,"convert",source,qout,"--rate",48000,"--quality",quality).stdout
            assert "quality="+quality in info
            expected=reference(samples,44100,48000,2,quality)
            actual=read(qout)[3]
            assert len(expected)==len(actual)
            assert max(abs(a-b) for a,b in zip(expected,actual))<=1
            checks.append("independent_direct_reference_"+quality)
        for fin,fout,frames in ((8000,192000,8),(192000,8000,192)):
            src=work/(str(fin)+".wav");dst=work/(str(fout)+"-out.wav")
            run(exe,"fixture",src,"--rate",fin,"--frames",frames,"--format","float32")
            run(exe,"convert",src,dst,"--rate",fout,"--quality","high","--format","float32")
            assert read_any(dst)[:3]==(1,fout,(frames*fout+fin-1)//fin)
            checks.append("extreme_rate_"+str(fin)+"_to_"+str(fout))
        for index,value in enumerate((float("nan"),float("inf"))):
            bad=work/("nonfinite"+str(index)+".wav")
            bad.write_bytes(independent_float_wav(48000,1,[value]))
            run(exe,"convert",bad,rejected,"--rate",16000,"--format","float32",ok=False)
            assert not rejected.exists()
            checks.append("float_nonfinite_rejected_"+str(index))
        for options in (("--quality","ultra"),("--format","opus"),("--quality","low","--quality","high"),("--format","float32","--format","pcm16"),("--quality",)):
            run(exe,"convert",source,rejected,"--rate",48000,*options,ok=False)
            assert not rejected.exists()
        checks.append("invalid_quality_format_and_duplicate_options")
        empty=work/"empty-eight.wav"; empty_out=work/"empty-eight-out.wav"
        run(exe,"fixture",empty,"--rate",8000,"--channels",8,"--frames",0,"--format","float32")
        run(exe,"convert",empty,empty_out,"--rate",192000,"--format","float32")
        assert read_any(empty_out)[:3]==(8,192000,0)
        checks.append("empty_eight_channel_float_conversion")
    result = {"status": "pass", "flows": len(checks), "checks": checks}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
