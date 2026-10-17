///|
/// Counts for this call, in complete frames. Retry unconsumed input.
pub(all) struct Progress {
  consumed_frames : Int
  produced_frames : Int
  needs_input : Bool
  needs_output : Bool
  finished : Bool
}

///|
/// Future input needed by the centered filter; no frames are prepended to output.
pub(all) struct Latency {
  input_frames : Int
  output_frames : Int
  seconds : Double
}

///|
/// Current stream counters and fixed storage budgets (Double slots, not RSS).
pub(all) struct Stats {
  input_frames : Int64
  output_frames : Int64
  buffered_frames : Int
  peak_history_frames : Int
  history_capacity_samples : Int
  coefficient_samples : Int
  internal_samples : Int
}

///|
enum StreamState {
  Active
  Finishing
  Finished
  Failed
}

///|
/// A single PCM stream. Internal sample storage has a fixed upper bound.
pub struct Resampler {
  priv config : Config
  priv coefficients : FixedArray[FixedArray[Double]]
  priv history : FixedArray[Double]
  priv capacity : Int
  priv radius : Int
  priv mut input_count : Int64
  priv mut output_count : Int64
  priv mut position : Int64
  priv mut phase : Int
  priv mut peak : Int
  priv mut state : StreamState
}

///|
/// Construct a bounded filter and ring. Config can only be created by validation.
pub fn Resampler::new(config : Config) -> Resampler {
  let identity = config.input_rate == config.output_rate
  let radius = if identity { 0 } else { @filter.FILTER_RADIUS }
  let ratio = config.output_rate.to_double() / config.input_rate.to_double()
  let coefficients = if identity {
    FixedArray::make(0, FixedArray::make(0, 0.0))
  } else {
    @filter.make_filter(
      config.numerator,
      0.94 * (if ratio < 1.0 { ratio } else { 1.0 }),
    ).unwrap()
  }
  let capacity = if identity { 0 } else { 2 * radius + 8 }
  {
    config,
    coefficients,
    history: FixedArray::make(capacity * config.channels, 0.0),
    capacity,
    radius,
    input_count: 0L,
    output_count: 0L,
    position: 0L,
    phase: 0,
    peak: 0,
    state: Active,
  }
}

///|
/// Lookahead in input/output frames, and seconds. Identity has zero latency.
pub fn Resampler::latency(self : Resampler) -> Latency {
  {
    input_frames: self.radius,
    output_frames: (
      self.radius * self.config.numerator + self.config.denominator - 1
    ) /
    self.config.denominator,
    seconds: self.radius.to_double() / self.config.input_rate.to_double(),
  }
}

///|
/// True only when finish has drained all timestamped output frames.
pub fn Resampler::is_finished(self : Resampler) -> Bool {
  self.state is Finished
}

///|
fn Resampler::live_frames(self : Resampler) -> Int {
  if self.radius == 0 || self.state is Finished {
    return 0
  }
  let oldest = (self.position - self.radius.to_int64()).max(0L)
  (self.input_count - oldest).max(0L).to_int()
}

///|
/// Storage counts exclude caller buffers, object headers and allocator overhead.
pub fn Resampler::stats(self : Resampler) -> Stats {
  let coefficient_samples = self.coefficients.length() * (2 * self.radius + 1)
  {
    input_frames: self.input_count,
    output_frames: self.output_count,
    buffered_frames: self.live_frames(),
    peak_history_frames: self.peak,
    history_capacity_samples: self.history.length(),
    coefficient_samples,
    internal_samples: self.history.length() + coefficient_samples,
  }
}

///|
/// Explicitly start an unrelated stream while reusing all allocated tables/ring.
pub fn Resampler::reset(self : Resampler) -> Unit {
  self.input_count = 0L
  self.output_count = 0L
  self.position = 0L
  self.phase = 0
  self.peak = 0
  self.state = Active
}

///|
fn Resampler::advance(self : Resampler) -> Unit {
  let next = self.phase + self.config.denominator
  self.position += (next / self.config.numerator).to_int64()
  self.phase = next % self.config.numerator
}

///|
fn Resampler::emit(
  self : Resampler,
  output : FixedArray[Double],
  offset : Int,
) -> Result[Unit, ResampleError] {
  let row = self.coefficients[self.phase]
  for channel in 0..<self.config.channels {
    let mut sum = 0.0
    for tap in 0..<row.length() {
      let frame = self.position + (tap - self.radius).to_int64()
      if frame >= 0L && frame < self.input_count {
        let index = (frame % self.capacity.to_int64()).to_int() *
          self.config.channels +
          channel
        sum += row[tap] * self.history[index]
      }
    }
    if sum.is_nan() || sum.is_inf() {
      self.state = Failed
      return Err(NumericOverflow)
    }
    output[offset * self.config.channels + channel] = sum
  }
  self.output_count += 1L
  Ok(())
}

///|
fn Resampler::progress(
  self : Resampler,
  consumed : Int,
  produced : Int,
  capacity : Int,
) -> Progress {
  {
    consumed_frames: consumed,
    produced_frames: produced,
    needs_input: self.state is Active &&
    (
      self.radius == 0 ||
      self.position + self.radius.to_int64() >= self.input_count
    ),
    needs_output: produced == capacity && !(self.state is Finished),
    finished: self.state is Finished,
  }
}

///|
/// Validate the entire supplied view, then consume only reported frames.
/// Zero output capacity consumes nothing. Invalid/misaligned/nonfinite inputs
/// leave stream state unchanged. NumericOverflow requires reset before reuse.
pub fn Resampler::process(
  self : Resampler,
  input : ArrayView[Double],
  output : FixedArray[Double],
) -> Result[Progress, ResampleError] {
  if !(self.state is Active) {
    return Err(InvalidState)
  }
  let channels = self.config.channels
  if input.length() % channels != 0 {
    return Err(MisalignedInput)
  }
  if output.length() % channels != 0 {
    return Err(MisalignedOutput)
  }
  for i in 0..<input.length() {
    if input[i].is_nan() || input[i].is_inf() {
      return Err(NonFinite(i))
    }
  }
  let offered = input.length() / channels
  if self.input_count > 9223372036854775614L - offered.to_int64() {
    return Err(FrameOverflow)
  }
  match self.config.output_frames(self.input_count + offered.to_int64()) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let capacity = output.length() / channels
  if self.radius == 0 {
    let count = offered.min(capacity)
    for i in 0..<(count * channels) {
      output[i] = input[i]
    }
    self.input_count += count.to_int64()
    self.output_count += count.to_int64()
    return Ok(self.progress(count, count, capacity))
  }
  let mut consumed = 0
  let mut produced = 0
  while produced < capacity {
    if self.position + self.radius.to_int64() < self.input_count {
      match self.emit(output, produced) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      produced += 1
      self.advance()
    } else if consumed < offered {
      let slot = (self.input_count % self.capacity.to_int64()).to_int() *
        channels
      for channel in 0..<channels {
        self.history[slot + channel] = input[consumed * channels + channel]
      }
      self.input_count += 1L
      consumed += 1
      self.peak = self.peak.max(self.live_frames())
    } else {
      break
    }
  }
  Ok(self.progress(consumed, produced, capacity))
}

///|
/// Signal end of input and drain the same FIR using zero extension. Repeated
/// calls are allowed, including zero capacity; completed finish is idempotent.
pub fn Resampler::finish(
  self : Resampler,
  output : FixedArray[Double],
) -> Result[Progress, ResampleError] {
  if output.length() % self.config.channels != 0 {
    return Err(MisalignedOutput)
  }
  if self.state is Failed {
    return Err(InvalidState)
  }
  if self.state is Active {
    self.state = Finishing
  }
  let target = self.config.output_frames(self.input_count).unwrap()
  let capacity = output.length() / self.config.channels
  let mut produced = 0
  while self.output_count < target && produced < capacity {
    match self.emit(output, produced) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    produced += 1
    if self.output_count < target {
      self.advance()
    }
  }
  if self.output_count == target {
    self.state = Finished
  }
  Ok(self.progress(0, produced, capacity))
}
