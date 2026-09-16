///|
fn is_restricted_xml_char(cp : Int) -> Bool {
  (cp >= 1 && cp <= 8) ||
  cp == 11 ||
  cp == 12 ||
  (cp >= 14 && cp <= 31) ||
  (cp >= 127 && cp <= 132) ||
  (cp >= 134 && cp <= 159)
}

///|
fn write_xml_charref(out : StringBuilder, cp : Int) -> Unit {
  out.write_string("&#")
  out.write_string(cp.to_string())
  out.write_char(';')
}

///|
/// Escape a BINXML string for an XML text node, matching Views.py:
/// `xml.sax.saxutils.escape` then `xmlcharrefreplace` then drop restricted chars.
pub fn escape_xml_value(text : String) -> String {
  let out = StringBuilder()
  for i = 0; i < text.length(); i = i + 1 {
    let cp = text[i].to_int()
    if cp == 38 {
      out.write_string("&amp;")
    } else if cp == 60 {
      out.write_string("&lt;")
    } else if cp == 62 {
      out.write_string("&gt;")
    } else if is_restricted_xml_char(cp) {
      ()
    } else if cp > 127 {
      write_xml_charref(out, cp)
    } else {
      out.write_char(cp.unsafe_to_char())
    }
  }
  out.to_string()
}

///|
fn xml_name_start(cp : Int) -> Bool {
  (cp >= 65 && cp <= 90) || (cp >= 97 && cp <= 122) || cp == 95
}

///|
fn xml_name_part(cp : Int) -> Bool {
  xml_name_start(cp) || cp == 45
}

///|
/// Stricter XML Name check used by python-evtx Views.validate_name.
pub fn validate_xml_name(name : String) -> Result[String, EvtxError] {
  if name.length() == 0 || !xml_name_start(name[0].to_int()) {
    return Err(InvalidXmlName(name))
  }
  for i = 1; i < name.length(); i = i + 1 {
    if !xml_name_part(name[i].to_int()) {
      return Err(InvalidXmlName(name))
    }
  }
  Ok(name)
}

///|
fn name_hash16(text : String) -> Int {
  let mut hash = 0
  for i = 0; i < text.length(); i = i + 1 {
    hash = (hash * 65599 + text[i].to_int()) & 0xFFFF
  }
  hash
}
