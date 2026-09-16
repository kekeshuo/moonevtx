///|
/// python-evtx `unpack_guid`: mixed-endian, lowercase, no braces.
pub fn format_guid(data : Bytes, pos : Int) -> Result[String, EvtxError] {
  let _ = match need(data, pos, 16, "guid") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let b = (i : Int) => data[pos + i].to_int()
  Ok(
    hex_byte(b(3)) +
    hex_byte(b(2)) +
    hex_byte(b(1)) +
    hex_byte(b(0)) +
    "-" +
    hex_byte(b(5)) +
    hex_byte(b(4)) +
    "-" +
    hex_byte(b(7)) +
    hex_byte(b(6)) +
    "-" +
    hex_byte(b(8)) +
    hex_byte(b(9)) +
    "-" +
    hex_byte(b(10)) +
    hex_byte(b(11)) +
    hex_byte(b(12)) +
    hex_byte(b(13)) +
    hex_byte(b(14)) +
    hex_byte(b(15)),
  )
}

///|
/// GuidTypeNode.string() wraps unpack_guid in braces.
pub fn format_guid_node(data : Bytes, pos : Int) -> Result[String, EvtxError] {
  Ok(
    "{" +
    (match format_guid(data, pos) {
      Ok(v) => v
      Err(e) => return Err(e)
    }) +
    "}",
  )
}

///|
/// Encode a mixed-endian GUID from an already-formatted lowercase string.
pub fn encode_guid_text(
  text : String,
  buf : Array[Byte],
) -> Result[Unit, EvtxError] {
  let cleaned = strip_guid_punct(text)
  if cleaned.length() != 32 {
    return Err(InvalidDraft("GUID must contain 16 bytes"))
  }
  let raw = match hex_decode(cleaned) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if raw.length() != 16 {
    return Err(InvalidDraft("GUID decode failed"))
  }
  buf.push(raw[3])
  buf.push(raw[2])
  buf.push(raw[1])
  buf.push(raw[0])
  buf.push(raw[5])
  buf.push(raw[4])
  buf.push(raw[7])
  buf.push(raw[6])
  for i = 8; i < 16; i = i + 1 {
    buf.push(raw[i])
  }
  Ok(())
}

///|
fn strip_guid_punct(text : String) -> String {
  let out = StringBuilder()
  for i = 0; i < text.length(); i = i + 1 {
    let cp = text[i].to_int()
    if cp != 45 && cp != 123 && cp != 125 {
      out.write_char(cp.unsafe_to_char())
    }
  }
  out.to_string()
}
