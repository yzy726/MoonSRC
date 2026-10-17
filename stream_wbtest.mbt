///|
test "stream/frame counter overflow is rejected before mutation" {
  let stream = Resampler::new(Config::new(48000, 16000, 1).unwrap())
  stream.input_count = 9223372036854775614L
  assert_true(
    stream.process([0.0][:], FixedArray::make(1, 0.0)) is Err(FrameOverflow),
  )
  assert_eq(stream.input_count, 9223372036854775614L)
}
