///|
/// Copy `[start, end)` out of an immutable buffer.
pub fn bytes_slice(data : Bytes, start : Int, end : Int) -> Bytes {
  Bytes::makei(end - start, i => data[start + i])
}

///|
/// Bounded slice that fails instead of panicking.
pub fn bytes_slice_result(
  data : Bytes,
  start : Int,
  end : Int,
) -> Result[Bytes, EvtxError] {
  if start < 0 || end < start || end > data.length() {
    Err(Truncated("slice", start, end - start))
  } else {
    Ok(bytes_slice(data, start, end))
  }
}

///|
/// Append immutable bytes onto a growable buffer.
pub fn append_bytes(target : Array[Byte], source : Bytes) -> Unit {
  for byte in source {
    target.push(byte)
  }
}

///|
/// Concatenate two byte strings.
pub fn concat_bytes(left : Bytes, right : Bytes) -> Bytes {
  let out : Array[Byte] = []
  append_bytes(out, left)
  append_bytes(out, right)
  Bytes::from_array(out)
}

///|
/// Require `n` bytes at `pos`.
fn need(
  data : Bytes,
  pos : Int,
  n : Int,
  what : String,
) -> Result[Unit, EvtxError] {
  if pos < 0 || n < 0 || pos > data.length() || n > data.length() - pos {
    Err(Truncated(what, pos, n))
  } else {
    Ok(())
  }
}

///|
fn read_u8(data : Bytes, pos : Int) -> Result[(Int, Int), EvtxError] {
  let _ = match need(data, pos, 1, "u8") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((data[pos].to_int(), pos + 1))
}

///|
fn read_u16(data : Bytes, pos : Int) -> Result[(Int, Int), EvtxError] {
  let _ = match need(data, pos, 2, "u16") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let lo = data[pos].to_int()
  let hi = data[pos + 1].to_int()
  Ok((lo | (hi << 8), pos + 2))
}

///|
fn read_u32(data : Bytes, pos : Int) -> Result[(UInt, Int), EvtxError] {
  let _ = match need(data, pos, 4, "u32") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let mut v = 0U
  for i = 0; i < 4; i = i + 1 {
    v = v | (data[pos + i].to_int().reinterpret_as_uint() << (i * 8))
  }
  Ok((v, pos + 4))
}

///|
fn read_i32(data : Bytes, pos : Int) -> Result[(Int, Int), EvtxError] {
  let (v, next) = match read_u32(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((v.reinterpret_as_int(), next))
}

///|
fn read_u64(data : Bytes, pos : Int) -> Result[(UInt64, Int), EvtxError] {
  let _ = match need(data, pos, 8, "u64") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let mut v = 0UL
  for i = 0; i < 8; i = i + 1 {
    v = v | (data[pos + i].to_int().to_uint64() << (i * 8))
  }
  Ok((v, pos + 8))
}

///|
fn read_i64(data : Bytes, pos : Int) -> Result[(Int64, Int), EvtxError] {
  let (v, next) = match read_u64(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((v.reinterpret_as_int64(), next))
}

///|
fn read_u32_be(data : Bytes, pos : Int) -> Result[(UInt, Int), EvtxError] {
  let _ = match need(data, pos, 4, "u32be") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let mut v = 0U
  for i = 0; i < 4; i = i + 1 {
    v = (v << 8) | data[pos + i].to_int().reinterpret_as_uint()
  }
  Ok((v, pos + 4))
}

///|
fn read_u16_be(data : Bytes, pos : Int) -> Result[(Int, Int), EvtxError] {
  let _ = match need(data, pos, 2, "u16be") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let hi = data[pos].to_int()
  let lo = data[pos + 1].to_int()
  Ok(((hi << 8) | lo, pos + 2))
}

///|
fn ascii_magic(data : Bytes, pos : Int, n : Int) -> Result[String, EvtxError] {
  let _ = match need(data, pos, n, "magic") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let sb = StringBuilder()
  for i = 0; i < n; i = i + 1 {
    sb.write_char(data[pos + i].to_int().unsafe_to_char())
  }
  Ok(sb.to_string())
}

///|
fn u8_from_uint(v : UInt) -> Byte {
  (v & 0xFFU).reinterpret_as_int().to_byte()
}

///|
fn put_u8(buf : Array[Byte], v : Int) -> Unit {
  buf.push(v.to_byte())
}

///|
fn put_u16(buf : Array[Byte], v : Int) -> Unit {
  buf.push((v & 0xFF).to_byte())
  buf.push(((v >> 8) & 0xFF).to_byte())
}

///|
fn put_u32(buf : Array[Byte], v : UInt) -> Unit {
  for i = 0; i < 4; i = i + 1 {
    buf.push(u8_from_uint(v >> (i * 8)))
  }
}

///|
fn put_u64(buf : Array[Byte], v : UInt64) -> Unit {
  for i = 0; i < 8; i = i + 1 {
    buf.push(((v >> (i * 8)) & 0xFFUL).to_int().to_byte())
  }
}

///|
fn write_u32_at(buf : Array[Byte], pos : Int, v : UInt) -> Unit {
  for i = 0; i < 4; i = i + 1 {
    buf[pos + i] = u8_from_uint(v >> (i * 8))
  }
}

///|
fn write_u64_at(buf : Array[Byte], pos : Int, v : UInt64) -> Unit {
  for i = 0; i < 8; i = i + 1 {
    buf[pos + i] = ((v >> (i * 8)) & 0xFFUL).to_int().to_byte()
  }
}

///|
fn write_u16_at(buf : Array[Byte], pos : Int, v : Int) -> Unit {
  buf[pos] = (v & 0xFF).to_byte()
  buf[pos + 1] = ((v >> 8) & 0xFF).to_byte()
}

///|
fn ensure_len(buf : Array[Byte], n : Int) -> Unit {
  while buf.length() < n {
    buf.push((0).to_byte())
  }
}
