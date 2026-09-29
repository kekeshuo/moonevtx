#!/usr/bin/env python3
"""Fail when the active MoonBit compiler is older than the project minimum."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys


def parse_version(text: str) -> tuple[int, int, int] | None:
    match = re.search(r"(?:^|\s)v?(\d+)\.(\d+)\.(\d+)(?:[+\-]|\s|$)", text)
    if match is None:
        return None
    return tuple(int(part) for part in match.groups())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--min", required=True, dest="minimum")
    args = parser.parse_args()
    minimum = parse_version(args.minimum)
    if minimum is None:
        print(f"invalid minimum version: {args.minimum}", file=sys.stderr)
        return 2
    try:
        result = subprocess.run(["moonc", "-v"], check=False, text=True, capture_output=True)
    except OSError as exc:
        print(f"cannot execute moonc: {exc}", file=sys.stderr)
        return 2
    output = (result.stdout + "\n" + result.stderr).strip()
    actual = parse_version(output)
    if result.returncode != 0 or actual is None:
        print(f"cannot parse moonc version from: {output}", file=sys.stderr)
        return 2
    print(f"moonc {actual[0]}.{actual[1]}.{actual[2]} (minimum {args.minimum})")
    if actual < minimum:
        print("compiler is too old", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
