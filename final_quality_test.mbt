///|
test "final_quality/low actual output meets fixed spectral gate" {
  let c = @MoonSRC.Config::with_quality(48000, 16000, 1, LowLatency).unwrap()
  let passed = @MoonSRC.resample(c, @signals.tone(48000, 1000.0, 48000, 1)[:]).unwrap()
  let stopped = @MoonSRC.resample(c, @signals.tone(48000, 12000.0, 48000, 1)[:]).unwrap()
  let pa = @signals.magnitude(passed[:], 16000, 1000.0, 256)
  let sa = @signals.magnitude(stopped[:], 16000, 4000.0, 256)
  assert_true((20.0 * @math.log10(pa / 0.5)).abs() <= 0.5)
  assert_true(20.0 * @math.log10(sa / pa) <= -45.0)
}

///|
test "final_quality/balanced actual output meets fixed spectral gate" {
  let c = @MoonSRC.Config::with_quality(48000, 16000, 1, Balanced).unwrap()
  let passed = @MoonSRC.resample(c, @signals.tone(48000, 1000.0, 48000, 1)[:]).unwrap()
  let stopped = @MoonSRC.resample(c, @signals.tone(48000, 12000.0, 48000, 1)[:]).unwrap()
  let pa = @signals.magnitude(passed[:], 16000, 1000.0, 256)
  let sa = @signals.magnitude(stopped[:], 16000, 4000.0, 256)
  assert_true((20.0 * @math.log10(pa / 0.5)).abs() <= 0.5)
  assert_true(20.0 * @math.log10(sa / pa) <= -50.0)
}

///|
test "final_quality/high actual output meets fixed spectral gate" {
  let c = @MoonSRC.Config::with_quality(48000, 16000, 1, HighQuality).unwrap()
  let passed = @MoonSRC.resample(c, @signals.tone(48000, 1000.0, 48000, 1)[:]).unwrap()
  let stopped = @MoonSRC.resample(c, @signals.tone(48000, 12000.0, 48000, 1)[:]).unwrap()
  let pa = @signals.magnitude(passed[:], 16000, 1000.0, 256)
  let sa = @signals.magnitude(stopped[:], 16000, 4000.0, 256)
  assert_true((20.0 * @math.log10(pa / 0.5)).abs() <= 0.5)
  assert_true(20.0 * @math.log10(sa / pa) <= -70.0)
}

///|
test "final_quality/extreme ratios preserve steady DC after full boundary trim" {
  for pair in [(8000, 192000), (192000, 8000), (44100, 16000), (48000, 44100)] {
    for quality in [@MoonSRC.LowLatency, Balanced, HighQuality] {
      let c = @MoonSRC.Config::with_quality(pair.0, pair.1, 1, quality).unwrap()
      let latency = @MoonSRC.Resampler::new(c).latency()
      let frames = 4 * latency.input_frames + 512
      let output = @MoonSRC.resample(c, Array::make(frames, 0.25)[:]).unwrap()
      let trim = latency.output_frames + 8
      for i in trim..<(output.length() - trim) {
        assert_true((output[i] - 0.25).abs() < 1.0e-10)
      }
    }
  }
}

///|
test "final_quality/maximum accepted exact phase table actually runs" {
  let c = @MoonSRC.Config::new(12285, 12288, 1).unwrap()
  let s = @MoonSRC.Resampler::new(c)
  assert_eq(s.stats().coefficient_samples, 790528)
  let input = Array::make(513, 0.25)
  let output = @MoonSRC.resample(c, input[:]).unwrap()
  assert_eq(output.length(), 514)
  for value in output {
    assert_true(!value.is_nan() && !value.is_inf())
  }
}
