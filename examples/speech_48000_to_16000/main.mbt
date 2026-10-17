///|
fn main {
  let config = @src.Config::new(48000, 16000, 1).unwrap()
  let pass = @src.resample(config, @signals.tone(48000, 1000.0, 48000, 1)[:]).unwrap()
  let stop = @src.resample(config, @signals.tone(48000, 12000.0, 48000, 1)[:]).unwrap()
  let pass_amplitude = @signals.magnitude(pass[:], 16000, 1000.0, 256)
  let alias_amplitude = @signals.magnitude(stop[:], 16000, 4000.0, 256)
  let pass_db = 20.0 * @math.log10(pass_amplitude / 0.5)
  let alias_db = 20.0 * @math.log10(alias_amplitude / pass_amplitude)
  if pass_db.abs() > 0.5 || alias_db > -50.0 {
    abort("quality threshold failed")
  }
  println(
    "synthetic_voice_band input_frames=48000 output_frames=16000 passband_error_db=\{pass_db} alias_relative_db=\{alias_db}",
  )
}
