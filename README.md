# MoonEvtx

MoonBit library for Windows Event Log `.evtx` files. It reads the 4 KiB file header, 64 KiB chunks, record stream and Microsoft BINXML, checks CRC-32 the same way [python-evtx](https://github.com/williballenthin/python-evtx) does, renders XML/JSON, filters extracted events, and writes a well-formed EVTX buffer in memory.

This is a behavior port of python-evtx (Apache-2.0), not a Windows Event Log API wrapper and not a text XML parser.

## Why it exists

Forensics and IR tools often need to inspect `.evtx` without `wevtutil` or Win32. MoonBit did not have an EVTX/BINXML codec. Adjacent packages cover live Win32 FFI, application loggers, or text XML; they do not decode `ElfFile` chunks.

## Install

```text
moon add kekeshuo/moonevtx
```

Or copy this repository and `moon check`.

## Example

```moonbit
let bytes = @evtx.write_events(@evtx.sample_event_drafts()).unwrap()
let file = @evtx.parse_evtx(bytes).unwrap()
file.verify().unwrap()
let xml = file.records[0].xml(@evtx.PythonEvtx).unwrap()
let events = file.events(@evtx.PythonEvtx).unwrap()
```

Runnable programs:

```text
moon run examples/inspect
moon run examples/filter
moon run examples/roundtrip
```

`inspect` prints header/chunk CRC status, EventID 1000/1001/4624, and python-evtx-compatible XML.

## What it does

- Parse `ElfFile` / `ElfChnk` / record magic `0x00002a2a`
- CRC-32 over header `0x00..0x78` and chunk header+tables / record payload
- Recursive-descent BINXML (open/close, attributes, substitutions, resident templates)
- XML rendering matching python-evtx `Views.py`
- Event field extraction, filter, dump, JSON
- In-memory writer: 4096-byte header + 65536-byte chunks, 8-byte record padding, resident templates

## What it does not do

- Call `OpenEventLog` / `wevtutil`
- Parse text XML or Windows XML Eventing XSLT
- Ship third-party captured logs (tests generate fixtures)

## Tests

```text
moon test --target wasm-gc
moon test --target js
```

Goldens: 3 records, EventIDs 1000/1001/4624, TimeCreated `2024-03-09 16:00:00+00:00`, record sizes 896/888/888, file length 69632, header/chunk CRC verify.

## License

Apache-2.0. See `LICENSE` and `NOTICE`.
