# Changelog

## 0.1.0 — local initial acceptance, 2026-10-17

- Pure MoonBit anti-alias polyphase FIR for 44100<->48000, 48000<->16000 and identity,
  mono/stereo Double PCM, bounded history and integer sample clock.
- Explicit partial consumption, caller output, finish/reset, frame/latency/storage
  reporting, and a batch facade through the same streaming engine.
- Explicit PCM16 quantization and validated RIFF/WAVE adapter; bounded native CLI
  with Unicode paths and exclusive output creation.
- Five examples, independent quality/raw evidence, long-stream measurements,
  backend tests, local archive consumer and reproducible CI configuration.

This version is prepared locally. It has not been pushed or published to
Mooncakes. Public repository metadata and registry install verification remain
release work. Broader rate/channel ranges, quality presets and float32 WAV are
not part of this initial version.
