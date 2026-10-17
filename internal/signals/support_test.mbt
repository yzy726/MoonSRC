///|
test "signals/tone is deterministic and stereo right is silent" {
  let samples = @signals.tone(48000, 1000.0, 48, 2)
  assert_eq(samples.length(), 96)
  assert_eq(samples[0], 0.0)
  assert_true((samples[24] - 0.5).abs() < 1.0e-14)
  for i in 0..<48 {
    assert_eq(samples[i * 2 + 1], 0.0)
  }
}

///|
test "signals/chunk helper uses caller capacities and fixed patterns" {
  let config = @src.Config::new(44100, 48000, 2).unwrap()
  let samples = @signals.tone(44100, 1000.0, 1000, 2)
  let expected = @src.resample(config, samples[:]).unwrap()
  for capacity in [1, 7, 127] {
    let actual = @signals.chunked(
      config,
      samples[:],
      [1, 127, 17, 3][:],
      capacity,
    ).unwrap()
    assert_eq(actual, expected)
  }
  assert_true(
    @signals.chunked(config, samples[:], [][:], 1) is Err(ResourceLimit),
  )
  assert_true(
    @signals.chunked(config, samples[:], [0][:], 1) is Err(ResourceLimit),
  )
  assert_true(
    @signals.chunked(config, samples[:], [1][:], 0) is Err(ResourceLimit),
  )
}
