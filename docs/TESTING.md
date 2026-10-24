# Verification and test organization — 0.2.0

Final candidate: **195 tests per backend**, including the checked README.
[test_inventory.json](evidence/0.2.0/test_inventory.json) lists every name and a
conservative 63 explicitly named /invalid or /error cases, exceeding the
required 30 without counting other state/edge tests. The shared suite runs on
native/js/wasm-gc; this is not 585 distinct scenarios.

Coverage includes config/clock/budgets, filters/presets/severe ratios, exact
whole/chunk equality, fixed seeds/one-frame/tiny buffers, 1..8 channels, independent
mono equivalence, finish/reset/fault, overflow, PCM16 and malformed/canonical
float32/extensible WAV. Assertions and explicit tolerances fix behavior. Original
valid 0.1.0 scenarios remain regressions; invalid cases newly supported by 0.2.0
were deliberately updated.

```sh
moon fmt --check
moon check --target native --deny-warn --warn-list +73
moon build --target native --deny-warn
moon test --target native --deny-warn
moon check --target js --deny-warn --warn-list +73
moon build --target js --deny-warn
moon test --target js --deny-warn
moon check --target wasm-gc --deny-warn --warn-list +73
moon build --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
python scripts/e2e.py --report _build/e2e-020.json
python scripts/run_examples.py --report _build/examples-020.json
python scripts/quality.py --keep-raw _build/quality-020 --report _build/quality-020.json
python scripts/consumer.py --report _build/consumer-020.json
python scripts/consumer.py --registry-version 0.1.0 --report _build/registry-010.json
moon doc
moon info --target native
moon fmt
moon fmt --check
```

[24 E2E flows](evidence/0.2.0/e2e.json) check direct sinc values, three presets,
multichannel float/extensible, severe ratios, nonfinite errors, Unicode and
existing-file preservation. [Nine examples](evidence/0.2.0/examples.json) make
real assertions, including byte-identical library/CLI WAV output.

The [0.2.0 archive consumer](evidence/0.2.0/consumer_local.json) uses new eight-
channel/quality/float32/caller-output APIs on all backends. The [installed 0.1.0
consumer](evidence/0.2.0/consumer_registry_0.1.0.json) verifies old APIs and an
exhaustive WavError match without local library membership. Source-tree examples
use the local library; only the registry validator is an actual installed test.
Archive checks exclude private material and preserve the root workspace.

[Final commands](evidence/0.2.0/final_checks.json) retain exit codes, counts and
timestamps. Long-stream/matrix/reference measurements were run after relevant
code changes and retained; unchanged-path applicability is explained in
[BENCHMARKS](BENCHMARKS.md). The retained local reports describe the 2026-10-18
snapshot. Current remote results are in [GitHub Actions](https://github.com/yzy726/MoonSRC/actions/workflows/ci.yml);
old-version CI is not used as final-version evidence. Local acceptance notes
are excluded from Git and package archives.
