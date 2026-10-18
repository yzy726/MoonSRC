///|
test "final_model/general fixed rates and eight channels" {
  for
    pair in [
      (8000, 192000),
      (192000, 8000),
      (44100, 16000),
      (16000, 44100),
      (22050, 48000),
      (96000, 44100),
      (192000, 192000),
    ] {
    for channels in [1, 2, 6, 8] {
      for quality in [@MoonSRC.LowLatency, Balanced, HighQuality] {
        let c = @MoonSRC.Config::with_quality(pair.0, pair.1, channels, quality).unwrap()
        assert_eq(c.quality(), quality)
        assert_eq(c.channels(), channels)
        assert_eq(
          c.output_frames(pair.0.to_int64()).unwrap(),
          pair.1.to_int64(),
        )
      }
    }
  }
}

///|
test "final_model/default quality preserves Balanced configuration" {
  assert_eq(
    @MoonSRC.Config::new(44100, 48000, 2).unwrap(),
    @MoonSRC.Config::with_quality(44100, 48000, 2, Balanced).unwrap(),
  )
}

///|
test "final_model/invalid exact phase allocation budget" {
  assert_true(@MoonSRC.Config::new(8000, 8001, 1) is Err(ResourceLimit))
  assert_true(@MoonSRC.Config::new(12285, 12288, 1) is Ok(_))
  assert_true(@MoonSRC.Config::new(8000, 8194, 1) is Err(ResourceLimit))
}

///|
test "final_model/invalid coefficient allocation budget before construction" {
  assert_true(
    @MoonSRC.Config::with_quality(8192, 8190, 1, HighQuality)
    is Err(ResourceLimit),
  )
  assert_true(@MoonSRC.Config::with_quality(8192, 8190, 8, Balanced) is Ok(_))
}

///|
test "final_model/invalid negative input" {
  assert_true(@MoonSRC.Config::new(-1, 48000, 1) is Err(InvalidRate(_)))
}

///|
test "final_model/invalid zero input" {
  assert_true(@MoonSRC.Config::new(0, 48000, 1) is Err(InvalidRate(_)))
}

///|
test "final_model/invalid below minimum input" {
  assert_true(@MoonSRC.Config::new(7999, 48000, 1) is Err(InvalidRate(_)))
}

///|
test "final_model/invalid above maximum input" {
  assert_true(@MoonSRC.Config::new(192001, 48000, 1) is Err(InvalidRate(_)))
}

///|
test "final_model/invalid negative output" {
  assert_true(@MoonSRC.Config::new(48000, -1, 1) is Err(InvalidRate(_)))
}

///|
test "final_model/invalid zero output" {
  assert_true(@MoonSRC.Config::new(48000, 0, 1) is Err(InvalidRate(_)))
}

///|
test "final_model/invalid below minimum output" {
  assert_true(@MoonSRC.Config::new(48000, 7999, 1) is Err(InvalidRate(_)))
}

///|
test "final_model/invalid above maximum output" {
  assert_true(@MoonSRC.Config::new(48000, 192001, 1) is Err(InvalidRate(_)))
}

///|
test "final_model/invalid zero channels" {
  assert_true(@MoonSRC.Config::new(48000, 16000, 0) is Err(InvalidChannels(_)))
}

///|
test "final_model/invalid negative channels" {
  assert_true(@MoonSRC.Config::new(48000, 16000, -1) is Err(InvalidChannels(_)))
}

///|
test "final_model/invalid nine channels" {
  assert_true(@MoonSRC.Config::new(48000, 16000, 9) is Err(InvalidChannels(_)))
}

///|
test "final_model/invalid huge channels" {
  assert_true(
    @MoonSRC.Config::new(48000, 16000, 2147483647) is Err(InvalidChannels(_)),
  )
}
