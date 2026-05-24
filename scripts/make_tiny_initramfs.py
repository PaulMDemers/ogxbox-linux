#!/usr/bin/env python3
"""Create minimal compressed newc initramfs variants."""

from pathlib import Path
import gzip
import lzma
import stat


ROOT = Path(__file__).resolve().parents[1]
INIT = ROOT / "build" / "tiny-init" / "init"
OUT_GZ = ROOT / "artifacts" / "initramfs" / "xbox-tiny-init.gz"
OUT_XZ = ROOT / "artifacts" / "initramfs" / "xbox-tiny-init.xz"
OUT_CPIO = ROOT / "artifacts" / "initramfs" / "xbox-tiny-init.cpio"


def align4(value):
    return (value + 3) & ~3


def pad4(buf):
    buf.extend(b"\0" * (align4(len(buf)) - len(buf)))


def header(name, mode, data=b"", rdevmajor=0, rdevminor=0, ino=1):
    namesize = len(name.encode("ascii")) + 1
    fields = [
        ino,
        mode,
        0,
        0,
        1,
        0,
        len(data),
        0,
        0,
        rdevmajor,
        rdevminor,
        namesize,
        0,
    ]
    return b"070701" + b"".join(f"{field:08x}".encode("ascii") for field in fields)


def add_entry(buf, name, mode, data=b"", rdevmajor=0, rdevminor=0, ino=1):
    buf.extend(header(name, mode, data, rdevmajor, rdevminor, ino))
    buf.extend(name.encode("ascii") + b"\0")
    pad4(buf)
    buf.extend(data)
    pad4(buf)


def main():
    init_data = INIT.read_bytes()
    OUT_GZ.parent.mkdir(parents=True, exist_ok=True)

    raw = bytearray()
    add_entry(raw, ".", stat.S_IFDIR | 0o755, ino=1)
    add_entry(raw, "dev", stat.S_IFDIR | 0o755, ino=2)
    add_entry(raw, "dev/console", stat.S_IFCHR | 0o600, rdevmajor=5, rdevminor=1, ino=3)
    add_entry(raw, "init", stat.S_IFREG | 0o755, init_data, ino=4)
    add_entry(raw, "TRAILER!!!", 0, ino=5)

    OUT_CPIO.write_bytes(raw)
    with open(OUT_GZ, "wb") as raw_dst:
        with gzip.GzipFile(fileobj=raw_dst, mode="wb", compresslevel=9, mtime=0) as gz:
            gz.write(raw)
    OUT_XZ.write_bytes(lzma.compress(bytes(raw), format=lzma.FORMAT_XZ, preset=9))
    print(OUT_CPIO)
    print(OUT_GZ)
    print(OUT_XZ)


if __name__ == "__main__":
    main()
