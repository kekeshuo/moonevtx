///|
fn render_substitution(
  index : Int,
  subs : Array[SubCell],
  style : TimeStyle,
) -> Result[String, EvtxError] {
  if index < 0 || index >= subs.length() {
    return Err(InvalidSubstitution("index \{index} out of range"))
  }
  let cell = subs[index]
  if cell.type_code == 0 && cell.payload.length() == 0 {
    Ok("")
  } else {
    let raw = match sub_text(cell, style) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    Ok(escape_xml_value(raw))
  }
}

///|
fn render_node(
  node : BinNode,
  subs : Array[SubCell],
  style : TimeStyle,
  out : StringBuilder,
) -> Result[Unit, EvtxError] {
  match node {
    EndOfStream => Ok(())
    StreamStart => Ok(())
    OpenStart(name, attrs, children) => {
      let _ = match validate_xml_name(name) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      out.write_char('<')
      out.write_string(name)
      for i = 0; i < attrs.length(); i = i + 1 {
        let attr = attrs[i]
        out.write_char(' ')
        out.write_string(
          match validate_xml_name(attr.name) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
        )
        out.write_string("=\"")
        let _ = match render_node(attr.value, subs, style, out) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        out.write_char('"')
      }
      out.write_char('>')
      for i = 0; i < children.length(); i = i + 1 {
        let _ = match render_node(children[i], subs, style, out) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
      }
      out.write_string("</")
      out.write_string(name)
      out.write_string(">\n")
      Ok(())
    }
    ValueText(text) => {
      out.write_string(escape_xml_value(text))
      Ok(())
    }
    CData(text) => {
      out.write_string("<![CDATA[")
      out.write_string(escape_xml_value(text))
      out.write_string("]]>")
      Ok(())
    }
    CharRef(entity) => {
      out.write_string("&#x")
      out.write_string(hex_byte((entity >> 8) & 255))
      out.write_string(hex_byte(entity & 255))
      out.write_char(';')
      Ok(())
    }
    EntityRef(text) => {
      out.write_string(escape_xml_value(text))
      Ok(())
    }
    PITarget(text) => {
      out.write_string(escape_xml_value(text))
      Ok(())
    }
    PIData(text) => {
      out.write_string(escape_xml_value(text))
      Ok(())
    }
    NormalSub(index, _typ) => {
      out.write_string(
        match render_substitution(index, subs, style) {
          Ok(v) => v
          Err(e) => return Err(e)
        },
      )
      Ok(())
    }
    OptionalSub(index, _typ) => {
      out.write_string(
        match render_substitution(index, subs, style) {
          Ok(v) => v
          Err(e) => return Err(e)
        },
      )
      Ok(())
    }
  }
}

///|
/// Render a parsed root using python-evtx `Views.render_root_node_with_subs`.
pub fn render_root(
  root : ParsedRoot,
  style : TimeStyle,
) -> Result[String, EvtxError] {
  let out = StringBuilder()
  for i = 0; i < root.template.length(); i = i + 1 {
    let _ = match
      render_node(root.template[i], root.substitutions, style, out) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
  }
  Ok(out.to_string())
}

///|
fn json_escape(text : String) -> String {
  let out = StringBuilder()
  for i = 0; i < text.length(); i = i + 1 {
    let cp = text[i].to_int()
    if cp == 34 {
      out.write_string("\\\"")
    } else if cp == 92 {
      out.write_string("\\\\")
    } else if cp == 10 {
      out.write_string("\\n")
    } else if cp == 13 {
      out.write_string("\\r")
    } else if cp == 9 {
      out.write_string("\\t")
    } else if cp < 32 {
      out.write_string("\\u00")
      out.write_string(hex_byte(cp))
    } else {
      out.write_char(cp.unsafe_to_char())
    }
  }
  out.to_string()
}
