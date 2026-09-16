///|
/// Predicate over extracted events. Absent fields are ignored.
pub(all) struct FilterSpec {
  event_id : UInt?
  provider : String?
  channel : String?
  computer : String?
  level : Int?
  contains : String?
  since : UInt64?
  until : UInt64?
} derive(Debug)

///|
/// Empty filter that keeps every event.
pub fn empty_filter() -> FilterSpec {
  FilterSpec::{
    event_id: None,
    provider: None,
    channel: None,
    computer: None,
    level: None,
    contains: None,
    since: None,
    until: None,
  }
}

///|
pub fn text_contains(hay : String, needle : String) -> Bool {
  if needle.length() == 0 {
    return true
  }
  if needle.length() > hay.length() {
    return false
  }
  let last = hay.length() - needle.length()
  for i = 0; i <= last; i = i + 1 {
    let mut ok = true
    for j = 0; j < needle.length(); j = j + 1 {
      if hay[i + j] != needle[j] {
        ok = false
      }
    }
    if ok {
      return true
    }
  }
  false
}

///|
fn opt_eq_uint(got : UInt, want : UInt?) -> Bool {
  match want {
    None => true
    Some(v) => got == v
  }
}

///|
fn opt_eq_int(got : Int, want : Int?) -> Bool {
  match want {
    None => true
    Some(v) => got == v
  }
}

///|
fn opt_eq_str(got : String, want : String?) -> Bool {
  match want {
    None => true
    Some(v) => got == v
  }
}

///|
fn opt_since(ts : UInt64, want : UInt64?) -> Bool {
  match want {
    None => true
    Some(v) => ts >= v
  }
}

///|
fn opt_until(ts : UInt64, want : UInt64?) -> Bool {
  match want {
    None => true
    Some(v) => ts <= v
  }
}

///|
pub fn Event::matches(self : Event, spec : FilterSpec) -> Bool {
  let text_hit = match spec.contains {
    None => true
    Some(part) =>
      text_contains(self.message, part) ||
      text_contains(self.provider, part) ||
      text_contains(self.channel, part) ||
      text_contains(self.computer, part)
  }
  opt_eq_uint(self.event_id, spec.event_id) &&
  opt_eq_str(self.provider, spec.provider) &&
  opt_eq_str(self.channel, spec.channel) &&
  opt_eq_str(self.computer, spec.computer) &&
  opt_eq_int(self.level, spec.level) &&
  opt_since(self.timestamp, spec.since) &&
  opt_until(self.timestamp, spec.until) &&
  text_hit
}

///|
pub fn filter_events(events : Array[Event], spec : FilterSpec) -> Array[Event] {
  let out : Array[Event] = []
  for i = 0; i < events.length(); i = i + 1 {
    if events[i].matches(spec) {
      out.push(events[i])
    }
  }
  out
}

///|
pub fn EvtxFile::filter(
  self : EvtxFile,
  spec : FilterSpec,
  style : TimeStyle,
) -> Result[Array[Event], EvtxError] {
  Ok(
    filter_events(
      match self.events(style) {
        Ok(v) => v
        Err(e) => return Err(e)
      },
      spec,
    ),
  )
}
