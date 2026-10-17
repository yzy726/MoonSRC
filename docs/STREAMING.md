# Streaming API

Config::new validates the initial rate matrix and one/two channels. Its fields
and every mutable Resampler field are private. Create one Resampler per unrelated
PCM stream. Double input is interleaved by frame; all public counters use frames.
Buffers must contain a whole number of frames. The caller owns both buffers.

A correct consumer loop is:

1. Offer a bounded input view and a FixedArray[Double] output buffer.
2. Read exactly produced_frames*channels output samples.
3. Advance the input by consumed_frames*channels, retrying the unconsumed suffix.
4. Continue even if only output was produced or only input was consumed.
5. After all input was actually consumed, call finish repeatedly until finished.

process validates the complete offered view before mutation, including samples
it might not consume this call. InvalidState, MisalignedInput/MisalignedOutput,
NonFinite and preflight FrameOverflow do not consume input. Input/output memory
must not alias. The caller must retain the unconsumed input and must not mutate
an input view during a call. The instance is single-stream and not synchronized
for concurrent calls.

A zero-capacity output buffer consumes/produces nothing. An empty input view can
drain output whose lookahead is already available. The needs_input/needs_output
flags are conservative readiness hints and can both be true; use the counts and
is_finished for loop control. Never repeatedly call with zero output capacity
expecting forward progress. Small bounded offers also avoid rescanning a large
unconsumed view on every backpressure retry.

State transitions are Active -> Finishing -> Finished. The first valid finish
starts Finishing even with zero output capacity. process is rejected thereafter,
including empty input. Repeated finish drains pending frames and becomes
idempotent. Misaligned finish output does not start finishing. Empty streams
finish immediately. reset discards previous history/counters, returns to Active
and reuses allocations.

NumericOverflow can occur after partial processing and output writes; the stream
then faults, both process and finish return InvalidState, and the caller must
discard that failed conversion and reset before starting a new stream. Other
normal invalid data is validated atomically before consuming it.

latency reports 96 input frames and ceil(96*Fout/Fin) output frames, except identity
which reports zero. It also reports seconds. stats reports accepted input,
emitted output, current/peak live history and fixed coefficient/ring Double slots.
No output is prefixed to compensate latency; final frames follow the timestamp
formula in ALGORITHM. Zero extension explains boundary ringing on short files.

resample is a convenience consumer of exactly this process/finish implementation,
with a 16,777,216 output-sample payload cap. Its input/output arrays can be large;
use the streaming interface for long audio. Examples and scripts/consumer.py
contain executable loops with backpressure and final flushing.
