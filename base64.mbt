///|
fn b64_alphabet() -> String {
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
}

///|
/// Standard Base64 with `=` padding, matching python-evtx BinaryTypeNode.
pub fn base64_encode(data : Bytes) -> String {
  let alpha = b64_alphabet()
  let out = StringBuilder()
  let mut i = 0
  while i < data.length() {
    let b0 = data[i].to_int()
    let rest = data.length() - i
    let b1 = if rest > 1 { data[i + 1].to_int() } else { 0 }
    let b2 = if rest > 2 { data[i + 2].to_int() } else { 0 }
    let triple = (b0 << 16) | (b1 << 8) | b2
    out.write_char(alpha[(triple >> 18) & 63].to_int().unsafe_to_char())
    out.write_char(alpha[(triple >> 12) & 63].to_int().unsafe_to_char())
    if rest == 1 {
      out.write_char('=')
      out.write_char('=')
    } else if rest == 2 {
      out.write_char(alpha[(triple >> 6) & 63].to_int().unsafe_to_char())
      out.write_char('=')
    } else {
      out.write_char(alpha[(triple >> 6) & 63].to_int().unsafe_to_char())
      out.write_char(alpha[triple & 63].to_int().unsafe_to_char())
    }
    i = i + 3
  }
  out.to_string()
}
