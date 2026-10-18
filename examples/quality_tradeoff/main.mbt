///|
fn main {
  let pass = @wav.decode(
    @wav.encode_float32(48000, 1, @signals.tone(48000, 1000.0, 48000, 1)[:]).unwrap().bytes,
  ).unwrap()
  let stop = @wav.decode(
    @wav.encode_float32(48000, 1, @signals.tone(48000, 12000.0, 48000, 1)[:]).unwrap().bytes,
  ).unwrap()
  for
    tuple in [
      ("low", @src.LowLatency, -45.0),
      ("balanced", Balanced, -50.0),
      ("high", HighQuality, -70.0),
    ] {
    let c = @src.Config::with_quality(48000, 16000, 1, tuple.1).unwrap()
    let start = @probe.seconds()
    let pass_out = @src.resample(c, pass.samples[:]).unwrap()
    let stop_out = @src.resample(c, stop.samples[:]).unwrap()
    let elapsed = @probe.seconds() - start
    let amplitude = @signals.magnitude(pass_out[:], 16000, 1000.0, 256)
    let folded = @signals.magnitude(stop_out[:], 16000, 4000.0, 256)
    let pass_db = 20.0 * @math.log10(amplitude / 0.5)
    let alias_db = 20.0 * @math.log10(folded / amplitude)
    if pass_db.abs() > 0.5 || alias_db > tuple.2 || elapsed <= 0.0 {
      abort("quality/clock check failed")
    }
    let stream = @src.Resampler::new(c)
    println(
      "quality=\{tuple.0} frames_out=16000 passband_db=\{pass_db} alias_db=\{alias_db} lookahead=\{stream.latency().input_frames} coefficient_samples=\{stream.stats().coefficient_samples} elapsed_seconds=\{elapsed}",
    )
  }
}
