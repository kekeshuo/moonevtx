///|
/// Stable errors returned by the EVTX decoder, renderer and writer.
pub(all) enum EvtxError {
  Truncated(String, Int, Int)
  InvalidMagic(String, String)
  InvalidChecksum(String, UInt, UInt)
  InvalidHeader(String)
  InvalidChunk(String)
  InvalidRecord(String)
  UnexpectedToken(Int, Int)
  InvalidName(String)
  UnsupportedType(Int, Int)
  InvalidSubstitution(String)
  InvalidDraft(String)
  InvalidXmlName(String)
} derive(Eq, Debug)

///|
pub fn EvtxError::code(self : EvtxError) -> String {
  match self {
    Truncated(_) => "EVTX001"
    InvalidMagic(_) => "EVTX002"
    InvalidChecksum(_) => "EVTX003"
    InvalidHeader(_) => "EVTX004"
    InvalidChunk(_) => "EVTX005"
    InvalidRecord(_) => "EVTX006"
    UnexpectedToken(_) => "EVTX007"
    InvalidName(_) => "EVTX008"
    UnsupportedType(_) => "EVTX009"
    InvalidSubstitution(_) => "EVTX010"
    InvalidDraft(_) => "EVTX011"
    InvalidXmlName(_) => "EVTX012"
  }
}

///|
pub fn EvtxError::message(self : EvtxError) -> String {
  match self {
    Truncated(what, pos, need) =>
      "truncated \{what} at \{pos}, need \{need} bytes"
    InvalidMagic(what, found) => "invalid \{what} magic: \{found}"
    InvalidChecksum(what, expected, actual) =>
      "\{what} checksum mismatch: expected \{expected}, actual \{actual}"
    InvalidHeader(why) => "invalid EVTX file header: \{why}"
    InvalidChunk(why) => "invalid EVTX chunk: \{why}"
    InvalidRecord(why) => "invalid EVTX record: \{why}"
    UnexpectedToken(token, pos) =>
      "unexpected BINXML token \{token} at offset \{pos}"
    InvalidName(why) => "invalid BINXML name: \{why}"
    UnsupportedType(type_code, pos) =>
      "unsupported substitution type \{type_code} at \{pos}"
    InvalidSubstitution(why) => "invalid substitution table: \{why}"
    InvalidDraft(why) => "invalid event draft: \{why}"
    InvalidXmlName(name) => "invalid XML name: \{name}"
  }
}
