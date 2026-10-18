///|
test "stream/frame counter overflow is rejected before mutation" {
  let stream = Resampler::new(Config::new(48000, 16000, 1).unwrap())
  stream.input_count = 9223372036854775614L
  assert_true(
    stream.process([0.0][:], FixedArray::make(1, 0.0)) is Err(FrameOverflow),
  )
  assert_eq(stream.input_count, 9223372036854775614L)
}

///|
test "stream/integer phase clock has no long-run drift" {
  for pair in [(44100, 48000), (48000, 44100)] {
    let config = Config::new(pair.0, pair.1, 1).unwrap()
    let stream = Resampler::new(config)
    for _ in 0..<1000003 {
      stream.advance()
    }
    assert_eq(
      stream.position,
      1000003L * config.denominator.to_int64() / config.numerator.to_int64(),
    )
    assert_eq(stream.phase, 1000003 * config.denominator % config.numerator)
  }
}

///|
test "final_api/invalid expanded filter frame reserve is atomic" {
  let s = Resampler::new(
    Config::with_quality(192000, 8000, 8, HighQuality).unwrap(),
  )
  s.input_count = 9223372036854775807L - 3073L
  assert_true(
    s.process(Array::make(8, 0.0)[:], FixedArray::make(8, 0.0))
    is Err(FrameOverflow),
  )
  assert_eq(s.input_count, 9223372036854775807L - 3073L)
}
