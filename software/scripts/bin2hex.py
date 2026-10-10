#!/usr/bin/env python3

import argparse
from pathlib import Path


def convert(input_path: Path, output_path: Path) -> None:
    data = input_path.read_bytes()
    padding = (-len(data)) % 4
    if padding:
        data += bytes(padding)

    lines = []
    for offset in range(0, len(data), 4):
        word = int.from_bytes(data[offset:offset + 4], byteorder="little")
        lines.append(f"{word:08x}\n")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("".join(lines), encoding="ascii")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert a little-endian binary to 32-bit readmemh words."
    )
    parser.add_argument("input", type=Path, help="input binary file")
    parser.add_argument("output", type=Path, help="output hex file")
    args = parser.parse_args()
    convert(args.input, args.output)


if __name__ == "__main__":
    main()
