///|
priv suberror CliError {
  CliError(String)
}

///|
fn decimal(text : String, minimum : Int, maximum : Int) -> Int raise CliError {
  if text.length() == 0 {
    raise CliError("empty numeric option")
  }
  let mut value = 0
  for c in text {
    if c < '0' || c > '9' {
      raise CliError("options require decimal integers")
    }
    let digit = c.to_int() - '0'.to_int()
    if value > (maximum - digit) / 10 {
      raise CliError("numeric option exceeds budget")
    }
    value = value * 10 + digit
  }
  if value < minimum || value > maximum {
    raise CliError("numeric option outside supported range")
  }
  value
}

///|
fn options(
  args : Array[String],
  start : Int,
  fixture : Bool,
) -> (Int, Int, Int) raise CliError {
  let mut rate = 0
  let mut channels = 1
  let mut frames = 4800
  let mut have_rate = false
  let mut have_channels = false
  let mut have_frames = false
  let mut i = start
  while i < args.length() {
    if i + 1 >= args.length() {
      raise CliError("option requires a value")
    }
    match args[i] {
      "--rate" if !have_rate => {
        rate = decimal(args[i + 1], 1, 192000)
        have_rate = true
      }
      "--channels" if fixture && !have_channels => {
        channels = decimal(args[i + 1], 1, 2)
        have_channels = true
      }
      "--frames" if fixture && !have_frames => {
        frames = decimal(args[i + 1], 0, 1000000)
        have_frames = true
      }
      _ => raise CliError("unknown or repeated option: \{args[i]}")
    }
    i += 2
  }
  if !have_rate {
    raise CliError("--rate is required")
  }
  (rate, channels, frames)
}

///|
fn run(args : Array[String]) -> Unit raise CliError {
  if args.length() == 0 ||
    (args.length() == 1 && (args[0] == "--help" || args[0] == "-h")) {
    println(
      "MoonSRC 0.1.0\nmoonsrc convert INPUT.wav OUTPUT.wav --rate 48000\nmoonsrc fixture OUTPUT.wav --rate 44100 --channels 2 --frames 441\nSupports PCM16LE, mono/stereo, 44100<->48000, 48000<->16000, identity.\nOutput paths must be new. Exit 0=success, 2=invalid input or I/O failure.",
    )
    return
  }
  if args.length() == 1 && args[0] == "--version" {
    println("0.1.0")
    return
  }
  if args[0] == "fixture" && args.length() >= 4 {
    let (rate, channels, frames) = options(args, 2, true)
    match @src.Config::new(rate, rate, channels) {
      Err(error) => raise CliError(@debug.to_string(error))
      Ok(_) => ()
    }
    let samples = Array::makei(frames * channels, i => {
      if i % channels == 0 {
        0.5 *
        @math.sin(
          2.0 *
          @math.PI *
          1000.0 *
          (i / channels).to_double() /
          rate.to_double(),
        )
      } else {
        0.0
      }
    })
    let encoded = match @wav.encode(rate, channels, samples[:]) {
      Ok(value) => value
      Err(error) => raise CliError(@debug.to_string(error))
    }
    match @io.write_new_file(args[1], encoded.bytes) {
      Ok(_) => ()
      Err(error) => raise CliError(error)
    }
    println(
      "synthetic_fixture rate=\{rate} channels=\{channels} frames=\{frames}",
    )
  } else if args[0] == "convert" && args.length() >= 5 {
    let (rate, _, _) = options(args, 3, false)
    let bytes = match @io.read_file(args[1]) {
      Ok(value) => value
      Err(error) => raise CliError(error)
    }
    let audio = match @wav.decode(bytes) {
      Ok(value) => value
      Err(error) => raise CliError(@debug.to_string(error))
    }
    let config = match @src.Config::new(audio.rate, rate, audio.channels) {
      Ok(value) => value
      Err(error) => raise CliError(@debug.to_string(error))
    }
    let samples = match @src.resample(config, audio.samples[:]) {
      Ok(value) => value
      Err(error) => raise CliError(@debug.to_string(error))
    }
    let encoded = match @wav.encode(rate, audio.channels, samples[:]) {
      Ok(value) => value
      Err(error) => raise CliError(@debug.to_string(error))
    }
    match @io.write_new_file(args[2], encoded.bytes) {
      Ok(_) => ()
      Err(error) => raise CliError(error)
    }
    let latency = @src.Resampler::new(config).latency()
    println(
      "frames_in=\{audio.samples.length() / audio.channels} frames_out=\{samples.length() / audio.channels} rate=\{rate} channels=\{audio.channels} lookahead_in=\{latency.input_frames} clipped_samples=\{encoded.clipped_samples}",
    )
  } else {
    raise CliError("invalid command; run --help")
  }
}

///|
fn main {
  let args = @env.args()
  run(args[1:].to_owned()) catch {
    CliError(message) => {
      println("error: \{message}")
      @io.exit(2)
    }
  }
}
