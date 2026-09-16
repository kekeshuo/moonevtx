///|
/// BINXML / substitution type codes used by python-evtx `NODE_TYPES`.
pub fn variant_type_name(type_code : Int) -> String {
  let code = type_code & 0x7F
  match code {
    0x00 => "Null"
    0x01 => "WString"
    0x02 => "String"
    0x03 => "Int8"
    0x04 => "UInt8"
    0x05 => "Int16"
    0x06 => "UInt16"
    0x07 => "Int32"
    0x08 => "UInt32"
    0x09 => "Int64"
    0x0A => "UInt64"
    0x0B => "Float32"
    0x0C => "Float64"
    0x0D => "Boolean"
    0x0E => "Binary"
    0x0F => "Guid"
    0x10 => "Size"
    0x11 => "FileTime"
    0x12 => "SystemTime"
    0x13 => "SID"
    0x14 => "HexInt32"
    0x15 => "HexInt64"
    0x21 => "BXml"
    _ => "Unknown"
  }
}

///|
fn is_array_type(type_code : Int) -> Bool {
  (type_code & 0x80) != 0
}

///|
fn format_wstring_payload(
  data : Bytes,
  pos : Int,
  length : Int?,
) -> Result[(String, Int), EvtxError] {
  match length {
    None => {
      let (count, next) = match read_u16(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let text = rstrip_utf16_nuls(
        match read_utf16_units(data, next, count) {
          Ok(v) => v
          Err(e) => return Err(e)
        },
      )
      Ok((text, 2 + count * 2))
    }
    Some(n) => {
      let text = rstrip_utf16_nuls(
        match read_utf16_bytes(data, pos, n) {
          Ok(v) => v
          Err(e) => return Err(e)
        },
      )
      Ok((text, n))
    }
  }
}

///|
fn format_ansi_payload(
  data : Bytes,
  pos : Int,
  length : Int?,
) -> Result[(String, Int), EvtxError] {
  match length {
    None => {
      let (count, next) = match read_u16(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let _ = match need(data, next, count, "ansi") {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let sb = StringBuilder()
      for i = 0; i < count; i = i + 1 {
        let cp = data[next + i].to_int()
        if cp != 0 {
          sb.write_char(cp.unsafe_to_char())
        }
      }
      Ok((sb.to_string(), 2 + count))
    }
    Some(n) => {
      let _ = match need(data, pos, n, "ansi-sub") {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let sb = StringBuilder()
      for i = 0; i < n; i = i + 1 {
        let cp = data[pos + i].to_int()
        if cp != 0 {
          sb.write_char(cp.unsafe_to_char())
        }
      }
      Ok((sb.to_string(), n))
    }
  }
}

///|
fn format_binary_payload(
  data : Bytes,
  pos : Int,
  length : Int?,
) -> Result[(String, Int), EvtxError] {
  match length {
    None => {
      let (size, next) = match read_u32(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let n = size.reinterpret_as_int()
      let _ = match need(data, next, n, "binary") {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((base64_encode(bytes_slice(data, next, next + n)), 4 + n))
    }
    Some(n) => {
      let _ = match need(data, pos, n, "binary-sub") {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((base64_encode(bytes_slice(data, pos, pos + n)), n))
    }
  }
}

///|
fn format_size_payload(
  data : Bytes,
  pos : Int,
  length : Int?,
) -> Result[(String, Int), EvtxError] {
  let n = match length {
    None => 8
    Some(v) => v
  }
  if n == 4 {
    let (v, _) = match read_u32(data, pos) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    Ok((v.to_string(), 4))
  } else {
    let (v, _) = match read_u64(data, pos) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    Ok((v.to_string(), n))
  }
}

///|
fn format_wstring_array(
  data : Bytes,
  pos : Int,
  length : Int?,
) -> Result[(String, Int), EvtxError] {
  let n = match length {
    None => {
      let (count, _) = match read_u16(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      2 + count
    }
    Some(v) => v
  }
  let start = match length {
    None => pos + 2
    Some(_) => pos
  }
  let payload_len = match length {
    None => n - 2
    Some(v) => v
  }
  let _ = match need(data, start, payload_len, "wstring-array") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out = StringBuilder()
  let mut ofs = 0
  while ofs + 1 < payload_len {
    let mut end = ofs
    while end + 1 < payload_len {
      let (unit, _) = match read_u16(data, start + end) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      if unit == 0 {
        break
      }
      end = end + 2
    }
    let chars = (end - ofs) / 2
    let piece = match read_utf16_units(data, start + ofs, chars) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    out.write_string("<string>")
    out.write_string(piece)
    out.write_string("</string>\n")
    ofs = end + 2
  }
  Ok((out.to_string(), n))
}

///|
/// Format a variant payload using python-evtx `VariantTypeNode.string()` rules.
pub fn format_variant(
  data : Bytes,
  pos : Int,
  type_code : Int,
  length : Int?,
  style : TimeStyle,
) -> Result[(String, Int), EvtxError] {
  if is_array_type(type_code) && (type_code & 0x7F) == 0x01 {
    return format_wstring_array(data, pos, length)
  }
  let code = type_code & 0x7F
  match code {
    0x00 => {
      let n = match length {
        None => 0
        Some(v) => v
      }
      Ok(("", n))
    }
    0x01 => format_wstring_payload(data, pos, length)
    0x02 => format_ansi_payload(data, pos, length)
    0x03 => {
      let v = match read_i8_at(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((v.to_string(), 1))
    }
    0x04 => {
      let (v, _) = match read_u8(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((v.to_string(), 1))
    }
    0x05 => {
      let v = match read_i16_at(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((v.to_string(), 2))
    }
    0x06 => {
      let (v, _) = match read_u16(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((v.to_string(), 2))
    }
    0x07 => {
      let v = match read_i32_at(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((v.to_string(), 4))
    }
    0x08 => {
      let (v, _) = match read_u32(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((v.to_string(), 4))
    }
    0x09 => {
      let v = match read_i64_at(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((v.to_string(), 8))
    }
    0x0A => {
      let (v, _) = match read_u64(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((v.to_string(), 8))
    }
    0x0B => {
      let (v, _) = match read_u32(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(
        (
          "0x" +
          hex_byte((v >> 24).reinterpret_as_int() & 255) +
          hex_byte((v >> 16).reinterpret_as_int() & 255) +
          hex_byte((v >> 8).reinterpret_as_int() & 255) +
          hex_byte(v.reinterpret_as_int() & 255),
          4,
        ),
      )
    }
    0x0C => {
      let _ = match need(data, pos, 8, "f64") {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((hex_encode(bytes_slice(data, pos, pos + 8)), 8))
    }
    0x0D => {
      let v = match read_i32_at(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      if v > 0 {
        Ok(("True", 4))
      } else {
        Ok(("False", 4))
      }
    }
    0x0E => format_binary_payload(data, pos, length)
    0x0F =>
      Ok(
        (
          match format_guid_node(data, pos) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
          16,
        ),
      )
    0x10 => format_size_payload(data, pos, length)
    0x11 => {
      let (ft, _) = match read_u64(data, pos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((format_filetime(ft, style), 8))
    }
    0x12 =>
      Ok(
        (
          match format_systemtime(data, pos, style) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
          16,
        ),
      )
    0x13 => {
      let n = match length {
        None => 0
        Some(v) => v
      }
      let (text, used) = match format_sid(data, pos, n) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((text, used))
    }
    0x14 =>
      Ok(
        (
          match hex_int32_string(data, pos) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
          4,
        ),
      )
    0x15 =>
      Ok(
        (
          match hex_int64_string(data, pos) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
          8,
        ),
      )
    0x21 => {
      let n = match length {
        None => 0
        Some(v) => v
      }
      Ok(("", n))
    }
    _ => Err(UnsupportedType(type_code, pos))
  }
}
