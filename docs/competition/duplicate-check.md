# MoonEvtx duplication check

- Date: 2026-09-16
- Candidate: MoonEvtx (`kekeshuo/moonevtx`)
- Kind: library port of [python-evtx](https://github.com/williballenthin/python-evtx) (Apache-2.0)
- Scope: Windows EVTX file header / chunk / record codec, BINXML recursive descent, CRC-32 verification, XML/JSON rendering, in-memory writer

## Search limitation

Local `moon search` is not available in this toolchain. Occupancy was checked against:

1. the MoonCakes HTTP API
2. a 2499-module catalog dump (`modules.json`)
3. GitHub code search restricted to MoonBit
4. `osc2026-guide` `project-registry.md`
5. adjacent package READMEs (hex_editor, win32, moonlog, sessionlog, XML parsers)

## MoonCakes live API (`[]` = no modules)

Exact terms returning empty arrays: `evtx`, `binxml`, `winevt`, `python-evtx`, `wevtutil`, `elfile`.

Noisy terms that are **not** EVTX codecs:

- `eventlog` -> EventLoop / issue-tracker packages
- `win32` -> `lijin1891/win32` MessageBox plus `orby` window-host FFI, not a file codec
- `elfile` -> WASI `EMFILE` / `ENFILE` constants
- `sessionlog` -> rehab session logger
- `ldap` / `marc21` -> already occupied (`moonldap`, `moonmarc`)

## GitHub / MoonBit

`gh search code "evtx language:MoonBit"` only hits imgui `PrimWriteVtx`. `kekeshuo/moonevtx` was 404 at reservation time.

`R00TK17/hex_editor` understands elf/pe/dex/bmp/png/gif/jpeg/mp3/zip/sqlite/class. It does not mention EVTX or BINXML.

## Registry

FIT (`MoonFitparse`) is reserved for Han-Wentao and is also license-sensitive. MoonLDAP, moonmarc, and MoonNTP are occupied or reserved. SOAP/WSDL is empty but sits on the text-XML problem loop, so it was rejected as an alternative.

## Adjacent but different

| Package | Why it is not an EVTX codec |
| --- | --- |
| `lijin1891/win32`, `orby` | live Windows API FFI, not `.evtx` bytes |
| MoonLog / xlog / moonlog | application loggers |
| `ywz1314/sessionlog` | rehab session records |
| `Milky2018/xml` and spreadsheet XML | text XML, not Microsoft BINXML |
| YARA / SARIF / SQLi engines | detection reports, not Event Log files |

## Decision

MoonEvtx is the selected port. Capability overlap with existing MoonBit packages is not present. Nearby Windows/logging/XML packages are documented as caveats, not as duplicates.
