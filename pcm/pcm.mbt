///|
/// Classified PCM16 conversion errors.
pub(all) enum PcmError {
  OddByteLength
  NonFinite(Int)
  ResourceLimit
} derive(Debug, Eq)

///|
pub extend PcmError with @debug.Debug::{to_repr}

///|
pub extend PcmError with Eq::{equal, not_equal}

///|
/// Quantized bytes plus the number of samples saturated to PCM16 endpoints.
pub(all) struct Encoded {
  bytes : Bytes
  clipped_samples : Int
}

///|
/// Decode signed little-endian PCM16 into Double samples divided by 32768.
/// The adapter accepts at most 16,777,216 samples per buffer.
pub fn decode(bytes : Bytes) -> Result[Array[Double], PcmError] {
  if bytes.length() % 2 != 0 {
    return Err(OddByteLength)
  }
  if bytes.length() / 2 > 16777216 {
    return Err(ResourceLimit)
  }
  Ok(
    Array::makei(bytes.length() / 2, i => {
      let value = bytes[i * 2].to_int() + bytes[i * 2 + 1].to_int() * 256
      (if value >= 32768 { value - 65536 } else { value }).to_double() / 32768.0
    }),
  )
}

///|
/// Clamp to [-1,32767/32768], multiply by 32768, round ties away from zero.
/// Reject all nonfinite samples before allocating or writing the result.
pub fn encode(samples : ArrayView[Double]) -> Result[Encoded, PcmError] {
  if samples.length() > 16777216 {
    return Err(ResourceLimit)
  }
  for i in 0..<samples.length() {
    if samples[i].is_nan() || samples[i].is_inf() {
      return Err(NonFinite(i))
    }
  }
  let bytes : FixedArray[Byte] = FixedArray::make(samples.length() * 2, 0)
  let mut clipped_samples = 0
  for i in 0..<samples.length() {
    let sample = samples[i]
    let limited = sample.max(-1.0).min(32767.0 / 32768.0)
    if limited != sample {
      clipped_samples += 1
    }
    let scaled = limited * 32768.0
    let value = (if scaled >= 0.0 {
      @math.floor(scaled + 0.5)
    } else {
      @math.ceil(scaled - 0.5)
    }).to_int()
    bytes[i * 2] = (value & 255).to_byte()
    bytes[i * 2 + 1] = ((value >> 8) & 255).to_byte()
  }
  Ok({ bytes: Bytes::from_array(bytes[:]), clipped_samples, })
}
