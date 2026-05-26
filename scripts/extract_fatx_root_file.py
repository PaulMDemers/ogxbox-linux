#!/usr/bin/env python3
"""Extract a root-directory file from an Xbox FATX partition image."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

from fatx_stage_boot import (
    END_OF_CHAIN,
    ROOT_CLUSTER,
    decode_name,
    open_partition,
    read_at,
    read_fat_entry,
    root_entries,
)


def find_root_file(fp, part, name: str) -> tuple[int, int]:
    target = name.lower().lstrip("\\/")
    for _, entry in root_entries(fp, part):
        entry_name = decode_name(entry)
        if entry_name and entry_name.lower() == target:
            start_cluster = struct.unpack_from("<I", entry, 0x2C)[0]
            size = struct.unpack_from("<I", entry, 0x30)[0]
            return start_cluster, size
    raise FileNotFoundError(f"{name!r} not found in FATX root")


def cluster_chain(fp, part, start_cluster: int):
    cluster = start_cluster
    seen: set[int] = set()
    while cluster not in seen and ROOT_CLUSTER <= cluster < part.cluster_count:
        seen.add(cluster)
        yield cluster
        next_cluster = read_fat_entry(fp, part, cluster)
        if next_cluster in (END_OF_CHAIN, 0xFFFFFFF8, 0xFFFF, 0xFFF8, 0):
            break
        cluster = next_cluster


def extract(raw_image: Path, partition: str, fatx_name: str, output: Path) -> None:
    with raw_image.open("rb") as fp:
        part = open_partition(fp, raw_image, partition)
        start_cluster, size = find_root_file(fp, part, fatx_name)

        output.parent.mkdir(parents=True, exist_ok=True)
        remaining = size
        with output.open("wb") as out:
            for cluster in cluster_chain(fp, part, start_cluster):
                data = read_at(fp, part.cluster_offset(cluster), part.cluster_size)
                take = min(remaining, len(data))
                out.write(data[:take])
                remaining -= take
                if remaining == 0:
                    break

        if remaining:
            raise EOFError(f"FATX chain ended with {remaining} bytes left")

        print(
            f"extracted /{fatx_name.lstrip('/')} size={size} "
            f"cluster={start_cluster} output={output}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("raw_image", type=Path)
    parser.add_argument("fatx_name")
    parser.add_argument("output", type=Path)
    parser.add_argument("--partition", default="E")
    args = parser.parse_args()

    extract(args.raw_image, args.partition, args.fatx_name, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
