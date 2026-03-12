#!/usr/bin/env python3
"""Bulk ingestion helper to generate placeholder embeddings for text files."""

import argparse
import json
import sys
from pathlib import Path
from typing import Iterable

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from dmf7_embedding_placeholder import generate_embedding  # type: ignore

OUTPUT_DIR = Path("/opt/dmf7/embeddings")


def iter_source_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if path.is_file() and path.suffix.lower() in {".txt", ".md"}:
            yield path


def output_path_for(source: Path, root: Path) -> Path:
    relative = source.relative_to(root)
    safe_name = "_".join(relative.parts)
    return OUTPUT_DIR / f"{safe_name}.json"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate placeholder embeddings for .txt and .md files in a directory."
    )
    parser.add_argument("directory", help="Directory containing .txt and .md files.")
    args = parser.parse_args()

    source_root = Path(args.directory).resolve()
    if not source_root.is_dir():
        parser.error(f"{source_root} is not a directory")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for source_file in iter_source_files(source_root):
        with open(source_file, "r", encoding="utf-8") as fh:
            text = fh.read()

        embedding = generate_embedding(text)
        payload = {"file": str(source_file), "embedding": embedding}

        out_path = output_path_for(source_file, source_root)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as out_f:
            json.dump(payload, out_f)
            out_f.write("\n")


if __name__ == "__main__":
    main()
