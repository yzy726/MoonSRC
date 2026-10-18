///|
extern "C" fn native_seconds() -> Double = "moonsrc_probe_seconds"

///|
extern "C" fn native_rss(peak : Int) -> Int64 = "moonsrc_probe_rss"

///|
/// Monotonic wall clock for native verification and examples only.
pub fn seconds() -> Double {
  native_seconds()
}

///|
/// Process RSS in bytes, or -1 where unsupported. Peak and current are distinct.
pub fn rss(peak : Bool) -> Int64 {
  native_rss(if peak { 1 } else { 0 })
}
