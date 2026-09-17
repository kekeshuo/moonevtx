///|
/// EVTX file header (4096-byte prefix, checksum over the first 0x78 bytes).
pub(all) struct FileHeader {
  oldest_chunk : UInt64
  current_chunk_number : UInt64
  next_record_number : UInt64
  header_size : UInt
  minor_version : Int
  major_version : Int
  header_chunk_size : Int
  chunk_count : Int
  flags : UInt
  checksum : UInt
  checksum_ok : Bool
} derive(Debug)

///|
/// One 64 KiB chunk header.
pub(all) struct ChunkHeader {
  offset : Int
  first_record : UInt64
  last_record : UInt64
  log_first_record : UInt64
  log_last_record : UInt64
  header_size : UInt
  last_record_offset : UInt
  next_record_offset : UInt
  data_checksum : UInt
  header_checksum : UInt
  header_ok : Bool
  data_ok : Bool
} derive(Debug)

///|
/// Parsed event record.
pub(all) struct EvtxRecord {
  number : UInt64
  timestamp : UInt64
  size : UInt
  chunk_offset : Int
  offset : Int
  root : ParsedRoot
} derive(Debug)

///|
/// In-memory EVTX file.
pub(all) struct EvtxFile {
  data : Bytes
  header : FileHeader
  chunks : Array[ChunkHeader]
  records : Array[EvtxRecord]
}

///|
fn parse_file_header(data : Bytes) -> Result[FileHeader, EvtxError] {
  let _ = match need(data, 0, 0x80, "file-header") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let _magic = match ascii_magic(data, 0, 8) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if data[0].to_int() != 69 ||
    data[1].to_int() != 108 ||
    data[2].to_int() != 102 ||
    data[3].to_int() != 70 ||
    data[4].to_int() != 105 ||
    data[5].to_int() != 108 ||
    data[6].to_int() != 101 ||
    data[7].to_int() != 0 {
    return Err(InvalidMagic("file", hex_encode(bytes_slice(data, 0, 8))))
  }
  let (oldest, _) = match read_u64(data, 8) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (current, _) = match read_u64(data, 16) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (next_record, _) = match read_u64(data, 24) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (header_size, _) = match read_u32(data, 32) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (minor, _) = match read_u16(data, 36) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (major, _) = match read_u16(data, 38) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (header_chunk, _) = match read_u16(data, 40) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (chunk_count, _) = match read_u16(data, 42) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (flags, _) = match read_u32(data, 0x78) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (checksum, _) = match read_u32(data, 0x7C) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let calc = match crc32_slice(data, 0, 0x78) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(FileHeader::{
    oldest_chunk: oldest,
    current_chunk_number: current,
    next_record_number: next_record,
    header_size,
    minor_version: minor,
    major_version: major,
    header_chunk_size: header_chunk,
    chunk_count,
    flags,
    checksum,
    checksum_ok: calc == checksum,
  })
}

///|
fn parse_chunk_header(
  data : Bytes,
  offset : Int,
) -> Result[ChunkHeader, EvtxError] {
  let _ = match need(data, offset, 0x200, "chunk-header") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let _magic = match ascii_magic(data, offset, 8) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if data[offset].to_int() != 69 ||
    data[offset + 1].to_int() != 108 ||
    data[offset + 2].to_int() != 102 ||
    data[offset + 3].to_int() != 67 ||
    data[offset + 4].to_int() != 104 ||
    data[offset + 5].to_int() != 110 ||
    data[offset + 6].to_int() != 107 ||
    data[offset + 7].to_int() != 0 {
    return Err(
      InvalidMagic("chunk", hex_encode(bytes_slice(data, offset, offset + 8))),
    )
  }
  let (first_record, _) = match read_u64(data, offset + 8) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (last_record, _) = match read_u64(data, offset + 16) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (log_first, _) = match read_u64(data, offset + 24) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (log_last, _) = match read_u64(data, offset + 32) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (header_size, _) = match read_u32(data, offset + 40) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (last_off, _) = match read_u32(data, offset + 44) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (next_off, _) = match read_u32(data, offset + 48) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (data_cs, _) = match read_u32(data, offset + 52) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (header_cs, _) = match read_u32(data, offset + 0x7C) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let header_calc = match
    crc32_two_slices(data, offset, offset + 0x78, offset + 0x80, offset + 0x200) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let data_end = offset + next_off.reinterpret_as_int()
  if data_end < offset + 0x200 || data_end > data.length() {
    return Err(InvalidChunk("next_record_offset out of range"))
  }
  let data_calc = match crc32_slice(data, offset + 0x200, data_end) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(ChunkHeader::{
    offset,
    first_record,
    last_record,
    log_first_record: log_first,
    log_last_record: log_last,
    header_size,
    last_record_offset: last_off,
    next_record_offset: next_off,
    data_checksum: data_cs,
    header_checksum: header_cs,
    header_ok: header_calc == header_cs,
    data_ok: data_calc == data_cs,
  })
}

///|
fn preload_chunk_names(
  data : Bytes,
  chunk_offset : Int,
  names : Array[(Int, String)],
) -> Result[Unit, EvtxError] {
  for i = 0; i < 64; i = i + 1 {
    let (ofs, _) = match read_u32(data, chunk_offset + 0x80 + i * 4) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let mut cur = ofs.reinterpret_as_int()
    let mut hops = 0
    while cur > 0 && hops < 64 {
      let name = match load_name(data, chunk_offset, cur, names) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      if name.length() < 0 {
        return Err(InvalidName("negative name"))
      }
      let (next, _) = match read_u32(data, chunk_offset + cur) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      cur = next.reinterpret_as_int()
      hops = hops + 1
    }
  }
  Ok(())
}

///|
fn parse_record(
  data : Bytes,
  offset : Int,
  chunk_offset : Int,
  names : Array[(Int, String)],
  style : TimeStyle,
) -> Result[EvtxRecord, EvtxError] {
  let _ = match need(data, offset, 24, "record-header") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (magic, _) = match read_u32(data, offset) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if magic != 0x00002A2AU {
    return Err(
      InvalidRecord(
        "magic \{hex_encode(bytes_slice(data, offset, offset + 4))}",
      ),
    )
  }
  let (size, _) = match read_u32(data, offset + 4) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (number, _) = match read_u64(data, offset + 8) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (timestamp, _) = match read_u64(data, offset + 16) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let n = size.reinterpret_as_int()
  if n < 28 || n > 0x10000 {
    return Err(InvalidRecord("size \{n}"))
  }
  let _ = match need(data, offset, n, "record") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (size2, _) = match read_u32(data, offset + n - 4) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if size2 != size {
    return Err(InvalidRecord("trailing size mismatch"))
  }
  let (root, _end) = match
    parse_root(data, offset + 24, chunk_offset, names, style) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(EvtxRecord::{ number, timestamp, size, chunk_offset, offset, root, })
}

///|
fn parse_chunk_records(
  data : Bytes,
  chunk : ChunkHeader,
  style : TimeStyle,
) -> Result[Array[EvtxRecord], EvtxError] {
  let names : Array[(Int, String)] = []
  let _ = match preload_chunk_names(data, chunk.offset, names) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let records : Array[EvtxRecord] = []
  let mut ofs = chunk.offset + 0x200
  let end = chunk.offset + chunk.next_record_offset.reinterpret_as_int()
  while ofs + 8 <= end {
    let (magic, _) = match read_u32(data, ofs) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    if magic != 0x00002A2AU {
      break
    }
    let rec = match parse_record(data, ofs, chunk.offset, names, style) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    records.push(rec)
    ofs = ofs + rec.size.reinterpret_as_int()
  }
  Ok(records)
}

///|
/// Parse an EVTX buffer. Checksums are recorded rather than required.
pub fn parse_evtx(data : Bytes) -> Result[EvtxFile, EvtxError] {
  parse_evtx_styled(data, PythonEvtx)
}

///|
/// Parse with an explicit FILETIME rendering style used while walking BINXML values.
pub fn parse_evtx_styled(
  data : Bytes,
  style : TimeStyle,
) -> Result[EvtxFile, EvtxError] {
  let header = match parse_file_header(data) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if header.header_chunk_size != 0x1000 {
    return Err(InvalidHeader("header_chunk_size \{header.header_chunk_size}"))
  }
  let chunks : Array[ChunkHeader] = []
  let records : Array[EvtxRecord] = []
  let mut i = 0
  while i < header.chunk_count {
    let offset = header.header_chunk_size + i * 0x10000
    if offset + 0x10000 > data.length() {
      return Err(Truncated("chunk", offset, 0x10000))
    }
    let chunk = match parse_chunk_header(data, offset) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let recs = match parse_chunk_records(data, chunk, style) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    chunks.push(chunk)
    for r = 0; r < recs.length(); r = r + 1 {
      records.push(recs[r])
    }
    i = i + 1
  }
  Ok(EvtxFile::{ data, header, chunks, records, })
}

///|
/// Fail if header/chunk checksums do not match python-evtx.
pub fn EvtxFile::verify(self : EvtxFile) -> Result[Unit, EvtxError] {
  if !self.header.checksum_ok {
    return Err(
      InvalidChecksum(
        "file header",
        self.header.checksum,
        match crc32_slice(self.data, 0, 0x78) {
          Ok(v) => v
          Err(e) => return Err(e)
        },
      ),
    )
  }
  if self.header.major_version != 3 || self.header.minor_version != 1 {
    return Err(
      InvalidHeader(
        "version \{self.header.major_version}.\{self.header.minor_version}",
      ),
    )
  }
  for i = 0; i < self.chunks.length(); i = i + 1 {
    let chunk = self.chunks[i]
    if !chunk.header_ok {
      return Err(InvalidChecksum("chunk header", chunk.header_checksum, 0U))
    }
    if !chunk.data_ok {
      return Err(InvalidChecksum("chunk data", chunk.data_checksum, 0U))
    }
  }
  Ok(())
}

///|
pub fn EvtxFile::record_count(self : EvtxFile) -> Int {
  self.records.length()
}

///|
pub fn EvtxRecord::xml(
  self : EvtxRecord,
  style : TimeStyle,
) -> Result[String, EvtxError] {
  render_root(self.root, style)
}
