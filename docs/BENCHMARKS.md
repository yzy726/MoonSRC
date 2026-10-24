# Resource and performance measurements — 0.2.0

Measured 2026-10-18 on Windows 11 build 22631, Intel Core i7-14700HX (28 logical
processors), Moon 0.1.20260920 / moonc 0.10.14+7d59c7ec9, Python 3.13.5,
native-release. JSON retains processor/platform strings, toolchain and every
trial. Results depend on host, signal and buffers; no hard-real-time guarantee.

## Method and long streams

Each configuration has three fresh-process trials and .1 second of actual warmup.
Constant .25 input drives all channels. process/finish produces an actual checksum;
input blocks are 257 frames and output capacity 128 frames. Native monotonic
clock timing separates initialization from processing and excludes startup from
core time. Min/median/max, throughput and RSS/current/process peak are retained.
Unsupported memory readings use -1. Runtime allocations were not instrumented.
Fixed Double slots exclude headers and caller buffers.

[bounded_stream.json](evidence/0.2.0/bounded_stream.json) has 61 configurations,
183 trials: all-preset 60/600-second mono 48->16 kHz, 60-second fractional stereo
44.1->48 kHz, and a 54-configuration matrix.

| Quality | Audio seconds | Median seconds | Min..max seconds | Fixed Double slots | Peak history frames |
|---|---:|---:|---:|---:|---:|
| low | 60 | 0.270165 | 0.268314..0.280388 | 137 | 65 |
| low | 600 | 2.779327 | 2.733891..2.828525 | 137 | 65 |
| balanced | 60 | 0.687559 | 0.668341..0.728740 | 393 | 193 |
| balanced | 600 | 6.980548 | 6.879937..7.081836 | 393 | 193 |
| high | 60 | 1.312568 | 1.290624..1.367080 | 777 | 385 |
| high | 600 | 16.017139 | 13.718475..16.094666 | 777 | 385 |

Same-quality fixed slots and peaks match at 1 and 10 minutes. This establishes
duration-independent sample storage for these configurations, not constant RSS
or zero allocation.

## Multichannel optimization and full matrix

After the baseline, >2-channel FIR reuses each history index across channels,
retaining per-channel tap order with no new buffer. Mono/stereo are unchanged.
Exact channel-vs-mono tests guard arithmetic equivalence.
[performance_change.json](evidence/0.2.0/performance_change.json) compares 24
nonidentity eight-channel cases with three trials each. Median of before/after
time ratios is 1.625431. This is a local matrix observation, not a universal gain.

The current repeated matrix in [bounded_stream_optimized.json](evidence/0.2.0/bounded_stream_optimized.json)
has 54 configurations and 162 trials. Earlier long mono/stereo runs remain
applicable because their processing paths did not change. Full current matrix:

| Fin->Fout, Hz | Channels | Quality | Median processing seconds / audio second | Median init seconds | Fixed Double slots |
|---|---:|---|---:|---:|---:|
| 44100->48000 | 1 | low | 0.012467 | 0.0003266 | 10472 |
| 44100->48000 | 1 | balanced | 0.032057 | 0.0009190 | 31080 |
| 44100->48000 | 1 | high | 0.061148 | 0.0017661 | 61992 |
| 44100->48000 | 8 | low | 0.052589 | 0.0003236 | 10976 |
| 44100->48000 | 8 | balanced | 0.158987 | 0.0010015 | 32480 |
| 44100->48000 | 8 | high | 0.299936 | 0.0017510 | 64736 |
| 48000->44100 | 1 | low | 0.011450 | 0.0003366 | 9627 |
| 48000->44100 | 1 | balanced | 0.029374 | 0.0008584 | 28571 |
| 48000->44100 | 1 | high | 0.059446 | 0.0017464 | 56987 |
| 48000->44100 | 8 | low | 0.050101 | 0.0003132 | 10131 |
| 48000->44100 | 8 | balanced | 0.136141 | 0.0008675 | 29971 |
| 48000->44100 | 8 | high | 0.276582 | 0.0017933 | 59731 |
| 48000->16000 | 1 | low | 0.004407 | 0.0000063 | 137 |
| 48000->16000 | 1 | balanced | 0.010760 | 0.0000101 | 393 |
| 48000->16000 | 1 | high | 0.021187 | 0.0000149 | 777 |
| 48000->16000 | 8 | low | 0.018426 | 0.0000068 | 641 |
| 48000->16000 | 8 | balanced | 0.053180 | 0.0000188 | 1793 |
| 48000->16000 | 8 | high | 0.098929 | 0.0000296 | 3521 |
| 16000->48000 | 1 | low | 0.012590 | 0.0000108 | 267 |
| 16000->48000 | 1 | balanced | 0.031848 | 0.0000214 | 779 |
| 16000->48000 | 1 | high | 0.060873 | 0.0000398 | 1547 |
| 16000->48000 | 8 | low | 0.052606 | 0.0000106 | 771 |
| 16000->48000 | 8 | balanced | 0.146717 | 0.0000280 | 2179 |
| 16000->48000 | 8 | high | 0.289984 | 0.0000508 | 4291 |
| 44100->16000 | 1 | low | 0.004457 | 0.0003268 | 10472 |
| 44100->16000 | 1 | balanced | 0.010736 | 0.0009360 | 31080 |
| 44100->16000 | 1 | high | 0.020910 | 0.0019316 | 61992 |
| 44100->16000 | 8 | low | 0.018429 | 0.0003232 | 10976 |
| 44100->16000 | 8 | balanced | 0.049606 | 0.0009740 | 32480 |
| 44100->16000 | 8 | high | 0.103725 | 0.0019329 | 64736 |
| 96000->44100 | 1 | low | 0.012543 | 0.0003428 | 9627 |
| 96000->44100 | 1 | balanced | 0.030233 | 0.0008211 | 28571 |
| 96000->44100 | 1 | high | 0.060712 | 0.0016539 | 56987 |
| 96000->44100 | 8 | low | 0.050010 | 0.0002869 | 10131 |
| 96000->44100 | 8 | balanced | 0.144381 | 0.0008475 | 29971 |
| 96000->44100 | 8 | high | 0.268662 | 0.0017460 | 59731 |
| 8000->192000 | 1 | low | 0.048020 | 0.0000531 | 1632 |
| 8000->192000 | 1 | balanced | 0.125638 | 0.0001543 | 4832 |
| 8000->192000 | 1 | high | 0.254655 | 0.0002812 | 9632 |
| 8000->192000 | 8 | low | 0.212999 | 0.0000623 | 2136 |
| 8000->192000 | 8 | balanced | 0.616684 | 0.0001579 | 6232 |
| 8000->192000 | 8 | high | 1.168179 | 0.0003027 | 12376 |
| 192000->8000 | 1 | low | 0.014845 | 0.0000179 | 1033 |
| 192000->8000 | 1 | balanced | 0.040598 | 0.0000532 | 3081 |
| 192000->8000 | 1 | high | 0.080645 | 0.0001050 | 6153 |
| 192000->8000 | 8 | low | 0.068639 | 0.0000331 | 4673 |
| 192000->8000 | 8 | balanced | 0.203831 | 0.0000937 | 13889 |
| 192000->8000 | 8 | high | 0.396146 | 0.0001794 | 27713 |
| 48000->48000 | 1 | low | 0.000240 | 0.0000004 | 0 |
| 48000->48000 | 1 | balanced | 0.000249 | 0.0000003 | 0 |
| 48000->48000 | 1 | high | 0.000241 | 0.0000002 | 0 |
| 48000->48000 | 8 | low | 0.001388 | 0.0000002 | 0 |
| 48000->48000 | 8 | balanced | 0.001433 | 0.0000003 | 0 |
| 48000->48000 | 8 | high | 0.001492 | 0.0000003 | 0 |

Some costly configurations exceed one processing second per audio second on this
host. Choose application limits from actual measurements. Conservative payload
caps are 1,048,576 coefficient and 24,640 ring Doubles, excluding headers/buffers.

## External reference and reproduction

[reference_compare.json](evidence/0.2.0/reference_compare.json) has 60 libsamplerate
0.2.2 comparisons, each with three timing trials. MoonSRC wall time includes CLI
startup, WAV parsing, table initialization, conversion and output. Reference time
is an in-process src_simple call, including internal initialization but excluding
Python buffers/I/O. Do not divide these unequal scopes to claim a speed advantage.
[QUALITY](QUALITY.md) explains signal alignment and frame/precision differences.

```sh
python scripts/bounded_stream.py --report _build/bounded-020.json
python scripts/bounded_stream.py --matrix-only --report _build/matrix-020.json
python scripts/reference_compare.py --fetch-reference --report _build/reference-020.json
```

internal/probe C code measures only time/RSS; MoonBit performs conversion.
Historical initial results remain under evidence/ and do not replace this matrix.
