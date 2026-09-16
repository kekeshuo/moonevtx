///|
fn main {
  let file = @evtx.parse_evtx(
    @evtx.write_events(@evtx.sample_event_drafts()).unwrap(),
  ).unwrap()
  let spec = @evtx.FilterSpec::{
    event_id: Some(4624U),
    provider: None,
    channel: Some("Security"),
    computer: None,
    level: None,
    contains: None,
    since: None,
    until: None,
  }
  let hit = file.filter(spec, @evtx.PythonEvtx).unwrap()
  println("matched=\{hit.length()}")
  println(hit[0].json())
}
