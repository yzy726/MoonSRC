# Algorithm and time contract

The core is independently implemented in MoonBit. C is confined to native file
I/O and timing/RSS probes; Python verifies outputs and never supplies the product
conversion algorithm. Internal packages are implementation details.

For N input frames, frame n is at n/Fin. Output m is at m/Fout while
m/Fout < N/Fin, so final length is ceil(N*Fout/Fin). Config::output_frames uses
quotient/remainder decomposition, checking the final Int64 addition/product
without overflowing an intermediate N*Fout. Empty input produces no output.

Reduce Fout/Fin to p/q. The next timestamp is position + phase/p in input frames.
For every emitted frame, s = phase + q, position += floor(s/p), phase = s mod p.
Only the filter evaluation uses floating point; the sample clock never does.
Identity uses exact copying and skips FIR allocation/latency.

For j = -96..96 and phase r, put x = j-r/p, cutoff = 0.94*min(1,Fout/Fin).
The unnormalized coefficient is

    cutoff * sin(pi*cutoff*x)/(pi*cutoff*x)
           * (0.42 + 0.5*cos(pi*x/96) + 0.08*cos(2*pi*x/96))

for |x|<96, and zero otherwise. At x=0 the sinc limit is 1. Each phase is
normalized by its own coefficient sum. Output channel c is the sum of these
coefficients times input[position+j,c]. There is no channel mixing.

The exact table has p phases, at most 160, each with 193 coefficients. There is no
phase interpolation and no coefficient computation in process/finish. With the
initial supported rates the table is finite and its largest payload is 30,880
Doubles. The state owns a 200-frame interleaved ring; at most 193 frames are live.
The maximum fixed sample payload is (30880+400)*8 = 250240 bytes for stereo
44100->48000. Object/array headers and caller buffers are separate.

The centered FIR waits for 96 future input frames. Input before zero and after
end-of-stream is zero. finish does not append a convolution tail: it emits only
valid output timestamps. Finite DC/tones can have expected onset/ending
transients. Lookahead is buffering delay, not a shift of the output time axis.

No core clipping or normalization of audio level occurs. All finite input
amplitudes are allowed; an unrepresentable arithmetic result returns
NumericOverflow, faults the instance, and requires reset. Invalid frames and
nonfinite input are rejected before state mutation. A total stream input limit
of Int64.max-193 reserves safe signed arithmetic for the FIR window; output frame
arithmetic is also checked before accepting each input view.

The independent direct sinc reference in scripts/e2e.py compares the native CLI
with an independently evaluated convolution, within one PCM16 least significant
bit. Phase normalization/symmetry/first moment and measured signal response have
separate tests. These checks complement the fixed quality experiment in QUALITY.
