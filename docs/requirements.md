# MoonSRC 0.1.0 requirements

The user requested implementation of the initial acceptance goals in goal.md on
2026-10-17, with a local Git commit after each completed step, authored and
committed as yzy726. The user explicitly selected local acceptance only:
no Git push and no Mooncakes publication. Publication and registry installation
are consequently deferred, and must not be claimed as completed.

## Design baseline

- Primary product: pure MoonBit library; native WAV CLI is a thin adapter (plan A).
- Consumers: MoonBit audio/voice applications; initial synthetic PCM and WAV
  consumers are included. No external production consumer has been identified.
- Keep the existing module name Ag108/MoonSRC and Apache-2.0 license.
- Intended library targets: native, JavaScript, wasm-gc; claim only tested targets.
- Support 44100 <-> 48000, 48000 <-> 16000, and identity at 16000/44100/48000 Hz;
  one or two interleaved channels; finite Double samples, without core clipping.
- Output timestamps m/Fout < N/Fin; total frames = ceil(N*Fout/Fin).
- Zero extension at both boundaries. The centered FIR uses future input;
  latency is lookahead, not additional output frames. Identity is exact passthrough.
- Blackman-windowed sinc; radius 96 input frames; cutoff 0.94*min(1,Fout/Fin).
  Exact rational phase table, maximum 160 phases and 193 taps per phase.
- Integer sample clock, bounded history, caller-owned output. All progress uses
  complete frames. Zero output capacity makes no progress and consumes no input.
- Nonfinite or misaligned input errors are atomic (validate before state mutation).
- finish drains ceil(N*Fout/Fin), is repeatable and eventually idempotent;
  process after finish starts is an error; reset explicitly starts a fresh stream.
- Resource counters use Int64, checked before arithmetic. Finite samples whose
  filtering result cannot be represented return an explicit numeric error.
- A root package separates model/clock/filter/stream/facade by file; pcm and wav
  are independent packages. WAV handles bytes only; native CLI owns file I/O.
  Dependencies flow model -> clock/filter -> stream -> facade -> CLI/examples.
  Keep implementation helpers private to avoid exporting incidental internals.

## Public API baseline

- Config::new(input_rate, output_rate, channels) -> Result[Config, ResampleError]
- Config::output_frames(Int64) -> Result[Int64, ResampleError]
- Resampler::new(Config) -> Resampler
- Resampler::process(ArrayView[Double], FixedArray[Double]) -> Result[Progress, ResampleError]
- Resampler::finish(FixedArray[Double]) -> Result[Progress, ResampleError]
- Resampler::reset(), latency(), stats(), is_finished()
- resample(Config, ArrayView[Double]) -> Result[Array[Double], ResampleError]
- pcm: explicit PCM16 quantization/dequantization.
- wav: decode/encode PCM16 RIFF/WAVE with classified errors and size limits.

## Acceptance and maintenance

At least 60 deterministic scenarios, 15 error/state scenarios, 5 end-to-end flows
and 5 runnable examples. Test signal definitions and analysis windows are fixed
before quality measurements: 48000 input frames, amplitude 0.5, trim 256 output
frames at each end; coherent projection at 1 kHz and aliased 4 kHz; <=0.5 dB
passband error and <=-50 dB alias relative to the 1 kHz output. Independent Python
analysis verifies actual MoonBit output. Compare internal storage at 1 and 10
minutes with the same configuration. Document actual timing and allocations.

New behavior uses failing tests first. Use blackbox public behavior tests and
whitebox tests only for phase/filter invariants. Deterministic seeds, no private
recordings. Each step passes fmt/check/test and interface review before commit.
Maintain versioned generated interfaces, automated quality checks and sources.
0.1.0 is an initial API baseline; future incompatible changes need release notes.
