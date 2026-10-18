# Verification and reproduction

Initial local verification uses Moon 0.1.20260920, moonc 0.10.14+7d59c7ec9,
moonrun 0.1.20260920, Node 22.19.0, Python 3.13.5 and the Windows native C backend.
New DSP, stream and byte-adapter behavior started with failing tests. Tests use
assertions rather than debug-output snapshots; no snapshots were refreshed to
hide numerical failures.

Run in the source root:

```sh
moon fmt --check
moon check --target native --deny-warn --warn-list +73
moon check --target js --deny-warn --warn-list +73
moon check --target wasm-gc --deny-warn --warn-list +73
moon build --target native --deny-warn
moon build --target js --deny-warn
moon build --target wasm-gc --deny-warn
moon test --target native --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon info --target native
moon fmt
```

Then run the five Python entrypoints e2e.py, quality.py, run_examples.py,
bounded_stream.py and consumer.py under scripts/. They use only the Python
standard library, build actual native-release binaries, fail on unmet assertions
and optionally write --report JSON to a chosen path. Verification output and
current counts are recorded in LOCAL_ACCEPTANCE and evidence/final_checks.json.

Coverage includes 70 individually named rate/channel/length matrix tests; every
supported pair in mono/stereo; zero/one/short input; single-frame output; phase/DC/
impulse response; finite overflow and nonfinite inputs; state/reset behavior;
whole/chunk equality; seeded partitions; PCM16 endpoints/rounding; and malformed
WAV metadata/chunks. More than 15 distinct error/state conditions have executable
checks. See *_test.mbt (public behavior) and *_wbtest.mbt (private phase/filter
invariants). The executable README example is a named mbt check test.

CLI evidence includes 12 end-to-end flows: help, generated fixtures, stereo
44100->48000 with isolation, exact identity, mono 48000->16000, existing-output
preservation, malformed input, argument/path errors, independent direct sinc
reference, Unicode paths, oversized/nonregular files and generator budgets.
run_examples additionally compares the library WAV example with CLI output byte
for byte. Every fixture is generated from declared formulas.

consumer.py packages the source locally, checks package exclusions, extracts into
a fresh temporary directory, writes a moon.work there and uses a separate module
with only public root/PCM/WAV imports. It runs native/js/wasm-gc. This verifies the
local archive; Mooncakes publication and registry installation are deferred by
user instruction. It does not change the source project's workspace membership.

CI configuration uses the official versioned installer with
0.10.14+7d59c7ec9. Its Linux bundle was checked reachable during setup. The installer
syntax follows the [official project workflow](https://github.com/moonbitlang/llvm.mbt/blob/master/.github/workflows/check.yaml).
CI has backend matrix and integration jobs, with the same local commands and
saved evidence. Remote runs and their exact commits are available in
[GitHub Actions](https://github.com/yzy726/MoonSRC/actions/workflows/ci.yml).
The existing Copilot setup workflow is preserved. Optional local hooks are
documented in .githooks/README.md.

For the first quality pass, an over-short uniform DC trim affected 3x interpolation;
the test window was corrected to actual latency. Core quality thresholds were
unchanged. For a correct steady comparison always exclude the complete boundary
support. Other diagnostics corrected current-toolchain syntax/deprecations;
failures were resolved rather than disabling warnings or deleting acceptance
cases. Cross-backend checks use the same deterministic inputs and tolerances.
