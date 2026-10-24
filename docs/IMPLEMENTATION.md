# Implementation delivery map — 0.2.0

The final implementation retains the initial architecture. Each verified task
used a scoped codex/ branch and yzy726 commit. Local verification is followed by
GitHub CI; Mooncakes publication is performed by the maintainer.

| Task | Source/evidence |
|---|---|
| Config, presets, resource budgets | model.mbt, final_model_test.mbt |
| Dynamic exact-phase FIR | internal/filter and final filter tests |
| Stream/caller batch, isolation | stream.mbt, api.mbt, final_api tests |
| Float32/extensible WAV | wav/wav.mbt, final_wav_test.mbt |
| Native CLI | cmd/main, scripts/e2e.py, 24 flows |
| Nine examples | examples, run_examples.py, shared internal/probe |
| Three-preset quality | tools/quality, quality.py, raw binary64 and frequency/DC/impulse reports |
| Performance and optimization | bounded_stream.py, before/after matrix and actual 1/10-minute streams |
| External reference | reference_compare.py, official pinned libsamplerate 0.2.2 |
| Independent consumption | consumer.py, fresh 0.2.0 archive + installed 0.1.0 and old exhaustive error match |
| Delivery | README, migration/quality/resource/source/testing docs and local report |

Production behavior was preceded by failing tests; task gates included format,
type, functional and generated-interface review. Final gates build/run all three
backends. Command results are in evidence/0.2.0/final_checks.json.
[FINAL_SCOPE](FINAL_SCOPE.md) defines the public contract; [TESTING](TESTING.md)
links reproducible evidence. Local acceptance notes and work checkpoints remain ignored.
