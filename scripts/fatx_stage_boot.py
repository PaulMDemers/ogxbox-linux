#!/usr/bin/env python3
"""Stage a Cromwell Linux boot set into the Xbox HDD FATX E partition."""

from __future__ import annotations

import argparse
import math
import struct
from dataclasses import dataclass
from pathlib import Path


PARTITIONS = {
    "E": (0x0055F400 * 512, 0x131F00000),
}

FATX_MAGIC = b"FATX"
HEADER_SIZE = 0x1000
DIRECTORY_ENTRY_SIZE = 0x40
ROOT_CLUSTER = 1
ATTR_ARCHIVE = 0x20
FREE_CLUSTER = 0x00000000
END_OF_CHAIN = 0xFFFFFFFF


@dataclass
class FatxPartition:
    image: Path
    partition_offset: int
    partition_size: int
    cluster_size: int
    cluster_count: int
    entry_size: int
    fat_offset: int
    fat_size: int
    cluster1_offset: int

    def cluster_offset(self, cluster_id: int) -> int:
        if cluster_id < 1 or cluster_id >= self.cluster_count:
            raise ValueError(f"cluster id out of range: {cluster_id}")
        return self.cluster1_offset + ((cluster_id - 1) * self.cluster_size)

    def fat_entry_offset(self, cluster_id: int) -> int:
        return self.fat_offset + (cluster_id * self.entry_size)


def read_at(fp, offset: int, size: int) -> bytes:
    fp.seek(offset)
    data = fp.read(size)
    if len(data) != size:
        raise EOFError(f"short read at {offset:#x}: wanted {size}, got {len(data)}")
    return data


def write_at(fp, offset: int, data: bytes) -> None:
    fp.seek(offset)
    fp.write(data)


def open_partition(fp, image: Path, partition_name: str) -> FatxPartition:
    try:
        partition_offset, partition_size = PARTITIONS[partition_name.upper()]
    except KeyError:
        raise ValueError(f"unsupported partition {partition_name!r}")

    header = read_at(fp, partition_offset, HEADER_SIZE)
    if header[:4] != FATX_MAGIC:
        raise ValueError(f"FATX magic not found at {partition_name}: offset {partition_offset:#x}")

    sectors_per_cluster = struct.unpack_from("<I", header, 8)[0]
    root_cluster = struct.unpack_from("<I", header, 12)[0]
    if root_cluster != ROOT_CLUSTER:
        raise ValueError(f"unsupported root cluster {root_cluster}; expected 1")

    cluster_size = sectors_per_cluster * 512
    cluster_count = partition_size // cluster_size
    entry_size = 4 if cluster_count >= 0xFFF4 else 2
    fat_size = math.ceil((cluster_count * entry_size) / 4096) * 4096
    return FatxPartition(
        image=image,
        partition_offset=partition_offset,
        partition_size=partition_size,
        cluster_size=cluster_size,
        cluster_count=cluster_count,
        entry_size=entry_size,
        fat_offset=partition_offset + HEADER_SIZE,
        fat_size=fat_size,
        cluster1_offset=partition_offset + HEADER_SIZE + fat_size,
    )


def read_fat_entry(fp, part: FatxPartition, cluster_id: int) -> int:
    data = read_at(fp, part.fat_entry_offset(cluster_id), part.entry_size)
    if part.entry_size == 4:
        return struct.unpack("<I", data)[0]
    return struct.unpack("<H", data)[0]


def write_fat_entry(fp, part: FatxPartition, cluster_id: int, value: int) -> None:
    if part.entry_size == 4:
        data = struct.pack("<I", value)
    else:
        data = struct.pack("<H", value & 0xFFFF)
    write_at(fp, part.fat_entry_offset(cluster_id), data)


def read_cluster(fp, part: FatxPartition, cluster_id: int) -> bytes:
    return read_at(fp, part.cluster_offset(cluster_id), part.cluster_size)


def write_cluster(fp, part: FatxPartition, cluster_id: int, data: bytes) -> None:
    if len(data) > part.cluster_size:
        raise ValueError("cluster write is too large")
    write_at(fp, part.cluster_offset(cluster_id), data.ljust(part.cluster_size, b"\0"))


def root_entries(fp, part: FatxPartition) -> list[tuple[int, bytearray]]:
    root = bytearray(read_cluster(fp, part, ROOT_CLUSTER))
    entries: list[tuple[int, bytearray]] = []
    for offset in range(0, len(root), DIRECTORY_ENTRY_SIZE):
        entry = root[offset : offset + DIRECTORY_ENTRY_SIZE]
        entries.append((offset, bytearray(entry)))
        if entry[0] in (0x00, 0xFF):
            break
    return entries


def decode_name(entry: bytes) -> str | None:
    if entry[0] in (0x00, 0xFF, 0xE5):
        return None
    return entry[2 : 2 + entry[0]].decode("ascii", errors="replace")


def free_chain(fp, part: FatxPartition, start_cluster: int) -> None:
    cluster_id = start_cluster
    seen: set[int] = set()
    while cluster_id not in seen and 1 <= cluster_id < part.cluster_count:
        seen.add(cluster_id)
        next_cluster = read_fat_entry(fp, part, cluster_id)
        write_fat_entry(fp, part, cluster_id, FREE_CLUSTER)
        if next_cluster in (0xFFFFFFFF, 0xFFFFFFF8, 0xFFFF, 0xFFF8, 0):
            break
        cluster_id = next_cluster


def remove_root_file(fp, part: FatxPartition, name: str) -> None:
    root = bytearray(read_cluster(fp, part, ROOT_CLUSTER))
    target = name.lower()
    for offset in range(0, len(root), DIRECTORY_ENTRY_SIZE):
        entry = root[offset : offset + DIRECTORY_ENTRY_SIZE]
        if entry[0] in (0x00, 0xFF):
            break
        entry_name = decode_name(entry)
        if entry_name and entry_name.lower() == target:
            start_cluster = struct.unpack_from("<I", entry, 0x2C)[0]
            if start_cluster:
                free_chain(fp, part, start_cluster)
            root[offset] = 0xE5
    write_cluster(fp, part, ROOT_CLUSTER, root)


def allocate_clusters(fp, part: FatxPartition, count: int) -> list[int]:
    clusters: list[int] = []
    for cluster_id in range(2, part.cluster_count):
        if read_fat_entry(fp, part, cluster_id) == FREE_CLUSTER:
            clusters.append(cluster_id)
            if len(clusters) == count:
                break
    if len(clusters) != count:
        raise RuntimeError(f"not enough free FATX clusters: need {count}, got {len(clusters)}")

    for index, cluster_id in enumerate(clusters):
        next_value = clusters[index + 1] if index + 1 < len(clusters) else END_OF_CHAIN
        write_fat_entry(fp, part, cluster_id, next_value)
    return clusters


def find_root_slot(root: bytearray) -> int:
    deleted_slot: int | None = None
    for offset in range(0, len(root), DIRECTORY_ENTRY_SIZE):
        marker = root[offset]
        if marker == 0xE5 and deleted_slot is None:
            deleted_slot = offset
        if marker in (0x00, 0xFF):
            return deleted_slot if deleted_slot is not None else offset
    if deleted_slot is not None:
        return deleted_slot
    raise RuntimeError("root directory is full")


def write_root_file(fp, part: FatxPartition, name: str, data: bytes) -> None:
    encoded = name.encode("ascii")
    if not encoded or len(encoded) > 42:
        raise ValueError(f"FATX filename must be 1-42 ASCII bytes: {name!r}")

    remove_root_file(fp, part, name)

    cluster_count = max(1, math.ceil(len(data) / part.cluster_size))
    clusters = allocate_clusters(fp, part, cluster_count)
    for index, cluster_id in enumerate(clusters):
        chunk = data[index * part.cluster_size : (index + 1) * part.cluster_size]
        write_cluster(fp, part, cluster_id, chunk)

    root = bytearray(read_cluster(fp, part, ROOT_CLUSTER))
    slot = find_root_slot(root)
    entry = bytearray(DIRECTORY_ENTRY_SIZE)
    entry[0] = len(encoded)
    entry[1] = ATTR_ARCHIVE
    entry[2 : 2 + len(encoded)] = encoded
    struct.pack_into("<I", entry, 0x2C, clusters[0])
    struct.pack_into("<I", entry, 0x30, len(data))
    root[slot : slot + DIRECTORY_ENTRY_SIZE] = entry

    next_slot = slot + DIRECTORY_ENTRY_SIZE
    if next_slot < len(root) and root[next_slot] == 0x00:
        root[next_slot] = 0xFF
    write_cluster(fp, part, ROOT_CLUSTER, root)


def list_root(fp, part: FatxPartition) -> list[str]:
    lines: list[str] = []
    for _, entry in root_entries(fp, part):
        name = decode_name(entry)
        if not name:
            continue
        flags = entry[1]
        cluster_id = struct.unpack_from("<I", entry, 0x2C)[0]
        size = struct.unpack_from("<I", entry, 0x30)[0]
        kind = "dir " if flags & 0x10 else "file"
        lines.append(f"{kind} {name} cluster={cluster_id} size={size}")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("raw_image", type=Path)
    parser.add_argument("--partition", default="E")
    parser.add_argument("--kernel", type=Path, required=True)
    parser.add_argument("--initrd", type=Path, required=True)
    parser.add_argument(
        "--append",
        default="init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7",
    )
    parser.add_argument("--title", default="Xbox HDD")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    if args.raw_image.suffix.lower() == ".qcow2":
        raise SystemExit("refusing to edit qcow2 directly; convert to a disposable raw image first")

    cfg = (
        f"title {args.title}\n"
        "kernel vmlinuz\n"
        "initrd initramf\n"
        f"append {args.append}\n"
    ).encode("ascii")

    files = {
        "linuxboot.cfg": cfg,
        "vmlinuz": args.kernel.read_bytes(),
        "initramf": args.initrd.read_bytes(),
    }

    with args.raw_image.open("r+b") as fp:
        part = open_partition(fp, args.raw_image, args.partition)
        for name, data in files.items():
            write_root_file(fp, part, name, data)
            print(f"wrote /{name}: {len(data)} bytes")

        print(f"\n{args.partition.upper()}: root directory:")
        for line in list_root(fp, part):
            print(line)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
