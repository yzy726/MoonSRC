///|
test "filter/every phase preserves steady DC" {
  for
    pair in [
      (160, 0.94),
      (147, 0.94 * 44100.0 / 48000.0),
      (1, 0.94 / 3.0),
      (3, 0.94),
    ] {
    let table = make_filter(pair.0, pair.1).unwrap()
    assert_eq(table.length(), pair.0)
    for row in table {
      assert_eq(row.length(), 193)
      let mut sum = 0.0
      for tap in row {
        sum += tap
      }
      assert_true((sum - 1.0).abs() < 1.0e-12)
    }
  }
}

///|
test "filter/zero phase symmetry and finite endpoints" {
  let row = make_filter(1, 0.94 / 3.0).unwrap()[0]
  for i in 0..<193 {
    assert_true((row[i] - row[192 - i]).abs() < 1.0e-14)
    assert_true(!row[i].is_nan() && !row[i].is_inf())
  }
  assert_true(row[0].abs() < 1.0e-14)
}

///|
test "filter/downsampling passband and alias rejection" {
  let row = make_filter(1, 0.94 / 3.0).unwrap()[0]
  let mut passband = 0.0
  let mut stopband = 0.0
  for i in 0..<193 {
    let x = (i - 96).to_double()
    passband += row[i] * @math.cos(2.0 * @math.PI * 1000.0 * x / 48000.0)
    stopband += row[i] * @math.cos(2.0 * @math.PI * 12000.0 * x / 48000.0)
  }
  assert_true((20.0 * @math.log10(passband.abs())).abs() <= 0.5)
  assert_true(20.0 * @math.log10(stopband.abs() / passband.abs()) <= -50.0)
}

///|
test "filter/fractional phases represent their timestamp" {
  let table = make_filter(160, 0.94).unwrap()
  for phase in [1, 79, 159] {
    let mut moment = 0.0
    for i in 0..<193 {
      moment += (i - 96).to_double() * table[phase][i]
    }
    assert_true((moment - phase.to_double() / 160.0).abs() < 0.001)
  }
}

///|
test "filter/resource budget and cutoff reject invalid input" {
  for phases in [-1, 0, 161, 2147483647] {
    assert_true(make_filter(phases, 0.5) is Err(_))
  }
  for cutoff in [-0.1, 0.0, 1.1, 0.0 / 0.0, 1.0 / 0.0] {
    assert_true(make_filter(1, cutoff) is Err(_))
  }
}
