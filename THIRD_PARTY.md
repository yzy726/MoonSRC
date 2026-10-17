# Sources, licenses and provenance

MoonSRC implementation, synthetic signals, direct reference validator and tests
were created for this project. The filter is an independent implementation of
standard windowed-sinc convolution, a Blackman window, per-phase DC normalization
and rational integer time stepping. No libsamplerate, SpeexDSP, SDL or closed-source
DSP code was copied, translated, linked or invoked by conversion code.

MoonBit core is supplied by the installed toolchain (Apache-2.0, International
Digital Economy Academy; see https://github.com/moonbitlang/core). Its math,
arrays, UTF-8, buffer and environment APIs are used as normal dependencies.
Native C files in internal/nativeio and tools/bounded_stream implement only file
I/O and measurement, against the installed MoonBit FFI header and system APIs.
No separate third-party Mooncakes dependency is required. Python verification
uses the standard library; no NumPy/SciPy/audio package is bundled.

All PCM/WAV fixtures and committed floating output are generated from the formulas
in QUALITY.md and source tests. They contain no private recordings or downloaded
samples, and are distributed under the project's Apache-2.0 license. Full raw
outputs and SHA-256 values are in docs/evidence. No license terms were inferred
from audio heard or obtained from an unverified site.

The design plan names [libsamplerate](https://github.com/libsndfile/libsamplerate)
and [SpeexDSP](https://github.com/xiph/speexdsp) as context/possible future black-box
comparisons. This initial implementation does not claim their quality or speed.
If code or data is imported later, record exact version, file, author, license,
modifications and redistribution notices before including it.
