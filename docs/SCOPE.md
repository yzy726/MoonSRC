# Supported formats and resource limits — 0.2.0

The product converts fixed-rate PCM. It does not include codecs, audio devices,
dynamic ratios, channel mixing, speaker remapping or a zero-allocation/hard-real-
time guarantee. Core targets native/js/wasm-gc; file CLI and probes are native.
Local OS evidence is Windows 11, not inferred Linux/macOS runtime support.

## Core

- Integer rates 8000..192000, interleaved channels 1..8.
- p=Fout/gcd(Fin,Fout)<=4096; coefficient slots p*(2R+1)<=1,048,576. ResourceLimit
  rejects excessive precision/table size before construction.
- R depends on quality/downsampling, maximum 1536. Ring slots (2R+8)*channels
  <=24,640 Doubles; live history <=2R+1 frames. Headers/caller arrays are separate.
- Both batch facades limit output to 16,777,216 samples (128 MiB binary64 payload).
  They also allocate a stream and scratch buffer; long streams use bounded blocks.
- Stream counts use checked Int64 with 2R+1 window reserve. Finite Double input
  is not clipped; nonfinite input and arithmetic overflow are explicit errors.

## WAV and PCM

Little-endian RIFF/WAVE supports PCM16 (tag 1), IEEE binary32 (tag 3), and
WAVEFORMATEXTENSIBLE (tag 65534) with corresponding PCM/float GUID, 1..8 channels.
Metadata rates are 1..192000 Hz; core conversion still requires >=8000.
Extensible valid bits must equal container bits, and nonzero speaker masks must
have exactly channels set bits. Audio preserves ordinal samples, not speaker
metadata; output multichannel headers use unspecified mask 0.

Unknown chunks, required odd-byte padding and data-before-fmt are accepted.
Truncation, inconsistent RIFF/length/rate/alignment, duplicate fmt/data, missing
chunks, unsupported depth/GUID and nonfinite float values are classified errors.
Float output emits fact; decode derives frames from validated data length rather
than trusting fact. No compressed formats or RF64 are supported.

Total file limit is 33,554,476 bytes before sample allocation. Canonical header
overheads are 44 (mono/stereo PCM16), 58 (mono/stereo float32), 68 (multichannel
PCM16), 80 (multichannel float32) bytes. Float32 therefore has a lower sample
capacity at the same byte limit. Whole-file adapters materialize arrays, so this
limit does not imply constant CLI memory.

PCM16 decode is signed_integer/32768. Encode scales by 32768, rounds ties away
from zero, saturates to [-32768,32767] and counts saturation. Float32 rounds to
binary32 without clipping to [-1,1], reporting zero clipped samples. Nonfinite
input or finite Double rounding to float Infinity returns NonFinite(index),
keeping old WavError variants.

Native read checks file type/size and growth/truncation, with Unicode paths.
Output is created exclusively. CLI defaults remain Balanced and PCM16;
--quality low|balanced|high and --format pcm16|float32 select alternatives.
See [STREAMING](STREAMING.md), [SECURITY](SECURITY.md) and [FINAL_SCOPE](FINAL_SCOPE.md).
