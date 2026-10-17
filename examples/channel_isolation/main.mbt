///|
fn main {
  let config = @src.Config::new(44100, 48000, 2).unwrap()
  let input = @signals.tone(44100, 997.0, 4410, 2)
  let output = @src.resample(config, input[:]).unwrap()
  for frame in 0..<(output.length() / 2) {
    if output[frame * 2 + 1] != 0.0 {
      abort("channel crosstalk")
    }
  }
  println("output_frames=4800 right_channel_peak=0")
}
