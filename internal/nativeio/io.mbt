///|
#borrow(path)
extern "C" fn read_native(path : Bytes) -> Bytes = "moonsrc_read_file"

///|
#borrow(path, content)
extern "C" fn write_native(path : Bytes, content : Bytes) -> Int = "moonsrc_write_new_file"

///|
extern "C" fn exit_native(code : Int) -> Unit = "moonsrc_exit"

///|
/// Read only a regular, seekable file of 1..33,554,476 bytes. The native shim
/// checks its 64-bit length before allocating; all descriptors close on failure.
pub fn read_file(path : String) -> Result[Bytes, String] {
  if path.iter().any(c => c == '\u0000') {
    return Err("NUL in input path")
  }
  let bytes = read_native(@utf8.encode(path + "\u0000"))
  if bytes.length() == 0 {
    Err("cannot read regular input file within 33554476-byte budget")
  } else {
    Ok(bytes)
  }
}

///|
/// Create exclusively; never replace any existing file or symbolic link.
pub fn write_new_file(path : String, bytes : Bytes) -> Result[Unit, String] {
  if path.iter().any(c => c == '\u0000') {
    return Err("NUL in output path")
  }
  if write_native(@utf8.encode(path + "\u0000"), bytes) == 0 {
    Ok(())
  } else {
    Err("cannot create output; path must be new and writable")
  }
}

///|
/// Terminate a command with the requested status (native CLI only).
pub fn exit(code : Int) -> Unit {
  exit_native(code)
}
