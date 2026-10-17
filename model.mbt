///|
/// Errors returned for invalid configuration, samples, resources or stream state.
pub(all) enum ResampleError {
  InvalidRate(Int)
  UnsupportedRatio(Int, Int)
  InvalidChannels(Int)
  MisalignedInput
  MisalignedOutput
  NonFinite(Int)
  InvalidState
  FrameOverflow
  NumericOverflow
  ResourceLimit
} derive(Debug, Eq)

///|
/// Validated immutable configuration for one interleaved PCM stream.
pub struct Config {
  priv input_rate : Int
  priv output_rate : Int
  priv channels : Int
  priv numerator : Int
  priv denominator : Int
} derive(Debug, Eq)

///|
/// Accept the 0.1.0 rate matrix and one or two channels. No allocation occurs.
pub fn Config::new(
  input_rate : Int,
  output_rate : Int,
  channels : Int,
) -> Result[Config, ResampleError] {
  if input_rate != 16000 && input_rate != 44100 && input_rate != 48000 {
    return Err(InvalidRate(input_rate))
  }
  if output_rate != 16000 && output_rate != 44100 && output_rate != 48000 {
    return Err(InvalidRate(output_rate))
  }
  if channels < 1 || channels > 2 {
    return Err(InvalidChannels(channels))
  }
  if input_rate != output_rate && input_rate != 48000 && output_rate != 48000 {
    return Err(UnsupportedRatio(input_rate, output_rate))
  }
  let divisor = gcd(input_rate, output_rate)
  Ok({
    input_rate,
    output_rate,
    channels,
    numerator: output_rate / divisor,
    denominator: input_rate / divisor,
  })
}

///|
/// Input sample rate, in complete frames per second.
pub fn Config::input_rate(self : Config) -> Int {
  self.input_rate
}

///|
/// Output sample rate, in complete frames per second.
pub fn Config::output_rate(self : Config) -> Int {
  self.output_rate
}

///|
/// Number of interleaved samples in each frame.
pub fn Config::channels(self : Config) -> Int {
  self.channels
}

///|
pub extend ResampleError with @debug.Debug::{to_repr}

///|
pub extend ResampleError with Eq::{equal, not_equal}

///|
pub extend Config with @debug.Debug::{to_repr}

///|
pub extend Config with Eq::{equal, not_equal}
