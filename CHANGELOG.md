# Changelog

## 0.2.0 — local final acceptance, 2026-10-18

- Extend fixed integer rates to 8000..192000 Hz and 1..8 channels, with checked
  exact-phase/coefficient budgets before allocation.
- Add LowLatency, Balanced and HighQuality; scale supports for severe downsampling
  while preserving old Balanced behavior and public error enums.
- Add caller-owned resample_into, float32/extensible WAV, CLI quality/format.
- Optimize >2-channel FIR index reuse without changing per-channel tap order;
  retain measured before/after matrix results.
- Nine examples, 195 tests per backend, 24 E2E flows, three-preset raw quality,
  long streams/matrix timing and 60 libsamplerate black-box comparisons.
- Validate 0.2.0 local archive and actual installed 0.1.0 on three backends.

Prepared for maintainer publication to Mooncakes. See [migration](docs/MIGRATION.md),
[test evidence](docs/TESTING.md) and the [CI workflow](https://github.com/yzy726/MoonSRC/actions/workflows/ci.yml).
Local acceptance notes remain outside the public repository and package.

## 0.1.0 — initial acceptance, 2026-10-17; maintainer publication 2026-10-18

Pure MoonBit polyphase FIR for 44100<->48000, 48000<->16000 and identity,
mono/stereo Double PCM, bounded history, integer clock, partial consumption,
finish/reset, progress/latency/stats, batch facade, PCM16 WAV and native CLI.
Five examples, 126 tests per backend, independent quality/long-stream evidence
and CI configuration. Initially accepted locally, later pushed with permission;
the maintainer subsequently published 0.1.0. Post-publication README formatting
fixes did not change the conversion implementation.
