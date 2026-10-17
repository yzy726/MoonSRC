# Input and resource review

Data flow is untrusted PCM/config -> validated Config -> FIR/ring -> caller output;
or WAV file -> bounded native read -> checked RIFF parser -> PCM -> same library
-> explicit quantizer -> exclusive new output file. There is no network or
credential processing in runtime code. Source dependencies are MoonBit core and
system C runtime only; no third-party Mooncakes module remains.

| Boundary / concern | Mitigation and evidence |
|---|---|
| Spoofed WAV metadata or chunk lengths | Int64 u32 decoding, containing-bound checks before conversion/allocation, alignment/byte-rate checks; WAV error tests |
| State tampering or channel mixing | Private Config/Resampler fields, distinct per-channel indexing, stereo isolation and reset tests |
| Denial via extreme sizes/configuration | Initial rate/channel allowlist, bounded phases/ring, checked frame arithmetic, facade and WAV budgets |
| File replacement | Exclusive create (wbx), including existing paths; end-to-end preservation test |
| Private data exposure | Synthetic fixtures only, metadata-only CLI output, no audio upload/logging |
| Resource/ownership failure | Borrowed path/content FFI arguments; owned returned Bytes; file descriptors and temporary wide paths closed/freed on all read branches |

Only the native boundary uses C, with MoonBit's #borrow and explicit ownership.
The reader checks regular-file status and 64-bit size before allocating sample
bytes, rejects growth/truncation during reading, and uses UTF-8 paths converted
to UTF-16 on Windows. The DSP has no unsafe code or FFI. Tests include oversized
files, directories, malformed lengths, Unicode paths, NaN/Infinity and state
misuse. Normal malformed input must not panic or silently succeed.

A manual boundary/source/dependency review was performed. moon-audit is not
installed, so automated vulnerability/static-audit coverage is not claimed.
No dependency CVE scan result is fabricated. Native portability beyond this
Windows host is prepared in CI, and is not described as a locally tested OS.
For security reports, include a minimal synthetic reproducer and the exact
backend/toolchain; avoid attaching private recordings.
