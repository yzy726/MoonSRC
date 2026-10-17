# Contributing

Use the documented MoonBit version and preserve ///| block organization. New
behavior needs a failing test first; regressions need a minimal reproducer. Prefer
public blackbox tests, with whitebox tests for private numerical/state invariants.
Use assert_eq/explicit tolerances for stable results. Do not weaken quality
thresholds or refresh snapshots to hide changed behavior.

Before a local commit: moon info --target native, moon fmt, moon fmt --check,
moon check --target native --deny-warn and moon test --target native --deny-warn.
Run js/wasm-gc and relevant independent Python checks for DSP/API changes. Review
generated .mbti changes deliberately. Keep commits scoped and use Conventional
Commits. Optional hook setup is in .githooks/README.md.

Document new public functions, frame/time/error behavior and resource budgets.
Do not import audio or code without provenance/license review. Keep measurement
scripts separate from the conversion implementation. Do not claim runtime/OS
support without actual runs, or source-registry installation from a local
workspace test. Preserve raw failures and explain test-window corrections.
