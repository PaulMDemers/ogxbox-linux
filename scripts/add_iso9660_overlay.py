#!/usr/bin/env python3
"""Add a minimal ISO9660 view over files already stored in an XDVDFS image."""

from __future__ import annotations

import argparse
from pathlib import Path


SECTOR_SIZE = 2048


def both32(value: int) -> bytes:
    return value.to_bytes(4, "little") + value.to_bytes(4, "big")


def both16(value: int) -> bytes:
    return value.to_bytes(2, "little") + value.to_bytes(2, "big")


def volume_date() -> bytes:
    return b"2026053000000000\x00"


def dir_date() -> bytes:
    return bytes([126, 5, 30, 0, 0, 0, 0])


def directory_record(extent: int, size: int, name: bytes, flags: int = 0) -> bytes:
    record_len = 33 + len(name)
    if record_len & 1:
        record_len += 1
    record = bytearray(record_len)
    record[0] = record_len
    record[1] = 0
    record[2:10] = both32(extent)
    record[10:18] = both32(size)
    record[18:25] = dir_date()
    record[25] = flags
    record[26] = 0
    record[27] = 0
    record[28:32] = both16(1)
    record[32] = len(name)
    record[33 : 33 + len(name)] = name
    return bytes(record)


def path_table(dirs: list[dict]) -> tuple[bytes, bytes]:
    little = bytearray()
    big = bytearray()
    for directory in dirs:
        name = directory["iso_name"]
        parent_index = directory["parent_index"]
        sector = directory["sector"]

        entry = bytearray(8 + len(name))
        entry[0] = len(name)
        entry[1] = 0
        entry[2:6] = sector.to_bytes(4, "little")
        entry[6:8] = parent_index.to_bytes(2, "little")
        entry[8 : 8 + len(name)] = name
        little += entry
        if len(name) & 1:
            little += b"\0"

        entry = bytearray(8 + len(name))
        entry[0] = len(name)
        entry[1] = 0
        entry[2:6] = sector.to_bytes(4, "big")
        entry[6:8] = parent_index.to_bytes(2, "big")
        entry[8 : 8 + len(name)] = name
        big += entry
        if len(name) & 1:
            big += b"\0"
    return bytes(little), bytes(big)


def parse_extent(value: str) -> tuple[str, int, int]:
    name, rest = value.split("=", 1)
    sector_text, size_text = rest.split(":", 1)
    normalized = name.replace("\\", "/").strip("/").lower()
    return normalized, int(sector_text, 0), int(size_text, 0)


def iso_file_name(filename: str) -> bytes:
    stem = filename.upper()
    if "." not in stem:
        stem = f"{stem}."
    return f"{stem};1".encode("ascii")


def build_directory_sector(directory: dict, all_dirs: list[dict], total_sectors: int) -> bytes:
    entries = [
        directory_record(directory["sector"], SECTOR_SIZE, b"\x00", flags=2),
        directory_record(directory["parent_sector"], SECTOR_SIZE, b"\x01", flags=2),
    ]
    for child in sorted(directory["dirs"].values(), key=lambda d: d["iso_name"]):
        entries.append(directory_record(child["sector"], SECTOR_SIZE, child["iso_name"], flags=2))
    for name, sector, size in sorted(directory["files"], key=lambda item: item[0]):
        entries.append(directory_record(sector, size, iso_file_name(name), flags=0))

    root = bytearray(SECTOR_SIZE)
    cursor = 0
    for entry in entries:
        if cursor + len(entry) > SECTOR_SIZE:
            raise RuntimeError(f"directory {directory['path'] or '/'} does not fit in one ISO9660 sector")
        root[cursor : cursor + len(entry)] = entry
        cursor += len(entry)
    return bytes(root)


def build_directory_tree(root_sector: int, first_extra_dir_sector: int, extents: dict[str, tuple[int, int]]) -> list[dict]:
    root = {
        "path": "",
        "iso_name": b"\x00",
        "sector": root_sector,
        "parent_sector": root_sector,
        "parent_index": 1,
        "dirs": {},
        "files": [],
    }
    dirs_by_path = {"": root}

    for path, (sector, size) in sorted(extents.items()):
        parts = [part for part in path.split("/") if part]
        if not parts:
            continue
        current = root
        current_path = ""
        for directory_name in parts[:-1]:
            next_path = f"{current_path}/{directory_name}".strip("/")
            if next_path not in dirs_by_path:
                child = {
                    "path": next_path,
                    "iso_name": directory_name.upper().encode("ascii"),
                    "sector": 0,
                    "parent_sector": current["sector"],
                    "parent_index": 0,
                    "dirs": {},
                    "files": [],
                }
                dirs_by_path[next_path] = child
                current["dirs"][directory_name] = child
            current = dirs_by_path[next_path]
            current_path = next_path
        current["files"].append((parts[-1], sector, size))

    ordered = [root]
    for path in sorted(path for path in dirs_by_path if path):
        ordered.append(dirs_by_path[path])
    for index, directory in enumerate(ordered[1:], start=0):
        directory["sector"] = first_extra_dir_sector + index

    index_by_path = {directory["path"]: index + 1 for index, directory in enumerate(ordered)}
    sector_by_path = {directory["path"]: directory["sector"] for directory in ordered}
    for directory in ordered[1:]:
        parent_path = "/".join(directory["path"].split("/")[:-1])
        directory["parent_index"] = index_by_path[parent_path]
        directory["parent_sector"] = sector_by_path[parent_path]
    return ordered


def build_pvd(root_sector: int, path_l_sector: int, path_m_sector: int, total_sectors: int, path_table_size: int) -> bytes:
    pvd = bytearray(SECTOR_SIZE)
    pvd[0] = 1
    pvd[1:6] = b"CD001"
    pvd[6] = 1
    pvd[8:40] = b"XBOX LINUX".ljust(32)
    pvd[40:72] = b"XBOXLINUX".ljust(32)
    pvd[80:88] = both32(total_sectors)
    pvd[120:124] = both16(1)
    pvd[124:128] = both16(1)
    pvd[128:132] = both16(SECTOR_SIZE)
    pvd[132:140] = both32(path_table_size)
    pvd[140:144] = path_l_sector.to_bytes(4, "little")
    pvd[144:148] = (0).to_bytes(4, "little")
    pvd[148:152] = path_m_sector.to_bytes(4, "big")
    pvd[152:156] = (0).to_bytes(4, "big")
    root_record = directory_record(root_sector, SECTOR_SIZE, b"\x00", flags=2)
    pvd[156 : 156 + len(root_record)] = root_record
    pvd[881] = 1
    return bytes(pvd)


def build_terminator() -> bytes:
    sector = bytearray(SECTOR_SIZE)
    sector[0] = 255
    sector[1:6] = b"CD001"
    sector[6] = 1
    return bytes(sector)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("--root-sector", type=int, default=18)
    parser.add_argument("--path-l-sector", type=int, default=19)
    parser.add_argument("--path-m-sector", type=int, default=20)
    parser.add_argument("--first-dir-sector", type=int, default=21)
    parser.add_argument("--extent", action="append", default=[], help="name=sector:size")
    args = parser.parse_args()

    extents = {}
    for value in args.extent:
        name, sector, size = parse_extent(value)
        extents[name] = (sector, size)
    if "linuxboot.cfg" not in extents:
        raise SystemExit("linuxboot.cfg extent is required")

    total_sectors = args.image.stat().st_size // SECTOR_SIZE
    dirs = build_directory_tree(args.root_sector, args.first_dir_sector, extents)
    path_l, path_m = path_table(dirs)
    if len(path_l) > SECTOR_SIZE or len(path_m) > SECTOR_SIZE:
        raise RuntimeError("path table does not fit in one ISO9660 sector")
    pvd = build_pvd(args.root_sector, args.path_l_sector, args.path_m_sector, total_sectors, len(path_l))
    terminator = build_terminator()

    with args.image.open("r+b") as fp:
        for sector, data in (
            (16, pvd),
            (17, terminator),
            (args.path_l_sector, path_l.ljust(SECTOR_SIZE, b"\0")),
            (args.path_m_sector, path_m.ljust(SECTOR_SIZE, b"\0")),
        ):
            fp.seek(sector * SECTOR_SIZE)
            fp.write(data)
        for directory in dirs:
            fp.seek(directory["sector"] * SECTOR_SIZE)
            fp.write(build_directory_sector(directory, dirs, total_sectors))

    print(f"overlayed ISO9660 view with {len(extents)} files on {args.image}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
