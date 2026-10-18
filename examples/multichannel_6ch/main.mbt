///|
fn main {
  let frames = 2048
  let input = Array::makei(frames * 6, i => {
    0.25 *
    @math.sin(
      2.0 *
      @math.PI *
      (150.0 * (i % 6 + 1).to_double()) *
      (i / 6).to_double() /
      44100.0,
    )
  })
  let c = @src.Config::with_quality(44100, 16000, 6, Balanced).unwrap()
  let output = @src.resample(c, input[:]).unwrap()
  for channel in 0..<6 {
    let mono = Array::makei(frames, i => input[i * 6 + channel])
    let reference = @src.resample(
      @src.Config::new(44100, 16000, 1).unwrap(),
      mono[:],
    ).unwrap()
    for i in 0..<reference.length() {
      if output[i * 6 + channel] != reference[i] {
        abort("channel mixing")
      }
    }
  }
  println(
    "multichannel frames_in=2048 frames_out=\{output.length()/6} channels=6 isolated=6",
  )
}
