///|
fn verify_facade(
  input_rate : Int,
  output_rate : Int,
  channels : Int,
  frames : Int,
) -> Unit raise {
  let config = @MoonSRC.Config::new(input_rate, output_rate, channels).unwrap()
  let input = Array::makei(frames * channels, i => {
    ((i * 31 + 7) % 101).to_double() / 101.0 - 0.5
  })
  let result = @MoonSRC.resample(config, input[:]).unwrap()
  assert_eq(
    result.length().to_int64(),
    config.output_frames(frames.to_int64()).unwrap() * channels.to_int64(),
  )
  assert_eq(result, drain_stream(config, input, 127, 11))
  for sample in result {
    assert_true(!sample.is_nan() && !sample.is_inf())
  }
}

///|
test "api/stereo isolation" {
  let config = @MoonSRC.Config::new(44100, 48000, 2).unwrap()
  let input = Array::makei(2000, i => if i % 2 == 0 { 0.75 } else { 0.0 })
  let result = @MoonSRC.resample(config, input[:]).unwrap()
  for frame in 0..<(result.length() / 2) {
    assert_eq(result[frame * 2 + 1], 0.0)
  }
}

///|
test "api/invalid input and state reset" {
  let config = @MoonSRC.Config::new(48000, 16000, 2).unwrap()
  assert_true(@MoonSRC.resample(config, [0.0][:]) is Err(MisalignedInput))
  assert_true(
    @MoonSRC.resample(config, [0.0, 0.0 / 0.0][:]) is Err(NonFinite(1)),
  )
  let stream = @MoonSRC.Resampler::new(config)
  let out = FixedArray::make(2048, 0.0)
  ignore(stream.process(Array::make(1000, 0.5)[:], out).unwrap())
  ignore(stream.finish(out).unwrap())
  stream.reset()
  let progress = stream.process(Array::make(1000, 0.0)[:], out).unwrap()
  for i in 0..<(progress.produced_frames * 2) {
    assert_eq(out[i], 0.0)
  }
  let tail = stream.finish(out).unwrap()
  for i in 0..<(tail.produced_frames * 2) {
    assert_eq(out[i], 0.0)
  }
}
