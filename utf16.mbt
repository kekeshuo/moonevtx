///|
/// Encode Unicode text as UTF-16LE code units without a terminator.
pub fn utf16_units(text : String) -> Array[Int] {
  let units : Array[Int] = []
  for i = 0; i < text.length(); i = i + 1 {
    units.push(text[i].to_int())
  }
  units
}

///|
fn put_utf16(buf : Array[Byte], text : String) -> Unit {
  let units = utf16_units(text)
  for i = 0; i < units.length(); i = i + 1 {
    put_u16(buf, units[i])
  }
}

///|
fn utf16_byte_length(text : String) -> Int {
  utf16_units(text).length() * 2
}

///|
fn read_utf16_units(
  data : Bytes,
  pos : Int,
  units : Int,
) -> Result[String, EvtxError] {
  let _ = match need(data, pos, units * 2, "utf16") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out = StringBuilder()
  let mut i = 0
  while i < units {
    let (unit, _) = match read_u16(data, pos + i * 2) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    if unit >= 0xD800 && unit <= 0xDBFF && i + 1 < units {
      let (low, _) = match read_u16(data, pos + (i + 1) * 2) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      if low >= 0xDC00 && low <= 0xDFFF {
        let cp = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
        out.write_char(cp.unsafe_to_char())
        i = i + 2
      } else {
        out.write_char(unit.unsafe_to_char())
        i = i + 1
      }
    } else {
      out.write_char(unit.unsafe_to_char())
      i = i + 1
    }
  }
  Ok(out.to_string())
}

///|
fn read_utf16_bytes(
  data : Bytes,
  pos : Int,
  nbytes : Int,
) -> Result[String, EvtxError] {
  if nbytes < 0 || nbytes % 2 != 0 {
    return Err(InvalidSubstitution("UTF-16 payload must be even"))
  }
  read_utf16_units(data, pos, nbytes / 2)
}

///|
fn rstrip_utf16_nuls(text : String) -> String {
  let mut end = text.length()
  while end > 0 && text[end - 1].to_int() == 0 {
    end = end - 1
  }
  if end == text.length() {
    text
  } else {
    let out = StringBuilder()
    for i = 0; i < end; i = i + 1 {
      out.write_char(text[i].to_int().unsafe_to_char())
    }
    out.to_string()
  }
}

///|
pub fn bytes_from_ascii(text : String) -> Bytes {
  Bytes::makei(text.length(), i => text[i].to_int().to_byte())
}

///|
fn read_i8_at(data : Bytes, pos : Int) -> Result[Int, EvtxError] {
  let _ = match need(data, pos, 1, "i8") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let v = data[pos].to_int()
  if v >= 128 {
    Ok(v - 256)
  } else {
    Ok(v)
  }
}

///|
fn read_i16_at(data : Bytes, pos : Int) -> Result[Int, EvtxError] {
  let (v, _) = match read_u16(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if v >= 32768 {
    Ok(v - 65536)
  } else {
    Ok(v)
  }
}

///|
fn read_i32_at(data : Bytes, pos : Int) -> Result[Int, EvtxError] {
  let (v, _) = match read_i32(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(v)
}

///|
fn read_i64_at(data : Bytes, pos : Int) -> Result[Int64, EvtxError] {
  let (v, _) = match read_i64(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(v)
}
