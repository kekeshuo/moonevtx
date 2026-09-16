# Architecture

## File layout

An EVTX file is a 4096-byte `ElfFile` header followed by 65536-byte `ElfChnk` chunks. Each chunk has a 0x200-byte header (including 64 string-table slots and 32 template-table slots) and then records. A record is magic `0x00002a2a`, size, record number, FILETIME, BINXML, padding, trailing size.

Checksums follow python-evtx:

- file header: CRC-32 of bytes `[0, 0x78)`
- chunk header: CRC-32 of `[0, 0x78)` plus `[0x80, 0x200)`
- chunk data: CRC-32 of `[0x200, next_record_offset)`

Polynomial is ISO 3309 / zlib (`0xEDB88320`), not CRC-32C.

## BINXML

Records usually start with StreamStart + TemplateInstance. If the template is resident, its definition sits immediately after the instance header. Substitutions follow the instance (which already includes the resident template body). Value tokens carry an inner length prefix; substitution payloads use the declared size only. That difference matters for WString/Binary.

The parser is procedural recursive descent (`binxml.mbt`), not an OOP node class hierarchy. XML rendering walks the template children the same way `Evtx/Views.py` does: attributes first, then body, always emitting a close tag.

## Writer

`write_events` emits one Event template with eight substitutions (Provider, EventID, Level, TimeCreated, EventRecordID, Channel, Computer, Message). Names are inlined. Records pad to 8 bytes. Multiple chunks are used when the current chunk would overflow.

## Targets

All logic is in-memory `Bytes`. wasm-gc/wasm/js/native are supported; tests do not touch the filesystem.
