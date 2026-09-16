///|
fn main {
  let original = @evtx.sample_event_drafts()
  let bytes = @evtx.write_events(original).unwrap()
  let file = @evtx.parse_evtx(bytes).unwrap()
  file.verify().unwrap()
  let events = file.events(@evtx.PythonEvtx).unwrap()
  println("bytes=\{bytes.length()} records=\{events.length()}")
  for i = 0; i < events.length(); i = i + 1 {
    println("\{events[i].event_id} \{events[i].message}")
  }
}
