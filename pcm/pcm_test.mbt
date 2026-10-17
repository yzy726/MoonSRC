///|
test "pcm/known little endian signed values" {
  let decoded = @pcm.decode(b"\x00\x80\xff\xff\x00\x00\x01\x00\xff\x7f").unwrap()
  assert_eq(decoded, [
    -1.0,
    -1.0 / 32768.0,
    0.0,
    1.0 / 32768.0,
    32767.0 / 32768.0,
  ])
  assert_eq(
    @pcm.encode(decoded[:]).unwrap().bytes,
    b"\x00\x80\xff\xff\x00\x00\x01\x00\xff\x7f",
  )
}

///|
test "pcm/explicit saturation and clipping count" {
  let encoded = @pcm.encode([-2.0, -1.0, 0.0, 1.0, 2.0][:]).unwrap()
  assert_eq(encoded.clipped_samples, 3)
  assert_eq(@pcm.decode(encoded.bytes).unwrap(), [
    -1.0,
    -1.0,
    0.0,
    32767.0 / 32768.0,
    32767.0 / 32768.0,
  ])
}

///|
test "pcm/ties round away from zero" {
  let input = [-1.5 / 32768.0, -0.5 / 32768.0, 0.5 / 32768.0, 1.5 / 32768.0]
  assert_eq(@pcm.decode(@pcm.encode(input[:]).unwrap().bytes).unwrap(), [
    -2.0 / 32768.0,
    -1.0 / 32768.0,
    1.0 / 32768.0,
    2.0 / 32768.0,
  ])
}

///|
test "pcm/invalid odd bytes and nonfinite samples" {
  assert_true(@pcm.decode(b"\x00") is Err(OddByteLength))
  for value in [0.0 / 0.0, 1.0 / 0.0, -1.0 / 0.0] {
    assert_true(@pcm.encode([0.0, value][:]) is Err(NonFinite(1)))
  }
}

///|
test "pcm/empty payload and quantization bound" {
  assert_eq(@pcm.encode([][:]).unwrap().bytes, b"")
  assert_eq(@pcm.decode(b"").unwrap(), [])
  let input = Array::makei(4096, i => i.to_double() / 4096.0 * 1.8 - 0.9)
  let encoded = @pcm.encode(input[:]).unwrap()
  let decoded = @pcm.decode(encoded.bytes).unwrap()
  assert_eq(encoded.clipped_samples, 0)
  for i in 0..<input.length() {
    assert_true((input[i] - decoded[i]).abs() <= 0.5 / 32768.0 + 1.0e-15)
  }
}
