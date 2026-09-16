///|
test "crc32 matches zlib/python-evtx vector" {
  let data = bytes_from_ascii("123456789")
  assert_eq(crc32_bytes(data), 0xCBF43926U)
}

///|
test "FILETIME 1710000000 is 2024-03-09 16:00:00 UTC" {
  let ft = unix_to_filetime(1710000000L)
  assert_eq(format_filetime(ft, PythonEvtx), "2024-03-09 16:00:00+00:00")
  assert_eq(format_filetime(ft, Iso8601), "2024-03-09T16:00:00Z")
  assert_eq(filetime_to_unix(ft), 1710000000L)
}

///|
test "zero FILETIME follows python-evtx datetime.min" {
  assert_eq(format_filetime(0UL, PythonEvtx), "0001-01-01 00:00:00")
}

///|
test "hex encode/decode roundtrip" {
  let raw = bytes_from_ascii("Moon")
  assert_eq(hex_encode(raw), "4d6f6f6e")
  assert_eq(hex_decode("4d6f6f6e").unwrap(), raw)
}

///|
test "xml escape matches saxutils plus charrefs" {
  assert_eq(escape_xml_value("a<b>&c>"), "a&lt;b&gt;&amp;c&gt;")
}

///|
test "name hash is python-evtx 65599" {
  assert_eq(name_hash16("Event"), 3258)
}

///|
test "base64 encodes substitution binary" {
  assert_eq(base64_encode(bytes_from_ascii("evtx")), "ZXZ0eA==")
}
