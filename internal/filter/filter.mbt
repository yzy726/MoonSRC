///|
/// Input-frame radius retained by the original Balanced configuration.
pub const FILTER_RADIUS : Int = 96

///|
/// Compatibility builder for the original 193-tap table with up to 160 phases.
pub fn make_filter(
  phases : Int,
  cutoff : Double,
) -> Result[FixedArray[FixedArray[Double]], String] {
  if phases > 160 {
    return Err("filter budget or cutoff")
  }
  make_filter_with_options(phases, cutoff, FILTER_RADIUS)
}

///|
/// Internal exact-phase FIR builder with checked allocation budget.
/// Radius 1..1536; <=4096 phases; <=1048576 coefficient Doubles.
pub fn make_filter_with_options(
  phases : Int,
  cutoff : Double,
  radius : Int,
) -> Result[FixedArray[FixedArray[Double]], String] {
  if phases < 1 ||
    phases > 4096 ||
    radius < 1 ||
    radius > 1536 ||
    cutoff <= 0.0 ||
    cutoff > 1.0 ||
    cutoff.is_nan() {
    return Err("filter budget or cutoff")
  }
  if phases * (2 * radius + 1) > 1048576 {
    return Err("coefficient budget")
  }
  Ok(
    FixedArray::makei(phases, phase => {
      let fraction = phase.to_double() / phases.to_double()
      let row = FixedArray::makei(2 * radius + 1, index => {
        let x = (index - radius).to_double() - fraction
        if x.abs() >= radius.to_double() {
          0.0
        } else {
          let z = @math.PI * cutoff * x
          let sinc = if z.abs() < 1.0e-12 { 1.0 } else { @math.sin(z) / z }
          let angle = @math.PI * x / radius.to_double()
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
