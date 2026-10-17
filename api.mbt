///|
/// Convert one finite interleaved buffer through the streaming engine.
/// The convenience API limits output to 16,777,216 samples (128 MiB payload).
/// Use Resampler with caller-owned blocks for longer audio.
pub fn resample(
  config : Config,
  input : ArrayView[Double],
) -> Result[Array[Double], ResampleError] {
  let channels = config.channels
  if input.length() % channels != 0 {
    return Err(MisalignedInput)
  }
  for i in 0..<input.length() {
    if input[i].is_nan() || input[i].is_inf() {
      return Err(NonFinite(i))
    }
  }
  let frames = input.length() / channels
  let expected = match config.output_frames(frames.to_int64()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if expected > 16777216L / channels.to_int64() {
    return Err(ResourceLimit)
  }
  let result = Array::make(expected.to_int() * channels, 0.0)
  let output = FixedArray::make(1024 * channels, 0.0)
  let stream = Resampler::new(config)
  let mut consumed = 0
  let mut written = 0
  while consumed < frames {
    let end = (consumed + 1024).min(frames)
    let progress = match
      stream.process(input[consumed * channels:end * channels], output) {
      Ok(progress) => progress
      Err(error) => return Err(error)
    }
    if progress.consumed_frames == 0 && progress.produced_frames == 0 {
      return Err(InvalidState)
    }
    consumed += progress.consumed_frames
    for i in 0..<(progress.produced_frames * channels) {
      result[written + i] = output[i]
    }
    written += progress.produced_frames * channels
  }
  while !stream.is_finished() {
    let progress = match stream.finish(output) {
      Ok(progress) => progress
      Err(error) => return Err(error)
    }
    for i in 0..<(progress.produced_frames * channels) {
      result[written + i] = output[i]
    }
    written += progress.produced_frames * channels
  }
  Ok(result)
}
