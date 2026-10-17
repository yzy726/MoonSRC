///|
fn main {
  let args = @env.args()
  if args.length() != 3 {
    abort("usage: quality PASSBAND.f64 ALIAS.f64 (new paths)")
  }
  let config = @src.Config::new(48000, 16000, 1).unwrap()
  for pair in [(1000.0, args[1]), (12000.0, args[2])] {
    let input = @signals.tone(48000, pair.0, 48000, 1)
    let output = @src.resample(config, input[:]).unwrap()
    let buffer = @buffer.Buffer(size_hint=output.length() * 8)
    for sample in output {
      buffer.write_double_le(sample)
    }
    match @io.write_new_file(pair.1, buffer.to_bytes()) {
      Ok(_) => ()
      Err(message) => {
        println(message)
        @io.exit(2)
      }
    }
    println(
      "frequency_in=\{pair.0} frames_in=48000 frames_out=\{output.length()}",
    )
  }
}
