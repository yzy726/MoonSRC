# Algorithm and time contract — 0.2.0

The algorithm is independently implemented in MoonBit. C implements file I/O
(internal/nativeio) and clock/RSS (internal/probe) only. Python verifies output;
it does not perform product conversion. Identity copies exactly with no FIR.

For N input frames, input n occurs at n/Fin. Output m occurs at m/Fout while
m/Fout<N/Fin, so final length is ceil(N*Fout/Fin). Checked quotient/remainder
arithmetic avoids intermediate N*Fout overflow. Reduce Fout/Fin to p/q; for each
output s=phase+q, position+=floor(s/p), phase=s mod p. Only convolution uses
floating point; the sample clock uses integers.

| Quality | Base radius B, input frames | Rolloff a |
|---|---:|---:|
| LowLatency | 32 | .90 |
| Balanced | 96 | .94 |
| HighQuality | 192 | .97 |

R=B*max(1,ceil(Fin/(3*Fout))), cutoff=a*min(1,Fout/Fin). For j=-R..R and phase r,
x=j-r/p; the unnormalized coefficient is:

```text
cutoff * sinc(cutoff*x) * (0.42 + 0.5*cos(pi*x/R) + 0.08*cos(2*pi*x/R))
sinc(t)=sin(pi*t)/(pi*t), sinc(0)=1
```

It is zero for |x|>=R. Each phase is divided by its coefficient sum. Output
channel c sums only input channel c. The table uses exact phases without phase
interpolation or hot-path coefficient construction. The >2-channel loop reuses
history indexing across channels but preserves each channel's tap order;
mono/stereo retain the original loop.

Creation rejects p>4096 or p*(2R+1)>1,048,576 before allocating the table. Ring
capacity is (2R+8)*channels; live history <=2R+1 frames. Across the domain R<=1536,
so conservative payload caps are 8 MiB coefficients plus 24,640 ring Doubles.
Headers, caller buffers and runtime allocation are separate. Identity has no FIR.

The centered FIR waits R future input frames. Both boundaries use zero extension.
finish emits only valid timestamps, without an appended convolution tail.
Lookahead is buffering delay, not an output-time shift: R input frames,
ceil(R*Fout/Fin) output frames and R/Fin seconds. Boundary ringing is expected.

Input count is limited to Int64.max-(2R+1); output arithmetic is checked before
acceptance. Normal invalid input is atomic. Finite input can overflow arithmetic;
NumericOverflow faults the stream and requires reset. Core levels are not clipped.

Balanced remains bitwise unchanged on original supported scenarios; original raw
quality output is retained. Severe new ratios intentionally use larger support.
Direct convolution, per-channel mono equivalence, integer-clock and filter tests
complement [signal evidence](QUALITY.md).
