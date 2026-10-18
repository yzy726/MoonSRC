///|
fn main {
  let stream = @src.Resampler::new(@src.Config::new(48000, 16000, 1).unwrap())
  let input = Array::make(257, 0.25)
  let output = FixedArray::make(128, 0.0)
  let mut remaining = 2880000
  let mut checksum = 0.0
  while remaining > 0 {
    let count = remaining.min(257)
    let mut used = 0
    while used < count {
      let p = stream.process(input[used:count], output).unwrap()
      if p.consumed_frames == 0 && p.produced_frames == 0 {
        abort("stream stalled")
      }
      used += p.consumed_frames
      for i in 0..<p.produced_frames {
        checksum += output[i]
      }
    }
    remaining -= count
  }
  while !stream.is_finished() {
    let p = stream.finish(output).unwrap()
    for i in 0..<p.produced_frames {
      checksum += output[i]
    }
  }
  let s = stream.stats()
  if s.output_frames != 960000L ||
    s.peak_history_frames != 193 ||
    s.internal_samples != 393 ||
    checksum < 239000.0 {
    abort("bounded stream invariant")
  }
  println(
    "bounded_stream seconds=60 frames_out=\{s.output_frames} peak_history_frames=\{s.peak_history_frames} internal_samples=\{s.internal_samples} checksum=\{checksum}",
  )
}
