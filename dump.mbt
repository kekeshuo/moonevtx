///|
/// Human-readable file dump covering header, chunks and record summaries.
pub fn dump_file(
  file : EvtxFile,
  style : TimeStyle,
) -> Result[String, EvtxError] {
  let out = StringBuilder()
  out.write_string("EVTX file\n")
  out.write_string("  records: ")
  out.write_string(file.records.length().to_string())
  out.write_string("\n  chunks: ")
  out.write_string(file.chunks.length().to_string())
  out.write_string("\n  next_record_number: ")
  out.write_string(file.header.next_record_number.to_string())
  out.write_string("\n  version: ")
  out.write_string(file.header.major_version.to_string())
  out.write_string(".")
  out.write_string(file.header.minor_version.to_string())
  out.write_string("\n  flags: ")
  out.write_string(file.header.flags.to_string())
  out.write_string("\n  header_checksum_ok: ")
  out.write_string(file.header.checksum_ok.to_string())
  out.write_string("\n")
  for i = 0; i < file.chunks.length(); i = i + 1 {
    let chunk = file.chunks[i]
    out.write_string("CHUNK ")
    out.write_string(i.to_string())
    out.write_string(" offset=")
    out.write_string(chunk.offset.to_string())
    out.write_string(" records=")
    out.write_string(chunk.first_record.to_string())
    out.write_string("-")
    out.write_string(chunk.last_record.to_string())
    out.write_string(" header_ok=")
    out.write_string(chunk.header_ok.to_string())
    out.write_string(" data_ok=")
    out.write_string(chunk.data_ok.to_string())
    out.write_string("\n")
  }
  for i = 0; i < file.records.length(); i = i + 1 {
    let rec = file.records[i]
    let ev = match rec.event(style) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    out.write_string("RECORD ")
    out.write_string(rec.number.to_string())
    out.write_string(" size=")
    out.write_string(rec.size.to_string())
    out.write_string(" EventID=")
    out.write_string(ev.event_id.to_string())
    out.write_string(" Level=")
    out.write_string(ev.level.to_string())
    out.write_string(" Provider=")
    out.write_string(ev.provider)
    out.write_string(" Channel=")
    out.write_string(ev.channel)
    out.write_string(" Computer=")
    out.write_string(ev.computer)
    out.write_string(" Time=")
    out.write_string(ev.time_text)
    out.write_string("\n  Message=")
    out.write_string(ev.message)
    out.write_string("\n")
  }
  Ok(out.to_string())
}

///|
/// Count records by EventID / channel / level.
pub fn file_stats(
  file : EvtxFile,
  style : TimeStyle,
) -> Result[String, EvtxError] {
  let events = match file.events(style) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let ids : Array[(UInt, Int)] = []
  let channels : Array[(String, Int)] = []
  let levels : Array[(Int, Int)] = []
  for i = 0; i < events.length(); i = i + 1 {
    bump_uint(ids, events[i].event_id)
    bump_str(channels, events[i].channel)
    bump_int(levels, events[i].level)
  }
  let out = StringBuilder()
  out.write_string("records=")
  out.write_string(events.length().to_string())
  out.write_string("\n")
  for i = 0; i < ids.length(); i = i + 1 {
    let (k, n) = ids[i]
    out.write_string("event_id ")
    out.write_string(k.to_string())
    out.write_string("=")
    out.write_string(n.to_string())
    out.write_string("\n")
  }
  for i = 0; i < channels.length(); i = i + 1 {
    let (k, n) = channels[i]
    out.write_string("channel ")
    out.write_string(k)
    out.write_string("=")
    out.write_string(n.to_string())
    out.write_string("\n")
  }
  for i = 0; i < levels.length(); i = i + 1 {
    let (k, n) = levels[i]
    out.write_string("level ")
    out.write_string(k.to_string())
    out.write_string("=")
    out.write_string(n.to_string())
    out.write_string("\n")
  }
  Ok(out.to_string())
}

///|
fn bump_uint(rows : Array[(UInt, Int)], key : UInt) -> Unit {
  for i = 0; i < rows.length(); i = i + 1 {
    let (k, n) = rows[i]
    if k == key {
      rows[i] = (k, n + 1)
      return
    }
  }
  rows.push((key, 1))
}

///|
fn bump_int(rows : Array[(Int, Int)], key : Int) -> Unit {
  for i = 0; i < rows.length(); i = i + 1 {
    let (k, n) = rows[i]
    if k == key {
      rows[i] = (k, n + 1)
      return
    }
  }
  rows.push((key, 1))
}

///|
fn bump_str(rows : Array[(String, Int)], key : String) -> Unit {
  for i = 0; i < rows.length(); i = i + 1 {
    let (k, n) = rows[i]
    if k == key {
      rows[i] = (k, n + 1)
      return
    }
  }
  rows.push((key, 1))
}

///|
fn write_json_pair(
  out : StringBuilder,
  key : String,
  value : String,
  quoted : Bool,
) -> Unit {
  out.write_char('"')
  out.write_string(key)
  out.write_char('"')
  out.write_char(':')
  if quoted {
    out.write_char('"')
    out.write_string(value)
    out.write_char('"')
  } else {
    out.write_string(value)
  }
}

///|
/// JSON object for one extracted event.
pub fn Event::json(self : Event) -> String {
  let out = StringBuilder()
  out.write_char('{')
  write_json_pair(out, "record_id", self.record_id.to_string(), false)
  out.write_char(',')
  write_json_pair(out, "event_id", self.event_id.to_string(), false)
  out.write_char(',')
  write_json_pair(out, "level", self.level.to_string(), false)
  out.write_char(',')
  write_json_pair(out, "provider", json_escape(self.provider), true)
  out.write_char(',')
  write_json_pair(out, "channel", json_escape(self.channel), true)
  out.write_char(',')
  write_json_pair(out, "computer", json_escape(self.computer), true)
  out.write_char(',')
  write_json_pair(out, "time", json_escape(self.time_text), true)
  out.write_char(',')
  write_json_pair(out, "message", json_escape(self.message), true)
  out.write_char(',')
  out.write_char('"')
  out.write_string("data")
  out.write_string("\":[")
  for i = 0; i < self.data.length(); i = i + 1 {
    if i > 0 {
      out.write_char(',')
    }
    let (k, v) = self.data[i]
    out.write_char('{')
    write_json_pair(out, "name", json_escape(k), true)
    out.write_char(',')
    write_json_pair(out, "value", json_escape(v), true)
    out.write_char('}')
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn events_json(events : Array[Event]) -> String {
  let out = StringBuilder()
  out.write_char('[')
  for i = 0; i < events.length(); i = i + 1 {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string(events[i].json())
  }
  out.write_char(']')
  out.to_string()
}

///|
/// Hex dump of a record body, 16 bytes per row.
pub fn hexdump_range(
  data : Bytes,
  start : Int,
  end : Int,
) -> Result[String, EvtxError] {
  let _ = match need(data, start, end - start, "hexdump") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out = StringBuilder()
  let mut i = start
  while i < end {
    out.write_string(hex_byte((i >> 8) & 255))
    out.write_string(hex_byte(i & 255))
    out.write_string(": ")
    let mut j = 0
    while j < 16 && i + j < end {
      out.write_string(hex_byte(data[i + j].to_int()))
      out.write_char(' ')
      j = j + 1
    }
    out.write_char('\n')
    i = i + 16
  }
  Ok(out.to_string())
}

///|
pub fn EvtxRecord::hexdump(
  self : EvtxRecord,
  file : EvtxFile,
) -> Result[String, EvtxError] {
  hexdump_range(
    file.data,
    self.offset,
    self.offset + self.size.reinterpret_as_int(),
  )
}

///|
/// True when the log was opened dirty (flag bit 0).
pub fn EvtxFile::is_dirty(self : EvtxFile) -> Bool {
  (self.header.flags & 1U) == 1U
}

///|
/// True when the log reported a full-file write failure (flag bit 1).
pub fn EvtxFile::is_full(self : EvtxFile) -> Bool {
  (self.header.flags & 2U) == 2U
}

///|
pub fn EvtxFile::xml_records(
  self : EvtxFile,
  style : TimeStyle,
) -> Result[Array[String], EvtxError] {
  let out : Array[String] = []
  for i = 0; i < self.records.length(); i = i + 1 {
    let xml = match self.records[i].xml(style) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    out.push(xml)
  }
  Ok(out)
}
