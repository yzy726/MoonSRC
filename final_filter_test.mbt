///|
test "final_filter/quality radius and storage are applied by the stream" {
  for pair in [(@MoonSRC.LowLatency, 32), (Balanced, 96), (HighQuality, 192)] {
    let c = @MoonSRC.Config::with_quality(48000, 16000, 6, pair.0).unwrap()
    let s = @MoonSRC.Resampler::new(c)
    assert_eq(s.latency().input_frames, pair.1)
    assert_eq(s.stats().coefficient_samples, 2 * pair.1 + 1)
    assert_eq(s.stats().history_capacity_samples, (2 * pair.1 + 8) * 6)
  }
}

///|
test "final_filter/severe downsample scales filter support" {
  let c = @MoonSRC.Config::with_quality(192000, 8000, 8, HighQuality).unwrap()
  let s = @MoonSRC.Resampler::new(c)
  assert_eq(s.latency().input_frames, 1536)
  assert_eq(s.stats().coefficient_samples, 3073)
  let result = @MoonSRC.resample(c, Array::make(192 * 8, 0.0)[:]).unwrap()
  assert_eq(result.length(), 8 * 8)
}

///|
test "final_filter/identity remains exact for every quality" {
  for q in [@MoonSRC.LowLatency, Balanced, HighQuality] {
    let c = @MoonSRC.Config::with_quality(192000, 192000, 8, q).unwrap()
    let s = @MoonSRC.Resampler::new(c)
    assert_eq(s.latency().input_frames, 0)
    assert_eq(s.stats().internal_samples, 0)
    let input = Array::makei(64, i => i.to_double() / 64.0)
    assert_eq(@MoonSRC.resample(c, input[:]).unwrap(), input)
  }
}
