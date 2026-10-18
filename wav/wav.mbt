///|
/// RIFF/WAVE errors for PCM16, IEEE float32 and validated extensible headers.
pub(all) enum WavError {
  InvalidHeader
  Truncated
  UnsupportedFormat
  InvalidFormat
  InvalidChannels
  InvalidRate
  MissingFormat
  MissingData
  DuplicateChunk
  FrameAlignment
  NonFinite(Int)
  SampleOverflow(Int)
  ResourceLimit
} derive(Debug, Eq)

///|
pub extend WavError with @debug.Debug::{to_repr}

///|
pub extend WavError with Eq::{equal, not_equal}

///|
/// Decoded interleaved samples; the byte adapter does not resample.
pub(all) struct Audio {
  rate : Int
  channels : Int
  samples : Array[Double]
}

///|
/// Encoded WAV bytes and PCM16 saturation count (zero for float32).
pub(all) struct Encoded {
  bytes : Bytes
  clipped_samples : Int
}

///|
fn tag(bytes : Bytes, offset : Int, expected : Bytes) -> Bool {
  for i in 0..<expected.length() {
    if bytes[offset + i] != expected[i] {
      return false
    }
  }
  true
}

///|
fn u16(bytes : Bytes, offset : Int) -> Int {
  bytes[offset].to_int() + bytes[offset + 1].to_int() * 256
}

///|
fn u32(bytes : Bytes, offset : Int) -> Int64 {
  bytes[offset].to_int64() +
  bytes[offset + 1].to_int64() * 256L +
  bytes[offset + 2].to_int64() * 65536L +
  bytes[offset + 3].to_int64() * 16777216L
}

///|
fn sample32(bytes : Bytes, offset : Int) -> Double {
  Float::reinterpret_from_int(
    u16(bytes, offset) | (u16(bytes, offset + 2) << 16),
  ).to_double()
}

///|
/// Decode PCM16 or finite IEEE float32, including extensible 1..8 channel WAV.
/// The adapter preserves ordinal channel order, not speaker metadata. Unknown
/// chunks are skipped; duplicate fmt/data, malformed lengths and nonfinite data
/// are rejected. File budget is 33554476 bytes and rate metadata 1..192000 Hz.
pub fn decode(bytes : Bytes) -> Result[Audio, WavError] {
  let limit = bytes.length()
  if limit > 33554476 {
    return Err(ResourceLimit)
  }
  if limit < 12 {
    return Err(Truncated)
  }
  if !tag(bytes, 0, b"RIFF") || !tag(bytes, 8, b"WAVE") {
    return Err(InvalidHeader)
  }
  let declared = u32(bytes, 4) + 8L
  if declared > limit.to_int64() {
    return Err(Truncated)
  }
  if declared != limit.to_int64() {
    return Err(InvalidHeader)
  }
  let mut offset = 12
  let mut have_format = false
  let mut rate = 0
  let mut channels = 0
  let mut width = 0
  let mut data_start : Int? = None
  let mut data_length = 0
  while offset < limit {
    if limit - offset < 8 {
      return Err(Truncated)
    }
    let length = u32(bytes, offset + 4)
    let start = offset + 8
    if length > (limit - start).to_int64() {
      return Err(Truncated)
    }
    let size = length.to_int()
    let padding = size % 2
    if padding > limit - start - size {
      return Err(Truncated)
    }
    if tag(bytes, offset, b"fmt ") {
      if have_format {
        return Err(DuplicateChunk)
      }
      if size < 16 {
        return Err(InvalidFormat)
      }
      let mut format = u16(bytes, start)
      let bits = u16(bytes, start + 14)
      channels = u16(bytes, start + 2)
      if channels < 1 || channels > 8 {
        return Err(InvalidChannels)
      }
      if format == 65534 {
        if size < 40 || u16(bytes, start + 16) != 22 {
          return Err(InvalidFormat)
        }
        if u16(bytes, start + 18) != bits {
          return Err(UnsupportedFormat)
        }
        if tag(
            bytes,
            start + 24,
            b"\x01\x00\x00\x00\x00\x00\x10\x00\x80\x00\x00\xaa\x00\x38\x9b\x71",
          ) {
          format = 1
        } else if tag(
            bytes,
            start + 24,
            b"\x03\x00\x00\x00\x00\x00\x10\x00\x80\x00\x00\xaa\x00\x38\x9b\x71",
          ) {
          format = 3
        } else {
          return Err(UnsupportedFormat)
        }
        let mut mask = u32(bytes, start + 20)
        let mut speakers = 0
        let unspecified = mask == 0L
        while mask > 0L {
          speakers += (mask % 2L).to_int()
          mask /= 2L
        }
        if !unspecified && speakers != channels {
          return Err(InvalidFormat)
        }
      } else if format == 3 &&
        (size == 17 || (size >= 18 && u16(bytes, start + 16) != 0)) {
        return Err(InvalidFormat)
      }
      if format == 1 && bits == 16 {
        width = 2
      } else if format == 3 && bits == 32 {
        width = 4
      } else {
        return Err(UnsupportedFormat)
      }
      let rate64 = u32(bytes, start + 4)
      if rate64 < 1L || rate64 > 192000L {
        return Err(InvalidRate)
      }
      rate = rate64.to_int()
      if u16(bytes, start + 12) != channels * width ||
        u32(bytes, start + 8) != rate64 * channels.to_int64() * width.to_int64() {
        return Err(InvalidFormat)
      }
      have_format = true
    } else if tag(bytes, offset, b"data") {
      if data_start is Some(_) {
        return Err(DuplicateChunk)
      }
      data_start = Some(start)
      data_length = size
    }
    offset = start + size + padding
  }
  if !have_format {
    return Err(MissingFormat)
  }
  let start = match data_start {
    Some(start) => start
    None => return Err(MissingData)
  }
  if data_length % (channels * width) != 0 {
    return Err(FrameAlignment)
  }
  if width == 2 {
    let pcm = Bytes::makei(data_length, i => bytes[start + i])
    match @pcm.decode(pcm) {
      Ok(samples) => Ok({ rate, channels, samples, })
      Err(_) => Err(ResourceLimit)
    }
  } else {
    let count = data_length / 4
    for i in 0..<count {
      let value = sample32(bytes, start + 4 * i)
      if value.is_nan() || value.is_inf() {
        return Err(NonFinite(i))
      }
    }
    Ok({
      rate,
      channels,
      samples: Array::makei(count, i => sample32(bytes, start + 4 * i)),
    })
  }
}

///|
fn encode_audio(
  rate : Int,
  channels : Int,
  samples : ArrayView[Double],
  floating : Bool,
) -> Result[Encoded, WavError] {
  if rate < 1 || rate > 192000 {
    return Err(InvalidRate)
  }
  if channels < 1 || channels > 8 {
    return Err(InvalidChannels)
  }
  if samples.length() % channels != 0 {
    return Err(FrameAlignment)
  }
  let width = if floating { 4 } else { 2 }
  let extensible = channels > 2
  let fmt_size = if extensible { 40 } else if floating { 18 } else { 16 }
  let overhead = 12 + 8 + fmt_size + (if floating { 12 } else { 0 }) + 8
  if samples.length() > (33554476 - overhead) / width {
    return Err(ResourceLimit)
  }
  for i in 0..<samples.length() {
    if samples[i].is_nan() || samples[i].is_inf() {
      return Err(NonFinite(i))
    }
    if floating && Float::from_double(samples[i]).to_double().is_inf() {
      return Err(SampleOverflow(i))
    }
  }
  let (data, clipped) = if floating {
    let payload = @buffer.Buffer(size_hint=samples.length() * 4)
    for sample in samples {
      payload.write_int_le(Float::from_double(sample).reinterpret_as_int())
    }
    (payload.to_bytes(), 0)
  } else {
    match @pcm.encode(samples) {
      Ok(value) => (value.bytes, value.clipped_samples)
      Err(NonFinite(i)) => return Err(NonFinite(i))
      Err(_) => return Err(ResourceLimit)
    }
  }
  let buffer = @buffer.Buffer(size_hint=overhead + data.length())
  buffer.write_bytes(b"RIFF"[:])
  buffer.write_int_le(overhead + data.length() - 8)
  buffer.write_bytes(b"WAVEfmt "[:])
  buffer.write_int_le(fmt_size)
  buffer.write_uint16_le(
    (if extensible { 65534 } else if floating { 3 } else { 1 }).to_uint16(),
  )
  buffer.write_uint16_le(channels.to_uint16())
  buffer.write_int_le(rate)
  buffer.write_int_le(rate * channels * width)
  buffer.write_uint16_le((channels * width).to_uint16())
  buffer.write_uint16_le((width * 8).to_uint16())
  if extensible {
    buffer.write_uint16_le(22)
    buffer.write_uint16_le((width * 8).to_uint16())
    buffer.write_int_le(0)
    buffer.write_int_le(if floating { 3 } else { 1 })
    buffer.write_bytes(b"\x00\x00\x10\x00\x80\x00\x00\xaa\x00\x38\x9b\x71"[:])
  } else if floating {
    buffer.write_uint16_le(0)
  }
  if floating {
    buffer.write_bytes(b"fact"[:])
    buffer.write_int_le(4)
    buffer.write_int_le(samples.length() / channels)
  }
  buffer.write_bytes(b"data"[:])
  buffer.write_int_le(data.length())
  buffer.write_bytes(data[:])
  Ok({ bytes: buffer.to_bytes(), clipped_samples: clipped, })
}

///|
/// Encode PCM16 WAV with explicit saturation and ties-away-from-zero rounding.
/// One/two channels retain canonical 44-byte headers; multichannel uses an
/// extensible header with unspecified speaker mask and ordinal channel order.
pub fn encode(
  rate : Int,
  channels : Int,
  samples : ArrayView[Double],
) -> Result[Encoded, WavError] {
  encode_audio(rate, channels, samples, false)
}

///|
/// Encode IEEE float32 without unit-range clipping. Rounds to binary32; rejects
/// nonfinite input and finite values that overflow binary32. Includes fact; uses
/// an extensible header for >2 channels. clipped_samples is always zero.
pub fn encode_float32(
  rate : Int,
  channels : Int,
  samples : ArrayView[Double],
) -> Result[Encoded, WavError] {
  encode_audio(rate, channels, samples, true)
}
