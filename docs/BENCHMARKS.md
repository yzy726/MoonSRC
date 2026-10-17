# Initial resource and timing measurements

Recorded environment: Intel Core i7-14700HX (20 cores, 28 logical processors),
Windows 11 build 22631, moon 0.1.20260920, moonc 0.10.14+7d59c7ec9,
Python 3.13.5, Node 22.19.0. The native-release probe uses one stream on one
execution thread; it does not use all cores.

Run `python scripts/bounded_stream.py`. Each configuration runs in a fresh
process with fixed 257-frame caller input and 128-frame caller output. Input is
constant 0.25 in every channel, a 48000-input-frame warmup precedes reset, and
monotonic timing surrounds actual process/finish work. The checksum reads all
emitted samples so audio work cannot be replaced by counting. Filter construction
and process startup are excluded from the native elapsed measurement; Python
wall time including process startup is also recorded. One run per configuration,
no percentile/confidence-interval claim and no fixed performance guarantee.

| Configuration | Input duration | Output frames | Fixed Double slots | Live history peak | Elapsed |
|---|---:|---:|---:|---:|---:|
| 48000->16000, mono | 60 s | 960000 | 393 | 193 frames | 0.6601391 s |
| 48000->16000, mono | 600 s | 9600000 | 393 | 193 frames | 7.2213305 s |
| 44100->48000, stereo | 60 s | 2880000 | 31280 | 193 frames | 4.0123870 s |

These 1/10-minute comparisons test the same ratio/channel/filter and actually
process every frame. Ring plus coefficient payload is 3144 bytes for the mono
configuration; longer input does not increase either allocation. The third run
also verifies long fractional-ratio counting and the maximum phase table.

OS current and peak resident working set are separately measured. The recorded
mono short process stayed at 6,631,424 bytes before/after; the long process stayed
at 6,254,592 bytes. Separate process baselines differ. This includes runtime,
code and allocator overhead, and is not equated with the 3144-byte payload.
Windows uses K32GetProcessMemoryInfo, Linux uses /proc/self/statm/getrusage;
only the Windows measurements are currently recorded. The C probe does timing
and process statistics only.

Hot paths reuse fixed sample/coefficient arrays; reset does not grow them.
Progress/Result/Stats values and views can cause runtime object allocation.
Per-call allocation counts were not instrumented, and no zero-allocation or hard
real-time guarantee is made. The internal payload/storage invariants and process
RSS are measured separately. Caller output arrays and the convenience facade's
whole-file allocations are excluded from the core bound.

Raw timing, counts, RSS, checksum and environment are in
[evidence/bounded_stream.json](evidence/bounded_stream.json). No external-library
speed or quality comparison has been performed for this initial version.
