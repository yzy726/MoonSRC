///|
/// Synthetic test signal: 0.5*sin(2*pi*f*n/rate) on channel 0, other channels zero.
/// Generator inputs are fixed by tests/examples, not untrusted PCM configuration.
pub fn tone(
  rate : Int,
  frequency : Double,
  frames : Int,
  channels : Int,
) -> Array[Double] {
  if rate < 1 || frames < 0 || frames > 1048576 || channels < 1 || channels > 2 {
    abort("invalid test signal budget")
  }
  Array::makei(frames * channels, i => {
    if i % channels == 0 {
      0.5 *
      @math.sin(
        2.0 *
        @math.PI *
        frequency *
        (i / channels).to_double() /
        rate.to_double(),
      )
    } else {
      0.0
    }
  })
}

///|
/// Deterministic finite-stream consumer used by examples and regression tests.
pub fn chunked(
  config : @src.Config,
  input : ArrayView[Double],
  pattern : ArrayView[Int],
  output_frames : Int,
) -> Result[Array[Double], @src.ResampleError] {
  let channels = config.channels()
  if input.length() % channels != 0 {
    return Err(MisalignedInput)
  }
  if pattern.length() == 0 || output_frames < 1 || output_frames > 65536 {
    return Err(ResourceLimit)
  }
  for block in pattern {
    if block < 1 || block > 65536 {
      return Err(ResourceLimit)
    }
  }
  let total_frames = input.length() / channels
  let expected = match config.output_frames(total_frames.to_int64()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if expected > 16777216L / channels.to_int64() {
    return Err(ResourceLimit)
  }
  let result : Array[Double] = []
  let output = FixedArray::make(output_frames * channels, 0.0)
  let stream = @src.Resampler::new(config)
  let mut offset = 0
  let mut block_index = 0
  while offset < input.length() {
    let block = pattern[block_index % pattern.length()].min(
      (input.length() - offset) / channels,
    )
    let end = offset + block * channels
    while offset < end {
      let progress = match stream.process(input[offset:end], output) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if progress.consumed_frames == 0 && progress.produced_frames == 0 {
        return Err(InvalidState)
      }
      offset += progress.consumed_frames * channels
      for i in 0..<(progress.produced_frames * channels) {
        result.push(output[i])
      }
    }
    block_index += 1
  }
  while !stream.is_finished() {
    let progress = match stream.finish(output) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    for i in 0..<(progress.produced_frames * channels) {
      result.push(output[i])
    }
  }
  Ok(result)
}

///|
/// Rectangular coherent projection on the stated steady interval. Its length
/// must contain complete periods for the frequency being measured.
pub fn magnitude(
  samples : ArrayView[Double],
  rate : Int,
  frequency : Double,
  trim : Int,
) -> Double {
  if rate < 1 || trim < 0 || trim > (samples.length() - 1) / 2 {
    abort("invalid analysis window")
  }
  let mut sine = 0.0
  let mut cosine = 0.0
  for i in trim..<(samples.length() - trim) {
    let angle = 2.0 * @math.PI * frequency * i.to_double() / rate.to_double()
    sine += samples[i] * @math.sin(angle)
    cosine += samples[i] * @math.cos(angle)
  }
  2.0 *
  (sine * sine + cosine * cosine).sqrt() /
  (samples.length() - 2 * trim).to_double()
}
