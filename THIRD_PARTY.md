# Sources, licenses and provenance

MoonSRC conversion, synthetic signals, direct reference checker and tests were
created for this project. It independently implements standard windowed sinc,
Blackman window, per-phase DC normalization and integer rational time stepping.
No libsamplerate, SpeexDSP, SDL or closed-source DSP code was copied, translated,
linked or invoked by product conversion code.

Toolchain MoonBit core is Apache-2.0, International Digital Economy Academy; see
[moonbitlang/core](https://github.com/moonbitlang/core). Math/array/UTF-8/buffer/
environment APIs are ordinary dependencies. C in internal/nativeio is file I/O;
internal/probe is time/RSS measurement using system APIs and MoonBit FFI headers.
No extra third-party Mooncakes runtime module is required. Python validators use
the standard library, without bundled NumPy/SciPy/audio packages.

All committed PCM/WAV and floating evidence is generated from recorded formulas.
There are no private recordings or downloaded audio samples; project-generated
data is under Apache-2.0. Reports and raw hashes are under docs/evidence/0.2.0;
the 0.1.0 baseline is retained.

## External measurement reference

scripts/reference_compare.py invokes official **libsamplerate 0.2.2** via ctypes
only as a black-box reference, using Best Sinc Interpolator (converter 0),
src_simple. The [official Windows release ZIP](https://github.com/libsndfile/libsamplerate/releases/download/0.2.2/libsamplerate-0.2.2-win64.zip)
is kept under ignored _build and verified with SHA-256
`35686fa4cae633a7418e40eb4cc520c4d9c53438cbdd75007b10859e468bc5da`.
Its share/doc/libsamplerate/license.md records the 2016 relicensing to BSD
2-clause. Upstream artifacts/docs/notices remain in the local archive; they are
not redistributed in Git or the Mooncakes product ZIP.

The [reference report](docs/evidence/0.2.0/reference_compare.json) records release,
DLL hash/version, ABI sizes, identical-input hashes, alignment, frame differences
and timing scopes. This adds no DSP dependency to the product and does not
establish universal quality or speed parity. See [official API docs](https://libsndfile.github.io/libsamplerate/api_simple.html).

[SpeexDSP](https://github.com/xiph/speexdsp) is context only; no implementation/data
was imported. Any future code/data incorporation requires exact version/files,
source/license, changes and redistribution notices before inclusion. Unknown
audio or AI-generated provenance claims are not accepted as license evidence.
