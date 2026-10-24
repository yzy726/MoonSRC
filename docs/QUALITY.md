# Quality evidence — 0.2.0

All values analyze actual MoonSRC native-release output on Windows 11. Core
quality tests also run on native/js/wasm-gc. Preset/filter parameters are in
[ALGORITHM](ALGORITHM.md). These finite measurements are not a universal
passband/stopband specification or quality-parity claim.

## Frozen fixed-signal gate

Input is 48,000 frames of .5*sin(2*pi*f*n/48000), converted to 16,000 Hz.
f=1000 measures passband, f=12000 measures the component folding to 4000 Hz.
Discard 256 output frames at each end, leaving 15,488 coherent frames. Independent
Python math.fsum computes projections and RMS. Amplitude is
2*sqrt(sum_cos^2+sum_sin^2)/M; passband error is 20*log10(Apass/.5), alias relative
level is 20*log10(Aalias/Apass). No FFT/window correction is hidden.

All presets require |passband error|<=.5 dB. Alias limits were fixed before
measurement at -45/-50/-70 dB for low/balanced/high. Actual values:

| Preset | Passband error, dB | Alias relative, dB | Alias upper limit, dB |
|---|---:|---:|---:|
| low | +9.084903752e-06 | -91.785047 | -45 |
| balanced | +1.247659545e-06 | -110.608188 | -50 |
| high | +1.336351203e-07 | -127.051823 | -70 |

The [report](evidence/0.2.0/quality.json) retains amplitudes, RMS, exact windows,
limits, toolchain, hashes and exporter logs. Six committed little-endian binary64
files hold all 16,000 output frames. Balanced files are bitwise identical to the
0.1.0 raw baseline under evidence/.

## Frequency, DC, impulse and delay

The report includes all 123 measured frequency points across common/extreme rate
pairs and presets, plus 27 DC/centered-impulse cases. Grid analysis excludes the
full filter radius mapped to output frames plus eight output frames and uses complete periods.
DC=.25; measured impulse peak and expected timestamp are recorded. The grid
provides measured response/alias values, including transition-band attenuation;
no unfavorable point is removed to improve a summary.

Window taper and cutoff attenuate near the transition band. Increasing quality
changes bandwidth, alias rejection, CPU, initialization and lookahead. The 1 kHz
gate does not imply flat response up to Nyquist. LowLatency still anti-aliases;
identity is exact copying. At 48->16 kHz lookahead is 32/96/192 input frames,
approximately .667/2/4 ms; severe ratios scale support and delay.

## External reference

[reference_compare.json](evidence/0.2.0/reference_compare.json) retains 60 shared
cases: five rate/channel combinations, three MoonSRC presets, four signals
(centered impulse, DC, 1 kHz and stopband). Both implementations receive identical
float32 values. MoonSRC computes in Double and writes float32; reference is
official libsamplerate 0.2.2, Best Sinc Interpolator (converter 0), src_simple.

Centered impulse alignment finds integer lag [0] frames. Analysis excludes
both boundary supports plus 32 output frames. MoonSRC-minus-reference frame-count
deltas are [-1, 0, 1]; the reference has a different finite-frame policy from
MoonSRC's ceil contract. Aligned RMSE and separate signal gains describe kernel
differences; samplewise equality is not required. Version/hash/ABI/input hashes,
complete results and limitations are retained. See [sources](../THIRD_PARTY.md).

```sh
python scripts/quality.py --keep-raw _build/quality-020 --report _build/quality-020.json
python scripts/reference_compare.py --fetch-reference --report _build/reference-020.json
```

The second command verifies a pinned official Windows ZIP before loading its
reference-only DLL under ignored _build. Other hosts can supply --library.
It adds no product DSP dependency and publishes nothing. Timing scopes and
memory measurements are explained in [BENCHMARKS](BENCHMARKS.md).
