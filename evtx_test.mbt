///|
test "writer produces verifiable EVTX with three records" {
  let bytes = @moonevtx.write_events(@moonevtx.sample_event_drafts()).unwrap()
  assert_eq(bytes.length(), 69632)
  let file = @moonevtx.parse_evtx(bytes).unwrap()
  file.verify().unwrap()
  assert_eq(file.record_count(), 3)
  assert_eq(file.header.chunk_count, 1)
  assert_eq(file.header.next_record_number, 4UL)
  assert_true(file.chunks[0].header_ok)
  assert_true(file.chunks[0].data_ok)
}

///|
test "parsed EventIDs match 1000/1001/4624 goldens" {
  let file = @moonevtx.parse_evtx(
    @moonevtx.write_events(@moonevtx.sample_event_drafts()).unwrap(),
  ).unwrap()
  let events = file.events(@moonevtx.PythonEvtx).unwrap()
  assert_eq(events[0].event_id, 1000U)
  assert_eq(events[1].event_id, 1001U)
  assert_eq(events[2].event_id, 4624U)
  assert_eq(events[0].provider, "MoonEvtx")
  assert_eq(events[2].provider, "Security")
  assert_eq(events[0].message, "service started")
  assert_eq(events[1].message, "disk warning")
  assert_eq(events[2].message, "logon success")
  assert_eq(events[0].time_text, "2024-03-09 16:00:00+00:00")
  assert_eq(events[2].channel, "Security")
  assert_eq(events[0].computer, "HOST1")
}

///|
test "XML rendering matches python-evtx Views.py" {
  let file = @moonevtx.parse_evtx(
    @moonevtx.write_events(@moonevtx.sample_event_drafts()).unwrap(),
  ).unwrap()
  let xml0 = file.records[0].xml(@moonevtx.PythonEvtx).unwrap()
  let xml1 = file.records[1].xml(@moonevtx.PythonEvtx).unwrap()
  let xml2 = file.records[2].xml(@moonevtx.PythonEvtx).unwrap()
  assert_true(@moonevtx.text_contains(xml0, "<EventID>1000</EventID>"))
  assert_true(@moonevtx.text_contains(xml0, "2024-03-09 16:00:00+00:00"))
  assert_true(@moonevtx.text_contains(xml0, "service started"))
  assert_true(@moonevtx.text_contains(xml1, "<EventID>1001</EventID>"))
  assert_true(@moonevtx.text_contains(xml1, "disk warning"))
  assert_true(@moonevtx.text_contains(xml2, "<EventID>4624</EventID>"))
  assert_true(@moonevtx.text_contains(xml2, "logon success"))
}

///|
test "filter keeps Security 4624" {
  let file = @moonevtx.parse_evtx(
    @moonevtx.write_events(@moonevtx.sample_event_drafts()).unwrap(),
  ).unwrap()
  let spec = @moonevtx.FilterSpec::{
    event_id: Some(4624U),
    provider: None,
    channel: Some("Security"),
    computer: None,
    level: None,
    contains: None,
    since: None,
    until: None,
  }
  let hit = file.filter(spec, @moonevtx.PythonEvtx).unwrap()
  assert_eq(hit.length(), 1)
  assert_eq(hit[0].message, "logon success")
}

///|
test "truncated header is an error" {
  match @moonevtx.parse_evtx(@moonevtx.bytes_from_ascii("ElfFile")) {
    Err(@moonevtx.Truncated(_, _, _)) => ()
    _ => fail("expected truncated header")
  }
}

///|
test "empty writer input is rejected" {
  match @moonevtx.write_events([]) {
    Err(@moonevtx.InvalidDraft(_)) => ()
    _ => fail("expected invalid draft")
  }
}

///|
test "stats count channels" {
  let file = @moonevtx.parse_evtx(
    @moonevtx.write_events(@moonevtx.sample_event_drafts()).unwrap(),
  ).unwrap()
  let text = @moonevtx.file_stats(file, @moonevtx.PythonEvtx).unwrap()
  assert_true(@moonevtx.text_contains(text, "event_id 1000=1"))
  assert_true(@moonevtx.text_contains(text, "channel Security=1"))
}

///|
test "json contains event_id" {
  let file = @moonevtx.parse_evtx(
    @moonevtx.write_events(@moonevtx.sample_event_drafts()).unwrap(),
  ).unwrap()
  let json = @moonevtx.events_json(file.events(@moonevtx.PythonEvtx).unwrap())
  assert_true(@moonevtx.text_contains(json, "\"event_id\":1000"))
}

///|
test "tampered header checksum fails verify" {
  let raw = @moonevtx.write_events(@moonevtx.sample_event_drafts()).unwrap()
  let buf : Array[Byte] = []
  for b in raw {
    buf.push(b)
  }
  buf[16] = (buf[16].to_int() ^ 1).to_byte()
  let file = @moonevtx.parse_evtx(Bytes::from_array(buf)).unwrap()
  match file.verify() {
    Err(@moonevtx.InvalidChecksum(_, _, _)) => ()
    _ => fail("expected checksum error")
  }
}
