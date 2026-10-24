# Streaming and batch contract — 0.2.0

Config fixes rates, channels and quality. Config::new defaults to Balanced;
Config::with_quality selects LowLatency/Balanced/HighQuality. Integer rates are
8000..192000, interleaved channels 1..8. Exact-table budgets can reject an in-range
pair with ResourceLimit before allocation; no silent ratio/quality replacement.

process accepts ArrayView[Double] and caller-owned FixedArray[Double]. Both
lengths must align to channels. Progress counts complete frames: advance input
by consumed_frames*channels and read only produced_frames*channels output values.
Retain unconsumed input for retry. Input/output must not alias; one stream is
used serially. Alignment/nonfinite checks precede consumption and output writes.

Zero output space consumes no input and produces nothing. With output space,
empty input can drain available output. needs_input/needs_output are conservative
hints and can both be true. Use counts and is_finished to control loops; provide
output space for progress. Small input offers avoid rescanning huge unconsumed
views on backpressure retries.

States: Active -> Finishing -> Finished. The first valid finish starts Finishing
even with no output space. process is rejected thereafter, including empty input.
Repeated finish drains remaining frames and becomes idempotent. Misaligned
finish does not change state. Empty streams finish immediately. reset clears
history/counters, returns Active and reuses arrays with the same configuration.

NumericOverflow may follow partial processing/output writes. It faults the
stream; later process/finish returns InvalidState. Discard that conversion and
reset for a new one. Other normal invalid data is rejected atomically. Checked
FrameOverflow prevents unsafe count/window arithmetic before consumption.

latency reports R input frames, ceil(R*Fout/Fin) output frames and R/Fin seconds,
with quality/rate-dependent R from [ALGORITHM](ALGORITHM.md); identity is zero.
stats reports accepted/emitted frames, live/peak history and fixed coefficient/
ring Double slots. Final length is ceil(N*Fout/Fin), zero-extended at both ends.

resample returns an Array through the same engine. resample_into writes caller
storage and returns output frames, leaving its unused tail intact. Alignment,
finite input, output capacity and the 16,777,216-output-sample budget are checked
before writes. Insufficient capacity returns ResourceLimit. NumericOverflow can
leave partial output, which must be discarded. Both facades allocate a stream
and small scratch buffer; caller storage does not imply zero allocation. Use
bounded process/finish blocks for long audio.

See [chunked example](../examples/chunked_equivalence/main.mbt), [isolated
consumer](../scripts/consumer.py) and [migration](MIGRATION.md).
