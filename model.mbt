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
  priv quality : Quality
} derive(Debug, Eq)

///|
/// Accept fixed rates 8000..192000 Hz and 1..8 channels, using Balanced quality.
/// Exact phase/coefficient budgets are checked before construction allocates.
pub fn Config::new(
  input_rate : Int,
  output_rate : Int,
  channels : Int,
) -> Result[Config, ResampleError] {
  Config::with_quality(input_rate, output_rate, channels, Balanced)
}

///|
/// Quality presets with increasing filter support and distinct cutoff rolloffs.
/// Balanced retains the 0.1.0 behavior for every previously supported pair.
pub(all) enum Quality {
  LowLatency
  Balanced
  HighQuality
} derive(Debug, Eq)

///|
pub extend Quality with @debug.Debug::{to_repr}

///|
pub extend Quality with Eq::{equal, not_equal}

///|
fn Quality::base_radius(self : Quality) -> Int {
  match self {
    LowLatency => 32
    Balanced => 96
    HighQuality => 192
  }
}

///|
/// Validate the full configuration without allocation. At most 4096 exact phases
/// and 1048576 coefficient Doubles. Extreme co-prime pairs return ResourceLimit.
pub fn Config::with_quality(
  input_rate : Int,
  output_rate : Int,
  channels : Int,
  quality : Quality,
) -> Result[Config, ResampleError] {
  if input_rate < 8000 || input_rate > 192000 {
    return Err(InvalidRate(input_rate))
  }
  if output_rate < 8000 || output_rate > 192000 {
    return Err(InvalidRate(output_rate))
  }
  if channels < 1 || channels > 8 {
    return Err(InvalidChannels(channels))
  }
  let divisor = gcd(input_rate, output_rate)
  let numerator = output_rate / divisor
  let scale = ((input_rate + 3 * output_rate - 1) / (3 * output_rate)).max(1)
  let radius = if input_rate == output_rate {
    0
  } else {
    quality.base_radius() * scale
  }
  if numerator > 4096 || numerator * (2 * radius + 1) > 1048576 {
    return Err(ResourceLimit)
  }
  Ok({
    input_rate,
    output_rate,
    channels,
    numerator,
    denominator: input_rate / divisor,
    quality,
  })
}

///|
/// Selected immutable quality preset.
pub fn Config::quality(self : Config) -> Quality {
  self.quality
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
