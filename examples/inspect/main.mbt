///|
fn main {
  let bytes = @evtx.write_events(@evtx.sample_event_drafts()).unwrap()
  let file = @evtx.parse_evtx(bytes).unwrap()
  file.verify().unwrap()
  println(@evtx.dump_file(file, @evtx.PythonEvtx).unwrap())
  println(file.records[0].xml(@evtx.PythonEvtx).unwrap())
}
