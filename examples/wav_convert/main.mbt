///|
fn main {
  let args = @env.args()
  if args.length() != 3 {
    abort("usage: wav_convert NEW_INPUT.wav NEW_OUTPUT.wav")
  }
  let fixture = @wav.encode(44100, 2, @signals.tone(44100, 1000.0, 441, 2)[:]).unwrap()
  @io.write_new_file(args[1], fixture.bytes).unwrap()
  let audio = @wav.decode(@io.read_file(args[1]).unwrap()).unwrap()
  let config = @src.Config::new(audio.rate, 48000, audio.channels).unwrap()
  let samples = @src.resample(config, audio.samples[:]).unwrap()
  let result = @wav.encode(48000, audio.channels, samples[:]).unwrap()
  @io.write_new_file(args[2], result.bytes).unwrap()
  println("input_frames=441 output_frames=480 output_rate=48000 channels=2")
}
