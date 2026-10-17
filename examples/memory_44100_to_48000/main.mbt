///|
fn main {
  let config = @src.Config::new(44100, 48000, 2).unwrap()
  let input = @signals.tone(44100, 1000.0, 4410, 2)
  let output = @src.resample(config, input[:]).unwrap()
  if output.length() != 9600 {
    abort("frame count mismatch")
  }
  println("input_frames=4410 output_frames=4800 channels=2")
}
