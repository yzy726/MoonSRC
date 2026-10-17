///|
/// Supported container is RIFF/WAVE, format tag 1, signed PCM16 little endian.
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
/// PCM16 WAV bytes plus the explicit quantizer saturation count.
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
/// Validate RIFF bounds, chunk padding and frame/byte-rate metadata before PCM
/// allocation. At most 33,554,476 file bytes; rate 1..192000 Hz, 1/2 channels.
/// Unknown chunks are skipped; duplicate fmt/data and trailing bytes are errors.
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
      if u16(bytes, start) != 1 || u16(bytes, start + 14) != 16 {
        return Err(UnsupportedFormat)
      }
      channels = u16(bytes, start + 2)
      if channels < 1 || channels > 2 {
        return Err(InvalidChannels)
      }
      let rate64 = u32(bytes, start + 4)
      if rate64 < 1L || rate64 > 192000L {
        return Err(InvalidRate)
      }
      rate = rate64.to_int()
      if u16(bytes, start + 12) != channels * 2 ||
        u32(bytes, start + 8) != rate64 * channels.to_int64() * 2L {
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
  if data_length % (channels * 2) != 0 {
    return Err(FrameAlignment)
  }
  let pcm = Bytes::makei(data_length, i => bytes[start + i])
  match @pcm.decode(pcm) {
    Ok(samples) => Ok({ rate, channels, samples, })
    Err(_) => Err(ResourceLimit)
  }
}

///|
/// Encode exactly one canonical fmt/data RIFF file. Quantization is the same
/// explicit PCM16 adapter used independently by consumers.
pub fn encode(
  rate : Int,
  channels : Int,
  samples : ArrayView[Double],
) -> Result[Encoded, WavError] {
  if rate < 1 || rate > 192000 {
    return Err(InvalidRate)
  }
  if channels < 1 || channels > 2 {
    return Err(InvalidChannels)
  }
  if samples.length() % channels != 0 {
    return Err(FrameAlignment)
  }
  let pcm = match @pcm.encode(samples) {
    Ok(value) => value
    Err(NonFinite(index)) => return Err(NonFinite(index))
    Err(_) => return Err(ResourceLimit)
  }
  let buffer = @buffer.Buffer(size_hint=44 + pcm.bytes.length())
  buffer.write_bytes(b"RIFF"[:])
  buffer.write_int_le(36 + pcm.bytes.length())
  buffer.write_bytes(b"WAVEfmt "[:])
  buffer.write_int_le(16)
  buffer.write_uint16_le(1)
  buffer.write_uint16_le(channels.to_uint16())
  buffer.write_int_le(rate)
  buffer.write_int_le(rate * channels * 2)
  buffer.write_uint16_le((channels * 2).to_uint16())
  buffer.write_uint16_le(16)
  buffer.write_bytes(b"data"[:])
  buffer.write_int_le(pcm.bytes.length())
  buffer.write_bytes(pcm.bytes[:])
  Ok({ bytes: buffer.to_bytes(), clipped_samples: pcm.clipped_samples, })
}
