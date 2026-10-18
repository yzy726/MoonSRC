///|
fn float_fixture() -> Bytes {
  b"\x52\x49\x46\x46\x42\x00\x00\x00\x57\x41\x56\x45\x66\x6d\x74\x20\x12\x00\x00\x00\x03\x00\x02\x00\x80\xbb\x00\x00\x00\xdc\x05\x00\x08\x00\x20\x00\x00\x00\x66\x61\x63\x74\x04\x00\x00\x00\x02\x00\x00\x00\x64\x61\x74\x61\x10\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80\x3e\x00\x00\x00\xbf\x00\x00\xc0\x3f"
}

///|
test "final_wav/independent IEEE float32 fixture decodes exact values" {
  let audio = @wav.decode(float_fixture()).unwrap()
  assert_eq(audio.rate, 48000)
  assert_eq(audio.channels, 2)
  assert_eq(audio.samples, [0.0, 0.25, -0.5, 1.5])
}

///|
test "final_wav/canonical IEEE float32 bytes match independent fixture" {
  let encoded = @wav.encode_float32(48000, 2, [0.0, 0.25, -0.5, 1.5][:]).unwrap()
  assert_eq(encoded.bytes, float_fixture())
  assert_eq(encoded.clipped_samples, 0)
}

///|
test "final_wav/float32 empty and negative zero roundtrip" {
  assert_eq(
    @wav.decode(@wav.encode_float32(8000, 1, [][:]).unwrap().bytes).unwrap().samples,
    [],
  )
  let negative_zero = @wav.decode(
      @wav.encode_float32(8000, 1, [-0.0][:]).unwrap().bytes,
    ).unwrap().samples[0]
  assert_true(1.0 / negative_zero < 0.0)
}

///|
test "final_wav/multichannel extensible PCM16 and float32 roundtrip" {
  for channels in [3, 6, 8] {
    let values = Array::makei(channels * 3, i => {
      if i % channels == channels - 1 {
        0.25
      } else {
        0.0
      }
    })
    for
      encoded in [
        @wav.encode(96000, channels, values[:]).unwrap(),
        @wav.encode_float32(96000, channels, values[:]).unwrap(),
      ] {
      assert_eq(encoded.bytes[20], 0xfe)
      assert_eq(encoded.bytes[21], 0xff)
      let audio = @wav.decode(encoded.bytes).unwrap()
      assert_eq(audio.samples, values)
      assert_eq(audio.channels, channels)
      assert_eq(audio.rate, 96000)
    }
  }
}

///|
test "final_wav/float32 uses binary32 rounding without unit clipping" {
  let audio = @wav.decode(
    @wav.encode_float32(48000, 1, [0.1, 2.0, -2.0][:]).unwrap().bytes,
  ).unwrap()
  assert_eq(audio.samples[0], Float::from_double(0.1).to_double())
  assert_eq(audio.samples[1], 2.0)
  assert_eq(audio.samples[2], -2.0)
}

///|
test "final_wav/invalid float overflow is classified" {
  assert_true(@wav.encode_float32(48000, 1, [1.0e100][:]) is Err(NonFinite(0)))
}

///|
test "final_wav/invalid float source NaN is classified" {
  assert_true(
    @wav.encode_float32(48000, 1, [0.0 / 0.0][:]) is Err(NonFinite(0)),
  )
}

///|
test "final_wav/invalid float source infinity is classified" {
  assert_true(
    @wav.encode_float32(48000, 1, [1.0 / 0.0][:]) is Err(NonFinite(0)),
  )
}

///|
test "final_wav/invalid float encode alignment" {
  assert_true(@wav.encode_float32(48000, 6, [0.0][:]) is Err(FrameAlignment))
}

///|
test "final_wav/invalid float encode zero rate" {
  assert_true(@wav.encode_float32(0, 1, [][:]) is Err(InvalidRate))
}

///|
test "final_wav/invalid float encode channel limit" {
  assert_true(@wav.encode_float32(48000, 9, [][:]) is Err(InvalidChannels))
}

///|
test "final_wav/invalid decoded positive infinity" {
  assert_true(
    @wav.decode(patch(float_fixture(), 58, b"\x00\x00\x80\x7f"))
    is Err(NonFinite(0)),
  )
}

///|
test "final_wav/invalid decoded negative infinity" {
  assert_true(
    @wav.decode(patch(float_fixture(), 58, b"\x00\x00\x80\xff"))
    is Err(NonFinite(0)),
  )
}

///|
test "final_wav/invalid decoded NaN" {
  assert_true(
    @wav.decode(patch(float_fixture(), 58, b"\x00\x00\xc0\x7f"))
    is Err(NonFinite(0)),
  )
}

///|
test "final_wav/invalid wrong float width" {
  assert_true(
    @wav.decode(patch(float_fixture(), 34, b"\x10\x00"))
    is Err(UnsupportedFormat),
  )
}

///|
test "final_wav/invalid wrong float alignment" {
  assert_true(
    @wav.decode(patch(float_fixture(), 32, b"\x04\x00")) is Err(InvalidFormat),
  )
}

///|
test "final_wav/invalid wrong float byte rate" {
  assert_true(
    @wav.decode(patch(float_fixture(), 28, b"\x01\x00\x00\x00"))
    is Err(InvalidFormat),
  )
}

///|
test "final_wav/invalid float channel limit" {
  assert_true(
    @wav.decode(patch(float_fixture(), 22, b"\x09\x00")) is Err(InvalidChannels),
  )
}

///|
test "final_wav/invalid float extra format size" {
  assert_true(
    @wav.decode(patch(float_fixture(), 36, b"\x01\x00")) is Err(InvalidFormat),
  )
}

///|
test "final_wav/invalid extensible GUID" {
  let b = @wav.encode(48000, 6, Array::make(6, 0.0)[:]).unwrap().bytes
  assert_true(
    @wav.decode(patch(b, 44, b"\x55\x00\x00\x00")) is Err(UnsupportedFormat),
  )
}

///|
test "final_wav/invalid extensible precision" {
  let b = @wav.encode(48000, 6, Array::make(6, 0.0)[:]).unwrap().bytes
  assert_true(@wav.decode(patch(b, 38, b"\x0f\x00")) is Err(UnsupportedFormat))
}

///|
test "final_wav/invalid extensible speaker count" {
  let b = @wav.encode(48000, 6, Array::make(6, 0.0)[:]).unwrap().bytes
  assert_true(
    @wav.decode(patch(b, 40, b"\x01\x00\x00\x00")) is Err(InvalidFormat),
  )
  assert_eq(@wav.decode(patch(b, 40, b"\x3f\x00\x00\x00")).unwrap().channels, 6)
}

///|
test "final_wav/invalid extensible extension length" {
  let b = @wav.encode(48000, 6, Array::make(6, 0.0)[:]).unwrap().bytes
  assert_true(@wav.decode(patch(b, 36, b"\x15\x00")) is Err(InvalidFormat))
}
