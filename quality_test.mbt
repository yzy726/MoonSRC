///|
test "quality/48000 to 16000 1kHz passband within 0.5dB" {
  let config = @MoonSRC.Config::new(48000, 16000, 1).unwrap()
  let input = @signals.tone(48000, 1000.0, 48000, 1)
  let result = @MoonSRC.resample(config, input[:]).unwrap()
  let amplitude = @signals.magnitude(result[:], 16000, 1000.0, 256)
  assert_true((20.0 * @math.log10(amplitude / 0.5)).abs() <= 0.5)
}

///|
test "quality/48000 to 16000 12kHz alias at least 50dB below passband" {
  let config = @MoonSRC.Config::new(48000, 16000, 1).unwrap()
  let passband = @MoonSRC.resample(
    config,
    @signals.tone(48000, 1000.0, 48000, 1)[:],
  ).unwrap()
  let rejected_tone = @MoonSRC.resample(
    config,
    @signals.tone(48000, 12000.0, 48000, 1)[:],
  ).unwrap()
  let reference = @signals.magnitude(passband[:], 16000, 1000.0, 256)
  let folded = @signals.magnitude(rejected_tone[:], 16000, 4000.0, 256)
  assert_true(20.0 * @math.log10(folded / reference) <= -50.0)
}

///|
test "quality/DC and impulse on every nonidentity ratio" {
  for pair in [(44100, 48000), (48000, 44100), (48000, 16000), (16000, 48000)] {
    let config = @MoonSRC.Config::new(pair.0, pair.1, 1).unwrap()
    let dc = @MoonSRC.resample(config, Array::make(4096, 0.25)[:]).unwrap()
    let trim = @MoonSRC.Resampler::new(config).latency().output_frames + 1
    for i in trim..<(dc.length() - trim) {
      assert_true((dc[i] - 0.25).abs() < 1.0e-12)
    }
    let impulse = Array::make(4096, 0.0)
    impulse[1024] = 1.0
    let response = @MoonSRC.resample(config, impulse[:]).unwrap()
    let mut sum = 0.0
    for sample in response {
      assert_true(!sample.is_nan() && !sample.is_inf())
      sum += sample
    }
    assert_true((sum - pair.1.to_double() / pair.0.to_double()).abs() < 0.001)
  }
}

///|
test "quality/fixed seed randomized blocks and reset isolation" {
  let input = Array::makei(4096, i => {
    ((i * 1103515245 + 12345) & 65535).to_double() / 65536.0 - 0.5
  })
  let pattern = Array::makei(41, i => (i * 73 + 37) % 251 + 1)
  for pair in [(44100, 48000), (48000, 44100), (48000, 16000), (16000, 48000)] {
    let config = @MoonSRC.Config::new(pair.0, pair.1, 2).unwrap()
    let expected = @MoonSRC.resample(config, input[:]).unwrap()
    assert_eq(
      @signals.chunked(config, input[:], pattern[:], 7).unwrap(),
      expected,
    )
  }
}
