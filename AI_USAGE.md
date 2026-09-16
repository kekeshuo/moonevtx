# AI usage

Codex was used to draft the MoonBit port, tests, CI and documentation from python-evtx's public format behavior and a generated three-record fixture.

Human-required checks:

- Occupancy against MoonCakes, GitHub/MoonBit and the contest registry before coding
- CRC, EventID and XML goldens against python-evtx `Views.evtx_record_xml_view`
- `moon check --deny-warn` on wasm-gc/wasm/js/native and `moon test` on wasm-gc/js
- License/NOTICE for Willi Ballenthin / Mandiant python-evtx (Apache-2.0)

The BINXML walker is original MoonBit. It is not a line-by-line copy of the Python classes.
