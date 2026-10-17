///|
/// Input-frame radius of the 0.1.0 centered Blackman-windowed sinc.
pub const FILTER_RADIUS : Int = 96

///|
/// Internal coefficient builder; phases and cutoff are bounded before allocation.
/// This package is an implementation detail, outside the stable root API.
pub fn make_filter(
  phases : Int,
  cutoff : Double,
) -> Result[FixedArray[FixedArray[Double]], String] {
  if phases < 1 ||
    phases > 160 ||
    cutoff <= 0.0 ||
    cutoff > 1.0 ||
    cutoff.is_nan() {
    return Err("filter budget or cutoff")
  }
  Ok(
    FixedArray::makei(phases, phase => {
      let fraction = phase.to_double() / phases.to_double()
      let row = FixedArray::makei(2 * FILTER_RADIUS + 1, index => {
        let x = (index - FILTER_RADIUS).to_double() - fraction
        if x.abs() >= FILTER_RADIUS.to_double() {
          0.0
        } else {
          let z = @math.PI * cutoff * x
          let sinc = if z.abs() < 1.0e-12 { 1.0 } else { @math.sin(z) / z }
          let angle = @math.PI * x / FILTER_RADIUS.to_double()
          let window = 0.42 +
            0.5 * @math.cos(angle) +
            0.08 * @math.cos(2.0 * angle)
          cutoff * sinc * window
        }
      })
      let mut sum = 0.0
      for value in row {
        sum += value
      }
      for i in 0..<row.length() {
        row[i] = row[i] / sum
      }
      row
    }),
  )
}
