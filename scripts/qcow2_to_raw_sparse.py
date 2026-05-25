#!/usr/bin/env python3
"""Convert a simple qcow2 image to a sparse raw image.

This intentionally supports the narrow qcow2 feature set used by xemu HDD
images here: version 2/3, unencrypted, uncompressed standard data clusters,
and no backing file dependency.
"""

from __future__ import annotations

import argparse
import os
import struct
from pathlib import Path


QCOW_MAGIC = 0x514649FB
QCOW_OFLAG_COMPRESSED = 1 << 62
QCOW_OFFSET_MASK = 0x00FFFFFFFFFFFE00


def read_at(fp, offset: int, size: int) -> bytes:
    fp.seek(offset)
    data = fp.read(size)
    if len(data) != size:
        raise EOFError(f"short read at {offset:#x}: wanted {size}, got {len(data)}")
    return data


def parse_header(fp) -> dict[str, int]:
    base = read_at(fp, 0, 104)
    (
        magic,
        version,
        backing_file_offset,
        backing_file_size,
        cluster_bits,
        virtual_size,
        crypt_method,
        l1_size,
        l1_table_offset,
        refcount_table_offset,
        refcount_table_clusters,
        nb_snapshots,
        snapshots_offset,
        incompatible_features,
        compatible_features,
        autoclear_features,
        refcount_order,
        header_length,
    ) = struct.unpack(">IIQIIQIIQQIIQQQQII", base)

    if magic != QCOW_MAGIC:
        raise ValueError("not a qcow2 image")
    if version not in (2, 3):
        raise ValueError(f"unsupported qcow2 version {version}")
    if backing_file_offset or backing_file_size:
        raise ValueError("backing files are not supported by this converter")
    if crypt_method:
        raise ValueError("encrypted qcow2 images are not supported")
    if incompatible_features & ~0:
        # The xemu image used for this project has no incompatible feature bits.
        raise ValueError(f"unsupported incompatible feature bits: {incompatible_features:#x}")

    return {
        "version": version,
        "cluster_bits": cluster_bits,
        "cluster_size": 1 << cluster_bits,
        "virtual_size": virtual_size,
        "l1_size": l1_size,
        "l1_table_offset": l1_table_offset,
        "refcount_table_offset": refcount_table_offset,
        "refcount_table_clusters": refcount_table_clusters,
        "nb_snapshots": nb_snapshots,
        "snapshots_offset": snapshots_offset,
        "compatible_features": compatible_features,
        "autoclear_features": autoclear_features,
        "refcount_order": refcount_order,
        "header_length": header_length,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    if args.output.exists() and not args.force:
        raise SystemExit(f"refusing to overwrite {args.output}")

    args.output.parent.mkdir(parents=True, exist_ok=True)

    copied_clusters = 0
    allocated_clusters = 0

    with args.input.open("rb") as src:
        header = parse_header(src)
        cluster_size = header["cluster_size"]
        l2_entries = cluster_size // 8
        l1_data = read_at(src, header["l1_table_offset"], header["l1_size"] * 8)
        l1_entries = struct.unpack(f">{header['l1_size']}Q", l1_data)

        with args.output.open("w+b") as dst:
            dst.truncate(header["virtual_size"])

            for l1_index, l1_entry in enumerate(l1_entries):
                if not l1_entry:
                    continue
                if l1_entry & QCOW_OFLAG_COMPRESSED:
                    raise ValueError(f"compressed L2 table at L1 index {l1_index}")

                l2_offset = l1_entry & QCOW_OFFSET_MASK
                l2_data = read_at(src, l2_offset, cluster_size)
                l2_entries_data = struct.unpack(f">{l2_entries}Q", l2_data)

                for l2_index, l2_entry in enumerate(l2_entries_data):
                    if not l2_entry:
                        continue
                    if l2_entry & QCOW_OFLAG_COMPRESSED:
                        raise ValueError(
                            f"compressed data cluster at L1 {l1_index}, L2 {l2_index}"
                        )

                    virtual_cluster = (l1_index * l2_entries) + l2_index
                    virtual_offset = virtual_cluster * cluster_size
                    if virtual_offset >= header["virtual_size"]:
                        continue

                    data_offset = l2_entry & QCOW_OFFSET_MASK
                    to_copy = min(cluster_size, header["virtual_size"] - virtual_offset)
                    data = read_at(src, data_offset, to_copy)
                    allocated_clusters += 1

                    if data.strip(b"\0"):
                        dst.seek(virtual_offset)
                        dst.write(data)
                        copied_clusters += 1

    print(f"virtual_size={header['virtual_size']}")
    print(f"cluster_size={header['cluster_size']}")
    print(f"allocated_clusters={allocated_clusters}")
    print(f"nonzero_clusters_written={copied_clusters}")
    print(f"output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
