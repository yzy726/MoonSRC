///|
fn gcd(a : Int, b : Int) -> Int {
  for a = a, b = b; b != 0; {
    continue b, a % b
  } nobreak {
    a
  }
}

///|
/// Final frame count: ceil(input_frames * output_rate / input_rate).
/// Uses quotient/remainder decomposition so even valid huge downsampling counts
/// do not overflow an intermediate product. Negative or unrepresentable counts
/// return FrameOverflow.
pub fn Config::output_frames(
  self : Config,
  input_frames : Int64,
) -> Result[Int64, ResampleError] {
  if input_frames < 0L {
    return Err(FrameOverflow)
  }
  let p = self.numerator.to_int64()
  let q = self.denominator.to_int64()
  let whole = input_frames / q
  let remainder = input_frames % q
  let tail = (remainder * p + q - 1L) / q
  if whole > (9223372036854775807L - tail) / p {
    return Err(FrameOverflow)
  }
  Ok(whole * p + tail)
}
