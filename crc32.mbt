///|
/// ISO 3309 / zlib CRC-32 polynomial, reflected.
fn crc32_poly() -> UInt {
  0xEDB88320U
}

///|
/// Build the 256-entry CRC-32 table used by python-evtx `binascii.crc32`.
fn crc32_table() -> Array[UInt] {
  let table : Array[UInt] = []
  let poly = crc32_poly()
  for i = 0; i < 256; i = i + 1 {
    let mut crc = i.reinterpret_as_uint()
    for bit = 0; bit < 8; bit = bit + 1 {
      if (crc & 1U) == 1U {
        crc = poly ^ (crc >> 1)
      } else {
        crc = crc >> 1
      }
    }
    table.push(crc)
  }
  table
}

///|
/// CRC-32 of `data[start, end)` with the ISO 3309 final XOR.
pub fn crc32_slice(
  data : Bytes,
  start : Int,
  end : Int,
) -> Result[UInt, EvtxError] {
  if start < 0 || end < start || end > data.length() {
    return Err(Truncated("crc32 range", start, end - start))
  }
  let table = crc32_table()
  let mut crc = 0xFFFFFFFFU
  for i = start; i < end; i = i + 1 {
    let mixed = crc ^ data[i].to_int().reinterpret_as_uint()
    let idx = (mixed & 0xFFU).reinterpret_as_int()
    crc = table[idx] ^ (crc >> 8)
  }
  Ok(crc ^ 0xFFFFFFFFU)
}

///|
/// CRC-32 of a whole byte string.
pub fn crc32_bytes(data : Bytes) -> UInt {
  crc32_slice(data, 0, data.length()).unwrap()
}

///|
/// Concatenate two ranges before hashing, matching chunk header checksums.
pub fn crc32_two_slices(
  data : Bytes,
  a0 : Int,
  a1 : Int,
  b0 : Int,
  b1 : Int,
) -> Result[UInt, EvtxError] {
  let left = match bytes_slice_result(data, a0, a1) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let right = match bytes_slice_result(data, b0, b1) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(crc32_bytes(concat_bytes(left, right)))
}
