///|
fn drain_stream(
  config : @MoonSRC.Config,
  input : Array[Double],
  block : Int,
  capacity : Int,
) -> Array[Double] raise {
  let stream = @MoonSRC.Resampler::new(config)
  let output = FixedArray::make(capacity * config.channels(), 0.0)
  let result : Array[Double] = []
  let mut offset = 0
  while offset < input.length() {
    let end = (offset + block * config.channels()).min(input.length())
    let progress = stream.process(input[offset:end], output).unwrap()
    assert_true(progress.consumed_frames > 0 || progress.produced_frames > 0)
    offset += progress.consumed_frames * config.channels()
    for i in 0..<(progress.produced_frames * config.channels()) {
      result.push(output[i])
    }
  }
  while !stream.is_finished() {
    let progress = stream.finish(output).unwrap()
    assert_true(progress.produced_frames > 0 || stream.is_finished())
    for i in 0..<(progress.produced_frames * config.channels()) {
      result.push(output[i])
    }
  }
  assert_eq(
    stream.stats().input_frames,
    (input.length() / config.channels()).to_int64(),
  )
  assert_eq(
    stream.stats().output_frames,
    (result.length() / config.channels()).to_int64(),
  )
  assert_true(stream.stats().peak_history_frames <= 193)
  result
}

///|
test "stream/one frame blocks equal whole input with one frame output" {
  let input = Array::makei(1024, i => (i % 17).to_double() / 17.0)
  for pair in [(44100, 48000), (48000, 44100), (48000, 16000), (16000, 48000)] {
    let config = @MoonSRC.Config::new(pair.0, pair.1, 1).unwrap()
    let whole = drain_stream(config, input, 1024, 2048)
    let tiny = drain_stream(config, input, 1, 1)
    assert_eq(whole.length().to_int64(), config.output_frames(1024L).unwrap())
    assert_eq(whole, tiny)
  }
}

///|
test "stream/identity is exact including stereo and values outside unity" {
  let input = [1.5, -2.0, 0.0, -0.0, 0.25, -0.75]
  let config = @MoonSRC.Config::new(48000, 48000, 2).unwrap()
  assert_eq(drain_stream(config, input, 1, 1), input)
  assert_eq(@MoonSRC.Resampler::new(config).latency().input_frames, 0)
}

///|
test "stream/empty short and lookahead contracts" {
  let config = @MoonSRC.Config::new(48000, 16000, 1).unwrap()
  assert_eq(drain_stream(config, [], 1, 1), [])
  for length in [1, 2, 3, 95, 96, 97, 193, 194] {
    let result = drain_stream(config, Array::make(length, 0.0), 1, 1)
    assert_eq(
      result.length().to_int64(),
      config.output_frames(length.to_int64()).unwrap(),
    )
    for sample in result {
      assert_eq(sample, 0.0)
    }
  }
  let stream = @MoonSRC.Resampler::new(config)
  assert_eq(stream.latency().input_frames, 96)
  let out = FixedArray::make(1, 0.0)
  let progress = stream.process(Array::make(96, 1.0)[:], out).unwrap()
  assert_eq(progress.produced_frames, 0)
  assert_eq(progress.consumed_frames, 96)
}

///|
test "stream/zero capacity partial consumption and finish state" {
  let config = @MoonSRC.Config::new(16000, 48000, 1).unwrap()
  let stream = @MoonSRC.Resampler::new(config)
  let input = Array::make(1000, 0.25)
  let none = stream.process(input[:], FixedArray::make(0, 0.0)).unwrap()
  assert_eq(none.consumed_frames, 0)
  assert_eq(none.produced_frames, 0)
  let out = FixedArray::make(1, 0.0)
  let some = stream.process(input[:], out).unwrap()
  assert_true(some.consumed_frames < 1000 && some.consumed_frames > 0)
  assert_eq(some.produced_frames, 1)
  ignore(stream.finish(FixedArray::make(0, 0.0)).unwrap())
  assert_true(stream.process([][:], out) is Err(InvalidState))
  while !stream.is_finished() {
    ignore(stream.finish(out).unwrap())
  }
  assert_eq(stream.finish(out).unwrap().produced_frames, 0)
  assert_true(stream.process([1.0][:], out) is Err(InvalidState))
  stream.reset()
  assert_eq(stream.stats().input_frames, 0L)
  assert_eq(stream.stats().output_frames, 0L)
  assert_true(!stream.is_finished())
}

///|
test "stream/invalid frames and nonfinite samples do not mutate state" {
  let stream = @MoonSRC.Resampler::new(
    @MoonSRC.Config::new(44100, 48000, 2).unwrap(),
  )
  let out = FixedArray::make(4, 0.0)
  assert_true(stream.process([1.0][:], out) is Err(MisalignedInput))
  assert_true(
    stream.process([1.0, 2.0][:], FixedArray::make(1, 0.0))
    is Err(MisalignedOutput),
  )
  for value in [0.0 / 0.0, 1.0 / 0.0, -1.0 / 0.0] {
    assert_true(stream.process([0.0, value][:], out) is Err(NonFinite(1)))
    assert_eq(stream.stats().input_frames, 0L)
  }
  assert_true(stream.finish(FixedArray::make(1, 0.0)) is Err(MisalignedOutput))
  assert_true(stream.process([0.0, 0.0][:], out) is Ok(_))
}

///|
test "stream/finite numeric overflow faults until reset" {
  let config = @MoonSRC.Config::new(48000, 16000, 1).unwrap()
  let stream = @MoonSRC.Resampler::new(config)
  let input = Array::makei(193, i => {
    let x = (i - 96).to_double()
    let sign = if x == 0.0 {
      1.0
    } else {
      @math.sin(@math.PI * (0.94 / 3.0) * x) / x
    }
    if sign < 0.0 {
      -1.7976931348623157e308
    } else {
      1.7976931348623157e308
    }
  })
  let output = FixedArray::make(256, 0.0)
  assert_true(stream.process(input[:], output) is Err(NumericOverflow))
  assert_true(stream.process([][:], output) is Err(InvalidState))
  assert_true(stream.finish(output) is Err(InvalidState))
  stream.reset()
  assert_true(stream.process(Array::make(193, 0.0)[:], output) is Ok(_))
}

///|
test "stream/nonfinite error preserves earlier valid history" {
  let config = @MoonSRC.Config::new(48000, 16000, 1).unwrap()
  let input = Array::make(96, 0.25)
  let expected = @MoonSRC.resample(config, input[:]).unwrap()
  let stream = @MoonSRC.Resampler::new(config)
  let output = FixedArray::make(128, 0.0)
  assert_eq(stream.process(input[:], output).unwrap().consumed_frames, 96)
  assert_true(stream.process([0.0, 0.0 / 0.0][:], output) is Err(NonFinite(1)))
  assert_eq(stream.stats().input_frames, 96L)
  let end_progress = stream.finish(output).unwrap()
  assert_eq(end_progress.produced_frames, expected.length())
  for i in 0..<expected.length() {
    assert_eq(output[i], expected[i])
  }
}
