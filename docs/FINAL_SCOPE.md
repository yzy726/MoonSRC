# MoonSRC 0.2.0 final acceptance scope

The user authorized the final goals from goal.md with version **0.2.0**, replacing the planned 1.0.0 label. The initial implementation was accepted locally; subsequent validation runs the GitHub CI workflow. Mooncakes publication is performed by the maintainer. Published 0.1.0 is retained for compatibility and registry-consumer validation. Reproducible evidence is described in [TESTING](TESTING.md), [QUALITY](QUALITY.md) and [BENCHMARKS](BENCHMARKS.md).

| ID | Required deliverable | Acceptance |
|---|---|---|
| F1 | General fixed rates and 1..8 channels | 8000..192000 Hz; explicit phase/table resource rejection; endpoint and co-prime tests |
| F2 | LowLatency, Balanced, HighQuality | Documented radii/cutoffs/exact phases, measured response/delay/resources; Balanced retains 0.1.0 outputs |
| F3 | Stream and batch APIs | Exact frame counts and whole/chunk equality, finite outputs, tiny buffers, reset/finish and six/eight-channel isolation |
| F4 | PCM16/IEEE float32 WAV | Canonical roundtrips, multichannel extensible headers, strict malformed/overflow/nonfinite and resource validation |
| F5 | Native CLI | Quality/format options, actual generated WAV conversions, safe errors and existing-file protection |
| F6 | Nine runnable examples | Five existing plus multichannel, quality tradeoff, bounded stream and independent registry consumer |
| F7 | Deterministic tests | At least 150 scenarios, 30 named invalid/state cases, 10 E2E flows; all promised backends actually run |
| F8 | Three-preset quality evidence | 48->16 kHz 1 kHz passband absolute error <=0.5 dB, 12 kHz alias relative <=-45/-50/-70 dB for low/balanced/high; grid and boundary results disclosed |
| F9 | Resource/performance/external reference | Ratio/channel/preset timing and storage, actual 1/10-minute processing, source-identified libsamplerate black-box comparison |
| F10 | Independent package consumption | 0.2.0 local archive on native/js/wasm-gc; published 0.1.0 registry compatibility; 0.2.0 registry install explicitly pending publication |
| F11 | Maintenance and delivery | API migration, scope/security/source/license/quality reports, fresh local gates and truthful release status |

## Algorithm and resource decisions

Continue the existing centered Blackman sinc, per-phase DC normalization and integer rational clock. Quality base radii are 32/96/192 input frames; rolloffs are .90/.94/.97. Actual radius is base*max(1,ceil(Fin/(3*Fout))). Exact phases are the reduced output numerator. Configurations above 4096 phases or 1048576 coefficient Double slots are rejected before allocation. The ring holds 2*radius+8 frames. This bounds data payload, not runtime object allocation or OS RSS. Identity copies exactly and has zero lookahead, with no FIR table.

No source-code migration from other audio libraries. The native adapter performs file I/O only; the benchmark probe performs measurements only. External reference code stays under ignored _build and never enters product artifacts. WAV preserves ordinal channels, with no speaker remapping or device/codec functionality. Multichannel canonical files use WAVEFORMATEXTENSIBLE with unspecified speaker mask; input mask validation is documented.

The numerical quality limits concern the declared signals/windows. Frequency sweeps are measured evidence, not an unmeasured all-band guarantee. No hard-real-time or zero-allocation claim. All original valid 0.1.0 behavior remains a regression baseline. Formerly rejected rates/channel layouts becoming supported is an intentional 0.2.0 extension.
