# Input and resource review — 0.2.0

Runtime flow is validated PCM/config -> FIR/ring -> caller output; or bounded
WAV read -> checked RIFF parser -> same library -> explicit encoder -> new file.
Runtime code has no networking or credentials. Dependencies are toolchain core
and system APIs; optional reference download is development-only, hash-pinned.

| Boundary | Mitigation/evidence |
|---|---|
| Extreme rate/precision/channel count | Bounds and exact phase/coefficient budgets before allocation; co-prime/endpoint tests |
| Count and allocation arithmetic | Checked Int64 counts/window reserve; batch/file budgets; overflow regression |
| NaN/Infinity/float overflow | Atomic normal input checks, numeric fault/reset, binary32 validation before encode allocation |
| WAV/extensible metadata | Containing bounds, exact rate/alignment, GUID/valid bits/mask validation; malformed independent fixtures |
| Channel leakage/state misuse | Private fields; channel-vs-mono, tiny/random blocks, finish/reset tests |
| Existing files/path handling | Exclusive creation and preservation tests, Unicode paths |
| Native ownership | Borrowed FFI arguments, owned Bytes, file/path cleanup; only file I/O and clock/RSS in C |
| Private content | Synthetic signals; no audio upload/content logging; ignored private proposal |

The native reader checks regular-file status and 64-bit size before allocation,
rejects growth/truncation and uses UTF-16 paths on Windows. Core DSP has no unsafe
code/FFI. Fixed table/ring payload does not bound process RSS, runtime allocations
or CPU cost. Whole-file adapters can materialize multiple buffers. Applications
must budget expensive configurations; input/output aliasing is unsupported.

Manual source/dependency/boundary review found no new third-party runtime module.
moon-audit is unavailable here; automated vulnerability scanning or independent
security certification is not claimed. Backend tests do not establish cross-OS
runtime results. Report minimal synthetic reproducers with backend/toolchain;
avoid private recordings. Precise budgets are in [SCOPE](SCOPE.md).
