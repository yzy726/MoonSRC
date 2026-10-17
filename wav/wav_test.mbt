///|
fn fixture() -> Bytes {
  @wav.encode(48000, 2, [0.0, 0.0, 0.25, -0.25][:]).unwrap().bytes
}

///|
fn patch(bytes : Bytes, offset : Int, value : Bytes) -> Bytes {
  let copy = bytes.to_array()
  for i in 0..<value.length() {
    copy[offset + i] = value[i]
  }
  Bytes::from_array(copy[:])
}

///|
fn riff_size(bytes : Bytes) -> Bytes {
  let size = bytes.length() - 8
  patch(bytes, 4, Bytes::makei(4, i => ((size >> (i * 8)) & 255).to_byte()))
}

///|
test "wav/PCM16 stereo roundtrip and header" {
  let audio = @wav.decode(fixture()).unwrap()
  assert_eq(audio.rate, 48000)
  assert_eq(audio.channels, 2)
  assert_eq(audio.samples, [0.0, 0.0, 0.25, -0.25])
  assert_eq(fixture().length(), 52)
}

///|
test "wav/empty mono roundtrip" {
  let encoded = @wav.encode(16000, 1, [][:]).unwrap()
  assert_eq(encoded.bytes.length(), 44)
  assert_eq(@wav.decode(encoded.bytes).unwrap().samples, [])
}

///|
test "wav/unknown odd chunk with padding is skipped" {
  let base = fixture()
  let bytes = riff_size(base + b"JUNK\x03\x00\x00\x00abc\x00")
  assert_eq(
    @wav.decode(bytes).unwrap().samples,
    @wav.decode(base).unwrap().samples,
  )
}

///|
test "wav/data before format is supported" {
  let base = fixture().to_array()
  let reordered = Bytes::from_array(base[0:12]) +
    Bytes::from_array(base[36:52]) +
    Bytes::from_array(base[12:36])
  assert_eq(@wav.decode(reordered).unwrap().samples, [0.0, 0.0, 0.25, -0.25])
}

///|
test "wav/error short RIFF" {
  assert_true(@wav.decode(b"RIFF") is Err(Truncated))
}

///|
test "wav/error wrong container" {
  assert_true(@wav.decode(patch(fixture(), 0, b"RIFX")) is Err(InvalidHeader))
}

///|
test "wav/error wrong form" {
  assert_true(@wav.decode(patch(fixture(), 8, b"AVI ")) is Err(InvalidHeader))
}

///|
test "wav/error huge RIFF length" {
  assert_true(
    @wav.decode(patch(fixture(), 4, b"\xff\xff\xff\xff")) is Err(Truncated),
  )
}

///|
test "wav/error trailing bytes" {
  assert_true(@wav.decode(fixture() + b"x") is Err(InvalidHeader))
}

///|
test "wav/error compressed format" {
  assert_true(
    @wav.decode(patch(fixture(), 20, b"\x03\x00")) is Err(UnsupportedFormat),
  )
}

///|
test "wav/error wrong depth" {
  assert_true(
    @wav.decode(patch(fixture(), 34, b"\x08\x00")) is Err(UnsupportedFormat),
  )
}

///|
test "wav/error zero channels" {
  assert_true(
    @wav.decode(patch(fixture(), 22, b"\x00\x00")) is Err(InvalidChannels),
  )
}

///|
test "wav/error too many channels" {
  assert_true(
    @wav.decode(patch(fixture(), 22, b"\xff\xff")) is Err(InvalidChannels),
  )
}

///|
test "wav/error zero rate" {
  assert_true(
    @wav.decode(patch(fixture(), 24, b"\x00\x00\x00\x00")) is Err(InvalidRate),
  )
}

///|
test "wav/error inconsistent alignment" {
  assert_true(
    @wav.decode(patch(fixture(), 32, b"\x01\x00")) is Err(InvalidFormat),
  )
}

///|
test "wav/error inconsistent byte rate" {
  assert_true(
    @wav.decode(patch(fixture(), 28, b"\x01\x00\x00\x00")) is Err(InvalidFormat),
  )
}

///|
test "wav/error oversized chunk" {
  assert_true(
    @wav.decode(patch(fixture(), 40, b"\xff\xff\xff\xff")) is Err(Truncated),
  )
}

///|
test "wav/error duplicate data" {
  assert_true(
    @wav.decode(riff_size(fixture() + b"data\x00\x00\x00\x00"))
    is Err(DuplicateChunk),
  )
}

///|
test "wav/error duplicate format" {
  let base = fixture().to_array()
  assert_true(
    @wav.decode(riff_size(fixture() + Bytes::from_array(base[12:36])))
    is Err(DuplicateChunk),
  )
}

///|
test "wav/error missing format" {
  assert_true(@wav.decode(patch(fixture(), 12, b"JUNK")) is Err(MissingFormat))
}

///|
test "wav/error missing data" {
  assert_true(@wav.decode(patch(fixture(), 36, b"JUNK")) is Err(MissingData))
}

///|
test "wav/error partial frame" {
  let mono = @wav.encode(48000, 1, [0.0][:]).unwrap().bytes
  let malformed = patch(
    patch(patch(mono, 22, b"\x02\x00"), 32, b"\x04\x00"),
    28,
    b"\x00\xee\x02\x00",
  )
  assert_true(@wav.decode(malformed) is Err(FrameAlignment))
}

///|
test "wav/error encode nonfinite and invalid parameters" {
  assert_true(@wav.encode(0, 1, [][:]) is Err(InvalidRate))
  assert_true(@wav.encode(48000, 0, [][:]) is Err(InvalidChannels))
  assert_true(@wav.encode(48000, 2, [0.0][:]) is Err(FrameAlignment))
  assert_true(@wav.encode(48000, 1, [1.0 / 0.0][:]) is Err(NonFinite(0)))
}

///|
test "wav/error truncated chunk header and missing odd pad" {
  assert_true(@wav.decode(riff_size(fixture() + b"bad")) is Err(Truncated))
  assert_true(
    @wav.decode(riff_size(fixture() + b"JUNK\x01\x00\x00\x00x"))
    is Err(Truncated),
  )
}
