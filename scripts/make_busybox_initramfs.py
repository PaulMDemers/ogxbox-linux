#!/usr/bin/env python3
"""Create a small raw newc initramfs with static i386 BusyBox."""

from pathlib import Path
import argparse
import stat


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "sources" / "xbox-linux-initramfs" / "initramfs-xbox"
OUT = ROOT / "artifacts" / "initramfs" / "xbox-busybox-raw.cpio"
OUT_CONSOLE = ROOT / "artifacts" / "initramfs" / "xbox-busybox-console.cpio"
OUT_STAGE2 = ROOT / "artifacts" / "initramfs" / "xbox-busybox-stage2.cpio"
OUT_REBOOT_PROBE = ROOT / "artifacts" / "initramfs" / "xbox-busybox-reboot-probe.cpio"
OUT_VISUAL_PROBE = ROOT / "artifacts" / "initramfs" / "xbox-busybox-visual-probe.cpio"
OUT_TINYCORE_STAGE3 = ROOT / "artifacts" / "initramfs" / "xbox-tinycore-stage3.cpio"
OUT_TINYCORE_STAGE4 = ROOT / "artifacts" / "initramfs" / "xbox-tinycore-stage4.cpio"
OUT_TINYCORE_STAGE5 = ROOT / "artifacts" / "initramfs" / "xbox-tinycore-stage5-desktop-probe.cpio"
OUT_TINYCORE_STAGE6 = ROOT / "artifacts" / "initramfs" / "xbox-tinycore-stage6-xfbdev-desktop.cpio"
OUT_TINYCORE_HDD_STAGE6 = ROOT / "artifacts" / "initramfs" / "xbox-tinycore-hdd-stage6-xfbdev-desktop.cpio"
OUT_TINYCORE_HDD_STAGE6_GAME = ROOT / "artifacts" / "initramfs" / "xbox-tinycore-hdd-stage6-xfbdev-desktop-game.cpio"
OUT_TINYCORE_HDD_EXT2_STAGE7 = ROOT / "artifacts" / "initramfs" / "xbox-tinycore-hdd-ext2-stage7-xfbdev-desktop.cpio"

CONSOLE_INIT = b"""#!/bin/busybox sh
exec </dev/console >/dev/console 2>&1

/bin/busybox --install -s
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null

echo
echo "*** Xbox BusyBox initramfs reached userspace via Cromwell ISO ***"
echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
echo "busybox: $(/bin/busybox 2>/dev/null | head -1)"
echo
echo "Mounted filesystems:"
mount
echo
echo "Launching /bin/sh on /dev/console"
echo

exec setsid cttyhack sh
"""

STAGE2_INIT = b"""#!/bin/busybox sh
exec </dev/console >/dev/console 2>&1

/bin/busybox --install -s
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null

echo
echo "*** Xbox BusyBox stage2 storage probe via Cromwell ISO ***"
echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
echo "busybox: $(/bin/busybox 2>/dev/null | head -1)"
echo
echo "Mounted filesystems:"
mount
echo
echo "/proc/partitions:"
cat /proc/partitions 2>/dev/null || true
echo
echo "/sys/block:"
ls -la /sys/block 2>/dev/null || true
echo
echo "/dev storage candidates:"
ls -la /dev/hd* /dev/sd* /dev/sr* /dev/cdrom /dev/dvd 2>/dev/null || true
echo
echo "Recent storage/kernel messages:"
dmesg 2>/dev/null | grep -E "hda|hdb|hdc|sr0|cdrom|DVD|ISO|FATX|QEMU|ata|ATAPI|SCSI|block" | tail -40 || true
echo
mkdir -p /mnt/cd
echo "CD mount attempts:"
for dev in /dev/hdb /dev/hdc /dev/sr0 /dev/cdrom /dev/dvd; do
    if [ -e "$dev" ]; then
        echo "Trying $dev -> /mnt/cd"
        if mount -t iso9660 -o ro "$dev" /mnt/cd 2>/dev/null; then
            echo "Mounted $dev on /mnt/cd"
            ls -la /mnt/cd 2>/dev/null || true
            break
        fi
    fi
done
echo
echo "Launching /bin/sh on /dev/console"
echo

exec setsid cttyhack sh
"""

REBOOT_PROBE_INIT = b"""#!/bin/busybox sh
exec </dev/console >/dev/console 2>&1

/bin/busybox --install -s
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null

echo
echo "*** Xbox BusyBox reboot probe reached userspace ***"
echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
echo "uname: $(uname -a 2>/dev/null)"
echo
sync
sleep 8
reboot -f
sleep 5
echo b >/proc/sysrq-trigger 2>/dev/null
while true; do sleep 60; done
"""

VISUAL_PROBE_INIT = b"""#!/bin/busybox sh
exec </dev/console >/dev/console 2>&1

/bin/busybox --install -s
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null
mknod /dev/fb0 c 29 0 2>/dev/null || true
mknod /dev/mem c 1 1 2>/dev/null || true

echo
echo "*** Xbox BusyBox visual framebuffer probe reached userspace ***"
echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
echo "uname: $(uname -a 2>/dev/null)"
echo "fb devices:"
cat /proc/fb 2>/dev/null || true
cat /sys/class/graphics/fb0/name /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null || true
echo

echo "Painting /dev/fb0 and framebuffer memory windows"
dd if=/fbmark.raw of=/dev/fb0 bs=4096 count=300 conv=notrunc 2>/tmp/fb0-dd.log || true
cat /tmp/fb0-dd.log 2>/dev/null || true
dd if=/fbmark.raw of=/dev/mem bs=4096 seek=15360 count=300 conv=notrunc 2>/tmp/mem-low-dd.log || true
cat /tmp/mem-low-dd.log 2>/dev/null || true
dd if=/fbmark.raw of=/dev/mem bs=4096 seek=998400 count=300 conv=notrunc 2>/tmp/mem-high-dd.log || true
cat /tmp/mem-high-dd.log 2>/dev/null || true

echo "Visual probe complete; holding."
while true; do sleep 60; done
"""

TINYCORE_STAGE3_INIT = b"""#!/bin/busybox sh
exec </dev/console >/dev/console 2>&1

/bin/busybox --install -s
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null

echo
echo "*** Xbox Tiny Core stage3 payload probe via Cromwell ISO ***"
echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
echo "busybox: $(/bin/busybox 2>/dev/null | head -1)"
echo
mkdir -p /mnt/cd /tmp/tinycore
for dev in /dev/hdb /dev/hdc /dev/sr0 /dev/cdrom /dev/dvd; do
    if [ -e "$dev" ]; then
        echo "Trying CD mount: $dev"
        if mount -t iso9660 -o ro "$dev" /mnt/cd 2>/dev/null; then
            echo "Mounted $dev on /mnt/cd"
            break
        fi
    fi
done

echo
echo "/mnt/cd:"
ls -la /mnt/cd 2>/dev/null || true
echo
if [ -f /mnt/cd/core.gz ]; then
    echo "Tiny Core core.gz found:"
    ls -l /mnt/cd/core.gz
    echo
    echo "gzip test:"
    gzip -t /mnt/cd/core.gz && echo "core.gz gzip OK" || echo "core.gz gzip FAILED"
    echo
    echo "core.gz archive preview:"
    zcat /mnt/cd/core.gz | cpio -t 2>/dev/null | head -40
    echo
    echo "Extracting Tiny Core marker files:"
    cd /tmp/tinycore
    zcat /mnt/cd/core.gz | cpio -idm './etc/os-release' './etc/tc-release' './usr/share/doc/tc/release.txt' 2>/dev/null || true
    find /tmp/tinycore -type f -maxdepth 5 -print -exec cat {} \\; 2>/dev/null || true
else
    echo "Tiny Core core.gz was not found on /mnt/cd"
fi

echo
echo "Launching /bin/sh on /dev/console"
echo

exec setsid cttyhack sh
"""

TINYCORE_STAGE4_INIT = b"""#!/bin/busybox sh
exec </dev/console >/dev/console 2>&1

/bin/busybox --install -s
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null

echo
echo "*** Xbox Tiny Core stage4 chroot probe via Cromwell ISO ***"
echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
echo "busybox: $(/bin/busybox 2>/dev/null | head -1)"
echo

mkdir -p /mnt/cd /mnt/tcroot
for dev in /dev/hdb /dev/hdc /dev/sr0 /dev/cdrom /dev/dvd; do
    if [ -e "$dev" ]; then
        echo "Trying CD mount: $dev"
        if mount -t iso9660 -o ro "$dev" /mnt/cd 2>/dev/null; then
            echo "Mounted $dev on /mnt/cd"
            break
        fi
    fi
done

if [ ! -f /mnt/cd/core.gz ]; then
    echo "Tiny Core core.gz was not found on /mnt/cd"
    exec setsid cttyhack sh
fi

echo
echo "Extracting /mnt/cd/core.gz to /mnt/tcroot"
cd /mnt/tcroot
if zcat /mnt/cd/core.gz | cpio -idm 2>/tmp/tc-cpio.err; then
    echo "Tiny Core extraction completed"
else
    echo "Tiny Core extraction failed"
    cat /tmp/tc-cpio.err 2>/dev/null || true
    exec setsid cttyhack sh
fi

mkdir -p /mnt/tcroot/proc /mnt/tcroot/sys /mnt/tcroot/dev /mnt/tcroot/dev/pts /mnt/tcroot/tmp /mnt/tcroot/mnt/cd
mount -t proc proc /mnt/tcroot/proc 2>/dev/null || true
mount -t sysfs sysfs /mnt/tcroot/sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /mnt/tcroot/dev 2>/dev/null || true
mkdir -p /mnt/tcroot/dev/pts
mount -t devpts devpts /mnt/tcroot/dev/pts 2>/dev/null || true
mount -t tmpfs tmpfs /mnt/tcroot/tmp 2>/dev/null || true
mount --bind /mnt/cd /mnt/tcroot/mnt/cd 2>/dev/null || true

echo
echo "Tiny Core root preview:"
ls -la /mnt/tcroot | head -40
echo
echo "Tiny Core release files:"
cat /mnt/tcroot/etc/os-release 2>/dev/null || true
cat /mnt/tcroot/etc/tc-release 2>/dev/null || true
cat /mnt/tcroot/usr/share/doc/tc/release.txt 2>/dev/null || true
echo
echo "Running proof commands inside chroot:"
chroot /mnt/tcroot /bin/sh -c 'echo CHROOT_OK; uname -a; busybox | head -1; pwd; ls -la / | head -30' 2>&1
rc=$?
echo "chroot proof exit code: $rc"
echo

if [ "$rc" = "0" ]; then
    echo "Launching Tiny Core /bin/sh chroot on /dev/console"
    exec chroot /mnt/tcroot /bin/sh
fi

echo "Falling back to initramfs /bin/sh"
exec setsid cttyhack sh
"""

TINYCORE_STAGE5_INIT = b"""#!/bin/busybox sh
exec </dev/console >/dev/console 2>&1

/bin/busybox --install -s
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null

echo
echo "*** Xbox Tiny Core stage5 desktop prerequisite probe ***"
echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
echo "busybox: $(/bin/busybox 2>/dev/null | head -1)"
echo

mkdir -p /mnt/cd /mnt/tcroot
for dev in /dev/hdb /dev/hdc /dev/sr0 /dev/cdrom /dev/dvd; do
    if [ -e "$dev" ]; then
        echo "Trying CD mount: $dev"
        if mount -t iso9660 -o ro "$dev" /mnt/cd 2>/dev/null; then
            echo "Mounted $dev on /mnt/cd"
            break
        fi
    fi
done

if [ ! -f /mnt/cd/core.gz ]; then
    echo "Tiny Core core.gz was not found on /mnt/cd"
    exec setsid cttyhack sh
fi

echo
echo "Extracting /mnt/cd/core.gz to /mnt/tcroot"
cd /mnt/tcroot
if zcat /mnt/cd/core.gz | cpio -idm 2>/tmp/tc-cpio.err; then
    echo "Tiny Core extraction completed"
else
    echo "Tiny Core extraction failed"
    cat /tmp/tc-cpio.err 2>/dev/null || true
    exec setsid cttyhack sh
fi

mkdir -p /mnt/tcroot/proc /mnt/tcroot/sys /mnt/tcroot/dev /mnt/tcroot/tmp /mnt/tcroot/mnt/cd
mount -t proc proc /mnt/tcroot/proc 2>/dev/null || true
mount -t sysfs sysfs /mnt/tcroot/sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /mnt/tcroot/dev 2>/dev/null || true
mount -t tmpfs tmpfs /mnt/tcroot/tmp 2>/dev/null || true
mount --bind /mnt/cd /mnt/tcroot/mnt/cd 2>/dev/null || true

echo
echo "Framebuffer devices:"
ls -la /dev/fb* /dev/fb/* 2>/dev/null || true
echo
echo "/proc/fb:"
cat /proc/fb 2>/dev/null || true
echo
echo "Graphics sysfs:"
ls -la /sys/class/graphics 2>/dev/null || true
for fb in /sys/class/graphics/fb*; do
    if [ -e "$fb" ]; then
        echo
        echo "$fb:"
        for attr in name modes mode virtual_size bits_per_pixel blank stride; do
            if [ -e "$fb/$attr" ]; then
                printf "  %s: " "$attr"
                cat "$fb/$attr" 2>/dev/null || true
            fi
        done
    fi
done

echo
echo "Input devices:"
ls -la /dev/input /dev/input/* 2>/dev/null || true
echo
echo "/proc/bus/input/devices:"
cat /proc/bus/input/devices 2>/dev/null || true
echo
echo "Tiny Core chroot can see devices:"
chroot /mnt/tcroot /bin/sh -c 'echo CHROOT_OK; uname -a; ls -la /dev/fb* /dev/input /dev/input/* 2>/dev/null || true' 2>&1
echo
echo "Relevant kernel messages:"
dmesg 2>/dev/null | grep -Ei "fb|frame|vesa|xbox|nv|input|hid|keyboard|mouse|tablet|usb" | tail -90 || true
echo
echo "Launching initramfs /bin/sh on /dev/console"

exec setsid cttyhack sh
"""

TINYCORE_STAGE6_INIT = b"""#!/bin/busybox sh
exec </dev/console >/dev/console 2>&1

/bin/busybox --install -s
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null

echo
echo "*** Xbox Tiny Core stage6 Xfbdev desktop attempt ***"
echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
echo "busybox: $(/bin/busybox 2>/dev/null | head -1)"
echo

mkdir -p /mnt/cd /mnt/tcroot
for dev in /dev/hdb /dev/hdc /dev/sr0 /dev/cdrom /dev/dvd; do
    if [ -e "$dev" ]; then
        echo "Trying CD mount: $dev"
        if mount -t iso9660 -o ro "$dev" /mnt/cd 2>/dev/null; then
            echo "Mounted $dev on /mnt/cd"
            break
        fi
    fi
done

if [ ! -f /mnt/cd/core.gz ]; then
    echo "Tiny Core core.gz was not found on /mnt/cd"
    exec setsid cttyhack sh
fi

echo
echo "Extracting /mnt/cd/core.gz to /mnt/tcroot"
cd /mnt/tcroot
if zcat /mnt/cd/core.gz | cpio -idm 2>/tmp/tc-cpio.err; then
    echo "Tiny Core extraction completed"
else
    echo "Tiny Core extraction failed"
    cat /tmp/tc-cpio.err 2>/dev/null || true
    exec setsid cttyhack sh
fi

mkdir -p /mnt/tcroot/proc /mnt/tcroot/sys /mnt/tcroot/dev /mnt/tcroot/tmp /mnt/tcroot/mnt/cd
mount -t proc proc /mnt/tcroot/proc 2>/dev/null || true
mount -t sysfs sysfs /mnt/tcroot/sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /mnt/tcroot/dev 2>/dev/null || true
mount -t tmpfs tmpfs /mnt/tcroot/tmp 2>/dev/null || true
mount --bind /mnt/cd /mnt/tcroot/mnt/cd 2>/dev/null || true

echo
echo "Framebuffer:"
cat /proc/fb 2>/dev/null || true
cat /sys/class/graphics/fb0/name /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null || true
echo
echo "Installing Tiny Core desktop extensions from /mnt/cd/tcz"
mkdir -p /mnt/tcroot/tmp/tcloop
if [ ! -f /mnt/cd/tcz/desktop-load-order.txt ]; then
    echo "Missing /mnt/cd/tcz/desktop-load-order.txt"
    ls -la /mnt/cd /mnt/cd/tcz 2>/dev/null || true
    exec setsid cttyhack sh
fi

while read ext; do
    ext="$(echo "$ext" | tr -d '\r')"
    [ -n "$ext" ] || continue
    src="/mnt/cd/tcz/$ext"
    if [ ! -f "$src" ]; then
        lower="$(echo "$ext" | tr 'A-Z' 'a-z')"
        src="/mnt/cd/tcz/$lower"
    fi
    base="${ext%.tcz}"
    loop="/mnt/tcroot/tmp/tcloop/$base"
    echo "Loading $ext"
    if [ ! -f "$src" ]; then
        echo "  missing $src"
        continue
    fi
    mkdir -p "$loop"
    if mount -o loop,ro -t squashfs "$src" "$loop" 2>/tmp/tcz-mount.err; then
        (
            cd "$loop" || exit 1
            find . -type d | while read d; do
                mkdir -p "/mnt/tcroot/${d#./}" 2>/dev/null || true
            done
            find . ! -type d | while read f; do
                rel="${f#./}"
                parent="$(dirname "$rel")"
                mkdir -p "/mnt/tcroot/$parent" 2>/dev/null || true
                ln -sf "/tmp/tcloop/$base/$rel" "/mnt/tcroot/$rel" 2>/tmp/tcz-link.err || {
                    echo "  link failed: $rel"
                    cat /tmp/tcz-link.err 2>/dev/null || true
                }
            done
        )
    else
        echo "  mount failed"
        cat /tmp/tcz-mount.err 2>/dev/null || true
    fi
done < /mnt/cd/tcz/desktop-load-order.txt

echo
echo "Running Tiny Core extension setup hooks"
while read ext; do
    ext="$(echo "$ext" | tr -d '\r')"
    [ -n "$ext" ] || continue
    base="${ext%.tcz}"
    hook="/usr/local/tce.installed/$base"
    if [ -x "/mnt/tcroot/$hook" ]; then
        echo "Setup $base"
        chroot /mnt/tcroot /bin/sh -c "export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin; export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib; $hook" 2>&1 || true
    fi
done < /mnt/cd/tcz/desktop-load-order.txt

X_HOTSET=0
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        xbox_x_hotset=1) X_HOTSET=1 ;;
    esac
done

hotset_mark() {
    event="$*"
    read uptime idle < /proc/uptime
    printf '%s %s\n' "$uptime" "$event" >> /mnt/tcroot/tmp/xbox-hotset-timing.txt
}

materialize_extension() {
    base="$1"
    source_root="/mnt/tcroot/tmp/tcloop/$base"
    if [ ! -d "$source_root" ]; then
        echo "X hotset missing extension: $base"
        return 1
    fi
    echo "X hotset materializing $base"
    (
        cd "$source_root" || exit 1
        find . -type d | while read d; do
            mkdir -p "/mnt/tcroot/${d#./}" 2>/dev/null || true
        done
        find . ! -type d | while read f; do
            rel="${f#./}"
            dest="/mnt/tcroot/$rel"
            mkdir -p "$(dirname "$dest")" 2>/dev/null || true
            rm -f "$dest" 2>/dev/null || true
            cp -a "$source_root/$rel" "$dest" 2>/tmp/x-hotset-copy.err || {
                echo "X hotset copy failed: $base/$rel"
                cat /tmp/x-hotset-copy.err 2>/dev/null || true
                exit 1
            }
            printf '%s|%s\n' "$rel" "/tmp/tcloop/$base/$rel" >> /mnt/tcroot/tmp/xbox-hotset-files.txt
        done
    )
}

: > /mnt/tcroot/tmp/xbox-hotset-timing.txt
: > /mnt/tcroot/tmp/xbox-hotset-files.txt
hotset_mark hotset-check
grep -E 'MemTotal|MemFree|MemAvailable' /proc/meminfo > /mnt/tcroot/tmp/xbox-hotset-memory-before.txt 2>/dev/null || true
if [ "$X_HOTSET" = "1" ]; then
    hotset_mark hotset-start
    for base in libXau libXdmcp libxcb libX11 Xlibs libpng freetype libfontenc libXfont Xfbdev; do
        materialize_extension "$base" || {
            echo "X hotset materialization failed at $base"
            exec setsid cttyhack sh
        }
        hotset_mark "hotset-extension-$base"
    done
    hotset_mark hotset-finished
fi
grep -E 'MemTotal|MemFree|MemAvailable' /proc/meminfo > /mnt/tcroot/tmp/xbox-hotset-memory-after.txt 2>/dev/null || true
du -sk /mnt/tcroot/usr/local/bin /mnt/tcroot/usr/local/lib 2>/dev/null > /mnt/tcroot/tmp/xbox-hotset-du.txt || true

mkdir -p /mnt/tcroot/root /mnt/tcroot/tmp/.X11-unix /mnt/tcroot/tmp/.ICE-unix
cat > /mnt/tcroot/root/start-xbox-desktop.sh <<'EOS'
#!/bin/sh
export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
export DISPLAY=:0.0

echo "Inside Tiny Core desktop launcher"
echo "PATH=$PATH"
echo "Xfbdev=$(command -v Xfbdev 2>/dev/null)"
echo "startx=$(command -v startx 2>/dev/null)"
echo "flwm_topside=$(command -v flwm_topside 2>/dev/null)"
echo "aterm=$(command -v aterm 2>/dev/null)"
echo "wbar=$(command -v wbar 2>/dev/null)"

mkdir -p /tmp/.X11-unix /tmp/.ICE-unix /tmp/tce/ondemand /usr/local/tce.installed /usr/local/bin
mkdir -p /home/tc/.X.d /etc/sysconfig
echo tc > /etc/sysconfig/tcuser
echo flwm_topside > /etc/sysconfig/desktop
echo wbar > /etc/sysconfig/icons
echo Xfbdev > /etc/sysconfig/Xserver
ln -snf /tmp/tce /etc/sysconfig/tcedir

cat > /usr/local/bin/xbox-storage-tune <<'EOX'
#!/bin/sh
DISK_RA=1024
FATX_RA=1024
ROOT_RA=1024
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        xbox_disk_readahead_kb=*) DISK_RA="${arg#xbox_disk_readahead_kb=}" ;;
        xbox_fatx_loop_readahead_kb=*) FATX_RA="${arg#xbox_fatx_loop_readahead_kb=}" ;;
        xbox_loop_readahead_kb=*) ROOT_RA="${arg#xbox_loop_readahead_kb=}" ;;
    esac
done
for q in /sys/block/hd*/queue/read_ahead_kb /sys/block/sd*/queue/read_ahead_kb; do
    [ -w "$q" ] || continue
    echo "$DISK_RA" > "$q" 2>/dev/null || true
done
[ -w /sys/block/loop0/queue/read_ahead_kb ] && echo "$FATX_RA" > /sys/block/loop0/queue/read_ahead_kb 2>/dev/null || true
[ -w /sys/block/loop1/queue/read_ahead_kb ] && echo "$ROOT_RA" > /sys/block/loop1/queue/read_ahead_kb 2>/dev/null || true
EOX

cat > /usr/local/bin/xbox-hotset-release <<'EOX'
#!/bin/sh
LOG=/tmp/xbox-hotset-release.txt
FILES=/tmp/xbox-hotset-files.txt

case " $(cat /proc/cmdline 2>/dev/null) " in
    *" xbox_x_hotset_release=1 "*) ;;
    *) exit 0 ;;
esac

{
    echo "== xbox x hotset release =="
    date
    echo
    echo "memory before:"
    grep -E 'MemTotal|MemFree|MemAvailable|Cached|Shmem|Slab' /proc/meminfo 2>/dev/null || true
    echo
} > "$LOG"

restored=0
failed=0
while IFS='|' read rel source; do
    [ -n "$rel" ] || continue
    dest="/$rel"
    if [ ! -e "$source" ]; then
        echo "missing source: $source" >> "$LOG"
        failed=$((failed + 1))
        continue
    fi
    rm -f "$dest" 2>/dev/null || true
    if ln -s "$source" "$dest" 2>/dev/null; then
        restored=$((restored + 1))
    else
        echo "restore failed: $dest -> $source" >> "$LOG"
        failed=$((failed + 1))
    fi
done < "$FILES"

{
    echo
    echo "restored=$restored"
    echo "failed=$failed"
    echo
    echo "memory after:"
    grep -E 'MemTotal|MemFree|MemAvailable|Cached|Shmem|Slab' /proc/meminfo 2>/dev/null || true
    echo
    if [ "$failed" -eq 0 ]; then
        echo "XBOX_X_HOTSET_RELEASE_OK"
    else
        echo "XBOX_X_HOTSET_RELEASE_FAILED"
    fi
} >> "$LOG"
EOX

cat > /usr/local/bin/xbox-diag <<'EOX'
#!/bin/sh
echo "== xbox linux diag =="
uname -a
echo
echo "== framebuffer =="
cat /sys/class/graphics/fb0/name /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null || true
echo
echo "== input =="
grep -E 'Name|Handlers' /proc/bus/input/devices 2>/dev/null || true
echo
echo "== mounts =="
mount
echo
echo "== memory =="
cat /proc/meminfo 2>/dev/null || true
echo
echo "== block devices =="
cat /proc/partitions 2>/dev/null || true
echo
echo "== network =="
ifconfig -a 2>/dev/null || true
echo
route -n 2>/dev/null || true
echo
[ -r /etc/resolv.conf ] && cat /etc/resolv.conf
echo
[ -s /tmp/xbox-network-up.txt ] && cat /tmp/xbox-network-up.txt
echo
echo "== read ahead =="
for q in /sys/block/hd*/queue/read_ahead_kb /sys/block/sd*/queue/read_ahead_kb /sys/block/loop*/queue/read_ahead_kb; do
    [ -r "$q" ] && echo "$q=$(cat "$q")"
done
echo
echo "== ata modes =="
for f in /sys/class/ata_device/dev*/pio_mode /sys/class/ata_device/dev*/dma_mode /sys/class/ata_device/dev*/xfer_mode; do
    [ -r "$f" ] && echo "$f=$(cat "$f")"
done
echo
echo "== storage dmesg =="
dmesg | grep -Ei 'FATX|loop|ata|pata|ide|dma|udma|pio|hda|sda|xbox' | tail -80
EOX

cat > /usr/local/bin/xbox-network-up <<'EOX'
#!/bin/sh
export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
LOG=/tmp/xbox-network-up.txt

if [ "${1:-}" = "--background" ]; then
    "$0" --foreground >"$LOG" 2>&1 &
    exit 0
fi

echo "== xbox tinycore network up =="
date 2>/dev/null || true
echo

if ! ifconfig eth0 >/dev/null 2>&1; then
    echo "XBOX_NETWORK_NO_ETH0"
    ifconfig -a 2>/dev/null || true
    exit 1
fi

echo "link before:"
ifconfig eth0 2>/dev/null || true
echo

ifconfig eth0 up 2>/dev/null || true

if ifconfig eth0 2>/dev/null | grep -q 'inet addr:'; then
    echo "XBOX_NETWORK_ALREADY_CONFIGURED"
else
    if command -v udhcpc >/dev/null 2>&1; then
        echo "running udhcpc eth0"
        udhcpc -i eth0 -n -q -T 4 -t 5 2>/tmp/xbox-udhcpc.err || {
            status=$?
            echo "udhcpc status=$status"
            [ -s /tmp/xbox-udhcpc.err ] && sed -n '1,60p' /tmp/xbox-udhcpc.err
        }
    elif command -v pump >/dev/null 2>&1; then
        echo "running pump eth0"
        pump -i eth0 2>/tmp/xbox-pump.err || {
            status=$?
            echo "pump status=$status"
            [ -s /tmp/xbox-pump.err ] && sed -n '1,60p' /tmp/xbox-pump.err
        }
    else
        echo "XBOX_NETWORK_NO_DHCP_CLIENT"
    fi
fi

echo
echo "link after:"
ifconfig eth0 2>/dev/null || true
echo
echo "routes:"
route -n 2>/dev/null || true
echo
echo "resolver:"
[ -r /etc/resolv.conf ] && cat /etc/resolv.conf || true
echo

if ifconfig eth0 2>/dev/null | grep -q 'inet addr:'; then
    echo "XBOX_NETWORK_DHCP_OK"
    xbox-remote-up --background >/tmp/xbox-remote-up-launch.log 2>&1 || true
    exit 0
fi

echo "XBOX_NETWORK_DHCP_FAILED"
exit 1
EOX

cat > /usr/local/bin/xbox-remote-up <<'EOX'
#!/bin/sh
export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
LOG=/tmp/xbox-remote-up.txt

if [ "${1:-}" = "--background" ]; then
    "$0" --foreground >"$LOG" 2>&1 &
    exit 0
fi

REMOTE_DIAG=0
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        xbox_remote_diag=1) REMOTE_DIAG=1 ;;
    esac
done

echo "== xbox tinycore remote diagnostics =="
if [ "$REMOTE_DIAG" != "1" ]; then
    echo "XBOX_REMOTE_DISABLED"
    exit 0
fi
if ! command -v dropbear >/dev/null 2>&1; then
    echo "XBOX_REMOTE_NO_DROPBEAR"
    exit 1
fi
if pidof dropbear >/dev/null 2>&1; then
    echo "XBOX_REMOTE_ALREADY_RUNNING"
    exit 0
fi
if ! ifconfig eth0 2>/dev/null | grep -q 'inet addr:'; then
    echo "XBOX_REMOTE_NO_ADDRESS"
    exit 1
fi

mkdir -p /var/run /usr/local/etc/dropbear
echo "starting Dropbear on tcp/22"
echo "login: tc (root login disabled)"
dropbear -R -w -E -p 22 -b /usr/local/etc/dropbear/banner 2>>"$LOG" || {
    status=$?
    echo "XBOX_REMOTE_START_FAILED status=$status"
    exit "$status"
}
sleep 1
if pidof dropbear >/dev/null 2>&1; then
    echo "XBOX_REMOTE_SSH_OK"
    exit 0
fi

echo "XBOX_REMOTE_START_FAILED no-process"
exit 1
EOX

cat > /usr/local/bin/xbox-aterm <<'EOX'
#!/bin/sh
export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
export TERM=xterm
export HOME="${HOME:-/home/tc}"
export USER="${USER:-tc}"
cd "$HOME" 2>/dev/null || cd /
XBOX_FONT=fixed
XBOX_GEOMETRY=78x24+20+20
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        xbox_terminal_font=9x15)
            XBOX_FONT=9x15
            XBOX_GEOMETRY=66x26+8+8
            ;;
    esac
done
exec aterm -fn "$XBOX_FONT" -fg white -bg black -geometry "$XBOX_GEOMETRY" -title "Xbox Terminal" -e /bin/sh -c "export HOME=/home/tc USER=tc TERM=xterm; cd /home/tc 2>/dev/null || cd /; exec /bin/sh -i" >/tmp/xbox-aterm.log 2>&1
EOX

cat > /usr/local/bin/xbox-proof-aterm <<'EOX'
#!/bin/sh
export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
xbox-diag >/tmp/xbox-diag.txt 2>&1 || true
XBOX_FONT=fixed
XBOX_GEOMETRY=78x26+20+20
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        xbox_terminal_font=9x15)
            XBOX_FONT=9x15
            XBOX_GEOMETRY=66x28+8+8
            ;;
    esac
done
exec aterm -fn "$XBOX_FONT" -fg white -bg black -geometry "$XBOX_GEOMETRY" -title "Xbox Tiny Core" -e /bin/sh -c "echo XBOX_TINYCORE_NORMAL_DESKTOP_OK; uname -a; echo; echo memory:; grep -E 'MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree' /proc/meminfo 2>/dev/null; echo; echo network:; ifconfig eth0 2>/dev/null || true; grep -E 'XBOX_NETWORK_(DHCP_OK|DHCP_FAILED|NO_ETH0|NO_DHCP_CLIENT)' /tmp/xbox-network-up.txt 2>/dev/null || true; echo; echo remote:; cat /tmp/xbox-remote-up.txt 2>/dev/null || echo pending; echo; echo framebuffer:; cat /sys/class/graphics/fb0/name /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null; echo; echo input:; grep -E 'Name|Handlers' /proc/bus/input/devices 2>/dev/null; echo; echo diag: /tmp/xbox-diag.txt; echo network log: /tmp/xbox-network-up.txt; echo remote log: /tmp/xbox-remote-up.txt; sleep 100000"
EOX
chmod 755 /usr/local/bin/xbox-storage-tune /usr/local/bin/xbox-hotset-release /usr/local/bin/xbox-diag /usr/local/bin/xbox-network-up /usr/local/bin/xbox-remote-up /usr/local/bin/xbox-aterm /usr/local/bin/xbox-proof-aterm

if ! grep -q '^tc:' /etc/passwd 2>/dev/null; then
    adduser -s /bin/sh -G staff -D tc 2>/tmp/adduser.log || cat /tmp/adduser.log
fi
echo "tc:tcuser" | chpasswd -m 2>/tmp/xbox-chpasswd.err || {
    echo "XBOX_TC_PASSWORD_SETUP_FAILED" >&2
    cat /tmp/xbox-chpasswd.err >&2 2>/dev/null || true
}
grep -q '^tc[[:space:]]' /etc/sudoers 2>/dev/null || echo 'tc ALL=NOPASSWD: ALL' >> /etc/sudoers

cp -a /etc/skel/. /home/tc/ 2>/dev/null || true
rm -f /home/tc/.xsession
cat > /home/tc/.xsession <<'EOX'
#!/bin/sh
: > /tmp/xbox-desktop-timing.txt
xbox_mark() {
    xbox_event="$*"
    read xbox_uptime xbox_idle < /proc/uptime
    printf '%s %s\n' "$xbox_uptime" "$xbox_event" >> /tmp/xbox-desktop-timing.txt
}
xbox_mark xsession-start
xbox_mark xfbdev-start
Xfbdev :0 -screen 640x480x32 -mouse /dev/input/mice,5 -nolisten tcp >/tmp/xfbdev.log 2>&1 &
export XPID=$!
xbox_mark xfbdev-launched
xbox_mark x-socket-wait-start
xbox_socket_wait=0
while [ ! -e /tmp/.X11-unix/X0 ] && [ "$xbox_socket_wait" -lt 60 ]; do
    sleep 1
    xbox_socket_wait=$((xbox_socket_wait + 1))
done
if [ -e /tmp/.X11-unix/X0 ]; then
    xbox_mark x-socket-ready
else
    xbox_mark x-socket-timeout
fi
xbox_mark waitforx-start
waitforX || ! echo failed in waitforX || exit
xbox_mark waitforx-finished
xbox_mark x-ready
"$DESKTOP" 2>/tmp/wm_errors &
export WM_PID=$!
xbox_mark wm-started
[ -x "$HOME/.mouse_config" ] && "$HOME/.mouse_config" &
[ -d "$HOME/.X.d" ] && find "$HOME/.X.d" -type f -o -type l | sort | while read F; do . "$F"; done
xbox_mark user-xd-started
[ -x "$HOME/.setbackground" ] && {
    xbox_mark wallpaper-start
    "$HOME/.setbackground" >/tmp/setbackground.log 2>&1
    xbox_mark wallpaper-finished
}
[ "$(which "$ICONS".sh 2>/dev/null)" ] && "$ICONS".sh &
xbox_mark icons-started
[ -d "/usr/local/etc/X.d" ] && find "/usr/local/etc/X.d" -type f -o -type l | sort | while read F; do . "$F"; done
xbox_mark system-xd-finished
( sleep 5; xbox-hotset-release ) >/tmp/xbox-hotset-release-launch.log 2>&1 &
wait "$XPID"
EOX

cat > /home/tc/.X.d/90-xbox-proof-aterm <<'EOX'
#!/bin/sh
xbox-proof-aterm >/tmp/aterm.log 2>&1 &
EOX

chmod 755 /home/tc/.xsession /home/tc/.X.d/90-xbox-proof-aterm
chown -R tc.staff /home/tc 2>/dev/null || true

export HOME=/home/tc
export USER=tc
if [ -f /usr/local/share/applications/aterm.desktop ]; then
    sed -i 's#^Exec=.*#Exec=xbox-aterm#' /usr/local/share/applications/aterm.desktop 2>/dev/null || true
fi
setupdesktop >/tmp/setupdesktop.log 2>&1 || cat /tmp/setupdesktop.log
wbar_setup.sh >/tmp/wbar-setup.log 2>&1 || cat /tmp/wbar-setup.log
if [ -e /usr/local/tce.icons ]; then
    sed -i 's#^c: .*aterm.*#c: exec xbox-aterm#' /usr/local/tce.icons 2>/dev/null || true
fi
if [ -e /home/tc/.wbar ]; then
    sed -i 's#^c: .*aterm.*#c: exec xbox-aterm#' /home/tc/.wbar 2>/dev/null || true
fi
xbox-storage-tune >/tmp/xbox-storage-tune.log 2>&1 || true
xbox-network-up --background >/tmp/xbox-network-up-launch.log 2>&1 || true

echo "Starting Tiny Core startx with tc home"
startx >/tmp/startx.log 2>&1 || {
    echo "startx failed"
    cat /tmp/startx.log 2>/dev/null
    cat /tmp/xfbdev.log 2>/dev/null
    cat /tmp/wm_errors 2>/dev/null
    exit 1
}
EOS
chmod 755 /mnt/tcroot/root/start-xbox-desktop.sh

echo
echo "Desktop binary check:"
chroot /mnt/tcroot /bin/sh -c 'export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin; export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib; command -v Xfbdev; command -v flwm_topside; command -v aterm; command -v wbar' 2>&1
echo
echo "Starting Xfbdev desktop. If this works, the screen should switch from console to X."
chroot /mnt/tcroot /root/start-xbox-desktop.sh 2>&1

echo
echo "Desktop launcher returned; falling back to shell"
exec setsid cttyhack sh
"""

TINYCORE_CD_MOUNT_SIMPLE = b"""mkdir -p /mnt/cd /mnt/tcroot
for dev in /dev/hdb /dev/hdc /dev/sr0 /dev/cdrom /dev/dvd; do
    if [ -e "$dev" ]; then
        echo "Trying CD mount: $dev"
        if mount -t iso9660 -o ro "$dev" /mnt/cd 2>/dev/null; then
            echo "Mounted $dev on /mnt/cd"
            break
        fi
    fi
done

if [ ! -f /mnt/cd/core.gz ]; then
    echo "Tiny Core core.gz was not found on /mnt/cd"
    exec setsid cttyhack sh
fi
"""

TINYCORE_CD_MOUNT_ROBUST = b"""mkdir -p /mnt/cd /mnt/iso /mnt/tcroot

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
    mknod "$dev" b "$major" "$minor" 2>/dev/null || true
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

try_mount_tinycore_disc() {
    dev="$1"
    [ -n "$dev" ] || return 1
    name="${dev#/dev/}"
    if [ "$name" != "$dev" ] && [ ! -e "$dev" ] && [ ! -r "/sys/block/$name/dev" ]; then
        return 1
    fi
    ensure_block_node "$dev" || true
    [ -b "$dev" ] || [ -e "$dev" ] || return 1
    umount /mnt/cd 2>/dev/null || true
    umount /mnt/iso 2>/dev/null || true
    echo "Trying CD mount: $dev"
    if mount -t iso9660 -o ro "$dev" /mnt/iso 2>/tmp/tc-iso-mount.err; then
        payload_dir=
        if [ -f /mnt/iso/core.gz ]; then
            payload_dir=/mnt/iso
        elif [ -f /mnt/iso/tc/core.gz ]; then
            payload_dir=/mnt/iso/tc
        fi
        if [ -n "$payload_dir" ]; then
            if mount --bind "$payload_dir" /mnt/cd 2>/tmp/tc-bind-mount.err; then
                echo "Mounted Tiny Core disc from $dev using $payload_dir"
            else
                echo "Bind mount of $payload_dir failed:"
                cat /tmp/tc-bind-mount.err 2>/dev/null || true
                umount /mnt/iso 2>/dev/null || true
                return 1
            fi
            return 0
        fi
        echo "Mounted $dev but neither /core.gz nor /tc/core.gz was present"
        ls -la /mnt/iso /mnt/iso/tc 2>/dev/null || true
        umount /mnt/iso 2>/dev/null || true
    else
        echo "  mount failed for $dev:"
        cat /tmp/tc-iso-mount.err 2>/dev/null || true
    fi
    return 1
}

find_tinycore_disc() {
    show_block_devices
    candidates=
    for sysdev in /sys/block/*; do
        [ -e "$sysdev" ] || continue
        name="$(basename "$sysdev")"
        dtype="$(cat "$sysdev/device/type" 2>/dev/null)"
        removable="$(cat "$sysdev/removable" 2>/dev/null)"
        case "$name:$dtype:$removable" in
            hd*:5:*|sr*:5:*|scd*:5:*|*:5:*|sr*:*:*|scd*:*:*|hd[b-z]:*:*|sd*:1)
                candidates="$candidates /dev/$name"
                ;;
        esac
    done
    candidates="$candidates /dev/hdb /dev/hdc /dev/hdd /dev/sr0 /dev/sr1 /dev/scd0 /dev/scd1 /dev/sda /dev/sdb /dev/cdrom /dev/dvd"
    tried=" "
    for dev in $candidates; do
        case "$tried" in
            *" $dev "*) continue ;;
        esac
        tried="$tried$dev "
        if try_mount_tinycore_disc "$dev"; then
            return 0
        fi
    done
    return 1
}

for i in 1 2 3 4 5 6 7 8; do
    echo "Tiny Core disc probe attempt $i"
    if find_tinycore_disc; then
        break
    fi
    sleep 1
done

if [ ! -f /mnt/cd/core.gz ]; then
    echo "Tiny Core core.gz was not found on /mnt/cd"
    echo "recent kernel messages:"
    dmesg | tail -80 2>/dev/null || true
    exec setsid cttyhack sh
fi
"""

TINYCORE_STAGE6_INIT = TINYCORE_STAGE6_INIT.replace(
    TINYCORE_CD_MOUNT_SIMPLE,
    TINYCORE_CD_MOUNT_ROBUST,
)

TINYCORE_HDD_STAGE6_INIT = TINYCORE_STAGE6_INIT.replace(
    b'echo "*** Xbox Tiny Core stage6 Xfbdev desktop attempt ***"',
    b'echo "*** Xbox Tiny Core HDD self-contained Xfbdev desktop attempt ***"',
).replace(
    TINYCORE_CD_MOUNT_ROBUST,
    b"""mkdir -p /tc/tcz /mnt/cd /mnt/tcroot
echo "Using embedded Tiny Core payload from initramfs /tc"
ls -la /tc /tc/tcz 2>/dev/null || true

if [ ! -f /tc/core.gz ]; then
    echo "Tiny Core core.gz was not found at /tc/core.gz"
    exec setsid cttyhack sh
fi
""",
).replace(
    b"/mnt/cd/core.gz",
    b"/tc/core.gz",
).replace(
    b"/mnt/cd/tcz",
    b"/tc/tcz",
).replace(
    b"mount --bind /mnt/cd /mnt/tcroot/mnt/cd 2>/dev/null || true",
    b"mount --bind /tc /mnt/tcroot/mnt/cd 2>/dev/null || true",
)

TINYCORE_HDD_EXT2_STAGE7_INIT = TINYCORE_STAGE6_INIT.replace(
    b'echo "*** Xbox Tiny Core stage6 Xfbdev desktop attempt ***"',
    b'echo "*** Xbox Tiny Core HDD ext2 payload Xfbdev desktop attempt ***"',
).replace(
    TINYCORE_CD_MOUNT_ROBUST,
    b"""mkdir -p /mnt/cd /mnt/tcroot /mnt/xboxe
PAYLOAD_OFFSET=
PAYLOAD_FILE=/linuxroot.ext2
E_PARTITION_OFFSET=2884108288
PAYLOAD_DISK=
DISK_RA=1024
FATX_RA=1024
ROOT_RA=1024
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        tc_payload_offset=*) PAYLOAD_OFFSET="${arg#tc_payload_offset=}" ;;
        tc_payload_file=*) PAYLOAD_FILE="${arg#tc_payload_file=}" ;;
        tc_fatx_e_offset=*) E_PARTITION_OFFSET="${arg#tc_fatx_e_offset=}" ;;
        tc_payload_disk=*) PAYLOAD_DISK="${arg#tc_payload_disk=}" ;;
        xbox_disk_readahead_kb=*) DISK_RA="${arg#xbox_disk_readahead_kb=}" ;;
        xbox_fatx_loop_readahead_kb=*) FATX_RA="${arg#xbox_fatx_loop_readahead_kb=}" ;;
        xbox_loop_readahead_kb=*) ROOT_RA="${arg#xbox_loop_readahead_kb=}" ;;
    esac
done

echo "Available block devices:"
cat /proc/partitions 2>/dev/null || true
ls -la /dev/hd* /dev/sd* /dev/vd* /dev/xvd* 2>/dev/null || true
if [ -z "$PAYLOAD_DISK" ]; then
    for dev in /dev/hda /dev/sda /dev/vda /dev/xvda; do
        if [ -b "$dev" ]; then
            PAYLOAD_DISK="$dev"
            break
        fi
    done
fi
if [ -z "$PAYLOAD_DISK" ]; then
    PAYLOAD_DISK=/dev/hda
fi
DISK_NAME="${PAYLOAD_DISK#/dev/}"
[ -w "/sys/block/$DISK_NAME/queue/read_ahead_kb" ] && echo "$DISK_RA" > "/sys/block/$DISK_NAME/queue/read_ahead_kb" 2>/dev/null || true

mknod /dev/loop0 b 7 0 2>/dev/null || true
mknod /dev/loop1 b 7 1 2>/dev/null || true
for i in 1 2 3 4 5; do
    [ -e "$PAYLOAD_DISK" ] && break
    sleep 1
done

if [ -n "$PAYLOAD_OFFSET" ]; then
    echo "Mounting Tiny Core ext2 HDD payload from $PAYLOAD_DISK at offset $PAYLOAD_OFFSET"
    if losetup -o "$PAYLOAD_OFFSET" /dev/loop0 "$PAYLOAD_DISK" 2>/tmp/tc-losetup.err; then
        echo "Attached /dev/loop0"
        [ -w /sys/block/loop0/queue/read_ahead_kb ] && echo "$ROOT_RA" > /sys/block/loop0/queue/read_ahead_kb 2>/dev/null || true
    else
        echo "losetup failed:"
        cat /tmp/tc-losetup.err 2>/dev/null || true
    fi
    if mount -t ext2 -o ro /dev/loop0 /mnt/cd 2>/tmp/tc-payload-mount.err; then
        echo "Mounted ext2 payload on /mnt/cd"
    else
        echo "ext2 payload mount failed:"
        cat /tmp/tc-payload-mount.err 2>/dev/null || true
    fi
else
    echo "Mounting Xbox E FATX from $PAYLOAD_DISK at offset $E_PARTITION_OFFSET"
    if losetup -o "$E_PARTITION_OFFSET" /dev/loop0 "$PAYLOAD_DISK" 2>/tmp/tc-fatx-losetup.err; then
        echo "Attached FATX loop /dev/loop0"
        [ -w /sys/block/loop0/queue/read_ahead_kb ] && echo "$FATX_RA" > /sys/block/loop0/queue/read_ahead_kb 2>/dev/null || true
    else
        echo "FATX losetup failed:"
        cat /tmp/tc-fatx-losetup.err 2>/dev/null || true
    fi
    if mount -t fatx -o ro /dev/loop0 /mnt/xboxe 2>/tmp/tc-fatx-mount.err; then
        echo "Mounted FATX E on /mnt/xboxe"
        ls -la /mnt/xboxe 2>/dev/null || true
        if losetup /dev/loop1 "/mnt/xboxe$PAYLOAD_FILE" 2>/tmp/tc-file-losetup.err; then
            echo "Attached ext2 image /mnt/xboxe$PAYLOAD_FILE to /dev/loop1"
            [ -w /sys/block/loop1/queue/read_ahead_kb ] && echo "$ROOT_RA" > /sys/block/loop1/queue/read_ahead_kb 2>/dev/null || true
        else
            echo "ext2 image losetup failed:"
            cat /tmp/tc-file-losetup.err 2>/dev/null || true
        fi
        if mount -t ext2 -o ro /dev/loop1 /mnt/cd 2>/tmp/tc-payload-mount.err; then
            echo "Mounted ext2 payload on /mnt/cd"
        else
            echo "ext2 payload mount failed:"
            cat /tmp/tc-payload-mount.err 2>/dev/null || true
        fi
    else
        echo "FATX mount failed:"
        cat /tmp/tc-fatx-mount.err 2>/dev/null || true
    fi
fi
""",
)


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
    add_entry(buf, name, stat.S_IFDIR | 0o755, ino=ino, nlink=2)


def add_file(buf, name, source, ino, mode=0o755):
    add_entry(buf, name, stat.S_IFREG | mode, source.read_bytes(), ino=ino)


def add_symlink(buf, name, target, ino):
    add_entry(buf, name, stat.S_IFLNK | 0o777, target.encode("ascii"), ino=ino)


def make_fb_marker(width=640, height=480):
    colors = [
        0x00ffffff,
        0x0000ff00,
        0x00ff00ff,
        0x0000ffff,
        0x00ff0000,
        0x000000ff,
    ]
    buf = bytearray()
    for y in range(height):
        band = colors[(y // 48) % len(colors)]
        for x in range(width):
            color = band if ((x // 32) + (y // 32)) % 2 == 0 else band ^ 0x00ffffff
            buf += color.to_bytes(4, "little")
    return bytes(buf)


def build(init_data, extra_entries=None):
    raw = bytearray()
    ino = 1

    for directory in [
        ".",
        "boot",
        "dev",
        "etc",
        "home",
        "mnt",
        "mnt/C",
        "mnt/cd",
        "mnt/D",
        "mnt/E",
        "mnt/F",
        "mnt/G",
        "mnt/X",
        "mnt/Y",
        "mnt/Z",
        "mnt/root",
        "proc",
        "root",
        "run",
        "sys",
        "tmp",
        "tc",
        "tc/tcz",
        "usr",
        "usr/bin",
        "usr/lib",
        "usr/lib/modules",
        "usr/sbin",
        "var",
        "var/service",
        "var/spool",
        "var/spool/cron",
    ]:
        add_dir(raw, directory, ino)
        ino += 1

    add_symlink(raw, "bin", "usr/bin", ino); ino += 1
    add_symlink(raw, "lib", "usr/lib", ino); ino += 1
    add_symlink(raw, "sbin", "usr/sbin", ino); ino += 1
    add_symlink(raw, "var/run", "../run", ino); ino += 1
    add_entry(raw, "dev/console", stat.S_IFCHR | 0o600, rdevmajor=5, rdevminor=1, ino=ino); ino += 1

    add_entry(raw, "init", stat.S_IFREG | 0o755, init_data, ino=ino); ino += 1
    add_file(raw, "etc/profile", SRC / "etc" / "profile", ino, 0o644); ino += 1
    add_file(raw, "etc/resolv.conf", SRC / "etc" / "resolv.conf", ino, 0o644); ino += 1
    add_file(raw, "usr/bin/busybox", SRC / "usr" / "bin" / "busybox", ino); ino += 1
    for name, data, mode in extra_entries or []:
        add_entry(raw, name, stat.S_IFREG | mode, data, ino=ino); ino += 1
    add_entry(raw, "TRAILER!!!", 0, ino=ino)
    return raw


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=ROOT / "artifacts" / "initramfs",
        help="write every generated initramfs under this directory",
    )
    args = parser.parse_args()
    out_dir = args.out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    outputs = {
        "raw": out_dir / OUT.name,
        "console": out_dir / OUT_CONSOLE.name,
        "stage2": out_dir / OUT_STAGE2.name,
        "reboot_probe": out_dir / OUT_REBOOT_PROBE.name,
        "visual_probe": out_dir / OUT_VISUAL_PROBE.name,
        "tinycore_stage3": out_dir / OUT_TINYCORE_STAGE3.name,
        "tinycore_stage4": out_dir / OUT_TINYCORE_STAGE4.name,
        "tinycore_stage5": out_dir / OUT_TINYCORE_STAGE5.name,
        "tinycore_stage6": out_dir / OUT_TINYCORE_STAGE6.name,
        "tinycore_hdd_stage6": out_dir / OUT_TINYCORE_HDD_STAGE6.name,
        "tinycore_hdd_stage6_game": out_dir / OUT_TINYCORE_HDD_STAGE6_GAME.name,
        "tinycore_hdd_ext2_stage7": out_dir / OUT_TINYCORE_HDD_EXT2_STAGE7.name,
    }
    tc_root = ROOT / "downloads" / "tinycore" / "11.x" / "x86"
    tcz_dir = tc_root / "tcz"
    tcz_order = tcz_dir / "desktop-load-order.txt"
    tcz_names = [
        name.strip()
        for name in tcz_order.read_text(encoding="ascii").splitlines()
        if name.strip()
    ]
    tinycore_hdd_entries = [
        ("tc/core.gz", (tc_root / "core.gz").read_bytes(), 0o644),
        ("tc/tcz/desktop-load-order.txt", tcz_order.read_bytes(), 0o644),
    ]
    tinycore_hdd_entries.extend(
        (f"tc/tcz/{name}", (tcz_dir / name).read_bytes(), 0o644)
        for name in tcz_names
    )

    game_tcz_names = [name for name in tcz_names if name != "Xorg-fonts.tcz"]
    game_tcz_order = ("\n".join(game_tcz_names) + "\n").encode("ascii")
    tinycore_hdd_game_entries = [
        ("tc/core.gz", (tc_root / "core.gz").read_bytes(), 0o644),
        ("tc/tcz/desktop-load-order.txt", game_tcz_order, 0o644),
    ]
    tinycore_hdd_game_entries.extend(
        (f"tc/tcz/{name}", (tcz_dir / name).read_bytes(), 0o644)
        for name in game_tcz_names
    )

    outputs["raw"].write_bytes(build((SRC / "init").read_bytes()))
    outputs["console"].write_bytes(build(CONSOLE_INIT))
    outputs["stage2"].write_bytes(build(STAGE2_INIT))
    outputs["reboot_probe"].write_bytes(build(REBOOT_PROBE_INIT))
    outputs["visual_probe"].write_bytes(build(VISUAL_PROBE_INIT, [("fbmark.raw", make_fb_marker(), 0o644)]))
    outputs["tinycore_stage3"].write_bytes(build(TINYCORE_STAGE3_INIT))
    outputs["tinycore_stage4"].write_bytes(build(TINYCORE_STAGE4_INIT))
    outputs["tinycore_stage5"].write_bytes(build(TINYCORE_STAGE5_INIT))
    outputs["tinycore_stage6"].write_bytes(build(TINYCORE_STAGE6_INIT))
    outputs["tinycore_hdd_stage6"].write_bytes(build(TINYCORE_HDD_STAGE6_INIT, tinycore_hdd_entries))
    outputs["tinycore_hdd_stage6_game"].write_bytes(build(TINYCORE_HDD_STAGE6_INIT, tinycore_hdd_game_entries))
    outputs["tinycore_hdd_ext2_stage7"].write_bytes(build(TINYCORE_HDD_EXT2_STAGE7_INIT))
    for output in outputs.values():
        print(output)


if __name__ == "__main__":
    main()
