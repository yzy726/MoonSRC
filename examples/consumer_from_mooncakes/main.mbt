///|
fn main {
  let config = @src.Config::new(44100, 48000, 2).unwrap()
  let input = Array::make(882, 0.25)
  let converted = @src.resample(config, input[:]).unwrap()
  if converted.length() != 960 {
    abort("wrong batch frame count")
  }
  let encoded = @wav.encode(48000, 2, converted[:]).unwrap()
  let decoded = @wav.decode(encoded.bytes).unwrap()
  if decoded.rate != 48000 ||
    decoded.channels != 2 ||
    decoded.samples.length() != 960 {
    abort("WAV metadata mismatch")
  }
  if @pcm.encode([0.25][:]).unwrap().bytes != b"\x00\x20" {
    abort("PCM quantization mismatch")
  }
  let stream = @src.Resampler::new(config)
  let buffer = FixedArray::make(14, 0.0)
  let mut consumed = 0
  while consumed < input.length() {
    let progress = stream.process(input[consumed:], buffer).unwrap()
    if progress.consumed_frames == 0 && progress.produced_frames == 0 {
      abort("no progress")
    }
    consumed += progress.consumed_frames * 2
  }
  while !stream.is_finished() {
    ignore(stream.finish(buffer).unwrap())
  }
  if stream.stats().output_frames != 480L {
    abort("wrong stream frame count")
  }
  println(
    "public_api_consumer frames=480 channels=2 lookahead_in=\{stream.latency().input_frames}",
  )
}
