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
  let legacy_tag = match @wav.decode(b"RIFF") {
    Err(error) => legacy_error_tag(error)
    Ok(_) => abort("malformed WAV unexpectedly accepted")
  }
  if legacy_tag != 1 {
    abort("0.1.0 error contract changed")
  }
  println(
    "public_api_consumer frames=480 channels=2 lookahead_in=\{stream.latency().input_frames}",
  )
}

///|
fn legacy_error_tag(error : @wav.WavError) -> Int {
  match error {
    InvalidHeader => 0
    Truncated => 1
    UnsupportedFormat => 2
    InvalidFormat => 3
    InvalidChannels => 4
    InvalidRate => 5
    MissingFormat => 6
    MissingData => 7
    DuplicateChunk => 8
    FrameAlignment => 9
    NonFinite(_) => 10
    ResourceLimit => 11
  }
}
