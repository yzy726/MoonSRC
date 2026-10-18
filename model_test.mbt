///|
test "model/allowed ratios and channel layouts" {
  let cases = [
    (44100, 48000),
    (48000, 44100),
    (48000, 16000),
    (16000, 48000),
    (16000, 16000),
    (44100, 44100),
    (48000, 48000),
  ]
  for pair in cases {
    for channels in [1, 2] {
      let config = @MoonSRC.Config::new(pair.0, pair.1, channels).unwrap()
      assert_eq(config.input_rate(), pair.0)
      assert_eq(config.output_rate(), pair.1)
      assert_eq(config.channels(), channels)
      assert_eq(
        config.output_frames(pair.0.to_int64()).unwrap(),
        pair.1.to_int64(),
      )
    }
  }
}

///|
test "model/invalid configuration is classified" {
  for rate in [-1, 0, 7999, 192001, 2147483647] {
    assert_true(@MoonSRC.Config::new(rate, 48000, 1) is Err(InvalidRate(_)))
    assert_true(@MoonSRC.Config::new(48000, rate, 1) is Err(InvalidRate(_)))
  }
  for channels in [-1, 0, 9, 16, 2147483647] {
    assert_true(
      @MoonSRC.Config::new(48000, 16000, channels) is Err(InvalidChannels(_)),
    )
  }
  assert_true(@MoonSRC.Config::new(8000, 8001, 1) is Err(ResourceLimit))
  assert_true(@MoonSRC.Config::new(8001, 8000, 1) is Err(ResourceLimit))
}

///|
test "model/frame length follows timestamp ceiling" {
  let down = @MoonSRC.Config::new(48000, 16000, 1).unwrap()
  for
    pair in [(0L, 0L), (1L, 1L), (2L, 1L), (3L, 1L), (4L, 2L), (47999L, 16000L)] {
    assert_eq(down.output_frames(pair.0).unwrap(), pair.1)
  }
  let fractional = @MoonSRC.Config::new(44100, 48000, 2).unwrap()
  assert_eq(fractional.output_frames(1L).unwrap(), 2L)
  assert_eq(fractional.output_frames(147L).unwrap(), 160L)
  assert_eq(fractional.output_frames(441000000000L).unwrap(), 480000000000L)
}

///|
test "model/frame arithmetic rejects negative and overflow" {
  let up = @MoonSRC.Config::new(16000, 48000, 1).unwrap()
  assert_true(up.output_frames(-1L) is Err(FrameOverflow))
  assert_true(up.output_frames(9223372036854775807L) is Err(FrameOverflow))
  let down = @MoonSRC.Config::new(48000, 16000, 1).unwrap()
  assert_eq(
    down.output_frames(9223372036854775807L).unwrap(),
    3074457345618258603L,
  )
  let identity = @MoonSRC.Config::new(48000, 48000, 1).unwrap()
  assert_eq(
    identity.output_frames(9223372036854775807L).unwrap(),
    9223372036854775807L,
  )
}
