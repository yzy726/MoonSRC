///|
fn main {
  let config = @src.Config::new(44100, 48000, 2).unwrap()
  let input = @signals.tone(44100, 997.0, 2048, 2)
  let expected = @src.resample(config, input[:]).unwrap()
  for pattern in [[1], [127], [37, 251, 3, 97, 1, 13]] {
    let actual = @signals.chunked(config, input[:], pattern[:], 7).unwrap()
    if actual != expected {
      abort("chunked result differs")
    }
  }
  println(
    "patterns=1,127,fixed_seed output_frames=\{expected.length() / 2} max_difference=0",
  )
}
