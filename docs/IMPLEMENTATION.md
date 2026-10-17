# MoonSRC initial acceptance implementation plan

Source: goal.md sections 6-9, 12-16, plus docs/requirements.md.
All commits stay local and use yzy726. Each task is a submission checkpoint.

## Phase 0 / Batch 0: baseline
1. Record requirements, test strategy, commit identity and implementation plan;
   preserve the existing skeleton and license. Verify native skeleton builds.

## Phase 1 / Batch 1: model and rational clock
2. Create model.mbt, clock.mbt and model_test.mbt/clock_wbtest.mbt.
   Implement Config::new(Int,Int,Int)->Result[Config,ResampleError], checked
   Config::output_frames(Int64), private integer rational phase arithmetic.
   Test every allowed ratio/channel and invalid inputs/overflow.
   RED: moon test --target native -f 'model/*'; then implement and full verify.

## Phase 2 / Batch 2: bandlimited filter
3. Create internal/filter/filter.mbt and internal/filter/filter_wbtest.mbt. Bounded internal make_filter(phases,cutoff)
   constructs normalized 193-tap exact phase tables. Test DC normalization,
   symmetry, fractional phase and 48->16 rejection before implementation.
   RED: moon test --target native -f 'filter/*'; then full verify.

## Phase 3 / Batch 3: streaming engine
4. Create stream.mbt and stream_test.mbt. Resampler::new/process/finish,
   Progress, Latency, Stats, reset and bounded ring storage. Test empty/tiny
   streams, partial consumption, finish misuse and chunk equivalence first.
   RED: moon test --target native -f 'stream/*'; then full verify.
5. Create api.mbt and api_test.mbt. resample(Config,ArrayView[Double]) facade
   reuses process/finish. Test all ratios, stereo isolation, seed-based chunks,
   1-frame blocks and tiny output buffers. Verify frame counts and tolerance.
   RED: moon test --target native -f 'api/*'; then full verify.

## Phase 4 / Batch 4: byte adapters
6. Create pcm/moon.pkg, pcm/pcm.mbt and pcm/pcm_test.mbt. Explicit finite PCM16
   quantization, saturation, roundtrip and clipping counts. Test first.
7. Create wav/moon.pkg, wav/wav.mbt and wav/wav_test.mbt. decode(Bytes) and
   encode(rate,channels,samples) with RIFF limits and unknown-chunk padding.
   Test valid/invalid/truncated headers and roundtrips before implementation.
   Verify adapters using moon test --target native and generated interfaces.

## Phase 5 / Batch 5: native CLI and end-to-end
8. Replace cmd/main with native moonsrc convert/fixture/help, file I/O errors,
   output overwrite protection and PCM16 header/length reporting. Create
   scripts/e2e.py that expects the CLI before implementation. Run >=5 E2E
   flows including library vs CLI sample equality and malformed WAV rejection.

## Phase 6 / Batch 6: evidence and examples
9. Create reusable synthetic-signal test support, five examples, a native quality
   exporter and scripts/quality.py independent projection/RMS analyzer. Add
   failing passband/alias tests, full deterministic matrix and raw quality data.
   Run examples and native/js/wasm-gc tests. Keep every measured result.
10. Add long-stream/storage probe and report 1-minute vs 10-minute internal
    storage and timing with machine/toolchain metadata. Test stream bounds.
    Measure actual processing; do not count caller output as internal memory.

## Phase 7 / Batch 7: delivery and maintenance
11. Add CI using moonbit-ci, local checks, an independent local consumer and
    source/algorithm/quality/streaming/testing/security/contribution docs.
    Run README commands, Python independent checks, all promised backends,
    moon info then moon fmt; review every generated interface and git diff.
    Commit local acceptance evidence and a clear publication-deferred status.

## Verification per code task
moon info --target native
moon fmt
moon fmt --check
moon check --target native --deny-warn --warn-list +73
moon test --target native --deny-warn
Review git diff plus generated .mbti files. Cross-backend runs are required at
filter/stream integration and final acceptance. Every task records test results
in .agent-workplace/state/checkpoint.json and docs/TESTING.md at delivery.

Delivery status: all eleven local steps completed; registry publication and Git push are explicitly excluded by the user. See LOCAL_ACCEPTANCE.md and evidence/final_checks.json.
