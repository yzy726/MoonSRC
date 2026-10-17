# Initial quality method and evidence

The thresholds are fixed from goal.md before measurement: for 48000->16000 Hz,
absolute 1 kHz passband amplitude error <=0.5 dB; alias from 12 kHz input <=-50 dB
relative to the same-amplitude 1 kHz output. This is a measured initial test, not
an all-frequency stopband specification or a comparison with mature libraries.

Signals: x[n] = 0.5*sin(2*pi*f*n/48000), n=0..47999, f=1000 or 12000 Hz, mono.
The MoonBit tool tools/quality uses the public resample API and writes 16000
Double outputs per signal, as little-endian IEEE binary64. No PCM16 quantizer is
used for this measurement. Files contain no headers.

The steady interval is output indices 256..15743 (15488 samples). Rectangular
coherent projection measures amplitude as 2/N*hypot(sum(y*sin),sum(y*cos)), using
absolute output indices and the stated output frequency. This interval contains
integer numbers of both 1 kHz and 4 kHz periods. For the 12 kHz input the folded
frequency is 4 kHz. dB error is 20*log10(Apass/0.5); alias is
20*log10(Aalias/Apass). RMS is reported independently on the same interval.

Measured on the recorded Windows native-release toolchain:

| Measurement | Actual | Threshold |
|---|---:|---:|
| 1 kHz output amplitude | 0.5000000718210619 | relative to input 0.5 |
| Passband error | +0.0000012476595447 dB | absolute <=0.5 dB |
| Aliased 4 kHz amplitude | 0.0000014742144735968 | relative to passband |
| Alias relative level | -110.608187920042 dB | <=-50 dB |

Reproduce with `python scripts/quality.py`. To retain a fresh report and raw data,
use `--report _build/quality.json --keep-raw _build/quality-raw`. The script builds
native-release, reads actual MoonBit binary outputs, performs its own Python
projection using math.fsum, checks finite samples/counts and fails if thresholds
are missed. MoonBit unit tests implement a separate threshold check on each
promised backend. Python has no nonstandard dependencies.

Committed evidence: evidence/quality.json, evidence/passband.f64 and
 evidence/alias.f64. The JSON records SHA-256 hashes, platform, Python/toolchain,
window and exporter log. Verify or reanalyze those raw files independently.

Other checks include DC normalization at every phase, impulse gain, stereo
isolation, silence, boundaries and fixed-seed block partitions. DC steady windows
trim ceil(96*Fout/Fin)+1 output frames: 3x interpolation needs more than 256
frames. An earlier test used 256 uniformly and correctly revealed boundary
transients; its window was corrected without relaxing the frozen 48->16 quality
thresholds. No speech recording, listening-only claim or external quality parity
claim substitutes for these measurements.
