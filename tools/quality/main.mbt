///|
fn write_result(
  config : @src.Config,
  input : Array[Double],
  path : String,
) -> Unit {
  let output = @src.resample(config, input[:]).unwrap()
  let buffer = @buffer.Buffer(size_hint=output.length() * 8)
  for sample in output {
    buffer.write_double_le(sample)
  }
  match @io.write_new_file(path, buffer.to_bytes()) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      @io.exit(2)
    }
  }
  let stream = @src.Resampler::new(config)
  println(
    "frames_in=\{input.length()/config.channels()} frames_out=\{output.length()/config.channels()} radius=\{stream.latency().input_frames} phases_coefficients=\{stream.stats().coefficient_samples}",
  )
}

///|
fn number(text : String) -> Int {
  @string.parse_int(text) catch {
    _ => abort("integer export option required")
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() == 3 {
    let config = @src.Config::new(48000, 16000, 1).unwrap()
    for pair in [(1000.0, args[1]), (12000.0, args[2])] {
      write_result(config, @signals.tone(48000, pair.0, 48000, 1), pair.1)
    }
  } else if args.length() == 9 && args[1] == "export" {
    let fin = number(args[3])
    let fout = number(args[4])
    let quality : @src.Quality = match args[5] {
      "low" => LowLatency
      "balanced" => Balanced
      "high" => HighQuality
      _ => abort("quality must be low, balanced or high")
    }
    let frames = number(args[7])
    let channels = number(args[8])
    if frames < 1 || frames > 1048576 {
      abort("export input frame budget")
    }
    let config = @src.Config::with_quality(fin, fout, channels, quality).unwrap()
    let input = match args[6] {
      "dc" => Array::make(frames * channels, 0.25)
      "impulse" =>
        Array::makei(frames * channels, i => {
          if i / channels == frames / 2 {
            1.0
          } else {
            0.0
          }
        })
      text => {
        let frequency = @string.parse_double(text) catch {
          _ => abort("signal must be dc, impulse or frequency")
        }
        @signals.tone(fin, frequency, frames, channels)
      }
    }
    write_result(config, input, args[2])
  } else {
    abort(
      "usage: quality PASS.f64 ALIAS.f64; quality export OUTPUT.f64 FIN FOUT low|balanced|high dc|impulse|FREQUENCY INPUT_FRAMES CHANNELS",
    )
  }
}
