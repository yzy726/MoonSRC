///|
fn feed(
  stream : @src.Resampler,
  input : Array[Double],
  output : FixedArray[Double],
  channels : Int,
  frames : Int,
) -> Double {
  let mut remaining = frames
  let mut checksum = 0.0
  while remaining > 0 {
    let block = remaining.min(257)
    let mut consumed = 0
    while consumed < block {
      let progress = stream
        .process(input[consumed * channels:block * channels], output)
        .unwrap()
      if progress.consumed_frames == 0 && progress.produced_frames == 0 {
        abort("stream did not advance")
      }
      consumed += progress.consumed_frames
      for i in 0..<(progress.produced_frames * channels) {
        checksum += output[i]
      }
    }
    remaining -= block
  }
  while !stream.is_finished() {
    let progress = stream.finish(output).unwrap()
    for i in 0..<(progress.produced_frames * channels) {
      checksum += output[i]
    }
  }
  if checksum.is_nan() || checksum.is_inf() {
    abort("nonfinite checksum")
  }
  checksum
}

///|
fn main {
  let args = @env.args()
  if args.length() != 5 {
    abort("usage: bounded_stream SECONDS INPUT_RATE OUTPUT_RATE CHANNELS")
  }
  let seconds = @string.parse_int(args[1]) catch {
    _ => abort("invalid duration")
  }
  let input_rate = @string.parse_int(args[2]) catch {
    _ => abort("invalid input rate")
  }
  let output_rate = @string.parse_int(args[3]) catch {
    _ => abort("invalid output rate")
  }
  let channels = @string.parse_int(args[4]) catch {
    _ => abort("invalid channels")
  }
  if seconds < 1 || seconds > 600 {
    abort("duration outside probe budget")
  }
  let config = @src.Config::new(input_rate, output_rate, channels).unwrap()
  let stream = @src.Resampler::new(config)
  let input = Array::make(257 * channels, 0.25)
  let output = FixedArray::make(128 * channels, 0.0)
  ignore(feed(stream, input, output, channels, 48000))
  stream.reset()
  let rss_before = @probe.rss(false)
  let start = @probe.seconds()
  let checksum = feed(stream, input, output, channels, seconds * input_rate)
  let elapsed = @probe.seconds() - start
  let rss_after = @probe.rss(false)
  let rss_peak = @probe.rss(true)
  let stats = stream.stats()
  println(
    "{\"audio_seconds\":\{seconds},\"input_rate\":\{input_rate},\"output_rate\":\{output_rate},\"channels\":\{channels},\"input_frames\":\{stats.input_frames},\"output_frames\":\{stats.output_frames},\"peak_history_frames\":\{stats.peak_history_frames},\"history_capacity_samples\":\{stats.history_capacity_samples},\"coefficient_samples\":\{stats.coefficient_samples},\"internal_samples\":\{stats.internal_samples},\"input_block_frames\":257,\"output_capacity_frames\":128,\"elapsed_seconds\":\{elapsed},\"input_frames_per_second\":\{stats.input_frames.to_double() / elapsed},\"rss_before_bytes\":\{rss_before},\"rss_after_bytes\":\{rss_after},\"process_peak_rss_bytes\":\{rss_peak},\"checksum\":\{checksum}}",
  )
}
