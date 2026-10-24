# MoonSRC 0.2.0 requirements and decisions

On 2026-10-18 the user authorized final goals from goal.md with version 0.2.0.
The initial architecture continues: pure MoonBit library, native WAV CLI as thin
adapter. Consumers are MoonBit audio/voice applications; no external production
deployment or listening-panel acceptance is claimed.

| Decision | Final requirement |
|---|---|
| Metadata | Ag108/MoonSRC; github.com/yzy726/MoonSRC; Apache-2.0 |
| Core | MoonBit fixed-rate PCM stream; native/js/wasm-gc actually run |
| PCM | Finite Double, interleaved 1..8 channels, no implicit clipping |
| Rates/budgets | 8000..192000 Hz; <=4096 exact phases and <=1,048,576 coefficient Doubles, reject before allocation |
| Presets | LowLatency/Balanced/HighQuality, base radii 32/96/192, rolloffs .90/.94/.97, downsampling-scaled support |
| Time | Integer clock, ceil(N*Fout/Fin), zero extension, lookahead without extra output delay/tail |
| State | Partial consumption, caller output, finish/reset, progress/latency/stats, atomic normal errors |
| Batch | Same stream engine, resample and resample_into; <=16,777,216 output samples |
| WAV | PCM16/IEEE float32/extensible, ordinal channels, explicit quantization; <=33,554,476 bytes |
| API | Original signatures/records/error enums retained; document newly accepted inputs and variable latency |

[FINAL_SCOPE](FINAL_SCOPE.md) freezes F1..F11, including >=150 scenarios, >=30
invalid/state cases, >=10 E2E flows, nine examples, fixed three-preset quality
gates, real 1/10-minute storage measurements, CPU matrix and source-identified
external reference. Methods/thresholds are in [QUALITY](QUALITY.md). New behavior
was implemented from failing tests; limits were not relaxed to hide failures.

Initial 0.1.0 restricted common ratios, mono/stereo and PCM16 with one Balanced
filter. It was published by the maintainer and remains a regression baseline.
The current local archive tests new APIs; a separate registry install tests old
compatibility. See [MIGRATION](MIGRATION.md).

Scoped commits use yzy726 without changing global Git identity. GitHub CI
validates the source before the maintainer publishes 0.2.0 to Mooncakes. Local
acceptance notes remain ignored; public evidence and reproduction commands are
linked from [TESTING](TESTING.md).
