///|
test "final_api/caller owned output has exact count and untouched tail" {
  let c = @MoonSRC.Config::with_quality(44100, 16000, 6, HighQuality).unwrap()
  let input = Array::makei(441 * 6, i => if i % 6 == 0 { 0.25 } else { 0.0 })
  let expected = @MoonSRC.resample(c, input[:]).unwrap()
  let out = FixedArray::make(expected.length() + 12, 9.0)
  assert_eq(@MoonSRC.resample_into(c, input[:], out).unwrap(), 160)
  for i in 0..<expected.length() {
    assert_eq(out[i], expected[i])
  }
  for i in expected.length()..<out.length() {
    assert_eq(out[i], 9.0)
  }
}

///|
test "final_api/invalid short output is rejected atomically" {
  let c = @MoonSRC.Config::new(8000, 192000, 2).unwrap()
  let out = FixedArray::make(2, 9.0)
  assert_true(
    @MoonSRC.resample_into(c, [0.1, 0.2][:], out) is Err(ResourceLimit),
  )
  assert_eq(out[0], 9.0)
  assert_eq(out[1], 9.0)
}

///|
test "final_api/invalid output alignment is rejected atomically" {
  let out = FixedArray::make(3, 9.0)
  assert_true(
    @MoonSRC.resample_into(
      @MoonSRC.Config::new(48000, 16000, 2).unwrap(),
      [0.0, 0.0][:],
      out,
    )
    is Err(MisalignedOutput),
  )
  assert_eq(out[0], 9.0)
}

///|
test "final_api/invalid input alignment is rejected atomically" {
  let out = FixedArray::make(8, 9.0)
  assert_true(
    @MoonSRC.resample_into(
      @MoonSRC.Config::new(48000, 16000, 2).unwrap(),
      [0.0][:],
      out,
    )
    is Err(MisalignedInput),
  )
  assert_eq(out[0], 9.0)
}

///|
test "final_api/invalid nonfinite input is rejected before output writes" {
  let out = FixedArray::make(8, 9.0)
  assert_true(
    @MoonSRC.resample_into(
      @MoonSRC.Config::new(48000, 16000, 1).unwrap(),
      [0.0, 0.0 / 0.0][:],
      out,
    )
    is Err(NonFinite(1)),
  )
  assert_eq(out[0], 9.0)
}

///|
test "final_api/empty caller owned conversion succeeds" {
  assert_eq(
    @MoonSRC.resample_into(
      @MoonSRC.Config::new(8000, 192000, 8).unwrap(),
      [][:],
      FixedArray::make(0, 0.0),
    ).unwrap(),
    0,
  )
}

///|
test "final_api/maximum upsample exact seeded chunk and one frame output" {
  for q in [@MoonSRC.LowLatency, Balanced, HighQuality] {
    let c = @MoonSRC.Config::with_quality(8000, 192000, 8, q).unwrap()
    let input = Array::makei(257 * 8, i => {
      ((i * 17 + 23) % 127).to_double() / 128.0 - 0.5
    })
    let whole = @MoonSRC.resample(c, input[:]).unwrap()
    let chunks = @signals.chunked(c, input[:], [1, 7, 127, 3][:], 1).unwrap()
    assert_eq(chunks, whole)
    assert_eq(whole.length(), c.output_frames(257L).unwrap().to_int() * 8)
  }
}

///|
test "final_api/maximum downsample exact seeded chunk and one frame output" {
  for q in [@MoonSRC.LowLatency, Balanced, HighQuality] {
    let c = @MoonSRC.Config::with_quality(192000, 8000, 8, q).unwrap()
    let input = Array::makei(257 * 8, i => {
      ((i * 17 + 23) % 127).to_double() / 128.0 - 0.5
    })
    let whole = @MoonSRC.resample(c, input[:]).unwrap()
    let chunks = @signals.chunked(c, input[:], [1, 7, 127, 3][:], 1).unwrap()
    assert_eq(chunks, whole)
    assert_eq(whole.length(), c.output_frames(257L).unwrap().to_int() * 8)
  }
}

///|
test "final_api/new fractional downsample exact seeded chunk and one frame output" {
  for q in [@MoonSRC.LowLatency, Balanced, HighQuality] {
    let c = @MoonSRC.Config::with_quality(44100, 16000, 8, q).unwrap()
    let input = Array::makei(257 * 8, i => {
      ((i * 17 + 23) % 127).to_double() / 128.0 - 0.5
    })
    let whole = @MoonSRC.resample(c, input[:]).unwrap()
    let chunks = @signals.chunked(c, input[:], [1, 7, 127, 3][:], 1).unwrap()
    assert_eq(chunks, whole)
    assert_eq(whole.length(), c.output_frames(257L).unwrap().to_int() * 8)
  }
}

///|
test "final_api/new fractional upsample exact seeded chunk and one frame output" {
  for q in [@MoonSRC.LowLatency, Balanced, HighQuality] {
    let c = @MoonSRC.Config::with_quality(16000, 44100, 8, q).unwrap()
    let input = Array::makei(257 * 8, i => {
      ((i * 17 + 23) % 127).to_double() / 128.0 - 0.5
    })
    let whole = @MoonSRC.resample(c, input[:]).unwrap()
    let chunks = @signals.chunked(c, input[:], [1, 7, 127, 3][:], 1).unwrap()
    assert_eq(chunks, whole)
    assert_eq(whole.length(), c.output_frames(257L).unwrap().to_int() * 8)
  }
}

///|
test "final_api/high rate fractional exact seeded chunk and one frame output" {
  for q in [@MoonSRC.LowLatency, Balanced, HighQuality] {
    let c = @MoonSRC.Config::with_quality(96000, 44100, 8, q).unwrap()
    let input = Array::makei(257 * 8, i => {
      ((i * 17 + 23) % 127).to_double() / 128.0 - 0.5
    })
    let whole = @MoonSRC.resample(c, input[:]).unwrap()
    let chunks = @signals.chunked(c, input[:], [1, 7, 127, 3][:], 1).unwrap()
    assert_eq(chunks, whole)
    assert_eq(whole.length(), c.output_frames(257L).unwrap().to_int() * 8)
  }
}

///|
test "final_api/upper identity exact seeded chunk and one frame output" {
  for q in [@MoonSRC.LowLatency, Balanced, HighQuality] {
    let c = @MoonSRC.Config::with_quality(192000, 192000, 8, q).unwrap()
    let input = Array::makei(257 * 8, i => {
      ((i * 17 + 23) % 127).to_double() / 128.0 - 0.5
    })
    let whole = @MoonSRC.resample(c, input[:]).unwrap()
    let chunks = @signals.chunked(c, input[:], [1, 7, 127, 3][:], 1).unwrap()
    assert_eq(chunks, whole)
    assert_eq(whole.length(), c.output_frames(257L).unwrap().to_int() * 8)
  }
}

///|
test "final_api/lower identity exact seeded chunk and one frame output" {
  for q in [@MoonSRC.LowLatency, Balanced, HighQuality] {
    let c = @MoonSRC.Config::with_quality(8000, 8000, 8, q).unwrap()
    let input = Array::makei(257 * 8, i => {
      ((i * 17 + 23) % 127).to_double() / 128.0 - 0.5
    })
    let whole = @MoonSRC.resample(c, input[:]).unwrap()
    let chunks = @signals.chunked(c, input[:], [1, 7, 127, 3][:], 1).unwrap()
    assert_eq(chunks, whole)
    assert_eq(whole.length(), c.output_frames(257L).unwrap().to_int() * 8)
  }
}

///|
test "final_api/uneven rate exact seeded chunk and one frame output" {
  for q in [@MoonSRC.LowLatency, Balanced, HighQuality] {
    let c = @MoonSRC.Config::with_quality(32000, 22050, 8, q).unwrap()
    let input = Array::makei(257 * 8, i => {
      ((i * 17 + 23) % 127).to_double() / 128.0 - 0.5
    })
    let whole = @MoonSRC.resample(c, input[:]).unwrap()
    let chunks = @signals.chunked(c, input[:], [1, 7, 127, 3][:], 1).unwrap()
    assert_eq(chunks, whole)
    assert_eq(whole.length(), c.output_frames(257L).unwrap().to_int() * 8)
  }
}

///|
test "final_api/six and eight channel impulse isolation" {
  for channels in [6, 8] {
    for active in 0..<channels {
      let c = @MoonSRC.Config::with_quality(44100, 48000, channels, LowLatency).unwrap()
      let input = Array::makei(400 * channels, i => {
        if i / channels == 200 && i % channels == active {
          1.0
        } else {
          0.0
        }
      })
      let output = @signals.chunked(c, input[:], [1, 127, 13][:], 3).unwrap()
      let mut energy = 0.0
      for i in 0..<output.length() {
        if i % channels == active {
          energy += output[i] * output[i]
        } else {
          assert_eq(output[i], 0.0)
        }
      }
      assert_true(energy > 0.1)
    }
  }
}

///|
test "final_api/reset preserves quality and starts an unrelated stream" {
  for q in [@MoonSRC.LowLatency, Balanced, HighQuality] {
    let c = @MoonSRC.Config::with_quality(192000, 8000, 6, q).unwrap()
    let s = @MoonSRC.Resampler::new(c)
    let buffer = FixedArray::make(6, 0.0)
    ignore(s.process(Array::make(257 * 6, 0.25)[:], buffer).unwrap())
    while !s.is_finished() {
      ignore(s.finish(buffer).unwrap())
    }
    let storage = s.stats().internal_samples
    s.reset()
    assert_eq(s.stats().input_frames, 0L)
    assert_eq(s.stats().output_frames, 0L)
    assert_eq(s.stats().internal_samples, storage)
    ignore(s.process([0.0, 0.0, 0.0, 0.0, 0.0, 0.0][:], buffer).unwrap())
    while !s.is_finished() {
      ignore(s.finish(buffer).unwrap())
    }
    assert_eq(s.stats().output_frames, 1L)
    for value in buffer {
      assert_eq(value, 0.0)
    }
  }
}

///|
test "final_api/eight channel samples match independent mono paths" {
  for pair in [(8000, 192000), (192000, 8000), (44100, 16000), (96000, 44100)] {
    for quality in [@MoonSRC.LowLatency, Balanced, HighQuality] {
      let input = Array::makei(97 * 8, i => {
        ((i / 8 * 19 + i % 8 * 31) % 127).to_double() / 128.0 - 0.5
      })
      let c = @MoonSRC.Config::with_quality(pair.0, pair.1, 8, quality).unwrap()
      let output = @MoonSRC.resample(c, input[:]).unwrap()
      for channel in 0..<8 {
        let mono = Array::makei(97, i => input[i * 8 + channel])
        let reference = @MoonSRC.resample(
          @MoonSRC.Config::with_quality(pair.0, pair.1, 1, quality).unwrap(),
          mono[:],
        ).unwrap()
        for i in 0..<reference.length() {
          assert_eq(output[i * 8 + channel], reference[i])
        }
      }
    }
  }
}
