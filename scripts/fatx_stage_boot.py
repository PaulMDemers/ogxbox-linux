#!/usr/bin/env python3
"""Stage a Cromwell Linux boot set into the Xbox HDD FATX E partition."""

from __future__ import annotations

import argparse
import hashlib
import json
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
ATTR_DIRECTORY = 0x10
FREE_CLUSTER = 0x00000000
END_OF_CHAIN = 0xFFFFFFFF
KNOWN_BOOT_ROOT_FILES = (
    "linuxboot.cfg",
    "vmlinuz",
    "initramf",
    "devkrnl",
    "devinit",
    "devuan.ext2",
    "xkrnl",
    "xinit",
    "xdevuan.ext2",
    "pluskrnl",
    "plusinit",
    "plusdevuan.ext2",
    "plkrnl",
    "plinit",
    "pldevuan.ext2",
    "tfkrnl",
    "tfinit",
    "tfdevuan.ext2",
    "rakrnl",
    "rainit",
    "rdevuan.ext2",
    "ndkrnl",
    "ndinit",
    "nddevuan.ext2",
    "rwkrnl",
    "rwinit",
    "rwdebian.ext2",
    "pskrnl",
    "psinit",
    "psdebian.ext2",
)


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


@dataclass
class FatxWriteResult:
    name: str
    size: int
    start_cluster: int
    cluster_count: int
    disk_offset: int
    contiguous: bool
    sha256: str
    readback_sha256: str
    first_sector: int
    last_sector: int
    chain_sample: list[int]


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


def end_of_chain_value(part: FatxPartition) -> int:
    return 0xFFFFFFFF if part.entry_size == 4 else 0xFFFF


def read_cluster(fp, part: FatxPartition, cluster_id: int) -> bytes:
    return read_at(fp, part.cluster_offset(cluster_id), part.cluster_size)


def write_cluster(fp, part: FatxPartition, cluster_id: int, data: bytes) -> None:
    if len(data) > part.cluster_size:
        raise ValueError("cluster write is too large")
    write_at(fp, part.cluster_offset(cluster_id), data.ljust(part.cluster_size, b"\0"))


def root_entries(fp, part: FatxPartition) -> list[tuple[int, bytearray]]:
    return directory_entries(fp, part, ROOT_CLUSTER)


def directory_entries(fp, part: FatxPartition, directory_cluster: int) -> list[tuple[int, bytearray]]:
    root = bytearray(read_cluster(fp, part, directory_cluster))
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


def cluster_chain(fp, part: FatxPartition, start_cluster: int) -> list[int]:
    chain: list[int] = []
    cluster_id = start_cluster
    seen: set[int] = set()
    while cluster_id not in seen and 1 <= cluster_id < part.cluster_count:
        seen.add(cluster_id)
        chain.append(cluster_id)
        next_cluster = read_fat_entry(fp, part, cluster_id)
        if next_cluster in (0xFFFFFFFF, 0xFFFFFFF8, 0xFFFF, 0xFFF8, 0):
            break
        cluster_id = next_cluster
    return chain


def remove_root_file(fp, part: FatxPartition, name: str) -> None:
    remove_directory_entry(fp, part, ROOT_CLUSTER, name)


def clean_known_boot_files(fp, part: FatxPartition) -> None:
    for name in KNOWN_BOOT_ROOT_FILES:
        remove_root_file(fp, part, name)


def remove_directory_entry(fp, part: FatxPartition, directory_cluster: int, name: str) -> None:
    root = bytearray(read_cluster(fp, part, directory_cluster))
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
    write_cluster(fp, part, directory_cluster, root)


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


def allocate_contiguous_clusters(fp, part: FatxPartition, count: int) -> list[int]:
    run_start: int | None = None
    run_length = 0

    for cluster_id in range(2, part.cluster_count):
        if read_fat_entry(fp, part, cluster_id) == FREE_CLUSTER:
            if run_start is None:
                run_start = cluster_id
                run_length = 1
            else:
                run_length += 1
            if run_length == count:
                clusters = list(range(run_start, run_start + count))
                for index, allocated_cluster in enumerate(clusters):
                    next_value = clusters[index + 1] if index + 1 < len(clusters) else END_OF_CHAIN
                    write_fat_entry(fp, part, allocated_cluster, next_value)
                return clusters
        else:
            run_start = None
            run_length = 0

    raise RuntimeError(f"not enough contiguous free FATX clusters: need {count}")


def allocate_fragmented_clusters(fp, part: FatxPartition, count: int, stride: int = 2) -> list[int]:
    free_clusters: list[int] = []
    for cluster_id in range(2, part.cluster_count):
        if read_fat_entry(fp, part, cluster_id) == FREE_CLUSTER:
            free_clusters.append(cluster_id)

    if len(free_clusters) < count:
        raise RuntimeError(f"not enough free FATX clusters: need {count}, got {len(free_clusters)}")

    clusters: list[int] = []
    cursor = 0
    while len(clusters) < count and cursor < len(free_clusters):
        clusters.append(free_clusters[cursor])
        cursor += max(2, stride)

    if len(clusters) < count:
        used = set(clusters)
        for cluster_id in free_clusters:
            if cluster_id not in used:
                clusters.append(cluster_id)
                if len(clusters) == count:
                    break

    if len(clusters) != count:
        raise RuntimeError(f"not enough fragmented free FATX clusters: need {count}, got {len(clusters)}")

    for index, cluster_id in enumerate(clusters):
        next_value = clusters[index + 1] if index + 1 < len(clusters) else end_of_chain_value(part)
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


def split_fatx_path(path: str) -> list[str]:
    parts = [part for part in path.replace("\\", "/").split("/") if part]
    if not parts:
        raise ValueError("empty FATX path")
    for part in parts:
        encoded = part.encode("ascii")
        if not encoded or len(encoded) > 42:
            raise ValueError(f"FATX filename must be 1-42 ASCII bytes: {part!r}")
    return parts


def find_entry(fp, part: FatxPartition, directory_cluster: int, name: str) -> bytearray | None:
    target = name.lower()
    for _, entry in directory_entries(fp, part, directory_cluster):
        entry_name = decode_name(entry)
        if entry_name and entry_name.lower() == target:
            return entry
    return None


def add_directory_entry(
    fp,
    part: FatxPartition,
    directory_cluster: int,
    name: str,
    flags: int,
    start_cluster: int,
    size: int,
) -> None:
    encoded = name.encode("ascii")
    root = bytearray(read_cluster(fp, part, directory_cluster))
    slot = find_root_slot(root)
    entry = bytearray(DIRECTORY_ENTRY_SIZE)
    entry[0] = len(encoded)
    entry[1] = flags
    entry[2 : 2 + len(encoded)] = encoded
    struct.pack_into("<I", entry, 0x2C, start_cluster)
    struct.pack_into("<I", entry, 0x30, size)
    root[slot : slot + DIRECTORY_ENTRY_SIZE] = entry

    next_slot = slot + DIRECTORY_ENTRY_SIZE
    if next_slot < len(root) and root[next_slot] == 0x00:
        root[next_slot] = 0xFF
    write_cluster(fp, part, directory_cluster, root)


def ensure_directory(fp, part: FatxPartition, parent_cluster: int, name: str) -> int:
    entry = find_entry(fp, part, parent_cluster, name)
    if entry is not None:
        if not (entry[1] & ATTR_DIRECTORY):
            raise RuntimeError(f"{name!r} exists and is not a directory")
        return struct.unpack_from("<I", entry, 0x2C)[0]

    cluster = allocate_clusters(fp, part, 1)[0]
    write_cluster(fp, part, cluster, b"")
    add_directory_entry(fp, part, parent_cluster, name, ATTR_DIRECTORY, cluster, 0)
    return cluster


def resolve_parent_directory(fp, part: FatxPartition, path: str) -> tuple[int, str]:
    parts = split_fatx_path(path)
    directory_cluster = ROOT_CLUSTER
    for name in parts[:-1]:
        directory_cluster = ensure_directory(fp, part, directory_cluster, name)
    return directory_cluster, parts[-1]


def read_path_file(fp, part: FatxPartition, path: str) -> bytes:
    parts = split_fatx_path(path)
    directory_cluster = ROOT_CLUSTER
    entry: bytearray | None = None
    for name in parts:
        entry = find_entry(fp, part, directory_cluster, name)
        if entry is None:
            raise FileNotFoundError(path)
        if name != parts[-1]:
            if not (entry[1] & ATTR_DIRECTORY):
                raise RuntimeError(f"{name!r} exists and is not a directory")
            directory_cluster = struct.unpack_from("<I", entry, 0x2C)[0]

    if entry is None or (entry[1] & ATTR_DIRECTORY):
        raise FileNotFoundError(path)

    start_cluster = struct.unpack_from("<I", entry, 0x2C)[0]
    size = struct.unpack_from("<I", entry, 0x30)[0]
    remaining = size
    data = bytearray()
    for cluster_id in cluster_chain(fp, part, start_cluster):
        chunk = read_cluster(fp, part, cluster_id)
        take = min(remaining, len(chunk))
        data.extend(chunk[:take])
        remaining -= take
        if remaining == 0:
            break
    if remaining:
        raise EOFError(f"FATX chain for {path} ended with {remaining} bytes left")
    return bytes(data)


def write_root_file(fp, part: FatxPartition, name: str, data: bytes, *, layout: str = "normal") -> FatxWriteResult:
    return write_path_file(fp, part, name, data, layout=layout)


def write_path_file(fp, part: FatxPartition, path: str, data: bytes, *, layout: str = "normal") -> FatxWriteResult:
    directory_cluster, name = resolve_parent_directory(fp, part, path)
    remove_directory_entry(fp, part, directory_cluster, name)
    cluster_count = max(1, math.ceil(len(data) / part.cluster_size))
    if layout == "contiguous":
        clusters = allocate_contiguous_clusters(fp, part, cluster_count)
    elif layout == "fragmented":
        clusters = allocate_fragmented_clusters(fp, part, cluster_count)
    else:
        clusters = allocate_clusters(fp, part, cluster_count)
    for index, cluster_id in enumerate(clusters):
        chunk = data[index * part.cluster_size : (index + 1) * part.cluster_size]
        write_cluster(fp, part, cluster_id, chunk)

    add_directory_entry(fp, part, directory_cluster, name, ATTR_ARCHIVE, clusters[0], len(data))
    readback = read_path_file(fp, part, path)
    source_sha256 = hashlib.sha256(data).hexdigest()
    readback_sha256 = hashlib.sha256(readback).hexdigest()
    if source_sha256 != readback_sha256:
        raise RuntimeError(
            f"FATX readback mismatch for {path}: "
            f"source={source_sha256} readback={readback_sha256}"
        )
    first_sector = part.cluster_offset(clusters[0]) // 512
    last_sector = (part.cluster_offset(clusters[-1]) + part.cluster_size - 1) // 512
    return FatxWriteResult(
        name=path,
        size=len(data),
        start_cluster=clusters[0],
        cluster_count=len(clusters),
        disk_offset=part.cluster_offset(clusters[0]),
        contiguous=all(clusters[index] + 1 == clusters[index + 1] for index in range(len(clusters) - 1)),
        sha256=source_sha256,
        readback_sha256=readback_sha256,
        first_sector=first_sector,
        last_sector=last_sector,
        chain_sample=clusters[:64],
    )


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
    parser.add_argument("--kernel-name", default="vmlinuz")
    parser.add_argument("--initrd", type=Path)
    parser.add_argument("--initrd-name", default="initramf")
    parser.add_argument(
        "--append",
        default="init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7",
    )
    parser.add_argument("--title", default="Xbox HDD")
    parser.add_argument("--payload", type=Path)
    parser.add_argument("--payload-name", default="linuxroot.ext2")
    parser.add_argument("--append-payload-info", action="store_true")
    parser.add_argument(
        "--stage-order",
        choices=("payload-first", "boot-first"),
        default="payload-first",
        help="write payload before boot files (legacy) or pin boot files before payload",
    )
    parser.add_argument(
        "--boot-layout",
        choices=("normal", "contiguous", "fragmented"),
        default="normal",
        help="cluster allocation layout for linuxboot.cfg, kernel, and initrd",
    )
    parser.add_argument(
        "--payload-layout",
        choices=("normal", "contiguous", "fragmented"),
        default="contiguous",
        help="cluster allocation layout for the optional payload file",
    )
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--clean-known-boot", action="store_true")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    if args.raw_image.suffix.lower() == ".qcow2":
        raise SystemExit("refusing to edit qcow2 directly; convert to a disposable raw image first")
    if args.stage_order == "boot-first" and args.append_payload_info:
        raise SystemExit("--stage-order boot-first cannot be combined with --append-payload-info")

    with args.raw_image.open("r+b") as fp:
        part = open_partition(fp, args.raw_image, args.partition)
        append = args.append
        manifest = {
            "raw_image": str(args.raw_image),
            "partition": args.partition.upper(),
            "cluster_size": part.cluster_size,
            "cluster_count": part.cluster_count,
            "entry_size": part.entry_size,
            "fat_size": part.fat_size,
            "cluster1_offset": part.cluster1_offset,
            "boot_layout": args.boot_layout,
            "payload_layout": args.payload_layout,
            "stage_order": args.stage_order,
            "files": [],
        }

        if args.clean_known_boot:
            clean_known_boot_files(fp, part)
            print("cleaned known root-level Linux boot files")

        def stage_payload() -> FatxWriteResult | None:
            if not args.payload:
                return None
            payload_result = write_root_file(fp, part, args.payload_name, args.payload.read_bytes(), layout=args.payload_layout)
            if args.payload_layout == "contiguous" and not payload_result.contiguous:
                raise RuntimeError(f"/{args.payload_name} was not allocated contiguously")
            manifest["files"].append(payload_result.__dict__)
            print(
                f"wrote /{args.payload_name}: {payload_result.size} bytes "
                f"cluster={payload_result.start_cluster} clusters={payload_result.cluster_count} "
                f"offset={payload_result.disk_offset} contiguous={payload_result.contiguous}"
            )
            return payload_result

        def stage_boot(boot_append: str) -> None:
            initrd_line = "initrd no\n"
            if args.initrd:
                initrd_line = f"initrd {args.initrd_name}\n"

            cfg = (
                f"title {args.title}\n"
                f"kernel {args.kernel_name}\n"
                f"{initrd_line}"
                f"append {boot_append}\n"
            ).encode("ascii")
            files = {
                "linuxboot.cfg": cfg,
                args.kernel_name: args.kernel.read_bytes(),
            }
            if args.initrd:
                files[args.initrd_name] = args.initrd.read_bytes()

            for name, data in files.items():
                result = write_root_file(fp, part, name, data, layout=args.boot_layout)
                manifest["files"].append(result.__dict__)
                print(
                    f"wrote /{name}: {result.size} bytes "
                    f"cluster={result.start_cluster} clusters={result.cluster_count} "
                    f"contiguous={result.contiguous} sha256={result.sha256[:16]}"
                )

        if args.stage_order == "boot-first":
            stage_boot(append)
            stage_payload()
        else:
            payload_result = stage_payload()
            if payload_result is not None and args.append_payload_info:
                append = (
                    f"{append} tc_payload_offset={payload_result.disk_offset} "
                    f"tc_payload_size={payload_result.size} tc_payload_file=/{args.payload_name}"
                )
            stage_boot(append)

        print(f"\n{args.partition.upper()}: root directory:")
        for line in list_root(fp, part):
            print(line)

        if args.manifest:
            args.manifest.parent.mkdir(parents=True, exist_ok=True)
            args.manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
            print(f"\nmanifest={args.manifest}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
