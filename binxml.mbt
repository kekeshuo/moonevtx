///|
/// One attribute on an open-start element.
pub(all) struct BinAttr {
  name : String
  value : BinNode
} derive(Debug)

///|
/// Procedural BINXML node. Close tokens are consumed and not stored.
pub(all) enum BinNode {
  EndOfStream
  StreamStart
  OpenStart(String, Array[BinAttr], Array[BinNode])
  ValueText(String)
  CData(String)
  CharRef(Int)
  EntityRef(String)
  PITarget(String)
  PIData(String)
  NormalSub(Int, Int)
  OptionalSub(Int, Int)
} derive(Debug)

///|
/// Substitution cell. Nested BINXML lives in `nested` when type is BXml.
pub(all) struct SubCell {
  type_code : Int
  payload : Bytes
  nested : Array[ParsedRoot]
} derive(Debug)

///|
/// Root BINXML: template body plus substitution table.
pub(all) struct ParsedRoot {
  template : Array[BinNode]
  substitutions : Array[SubCell]
} derive(Debug)

///|
fn peek_byte(data : Bytes, pos : Int) -> Result[Int, EvtxError] {
  let _ = match need(data, pos, 1, "token") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(data[pos].to_int())
}

///|
fn load_name(
  data : Bytes,
  chunk_offset : Int,
  string_offset : Int,
  names : Array[(Int, String)],
) -> Result[String, EvtxError] {
  for i = 0; i < names.length(); i = i + 1 {
    let (off, name) = names[i]
    if off == string_offset {
      return Ok(name)
    }
  }
  let abs = chunk_offset + string_offset
  let (next_off, p1) = match read_u32(data, abs) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (hash, p2) = match read_u16(data, p1) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (nchars, p3) = match read_u16(data, p2) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let name = match read_utf16_units(data, p3, nchars) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if next_off == 0xFFFFFFFF && hash == -2 {
    return Err(InvalidName("impossible name header"))
  }
  names.push((string_offset, name))
  Ok(name)
}

///|
fn parse_attribute(
  data : Bytes,
  pos : Int,
  chunk_offset : Int,
  names : Array[(Int, String)],
  style : TimeStyle,
) -> Result[(BinAttr, Int), EvtxError] {
  let token = match peek_byte(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if (token & 0x0F) != 0x06 {
    return Err(UnexpectedToken(token, pos))
  }
  let (string_offset, cur) = match read_u32(data, pos + 1) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let rel = pos - chunk_offset
  let name = match
    load_name(data, chunk_offset, string_offset.reinterpret_as_int(), names) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let mut body = cur
  if string_offset.reinterpret_as_int() > rel {
    let abs = chunk_offset + string_offset.reinterpret_as_int()
    let (nchars_hdr, _) = match read_u16(data, abs + 6) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    body = abs + nchars_hdr * 2 + 10
  }
  let (value, next) = match parse_node(data, body, chunk_offset, names, style) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((BinAttr::{ name, value, }, next))
}

///|
fn parse_value_node(
  data : Bytes,
  pos : Int,
  style : TimeStyle,
) -> Result[(BinNode, Int), EvtxError] {
  let (type_code, cur) = match read_u8(data, pos + 1) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (text, used) = match format_variant(data, cur, type_code, None, style) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((ValueText(text), cur + used))
}

///|
fn parse_open_start(
  data : Bytes,
  pos : Int,
  chunk_offset : Int,
  names : Array[(Int, String)],
  style : TimeStyle,
) -> Result[(BinNode, Int), EvtxError] {
  let token = match peek_byte(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (_unknown, p1) = match read_u16(data, pos + 1) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (size, p2) = match read_u32(data, p1) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (string_offset, p3) = match read_u32(data, p2) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let mut cur = p3
  if (token & 0x40) != 0 {
    let (_extra, next) = match read_u32(data, cur) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    cur = next
  }
  let rel = pos - chunk_offset
  let name = match
    load_name(data, chunk_offset, string_offset.reinterpret_as_int(), names) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if string_offset.reinterpret_as_int() > rel {
    let abs = chunk_offset + string_offset.reinterpret_as_int()
    let (nchars, _) = match read_u16(data, abs + 6) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    cur = abs + nchars * 2 + 10
  }
  if size == 0U && name.length() == 0 {
    return Err(InvalidName("empty open-start"))
  }
  let attrs : Array[BinAttr] = []
  let children : Array[BinNode] = []
  let mut done = false
  while !done {
    let tok = match peek_byte(data, cur) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let code = tok & 0x0F
    if code == 0x02 {
      cur = cur + 1
    } else if code == 0x03 || code == 0x04 {
      cur = cur + 1
      done = true
    } else if code == 0x06 {
      let (attr, next) = match
        parse_attribute(data, cur, chunk_offset, names, style) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      attrs.push(attr)
      cur = next
    } else {
      let (child, next) = match
        parse_node(data, cur, chunk_offset, names, style) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      children.push(child)
      cur = next
    }
  }
  Ok((OpenStart(name, attrs, children), cur))
}

///|
fn parse_node(
  data : Bytes,
  pos : Int,
  chunk_offset : Int,
  names : Array[(Int, String)],
  style : TimeStyle,
) -> Result[(BinNode, Int), EvtxError] {
  let token = match peek_byte(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let code = token & 0x0F
  match code {
    0x00 => Ok((EndOfStream, pos + 1))
    0x01 => parse_open_start(data, pos, chunk_offset, names, style)
    0x02 => Ok((EndOfStream, pos + 1))
    0x03 => Ok((EndOfStream, pos + 1))
    0x04 => Ok((EndOfStream, pos + 1))
    0x05 => parse_value_node(data, pos, style)
    0x07 => {
      let (slen, cur) = match read_u16(data, pos + 1) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let nchars = slen - 2
      let text = match read_utf16_units(data, cur, nchars) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((CData(text), cur + nchars * 2))
    }
    0x08 => {
      let (entity, next) = match read_u16(data, pos + 1) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((CharRef(entity), next))
    }
    0x09 => {
      let (string_offset, cur) = match read_u32(data, pos + 1) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let name = match
        load_name(data, chunk_offset, string_offset.reinterpret_as_int(), names) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let mut next = cur
      if string_offset.reinterpret_as_int() > pos - chunk_offset {
        let abs = chunk_offset + string_offset.reinterpret_as_int()
        let (nchars, _) = match read_u16(data, abs + 6) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        next = abs + nchars * 2 + 10
      }
      Ok((EntityRef("&" + name + ";"), next))
    }
    0x0A => {
      let (string_offset, cur) = match read_u32(data, pos + 1) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let name = match
        load_name(data, chunk_offset, string_offset.reinterpret_as_int(), names) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let mut next = cur
      if string_offset.reinterpret_as_int() > pos - chunk_offset {
        let abs = chunk_offset + string_offset.reinterpret_as_int()
        let (nchars, _) = match read_u16(data, abs + 6) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        next = abs + nchars * 2 + 10
      }
      Ok((PITarget(name), next))
    }
    0x0B => {
      let (nchars, cur) = match read_u16(data, pos + 1) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let text = if nchars == 0 {
        ""
      } else {
        match read_utf16_units(data, cur, nchars) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
      }
      Ok((PIData(text), cur + nchars * 2))
    }
    0x0D => {
      let (index, p1) = match read_u16(data, pos + 1) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let (typ, next) = match read_u8(data, p1) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((NormalSub(index, typ), next))
    }
    0x0E => {
      let (index, p1) = match read_u16(data, pos + 1) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let (typ, next) = match read_u8(data, p1) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((OptionalSub(index, typ), next))
    }
    0x0F => {
      let _ = match need(data, pos, 4, "stream-start") {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((StreamStart, pos + 4))
    }
    _ => Err(UnexpectedToken(token, pos))
  }
}

///|
fn parse_node_list(
  data : Bytes,
  pos : Int,
  chunk_offset : Int,
  names : Array[(Int, String)],
  style : TimeStyle,
  end_abs : Int,
) -> Result[(Array[BinNode], Int), EvtxError] {
  let nodes : Array[BinNode] = []
  let mut cur = pos
  let mut stop = false
  while !stop {
    if cur >= end_abs {
      stop = true
    } else {
      let (node, next) = match
        parse_node(data, cur, chunk_offset, names, style) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      nodes.push(node)
      cur = next
      match node {
        EndOfStream => stop = true
        _ => ()
      }
    }
  }
  Ok((nodes, cur))
}

///|
fn parse_substitutions(
  data : Bytes,
  pos : Int,
  chunk_offset : Int,
  names : Array[(Int, String)],
  style : TimeStyle,
) -> Result[(Array[SubCell], Int), EvtxError] {
  let (count_u, cur0) = match read_u32(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let count = count_u.reinterpret_as_int()
  if count < 0 || count > 4096 {
    return Err(InvalidSubstitution("substitution count \{count}"))
  }
  let sizes : Array[Int] = []
  let types : Array[Int] = []
  let mut cur = cur0
  for i = 0; i < count; i = i + 1 {
    let (size, p1) = match read_u16(data, cur) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let (typ, p2) = match read_u8(data, p1) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let (_pad, p3) = match read_u8(data, p2) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    sizes.push(size)
    types.push(typ)
    cur = p3
  }
  let cells : Array[SubCell] = []
  for i = 0; i < count; i = i + 1 {
    let size = sizes[i]
    let typ = types[i]
    let _ = match need(data, cur, size, "substitution") {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let payload = bytes_slice(data, cur, cur + size)
    let nested : Array[ParsedRoot] = []
    if (typ & 0x7F) == 0x21 {
      let (root, _) = match parse_root(data, cur, chunk_offset, names, style) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      nested.push(root)
    }
    cells.push(SubCell::{ type_code: typ, payload, nested, })
    cur = cur + size
  }
  Ok((cells, cur))
}

///|
fn parse_template_body(
  data : Bytes,
  pos : Int,
  chunk_offset : Int,
  names : Array[(Int, String)],
  style : TimeStyle,
) -> Result[(Array[BinNode], UInt, Int), EvtxError] {
  let (_next_off, _) = match read_u32(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (template_id, _) = match read_u32(data, pos + 4) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let _ = match need(data, pos, 0x18, "template") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (data_length, _) = match read_u32(data, pos + 0x14) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let body = pos + 0x18
  let end_abs = body + data_length.reinterpret_as_int()
  let (nodes, cur) = match
    parse_node_list(data, body, chunk_offset, names, style, end_abs) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if cur > end_abs {
    return Err(InvalidRecord("template body overruns data_length"))
  }
  Ok((nodes, template_id, pos + 0x18 + data_length.reinterpret_as_int()))
}

///|
fn parse_root(
  data : Bytes,
  pos : Int,
  chunk_offset : Int,
  names : Array[(Int, String)],
  style : TimeStyle,
) -> Result[(ParsedRoot, Int), EvtxError] {
  let mut cur = pos
  let first = match peek_byte(data, pos) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if (first & 0x0F) == 0x0F {
    cur = pos + 4
  }
  let tok = match peek_byte(data, cur) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if (tok & 0x0F) == 0x0C {
    let (_unknown0, p1) = match read_u8(data, cur + 1) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let (_tid, p2) = match read_u32(data, p1) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let (template_offset, p3) = match read_u32(data, p2) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let rel = cur - chunk_offset
    let mut after_inst = p3
    let tpl_abs = chunk_offset + template_offset.reinterpret_as_int()
    let (nodes, _tid2, tpl_end) = match
      parse_template_body(data, tpl_abs, chunk_offset, names, style) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    if template_offset.reinterpret_as_int() > rel {
      after_inst = tpl_end
    }
    let (subs, end) = match
      parse_substitutions(data, after_inst, chunk_offset, names, style) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    Ok((ParsedRoot::{ template: nodes, substitutions: subs, }, end))
  } else {
    let (nodes, mid) = match
      parse_node_list(data, pos, chunk_offset, names, style, data.length()) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    if mid + 4 <= data.length() {
      let (subs, end) = match
        parse_substitutions(data, mid, chunk_offset, names, style) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((ParsedRoot::{ template: nodes, substitutions: subs, }, end))
    } else {
      Ok((ParsedRoot::{ template: nodes, substitutions: [], }, mid))
    }
  }
}

///|
fn sub_text(cell : SubCell, style : TimeStyle) -> Result[String, EvtxError] {
  if cell.nested.length() > 0 {
    render_root(cell.nested[0], style)
  } else {
    let (text, _) = match
      format_variant(
        cell.payload,
        0,
        cell.type_code,
        Some(cell.payload.length()),
        style,
      ) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    Ok(text)
  }
}
