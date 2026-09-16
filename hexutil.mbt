///|
fn nibble_char(value : Int) -> Char {
  if value < 10 {
    (48 + value).unsafe_to_char()
  } else {
    (87 + value).unsafe_to_char()
  }
}

///|
fn hex_nibble(c : Int) -> Int? {
  if c >= 48 && c <= 57 {
    Some(c - 48)
  } else if c >= 65 && c <= 70 {
    Some(c - 55)
  } else if c >= 97 && c <= 102 {
    Some(c - 87)
  } else {
    None
  }
}

///|
/// Encode bytes as lowercase hexadecimal.
pub fn hex_encode(data : Bytes) -> String {
  let out = StringBuilder()
  for byte in data {
    let value = byte.to_int()
    out.write_char(nibble_char((value >> 4) & 15))
    out.write_char(nibble_char(value & 15))
  }
  out.to_string()
}

///|
fn hex_byte(value : Int) -> String {
  let out = StringBuilder()
  out.write_char(nibble_char((value >> 4) & 15))
  out.write_char(nibble_char(value & 15))
  out.to_string()
}

///|
/// Decode a hex string into bytes. Odd length is rejected.
pub fn hex_decode(text : String) -> Result[Bytes, EvtxError] {
  if text.length() % 2 != 0 {
    return Err(InvalidName("odd hex length"))
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < text.length() {
    match (hex_nibble(text[i].to_int()), hex_nibble(text[i + 1].to_int())) {
      (Some(hi), Some(lo)) => out.push(((hi << 4) | lo).to_byte())
      _ => return Err(InvalidName("invalid hex digit"))
    }
    i = i + 2
  }
  Ok(Bytes::from_array(out))
}

///|
fn hex_int32_string(data : Bytes, pos : Int) -> Result[String, EvtxError] {
  let _ = match need(data, pos, 4, "hex32") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out = StringBuilder()
  out.write_string("0x")
  for i = 3; i >= 0; i = i - 1 {
    out.write_string(hex_byte(data[pos + i].to_int()))
  }
  Ok(out.to_string())
}

///|
fn hex_int64_string(data : Bytes, pos : Int) -> Result[String, EvtxError] {
  let _ = match need(data, pos, 8, "hex64") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out = StringBuilder()
  out.write_string("0x")
  for i = 7; i >= 0; i = i - 1 {
    out.write_string(hex_byte(data[pos + i].to_int()))
  }
  Ok(out.to_string())
}
