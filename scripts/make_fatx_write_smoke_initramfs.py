#!/usr/bin/env python3
"""Create a FATX existing-file write smoke-test initramfs."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "sources" / "xbox-linux-initramfs" / "initramfs-xbox"
OUT = ROOT / "artifacts" / "initramfs" / "xbox-fatx-write-smoke.cpio"

FATX_WRITE_INIT = b"""#!/bin/busybox sh
exec </dev/console >/dev/console 2>&1

/bin/busybox --install -s
/bin/busybox mount -t proc proc /proc 2>/dev/null
/bin/busybox mount -t sysfs sysfs /sys 2>/dev/null
/bin/busybox mount -t devtmpfs devtmpfs /dev 2>/dev/null

PAYLOAD_DISK=
E_PARTITION_OFFSET=2884108288
TEST_FILE=/fatxrw.bin
MARKER=FATX_WRITE_EXISTING_OK_20260525

for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        fatx_test_disk=*) PAYLOAD_DISK="${arg#fatx_test_disk=}" ;;
        fatx_test_e_offset=*) E_PARTITION_OFFSET="${arg#fatx_test_e_offset=}" ;;
        fatx_test_file=*) TEST_FILE="${arg#fatx_test_file=}" ;;
        fatx_test_marker=*) MARKER="${arg#fatx_test_marker=}" ;;
    esac
done

echo
echo "*** FATX existing-file write smoke test ***"
echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
echo "test file: $TEST_FILE"
echo "marker: $MARKER"
echo

if [ -z "$PAYLOAD_DISK" ]; then
    for dev in /dev/hda /dev/sda /dev/vda /dev/xvda; do
        if [ -b "$dev" ]; then
            PAYLOAD_DISK="$dev"
            break
        fi
    done
fi
[ -n "$PAYLOAD_DISK" ] || PAYLOAD_DISK=/dev/hda

/bin/busybox mknod /dev/loop0 b 7 0 2>/dev/null || true
/bin/busybox mkdir -p /mnt/xboxe

echo "losetup: $PAYLOAD_DISK offset $E_PARTITION_OFFSET"
if ! /bin/busybox losetup -o "$E_PARTITION_OFFSET" /dev/loop0 "$PAYLOAD_DISK" 2>/tmp/fatx-losetup.err; then
    echo "FATX losetup failed:"
    cat /tmp/fatx-losetup.err 2>/dev/null || true
    exec setsid cttyhack sh
fi

echo "mount rw"
if ! /bin/busybox mount -t fatx -o rw /dev/loop0 /mnt/xboxe 2>/tmp/fatx-mount-rw.err; then
    echo "FATX rw mount failed:"
    cat /tmp/fatx-mount-rw.err 2>/dev/null || true
    exec setsid cttyhack sh
fi

echo "root listing:"
/bin/busybox ls -la /mnt/xboxe 2>/dev/null || true
echo
echo "before:"
/bin/busybox dd if="/mnt/xboxe$TEST_FILE" bs=64 count=1 2>/dev/null | /bin/busybox hexdump -C || true
echo

/bin/busybox printf "%-64s" "$MARKER" | /bin/busybox dd of="/mnt/xboxe$TEST_FILE" bs=64 count=1 conv=notrunc
/bin/busybox sync

echo "create should fail:"
if echo "unexpected" > /mnt/xboxe/fatx-created-by-kernel.txt 2>/tmp/fatx-create.err; then
    echo "FATX_CREATE_UNEXPECTED_OK"
else
    echo "FATX_CREATE_REJECTED_OK"
    cat /tmp/fatx-create.err 2>/dev/null || true
fi
/bin/busybox sync

echo
echo "after:"
/bin/busybox dd if="/mnt/xboxe$TEST_FILE" bs=64 count=1 2>/dev/null | /bin/busybox hexdump -C || true

/bin/busybox umount /mnt/xboxe || true
/bin/busybox sync
echo
echo "remount ro verify"
if ! /bin/busybox mount -t fatx -o ro /dev/loop0 /mnt/xboxe 2>/tmp/fatx-mount-ro.err; then
    echo "FATX ro remount failed:"
    cat /tmp/fatx-mount-ro.err 2>/dev/null || true
    exec setsid cttyhack sh
fi

VERIFY="$(/bin/busybox dd if="/mnt/xboxe$TEST_FILE" bs=64 count=1 2>/dev/null)"
echo "verify: $VERIFY"
case "$VERIFY" in
    "$MARKER"*) echo "FATX_WRITE_EXISTING_OK" ;;
    *) echo "FATX_WRITE_EXISTING_FAILED" ;;
esac

echo
echo "Dropping to shell"
exec setsid cttyhack sh
"""


def align4(value):
    return (value + 3) & ~3


def pad4(buf):
    buf.extend(b"\0" * (align4(len(buf)) - len(buf)))


def header(name, mode, data=b"", rdevmajor=0, rdevminor=0, ino=1, nlink=1):
    namesize = len(name.encode("ascii")) + 1
    fields = [
        ino,
        mode,
        0,
        0,
        nlink,
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


def add_entry(buf, name, mode, data=b"", rdevmajor=0, rdevminor=0, ino=1, nlink=1):
    buf.extend(header(name, mode, data, rdevmajor, rdevminor, ino, nlink))
    buf.extend(name.encode("ascii") + b"\0")
    pad4(buf)
    buf.extend(data)
    pad4(buf)


def add_dir(buf, name, ino):
    add_entry(buf, name, 0o040755, ino=ino, nlink=2)


def add_file(buf, name, data, mode=0o100755, ino=1):
    add_entry(buf, name, mode, data=data, ino=ino)


def add_symlink(buf, name, target, ino):
    add_entry(buf, name, 0o120777, data=target.encode("ascii"), ino=ino)


def add_dev(buf, name, major, minor, mode, ino):
    add_entry(buf, name, mode, rdevmajor=major, rdevminor=minor, ino=ino)


def build():
    busybox = (SRC / "usr" / "bin" / "busybox").read_bytes()
    buf = bytearray()
    ino = 1
    for d in [".", "dev", "mnt", "mnt/xboxe", "proc", "sys", "tmp", "usr", "usr/bin"]:
        add_dir(buf, d, ino)
        ino += 1
    add_symlink(buf, "bin", "usr/bin", ino)
    ino += 1
    add_file(buf, "init", FATX_WRITE_INIT, ino=ino)
    ino += 1
    add_file(buf, "usr/bin/busybox", busybox, ino=ino)
    ino += 1
    add_dev(buf, "dev/console", 5, 1, 0o020600, ino)
    ino += 1
    add_dev(buf, "dev/null", 1, 3, 0o020666, ino)
    ino += 1
    add_entry(buf, "TRAILER!!!", 0, ino=ino)
    return bytes(buf)


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(build())
    print(OUT)


if __name__ == "__main__":
    main()
