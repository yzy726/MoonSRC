///|
test "final_filter/radius and phases preserve normalized DC" {
  for radius in [32, 96, 192, 1536] {
    let table = make_filter_with_options(3, 0.1, radius).unwrap()
    for row in table {
      assert_eq(row.length(), 2 * radius + 1)
      let mut total = 0.0
      for value in row {
        assert_true(!value.is_nan() && !value.is_inf())
        total += value
      }
      assert_true((total - 1.0).abs() < 1.0e-12)
    }
  }
}

///|
test "final_filter/invalid radius rejects before allocation" {
  for radius in [-1, 0, 1537, 2147483647] {
    assert_true(make_filter_with_options(1, 0.5, radius) is Err(_))
  }
}

///|
test "final_filter/invalid phase and combined budget reject before allocation" {
  for phases in [-1, 0, 4097, 2147483647] {
    assert_true(make_filter_with_options(phases, 0.5, 32) is Err(_))
  }
  assert_true(make_filter_with_options(4096, 0.5, 192) is Err(_))
}

///|
test "final_filter/three preset measured passband and alias thresholds" {
  for tuple in [(32, 0.90, -45.0), (96, 0.94, -50.0), (192, 0.97, -70.0)] {
    let row = make_filter_with_options(1, tuple.1 / 3.0, tuple.0).unwrap()[0]
    let mut passband = 0.0
    let mut stopband = 0.0
    for i in 0..<row.length() {
      let x = (i - tuple.0).to_double()
      passband += row[i] * @math.cos(2.0 * @math.PI * 1000.0 * x / 48000.0)
      stopband += row[i] * @math.cos(2.0 * @math.PI * 12000.0 * x / 48000.0)
    }
    assert_true((20.0 * @math.log10(passband.abs())).abs() <= 0.5)
    assert_true(20.0 * @math.log10(stopband.abs() / passband.abs()) <= tuple.2)
  }
}
