#!/usr/bin/env python3
"""Replace one regular file inside a gzip-compressed newc initramfs."""

import argparse
import gzip
import stat
import sys


HEADER_LEN = 110
TRAILER = "TRAILER!!!"


def align4(value):
    return (value + 3) & ~3


def parse_header(raw, offset):
    header = raw[offset:offset + HEADER_LEN]
    if len(header) != HEADER_LEN or header[:6] not in (b"070701", b"070702"):
        raise ValueError(f"bad newc header at offset {offset}")
    values = [int(header[6 + i * 8:14 + i * 8], 16) for i in range(13)]
    return header[:6].decode("ascii"), values


def make_header(magic, values):
    return magic.encode("ascii") + b"".join(f"{value:08x}".encode("ascii") for value in values)


def replace_entry(raw, target, replacement):
    out = bytearray()
    pos = 0
    replaced = False

    while pos < len(raw):
        entry_start = pos
        magic, values = parse_header(raw, pos)
        namesize = values[11]
        filesize = values[6]
        pos += HEADER_LEN

        name_bytes = raw[pos:pos + namesize]
        if len(name_bytes) != namesize or not name_bytes.endswith(b"\0"):
            raise ValueError(f"bad filename at offset {entry_start}")
        name = name_bytes[:-1].decode("utf-8")
        pos += namesize
        data_start = align4(pos)
        data_end = data_start + filesize
        data = raw[data_start:data_end]
        if len(data) != filesize:
            raise ValueError(f"truncated data for {name}")
        pos = align4(data_end)

        if name == target:
            values[1] = stat.S_IFREG | 0o755
            values[6] = len(replacement)
            data = replacement
            replaced = True

        out.extend(make_header(magic, values))
        out.extend(name.encode("utf-8") + b"\0")
        out.extend(b"\0" * (align4(len(out)) - len(out)))
        out.extend(data)
        out.extend(b"\0" * (align4(len(out)) - len(out)))

        if name == TRAILER:
            break

    if not replaced:
        raise ValueError(f"target {target!r} was not found")
    return bytes(out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input_gz")
    parser.add_argument("target")
    parser.add_argument("replacement_file")
    parser.add_argument("output_gz")
    args = parser.parse_args()

    with gzip.open(args.input_gz, "rb") as src:
        raw = src.read()
    with open(args.replacement_file, "rb") as src:
        replacement = src.read()

    updated = replace_entry(raw, args.target, replacement)

    with open(args.output_gz, "wb") as raw_dst:
        with gzip.GzipFile(fileobj=raw_dst, mode="wb", compresslevel=9, mtime=0) as dst:
            dst.write(updated)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"replace_newc_file.py: {exc}", file=sys.stderr)
        sys.exit(1)
