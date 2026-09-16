# Security

MoonEvtx treats EVTX as untrusted bytes. Truncation, bad magic and checksum mismatches return `EvtxError`. It does not execute BINXML substitutions as code.

Please open a GitHub issue for parser crashes or checksum bypasses on well-formed files.
