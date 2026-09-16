///|
/// FILETIME / SYSTEMTIME rendering style.
pub(all) enum TimeStyle {
  PythonEvtx
  Iso8601
} derive(Eq, Debug)

///|
fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn pad4(n : Int) -> String {
  if n < 10 {
    "000" + n.to_string()
  } else if n < 100 {
    "00" + n.to_string()
  } else if n < 1000 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn pad6(n : Int) -> String {
  if n < 10 {
    "00000" + n.to_string()
  } else if n < 100 {
    "0000" + n.to_string()
  } else if n < 1000 {
    "000" + n.to_string()
  } else if n < 10000 {
    "00" + n.to_string()
  } else if n < 100000 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
/// Civil date from days since Unix epoch using Howard Hinnant's algorithm.
fn civil_from_unix_days(unix_days : Int64) -> (Int, Int, Int) {
  let z = unix_days + 719468L
  let era = if z >= 0L { z / 146097L } else { (z - 146096L) / 146097L }
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = mp + (if mp < 10L { 3L } else { -9L })
  let year = y + (if m <= 2L { 1L } else { 0L })
  (year.to_int(), m.to_int(), d.to_int())
}

///|
fn civil_from_unix(unix : Int64) -> (Int, Int, Int, Int, Int, Int) {
  let day_secs = 86400L
  let days = if unix >= 0L {
    unix / day_secs
  } else {
    (unix - (day_secs - 1L)) / day_secs
  }
  let sod = (unix - days * day_secs).to_int()
  let hour = sod / 3600
  let minute = sod % 3600 / 60
  let second = sod % 60
  let (year, month, day) = civil_from_unix_days(days)
  (year, month, day, hour, minute, second)
}

///|
/// Convert a Windows FILETIME (100-ns ticks from 1601-01-01) to Unix seconds.
pub fn filetime_to_unix(filetime : UInt64) -> Int64 {
  if filetime == 0UL {
    return -62135596800L
  }
  let seconds = filetime / 10000000UL
  seconds.reinterpret_as_int64() - 11644473600L
}

///|
fn filetime_microseconds(filetime : UInt64) -> Int {
  if filetime == 0UL {
    0
  } else {
    (filetime % 10000000UL / 10UL).to_int()
  }
}

///|
/// python-evtx `datetime.isoformat(" ")` for UTC FILETIME values.
pub fn format_filetime(filetime : UInt64, style : TimeStyle) -> String {
  if filetime == 0UL {
    match style {
      PythonEvtx => "0001-01-01 00:00:00"
      Iso8601 => "0001-01-01T00:00:00Z"
    }
  } else {
    let unix = filetime_to_unix(filetime)
    let us = filetime_microseconds(filetime)
    let (year, month, day, hour, minute, second) = civil_from_unix(unix)
    let date = pad4(year) + "-" + pad2(month) + "-" + pad2(day)
    let clock = pad2(hour) + ":" + pad2(minute) + ":" + pad2(second)
    let frac = if us == 0 { "" } else { "." + pad6(us) }
    match style {
      PythonEvtx => date + " " + clock + frac + "+00:00"
      Iso8601 => date + "T" + clock + frac + "Z"
    }
  }
}

///|
/// Encode Unix seconds as FILETIME.
pub fn unix_to_filetime(unix : Int64) -> UInt64 {
  let ticks = (unix + 11644473600L) * 10000000L
  ticks.reinterpret_as_uint64()
}

///|
/// SYSTEMTIME: year, month, dow, day, hour, minute, second, millisecond.
pub fn format_systemtime(
  data : Bytes,
  pos : Int,
  style : TimeStyle,
) -> Result[String, EvtxError] {
  let _ = match need(data, pos, 16, "systemtime") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (year, _) = match read_u16(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (month, _) = match read_u16(data, pos + 2) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (day, _) = match read_u16(data, pos + 6) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (hour, _) = match read_u16(data, pos + 8) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (minute, _) = match read_u16(data, pos + 10) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (second, _) = match read_u16(data, pos + 12) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (millis, _) = match read_u16(data, pos + 14) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let date = pad4(year) + "-" + pad2(month) + "-" + pad2(day)
  let clock = pad2(hour) + ":" + pad2(minute) + ":" + pad2(second)
  let us = millis * 1000
  let frac = if us == 0 { "" } else { "." + pad6(us) }
  match style {
    PythonEvtx => Ok(date + " " + clock + frac)
    Iso8601 => Ok(date + "T" + clock + frac)
  }
}
