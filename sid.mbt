///|
/// Windows SID string `S-{version}-{authority}-{rid}*`.
pub fn format_sid(
  data : Bytes,
  pos : Int,
  length : Int,
) -> Result[(String, Int), EvtxError] {
  let _ = match need(data, pos, 8, "sid") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let version = data[pos].to_int()
  let count = data[pos + 1].to_int()
  let needed = 8 + 4 * count
  if length != 0 && length < needed {
    return Err(Truncated("sid", pos, needed))
  }
  let _ = match need(data, pos, needed, "sid body") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (id_high, _) = match read_u32_be(data, pos + 2) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (id_low, _) = match read_u16_be(data, pos + 6) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let authority = (id_high.to_int64() << 16) ^ id_low.to_int64()
  let out = StringBuilder()
  out.write_string("S-")
  out.write_string(version.to_string())
  out.write_string("-")
  out.write_string(authority.to_string())
  let mut ofs = pos + 8
  for i = 0; i < count; i = i + 1 {
    let (rid, next) = match read_u32(data, ofs) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    out.write_string("-")
    out.write_string(rid.to_string())
    ofs = next
  }
  Ok((out.to_string(), needed))
}
