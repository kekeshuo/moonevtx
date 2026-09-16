#!/usr/bin/env python3
from __future__ import annotations
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOON = Path(r"C:\Users\42673\.moon\bin\moon.exe")
moon = str(MOON if MOON.exists() else "moon")

def run(args: list[str]) -> None:
    print("+", " ".join(args), flush=True)
    subprocess.check_call(args, cwd=ROOT)

def main() -> int:
    run([moon, "fmt"])
    run([sys.executable, str(ROOT / "tools" / "count_effective_moonbit.py"), "--check-core", "2000"])
    for target in ("wasm-gc", "wasm", "js", "native"):
        run([moon, "check", "--target", target, "--deny-warn"])
    run([moon, "test", "--target", "wasm-gc"])
    run([moon, "test", "--target", "js"])
    for example in ("inspect", "filter", "roundtrip"):
        run([moon, "run", f"examples/{example}"])
    print("verify ok")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
