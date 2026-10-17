# Supported scope and resource budgets

The 0.1.0 core accepts only 16000, 44100 and 48000 Hz, with identity or pairs that
include 48000; exactly one/two interleaved channels. It rejects 44100<->16000.
General 8..192 kHz ratios, 3..8 channels, dynamic drift correction, float32 WAV,
multiple quality presets and external-library comparisons remain final-stage
work, not initial features.

All core samples must be finite Double; values beyond [-1,1] are not clipped.
The FIR may produce a value outside the PCM16 range. NumericOverflow is explicit
when finite-input arithmetic cannot be represented. WAV/PCM quantization is a
separate layer, with clamp to [-1,32767/32768], scale by 32768 and ties away from
zero. clipped_samples counts input values changed by this saturation, including
+1.0. Decoding maps signed PCM16 values to value/32768.

| Budget | Bound |
|---|---:|
| Filter radius / taps | 96 / 193 |
| Exact phases | <=160 |
| Ring capacity | 200 frames * channels |
| Core sample payload | <=31280 Double slots / 250240 bytes |
| Stream accepted input | <=Int64.max-193 frames, also checked output count |
| One-shot output and PCM buffers | <=16777216 samples |
| Native WAV input file | <=33554476 bytes, checked before allocation |
| WAV byte adapter rate | integer 1..192000 Hz, but resampling still obeys the core matrix |

The byte-only WAV package accepts RIFF/WAVE, PCM format tag 1, 16-bit little
endian, one/two channels and consistent block/byte-rate metadata. Unknown chunks
with correct padding and data-before-fmt are supported. Compressed/extensible/
float/RF64 formats, duplicate fmt/data, trailing bytes, truncated lengths and
partial frames are rejected. A WAV field accepting a rate does not expand the
core's supported conversion pairs.

The native CLI uses the whole-buffer facade and refuses existing output paths.
It does not encode MP3/Opus/FLAC, change pitch independently, normalize volume,
mix channels, upload audio or provide an audio-device API. Failed disk writes
return failure and may leave a newly created partial output; existing files are
never opened for replacement. The library stream has bounded payload; the CLI
and facade intentionally have larger bounded whole-file allocations.
