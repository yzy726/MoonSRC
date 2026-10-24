# Upgrading from 0.1.0 to 0.2.0

0.2.0 is a locally verified candidate, not yet published. Config::new, resample,
process/finish/reset, progress/stats/latency, PCM16 and WAV encode/decode
signatures remain. Original error enums retain every variant, so exhaustive
matches compile. An isolated consumer checks the original WavError match against
both installed 0.1.0 and the local archive.

Config::new remains Balanced. Old valid rate/channel configurations retain
coefficients, frame counts, timestamps and outputs; original quality files match
bitwise. Previously rejected rates/channels/float WAV can now succeed. Consumers
requiring a narrower policy must validate it themselves. UnsupportedRatio stays
for compatibility; new in-range table-budget rejection is ResourceLimit.

Additions: Config::with_quality(Fin,Fout,channels,Quality), Config::quality(),
Quality::{LowLatency,Balanced,HighQuality}, resample_into for caller output,
wav::encode_float32 and float/extensible decode, CLI --quality/--format.
Float32 overflow uses existing NonFinite(index); PCM16 clipping is unchanged.

Core rates are 8000..192000 with 1..8 channels, subject to exact-table budgets.
Query latency rather than assuming 96 frames: qualities/severe ratios change it.
Channels are ordinal; speaker metadata is not retained. Float32 file sample
capacity is smaller at the same byte limit. Caller-owned batch output still
allocates internal stream/scratch and shares the batch budget.

See [SCOPE](SCOPE.md), [STREAMING](STREAMING.md) and [TESTING](TESTING.md). After a
separately authorized publication, run consumer.py --registry-version 0.2.0 for
registry delivery. A local archive result does not establish publication. Future
incompatible changes require explicit version review and migration notes.
