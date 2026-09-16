///|
/// Input event used by the in-memory EVTX writer.
pub(all) struct EventDraft {
  provider : String
  event_id : UInt
  level : Int
  timestamp : UInt64
  channel : String
  computer : String
  message : String
} derive(Debug)

///|
fn uint_from_int(n : Int) -> UInt {
  n.reinterpret_as_uint()
}

///|
fn align8(n : Int) -> Int {
  (n + 7) / 8 * 8
}

///|
fn write_name_string(buf : Array[Byte], chunk_abs : Int, name : String) -> Int {
  let rel = buf.length() - chunk_abs
  put_u32(buf, 0U)
  put_u16(buf, name_hash16(name))
  let units = utf16_units(name)
  put_u16(buf, units.length())
  put_utf16(buf, name)
  put_u16(buf, 0)
  rel
}

///|
fn write_value_wstring(buf : Array[Byte], text : String) -> Unit {
  put_u8(buf, 0x05)
  put_u8(buf, 0x01)
  let units = utf16_units(text)
  put_u16(buf, units.length())
  put_utf16(buf, text)
}

///|
fn write_normal_sub(buf : Array[Byte], index : Int, type_code : Int) -> Unit {
  put_u8(buf, 0x0D)
  put_u16(buf, index)
  put_u8(buf, type_code)
}

///|
fn write_attr_name_start(
  buf : Array[Byte],
  chunk_abs : Int,
  name : String,
) -> Unit {
  put_u8(buf, 0x06)
  let off_pos = buf.length()
  put_u32(buf, 0U)
  let rel = write_name_string(buf, chunk_abs, name)
  write_u32_at(buf, off_pos, uint_from_int(rel))
}

///|
fn write_attr_wstring(
  buf : Array[Byte],
  chunk_abs : Int,
  name : String,
  value : String,
) -> Unit {
  write_attr_name_start(buf, chunk_abs, name)
  write_value_wstring(buf, value)
}

///|
fn write_attr_sub(
  buf : Array[Byte],
  chunk_abs : Int,
  name : String,
  index : Int,
  type_code : Int,
) -> Unit {
  write_attr_name_start(buf, chunk_abs, name)
  write_normal_sub(buf, index, type_code)
}

///|
fn write_element_start(
  buf : Array[Byte],
  chunk_abs : Int,
  name : String,
) -> (Int, Int) {
  let start = buf.length()
  put_u8(buf, 0x01)
  put_u16(buf, 0)
  let size_pos = buf.length()
  put_u32(buf, 0U)
  let name_off_pos = buf.length()
  put_u32(buf, 0U)
  let rel = write_name_string(buf, chunk_abs, name)
  write_u32_at(buf, name_off_pos, uint_from_int(rel))
  (start, size_pos)
}

///|
fn finish_element(buf : Array[Byte], start : Int, size_pos : Int) -> Unit {
  write_u32_at(buf, size_pos, uint_from_int(buf.length() - start))
}

///|
fn write_ascii8_at(buf : Array[Byte], pos : Int, text : String) -> Unit {
  for i = 0; i < 8; i = i + 1 {
    if i < text.length() {
      buf[pos + i] = text[i].to_int().to_byte()
    } else {
      buf[pos + i] = (0).to_byte()
    }
  }
}

///|
fn write_event_template(buf : Array[Byte], chunk_abs : Int) -> Unit {
  put_u8(buf, 0x0F)
  put_u8(buf, 0x01)
  put_u16(buf, 0x01)
  let (ev_start, ev_size) = write_element_start(buf, chunk_abs, "Event")
  write_attr_wstring(
    buf, chunk_abs, "xmlns", "http://schemas.microsoft.com/win/2004/08/events/event",
  )
  put_u8(buf, 0x02)
  let (sys_start, sys_size) = write_element_start(buf, chunk_abs, "System")
  put_u8(buf, 0x02)
  let (p_start, p_size) = write_element_start(buf, chunk_abs, "Provider")
  write_attr_sub(buf, chunk_abs, "Name", 0, 0x01)
  put_u8(buf, 0x02)
  put_u8(buf, 0x04)
  finish_element(buf, p_start, p_size)
  let (id_start, id_size) = write_element_start(buf, chunk_abs, "EventID")
  put_u8(buf, 0x02)
  write_normal_sub(buf, 1, 0x08)
  put_u8(buf, 0x04)
  finish_element(buf, id_start, id_size)
  let (lv_start, lv_size) = write_element_start(buf, chunk_abs, "Level")
  put_u8(buf, 0x02)
  write_normal_sub(buf, 2, 0x04)
  put_u8(buf, 0x04)
  finish_element(buf, lv_start, lv_size)
  let (tm_start, tm_size) = write_element_start(buf, chunk_abs, "TimeCreated")
  write_attr_sub(buf, chunk_abs, "SystemTime", 3, 0x11)
  put_u8(buf, 0x02)
  put_u8(buf, 0x04)
  finish_element(buf, tm_start, tm_size)
  let (rid_start, rid_size) = write_element_start(
    buf, chunk_abs, "EventRecordID",
  )
  put_u8(buf, 0x02)
  write_normal_sub(buf, 4, 0x0A)
  put_u8(buf, 0x04)
  finish_element(buf, rid_start, rid_size)
  let (ch_start, ch_size) = write_element_start(buf, chunk_abs, "Channel")
  put_u8(buf, 0x02)
  write_normal_sub(buf, 5, 0x01)
  put_u8(buf, 0x04)
  finish_element(buf, ch_start, ch_size)
  let (cp_start, cp_size) = write_element_start(buf, chunk_abs, "Computer")
  put_u8(buf, 0x02)
  write_normal_sub(buf, 6, 0x01)
  put_u8(buf, 0x04)
  finish_element(buf, cp_start, cp_size)
  put_u8(buf, 0x04)
  finish_element(buf, sys_start, sys_size)
  let (ed_start, ed_size) = write_element_start(buf, chunk_abs, "EventData")
  put_u8(buf, 0x02)
  let (d_start, d_size) = write_element_start(buf, chunk_abs, "Data")
  write_attr_wstring(buf, chunk_abs, "Name", "Message")
  put_u8(buf, 0x02)
  write_normal_sub(buf, 7, 0x01)
  put_u8(buf, 0x04)
  finish_element(buf, d_start, d_size)
  put_u8(buf, 0x04)
  finish_element(buf, ed_start, ed_size)
  put_u8(buf, 0x04)
  finish_element(buf, ev_start, ev_size)
  put_u8(buf, 0x00)
}

///|
fn write_substitution_table(
  buf : Array[Byte],
  draft : EventDraft,
  record_id : UInt64,
) -> Result[Unit, EvtxError] {
  if draft.level < 0 || draft.level > 255 {
    return Err(InvalidDraft("level out of range"))
  }
  put_u32(buf, 8U)
  put_u16(buf, utf16_byte_length(draft.provider))
  put_u8(buf, 0x01)
  put_u8(buf, 0)
  put_u16(buf, 4)
  put_u8(buf, 0x08)
  put_u8(buf, 0)
  put_u16(buf, 1)
  put_u8(buf, 0x04)
  put_u8(buf, 0)
  put_u16(buf, 8)
  put_u8(buf, 0x11)
  put_u8(buf, 0)
  put_u16(buf, 8)
  put_u8(buf, 0x0A)
  put_u8(buf, 0)
  put_u16(buf, utf16_byte_length(draft.channel))
  put_u8(buf, 0x01)
  put_u8(buf, 0)
  put_u16(buf, utf16_byte_length(draft.computer))
  put_u8(buf, 0x01)
  put_u8(buf, 0)
  put_u16(buf, utf16_byte_length(draft.message))
  put_u8(buf, 0x01)
  put_u8(buf, 0)
  put_utf16(buf, draft.provider)
  put_u32(buf, draft.event_id)
  put_u8(buf, draft.level)
  put_u64(buf, draft.timestamp)
  put_u64(buf, record_id)
  put_utf16(buf, draft.channel)
  put_utf16(buf, draft.computer)
  put_utf16(buf, draft.message)
  Ok(())
}

///|
fn u32_at(buf : Array[Byte], pos : Int) -> UInt {
  buf[pos].to_int().reinterpret_as_uint() |
  (buf[pos + 1].to_int().reinterpret_as_uint() << 8) |
  (buf[pos + 2].to_int().reinterpret_as_uint() << 16) |
  (buf[pos + 3].to_int().reinterpret_as_uint() << 24)
}

///|
fn write_record(
  buf : Array[Byte],
  chunk_abs : Int,
  record_id : UInt64,
  draft : EventDraft,
) -> Result[Int, EvtxError] {
  if draft.provider.length() == 0 || draft.channel.length() == 0 {
    return Err(InvalidDraft("provider and channel are required"))
  }
  let rec_start = buf.length()
  put_u32(buf, 0x00002A2AU)
  let size_pos = buf.length()
  put_u32(buf, 0U)
  put_u64(buf, record_id)
  put_u64(buf, draft.timestamp)
  put_u8(buf, 0x0F)
  put_u8(buf, 0x01)
  put_u16(buf, 0x01)
  put_u8(buf, 0x0C)
  put_u8(buf, 0x01)
  let tid_pos = buf.length()
  put_u32(buf, 0U)
  let toff_pos = buf.length()
  put_u32(buf, 0U)
  let tpl_rel = buf.length() - chunk_abs
  write_u32_at(buf, toff_pos, uint_from_int(tpl_rel))
  put_u32(buf, 0U)
  let _ = match encode_guid_text("d4c3b2a1-f6e5-1807-293a-4b5c6d7e8f90", buf) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let tid = u32_at(buf, buf.length() - 16)
  write_u32_at(buf, tid_pos, tid)
  let data_len_pos = buf.length()
  put_u32(buf, 0U)
  let body_start = buf.length()
  write_event_template(buf, chunk_abs)
  write_u32_at(buf, data_len_pos, uint_from_int(buf.length() - body_start))
  let _ = match write_substitution_table(buf, draft, record_id) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let content = buf.length() - rec_start
  let size = align8(content + 4)
  while buf.length() < rec_start + size - 4 {
    buf.push((0).to_byte())
  }
  put_u32(buf, uint_from_int(size))
  write_u32_at(buf, size_pos, uint_from_int(size))
  Ok(size)
}

///|
fn patch_file_header(
  buf : Array[Byte],
  chunk_count : Int,
  next_record : UInt64,
) -> Result[Unit, EvtxError] {
  write_ascii8_at(buf, 0, "ElfFile")
  write_u64_at(buf, 8, 0UL)
  write_u64_at(buf, 16, (chunk_count - 1).to_int64().reinterpret_as_uint64())
  write_u64_at(buf, 24, next_record)
  write_u32_at(buf, 32, 0x80U)
  write_u16_at(buf, 36, 1)
  write_u16_at(buf, 38, 3)
  write_u16_at(buf, 40, 0x1000)
  write_u16_at(buf, 42, chunk_count)
  write_u32_at(buf, 0x78, 0U)
  let cs = match crc32_slice(Bytes::from_array(buf), 0, 0x78) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  write_u32_at(buf, 0x7C, cs)
  Ok(())
}

///|
fn patch_chunk_header(
  buf : Array[Byte],
  chunk_abs : Int,
  first : UInt64,
  last : UInt64,
  last_off : Int,
  next_off : Int,
) -> Result[Unit, EvtxError] {
  write_ascii8_at(buf, chunk_abs, "ElfChnk")
  write_u64_at(buf, chunk_abs + 8, first)
  write_u64_at(buf, chunk_abs + 16, last)
  write_u64_at(buf, chunk_abs + 24, first)
  write_u64_at(buf, chunk_abs + 32, last)
  write_u32_at(buf, chunk_abs + 40, 0x80U)
  write_u32_at(buf, chunk_abs + 44, uint_from_int(last_off))
  write_u32_at(buf, chunk_abs + 48, uint_from_int(next_off))
  let data_cs = match
    crc32_slice(Bytes::from_array(buf), chunk_abs + 0x200, chunk_abs + next_off) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  write_u32_at(buf, chunk_abs + 52, data_cs)
  let header_cs = match
    crc32_two_slices(
      Bytes::from_array(buf),
      chunk_abs,
      chunk_abs + 0x78,
      chunk_abs + 0x80,
      chunk_abs + 0x200,
    ) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  write_u32_at(buf, chunk_abs + 0x7C, header_cs)
  Ok(())
}

///|
fn finish_chunk(
  buf : Array[Byte],
  chunk_abs : Int,
  first : UInt64,
  last : UInt64,
  last_off : Int,
) -> Result[Unit, EvtxError] {
  let next_off = buf.length() - chunk_abs
  let end = chunk_abs + 0x10000
  while buf.length() < end {
    buf.push((0).to_byte())
  }
  patch_chunk_header(buf, chunk_abs, first, last, last_off, next_off)
}

///|
/// Encode events as a complete EVTX file (4 KiB header + 64 KiB chunks).
pub fn write_events(events : Array[EventDraft]) -> Result[Bytes, EvtxError] {
  if events.length() == 0 {
    return Err(InvalidDraft("at least one event is required"))
  }
  let buf : Array[Byte] = []
  ensure_len(buf, 0x1000)
  let mut chunk_abs = 0x1000
  ensure_len(buf, chunk_abs + 0x200)
  let mut first = 1UL
  let mut last = 0UL
  let mut last_off = 0x200
  let mut chunk_count = 1
  for i = 0; i < events.length(); i = i + 1 {
    let record_id = (i + 1).to_int64().reinterpret_as_uint64()
    let rec_rel = buf.length() - chunk_abs
    if rec_rel > 0x10000 - 0x400 {
      let _ = match finish_chunk(buf, chunk_abs, first, last, last_off) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      chunk_abs = buf.length()
      ensure_len(buf, chunk_abs + 0x200)
      first = record_id
      last = 0UL
      last_off = 0x200
      chunk_count = chunk_count + 1
    }
    last_off = buf.length() - chunk_abs
    let written = match write_record(buf, chunk_abs, record_id, events[i]) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    if written <= 0 {
      return Err(InvalidDraft("empty record"))
    }
    last = record_id
  }
  let _ = match finish_chunk(buf, chunk_abs, first, last, last_off) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let _ = match patch_file_header(buf, chunk_count, last + 1UL) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(Bytes::from_array(buf))
}

///|
/// Three Application/Security events matching the python-evtx fixture goldens.
pub fn sample_event_drafts() -> Array[EventDraft] {
  [
    EventDraft::{
      provider: "MoonEvtx",
      event_id: 1000U,
      level: 4,
      timestamp: unix_to_filetime(1710000000L),
      channel: "Application",
      computer: "HOST1",
      message: "service started",
    },
    EventDraft::{
      provider: "MoonEvtx",
      event_id: 1001U,
      level: 2,
      timestamp: unix_to_filetime(1710000001L),
      channel: "Application",
      computer: "HOST1",
      message: "disk warning",
    },
    EventDraft::{
      provider: "Security",
      event_id: 4624U,
      level: 0,
      timestamp: unix_to_filetime(1710000002L),
      channel: "Security",
      computer: "HOST1",
      message: "logon success",
    },
  ]
}
