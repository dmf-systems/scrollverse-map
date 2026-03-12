#!/usr/bin/env python3
"""Deterministic placeholder embedding generator."""

import argparse
import hashlib
import json
import sys
from typing import List, Optional


def generate_embedding(text: str) -> List[float]:
    """Create a deterministic 64-dim float vector from text."""
    digest = hashlib.sha256(text.encode("utf-8")).digest()
    extended = digest + hashlib.sha256(digest).digest()  # 64 bytes total

    def byte_to_float(b: int) -> float:
        # Map 0..255 to approximately -1..1
        return (b - 127.5) / 127.5

    return [byte_to_float(b) for b in extended]


def _read_text(path: Optional[str]) -> str:
    if path:
        with open(path, "r", encoding="utf-8") as fh:
            return fh.read()
    return sys.stdin.read()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate deterministic placeholder embeddings for text input."
    )
    parser.add_argument(
        "-f",
        "--file",
        help="Path to a text file. If omitted, reads from stdin.",
    )
    args = parser.parse_args()

    text = _read_text(args.file)
    embedding = generate_embedding(text)
    json.dump({"text": text, "embedding": embedding}, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
