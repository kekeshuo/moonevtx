///|
/// Extracted Windows Event Log fields.
pub(all) struct Event {
  record_id : UInt64
  event_id : UInt
  level : Int
  provider : String
  channel : String
  computer : String
  timestamp : UInt64
  time_text : String
  message : String
  data : Array[(String, String)]
} derive(Debug)

///|
fn parse_uint_decimal(text : String) -> UInt {
  let mut n = 0U
  for i = 0; i < text.length(); i = i + 1 {
    let cp = text[i].to_int()
    if cp >= 48 && cp <= 57 {
      n = n * 10U + (cp - 48).reinterpret_as_uint()
    }
  }
  n
}

///|
fn parse_int_decimal(text : String) -> Int {
  let mut n = 0
  let mut sign = 1
  for i = 0; i < text.length(); i = i + 1 {
    let cp = text[i].to_int()
    if cp == 45 && i == 0 {
      sign = -1
    } else if cp >= 48 && cp <= 57 {
      n = n * 10 + (cp - 48)
    }
  }
  n * sign
}

///|
fn node_text(
  node : BinNode,
  subs : Array[SubCell],
  style : TimeStyle,
) -> Result[String, EvtxError] {
  match node {
    ValueText(text) => Ok(text)
    NormalSub(index, _t) =>
      if index < 0 || index >= subs.length() {
        Err(InvalidSubstitution("index"))
      } else {
        sub_text(subs[index], style)
      }
    OptionalSub(index, _t) =>
      if index < 0 || index >= subs.length() {
        Err(InvalidSubstitution("index"))
      } else {
        sub_text(subs[index], style)
      }
    OpenStart(_n, _a, children) => {
      let out = StringBuilder()
      for i = 0; i < children.length(); i = i + 1 {
        out.write_string(
          match node_text(children[i], subs, style) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
        )
      }
      Ok(out.to_string())
    }
    _ => Ok("")
  }
}

///|
fn attr_value(
  attrs : Array[BinAttr],
  key : String,
  subs : Array[SubCell],
  style : TimeStyle,
) -> Result[String, EvtxError] {
  for i = 0; i < attrs.length(); i = i + 1 {
    if attrs[i].name == key {
      return node_text(attrs[i].value, subs, style)
    }
  }
  Ok("")
}

///|
fn walk_event(
  node : BinNode,
  subs : Array[SubCell],
  style : TimeStyle,
  acc : Event,
) -> Result[Event, EvtxError] {
  match node {
    OpenStart(name, attrs, children) => {
      let mut next = acc
      if name == "Provider" {
        next = Event::{
          ..next,
          provider: match attr_value(attrs, "Name", subs, style) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
        }
      } else if name == "EventID" {
        next = Event::{
          ..next,
          event_id: parse_uint_decimal(
            match node_text(node, subs, style) {
              Ok(v) => v
              Err(e) => return Err(e)
            },
          ),
        }
      } else if name == "Level" {
        next = Event::{
          ..next,
          level: parse_int_decimal(
            match node_text(node, subs, style) {
              Ok(v) => v
              Err(e) => return Err(e)
            },
          ),
        }
      } else if name == "TimeCreated" {
        next = Event::{
          ..next,
          time_text: match attr_value(attrs, "SystemTime", subs, style) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
        }
      } else if name == "EventRecordID" {
        let rec_text = match node_text(node, subs, style) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let rec_n = parse_uint_decimal(rec_text)
        next = Event::{
          ..next,
          record_id: rec_n
          .reinterpret_as_int()
          .to_int64()
          .reinterpret_as_uint64(),
        }
      } else if name == "Channel" {
        next = Event::{
          ..next,
          channel: match node_text(node, subs, style) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
        }
      } else if name == "Computer" {
        next = Event::{
          ..next,
          computer: match node_text(node, subs, style) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
        }
      } else if name == "Data" {
        let key = match attr_value(attrs, "Name", subs, style) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let value = match node_text(node, subs, style) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let data = next.data
        data.push((key, value))
        if key == "Message" || next.message.length() == 0 {
          next = Event::{ ..next, message: value, data, }
        } else {
          next = Event::{ ..next, data, }
        }
      }
      let mut cur = next
      for i = 0; i < children.length(); i = i + 1 {
        cur = match walk_event(children[i], subs, style, cur) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
      }
      Ok(cur)
    }
    _ => Ok(acc)
  }
}

///|
/// Pull conventional System/EventData fields out of a parsed record.
pub fn EvtxRecord::event(
  self : EvtxRecord,
  style : TimeStyle,
) -> Result[Event, EvtxError] {
  let mut acc = Event::{
    record_id: self.number,
    event_id: 0U,
    level: 0,
    provider: "",
    channel: "",
    computer: "",
    timestamp: self.timestamp,
    time_text: format_filetime(self.timestamp, style),
    message: "",
    data: [],
  }
  for i = 0; i < self.root.template.length(); i = i + 1 {
    acc = match
      walk_event(self.root.template[i], self.root.substitutions, style, acc) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
  }
  Ok(acc)
}

///|
pub fn EvtxFile::events(
  self : EvtxFile,
  style : TimeStyle,
) -> Result[Array[Event], EvtxError] {
  let out : Array[Event] = []
  for i = 0; i < self.records.length(); i = i + 1 {
    let ev = match self.records[i].event(style) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    out.push(ev)
  }
  Ok(out)
}
