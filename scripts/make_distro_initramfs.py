#!/usr/bin/env python3
"""Create a generic Xbox FATX-to-ext2 distro initramfs."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "sources" / "xbox-linux-initramfs" / "initramfs-xbox"
OUT = ROOT / "artifacts" / "initramfs" / "xbox-distro-hdd-ext2-stage1.cpio"

DISTRO_INIT = b"""#!/bin/busybox sh
exec </dev/console >/dev/console 2>&1

/bin/busybox --install -s
/bin/busybox mount -t proc proc /proc 2>/dev/null
/bin/busybox mount -t sysfs sysfs /sys 2>/dev/null
/bin/busybox mount -t devtmpfs devtmpfs /dev 2>/dev/null

PAYLOAD_FILE=/linuxroot.ext2
PAYLOAD_DISK=
ROOT_INIT=/xbox-init
ROOT_FSTYPE=ext2
FATX_MODE=ro
ROOT_MODE=ro
E_PARTITION_OFFSET=2884108288
CHROOT_PROOF=0
PAYLOAD_SOURCE=fatx
FATX_LOOP_READ_AHEAD_KB=
ROOT_LOOP_READ_AHEAD_KB=

for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        xbox_payload_file=*) PAYLOAD_FILE="${arg#xbox_payload_file=}" ;;
        xbox_payload_disk=*) PAYLOAD_DISK="${arg#xbox_payload_disk=}" ;;
        xbox_payload_source=iso) PAYLOAD_SOURCE=iso ;;
        xbox_payload_source=fatx) PAYLOAD_SOURCE=fatx ;;
        xbox_root_init=*) ROOT_INIT="${arg#xbox_root_init=}" ;;
        xbox_root_fstype=*) ROOT_FSTYPE="${arg#xbox_root_fstype=}" ;;
        xbox_fatx_mode=rw) FATX_MODE=rw ;;
        xbox_fatx_mode=ro) FATX_MODE=ro ;;
        xbox_root_mode=rw) ROOT_MODE=rw ;;
        xbox_root_mode=ro) ROOT_MODE=ro ;;
        xbox_fatx_e_offset=*) E_PARTITION_OFFSET="${arg#xbox_fatx_e_offset=}" ;;
        xbox_chroot_proof=1) CHROOT_PROOF=1 ;;
        xbox_fatx_loop_readahead_kb=*) FATX_LOOP_READ_AHEAD_KB="${arg#xbox_fatx_loop_readahead_kb=}" ;;
        xbox_loop_readahead_kb=*) ROOT_LOOP_READ_AHEAD_KB="${arg#xbox_loop_readahead_kb=}" ;;
    esac
done

echo
echo "*** Xbox distro stage1 FATX/ext2 loader ***"
echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
echo "payload: $PAYLOAD_FILE"
echo "root init: $ROOT_INIT"
echo "payload source: $PAYLOAD_SOURCE"
echo "fatx mode: $FATX_MODE"
echo "root mode: $ROOT_MODE"
echo

tune_readahead() {
    dev="$1"
    kb="$2"
    [ -n "$kb" ] || return 0
    case "$kb" in
        *[!0-9]*|"") return 0 ;;
    esac
    base="$(basename "$dev")"
    q="/sys/block/$base/queue/read_ahead_kb"
    if [ -w "$q" ]; then
        echo "$kb" > "$q" 2>/dev/null || true
        echo "read_ahead_kb $base=$kb"
    fi
}

ensure_block_node() {
    dev="$1"
    name="${dev#/dev/}"
    [ "$name" != "$dev" ] || return 1
    [ -b "$dev" ] && return 0
    majmin=
    if [ -r "/sys/block/$name/dev" ]; then
        majmin="$(cat "/sys/block/$name/dev" 2>/dev/null)"
    else
        case "$name" in
            hda) majmin="3:0" ;;
            hdb) majmin="3:64" ;;
            hdc) majmin="22:0" ;;
            hdd) majmin="22:64" ;;
            sr0|scd0) majmin="11:0" ;;
            sr1|scd1) majmin="11:1" ;;
        esac
    fi
    [ -n "$majmin" ] || return 1
    major="${majmin%:*}"
    minor="${majmin#*:}"
    case "$major:$minor" in
        *[!0-9:]*|:|*:|"") return 1 ;;
    esac
    /bin/busybox mknod "$dev" b "$major" "$minor" 2>/dev/null || true
    [ -b "$dev" ]
}

show_block_devices() {
    echo "block device inventory:"
    for sysdev in /sys/block/*; do
        [ -e "$sysdev" ] || continue
        name="$(basename "$sysdev")"
        majmin="$(cat "$sysdev/dev" 2>/dev/null)"
        removable="$(cat "$sysdev/removable" 2>/dev/null)"
        dtype="$(cat "$sysdev/device/type" 2>/dev/null)"
        echo "  $name dev=$majmin removable=$removable type=$dtype"
    done
    echo "proc partitions:"
    cat /proc/partitions 2>/dev/null || true
    if [ -r /proc/sys/dev/cdrom/info ]; then
        echo "cdrom info:"
        cat /proc/sys/dev/cdrom/info 2>/dev/null || true
    fi
}

try_mount_iso() {
    dev="$1"
    [ -n "$dev" ] || return 1
    ensure_block_node "$dev" || true
    [ -b "$dev" ] || [ -e "$dev" ] || return 1
    /bin/busybox umount /mnt/xboxe 2>/dev/null || true
    echo "Trying ISO payload source from $dev"
    if /bin/busybox mount -t iso9660 -o ro "$dev" /mnt/xboxe 2>/tmp/iso-mount.err; then
        if [ -f "/mnt/xboxe$PAYLOAD_FILE" ]; then
            PAYLOAD_DISK="$dev"
            return 0
        fi
        upper="$(echo "$PAYLOAD_FILE" | tr 'a-z' 'A-Z')"
        if [ -f "/mnt/xboxe$upper" ]; then
            PAYLOAD_DISK="$dev"
            return 0
        fi
        echo "ISO mounted from $dev but payload $PAYLOAD_FILE was not present"
        /bin/busybox umount /mnt/xboxe 2>/dev/null || true
    fi
    echo "  mount failed for $dev:"
    cat /tmp/iso-mount.err 2>/dev/null || true
    return 1
}

find_iso_payload_disk() {
    show_block_devices
    candidates="$PAYLOAD_DISK"

    for sysdev in /sys/block/*; do
        [ -e "$sysdev" ] || continue
        name="$(basename "$sysdev")"
        dtype="$(cat "$sysdev/device/type" 2>/dev/null)"
        removable="$(cat "$sysdev/removable" 2>/dev/null)"
        case "$name:$dtype:$removable" in
            hd*:5:*|sr*:5:*|scd*:5:*|*:5:*|sr*:*:*|scd*:*:*|hd[b-z]:*:*|*:1)
                candidates="$candidates /dev/$name"
                ;;
        esac
    done

    candidates="$candidates /dev/hdb /dev/hdc /dev/hdd /dev/sr0 /dev/sr1 /dev/scd0 /dev/scd1 /dev/cdrom /dev/dvd /dev/hda"
    tried=" "
    for dev in $candidates; do
        case "$tried" in
            *" $dev "*) continue ;;
        esac
        tried="$tried$dev "
        if try_mount_iso "$dev"; then
            echo "Mounted ISO payload source from $PAYLOAD_DISK"
            return 0
        fi
    done

    echo "ISO mount failed for all discovered candidates"
    cat /tmp/iso-mount.err 2>/dev/null || true
    echo "recent kernel messages:"
    dmesg | tail -80 2>/dev/null || true
    return 1
}

if [ "$PAYLOAD_SOURCE" = "iso" ]; then
    :
else
    if [ -z "$PAYLOAD_DISK" ]; then
        for dev in /dev/hda /dev/sda /dev/vda /dev/xvda; do
            if [ -b "$dev" ]; then
                PAYLOAD_DISK="$dev"
                break
            fi
        done
    fi
fi

if [ -z "$PAYLOAD_DISK" ] && [ "$PAYLOAD_SOURCE" != "iso" ]; then
    PAYLOAD_DISK=/dev/hda
fi

for i in 0 1; do
    /bin/busybox mknod "/dev/loop$i" b 7 "$i" 2>/dev/null || true
done

/bin/busybox mkdir -p /mnt/xboxe /mnt/root

if [ "$PAYLOAD_SOURCE" = "iso" ]; then
    if ! find_iso_payload_disk; then
        exec setsid cttyhack sh
    fi
else
    for i in 1 2 3 4 5; do
        [ -e "$PAYLOAD_DISK" ] && break
        /bin/busybox sleep 1
    done
    echo "Mounting Xbox E FATX from $PAYLOAD_DISK at offset $E_PARTITION_OFFSET"
    if ! /bin/busybox losetup -o "$E_PARTITION_OFFSET" /dev/loop0 "$PAYLOAD_DISK" 2>/tmp/fatx-losetup.err; then
        echo "FATX losetup failed:"
        cat /tmp/fatx-losetup.err 2>/dev/null || true
        exec setsid cttyhack sh
    fi
    tune_readahead /dev/loop0 "$FATX_LOOP_READ_AHEAD_KB"

    if ! /bin/busybox mount -t fatx -o "$FATX_MODE" /dev/loop0 /mnt/xboxe 2>/tmp/fatx-mount.err; then
        echo "FATX mount failed:"
        cat /tmp/fatx-mount.err 2>/dev/null || true
        exec setsid cttyhack sh
    fi
fi

echo "payload source root:"
ls -la /mnt/xboxe 2>/dev/null || true

ROOT_IMAGE="/mnt/xboxe$PAYLOAD_FILE"
if [ ! -f "$ROOT_IMAGE" ]; then
    upper="$(echo "$PAYLOAD_FILE" | tr 'a-z' 'A-Z')"
    [ -f "/mnt/xboxe$upper" ] && ROOT_IMAGE="/mnt/xboxe$upper"
fi

if ! /bin/busybox losetup /dev/loop1 "$ROOT_IMAGE" 2>/tmp/root-losetup.err; then
    echo "Root image losetup failed:"
    echo "tried: $ROOT_IMAGE"
    cat /tmp/root-losetup.err 2>/dev/null || true
    exec setsid cttyhack sh
fi
tune_readahead /dev/loop1 "$ROOT_LOOP_READ_AHEAD_KB"

if ! /bin/busybox mount -t "$ROOT_FSTYPE" -o "$ROOT_MODE" /dev/loop1 /mnt/root 2>/tmp/root-mount.err; then
    echo "Root image mount failed:"
    cat /tmp/root-mount.err 2>/dev/null || true
    exec setsid cttyhack sh
fi

echo "Mounted distro root:"
ls -la /mnt/root 2>/dev/null | head -30 || true

/bin/busybox mkdir -p /mnt/root/proc /mnt/root/sys /mnt/root/dev /mnt/root/run /mnt/root/tmp
if [ "$CHROOT_PROOF" = "1" ]; then
    /bin/busybox mount -t proc proc /mnt/root/proc 2>/dev/null || true
    /bin/busybox mount -t sysfs sysfs /mnt/root/sys 2>/dev/null || true
    /bin/busybox mount -t devtmpfs devtmpfs /mnt/root/dev 2>/dev/null || true
    echo "Entering distro root with chroot proof mode"
    /bin/busybox chroot /mnt/root "$ROOT_INIT"
    status=$?
    echo
    echo "chroot proof returned with status $status"
    echo "Dropping to initramfs shell"
    /bin/busybox sleep 20
    exec /bin/busybox sh
fi

/bin/busybox mount --move /proc /mnt/root/proc 2>/dev/null || /bin/busybox mount -t proc proc /mnt/root/proc 2>/dev/null || true
/bin/busybox mount --move /sys /mnt/root/sys 2>/dev/null || /bin/busybox mount -t sysfs sysfs /mnt/root/sys 2>/dev/null || true
/bin/busybox mount --move /dev /mnt/root/dev 2>/dev/null || /bin/busybox mount -t devtmpfs devtmpfs /mnt/root/dev 2>/dev/null || true

echo "Root init target:"
ls -l "/mnt/root$ROOT_INIT" 2>/dev/null || true
echo "Switching to distro root"
exec /bin/busybox switch_root /mnt/root "$ROOT_INIT"
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
    for d in [
        ".",
        "dev",
        "mnt",
        "mnt/root",
        "mnt/xboxe",
        "proc",
        "sys",
        "tmp",
        "sbin",
        "usr",
        "usr/bin",
        "usr/sbin",
    ]:
        add_dir(buf, d, ino)
        ino += 1
    add_symlink(buf, "bin", "usr/bin", ino)
    ino += 1
    add_file(buf, "init", DISTRO_INIT, ino=ino)
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
