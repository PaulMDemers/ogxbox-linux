#!/usr/bin/env python3
"""Create a small raw newc initramfs with static i386 BusyBox."""

from pathlib import Path
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
for q in /sys/block/hd*/queue/read_ahead_kb /sys/block/sd*/queue/read_ahead_kb /sys/block/loop*/queue/read_ahead_kb; do
    [ -w "$q" ] || continue
    echo 1024 > "$q" 2>/dev/null || true
done
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

cat > /usr/local/bin/xbox-aterm <<'EOX'
#!/bin/sh
export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
export TERM=xterm
export HOME="${HOME:-/home/tc}"
export USER="${USER:-tc}"
cd "$HOME" 2>/dev/null || cd /
exec aterm -fn fixed -fg white -bg black -geometry 78x24+20+20 -title "Xbox Terminal" -e /bin/sh
EOX

cat > /usr/local/bin/xbox-proof-aterm <<'EOX'
#!/bin/sh
export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
xbox-diag >/tmp/xbox-diag.txt 2>&1 || true
exec aterm -fn fixed -fg white -bg black -geometry 78x26+20+20 -title "Xbox Tiny Core" -e /bin/sh -c "echo XBOX_TINYCORE_NORMAL_DESKTOP_OK; uname -a; echo; echo memory:; grep -E 'MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree' /proc/meminfo 2>/dev/null; echo; echo framebuffer:; cat /sys/class/graphics/fb0/name /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null; echo; echo input:; grep -E 'Name|Handlers' /proc/bus/input/devices 2>/dev/null; echo; echo diag: /tmp/xbox-diag.txt; sleep 100000"
EOX
chmod 755 /usr/local/bin/xbox-storage-tune /usr/local/bin/xbox-diag /usr/local/bin/xbox-aterm /usr/local/bin/xbox-proof-aterm

if ! grep -q '^tc:' /etc/passwd 2>/dev/null; then
    adduser -s /bin/sh -G staff -D tc 2>/tmp/adduser.log || cat /tmp/adduser.log
    echo "tc:tcuser" | chpasswd -m 2>/dev/null || true
fi
grep -q '^tc[[:space:]]' /etc/sudoers 2>/dev/null || echo 'tc ALL=NOPASSWD: ALL' >> /etc/sudoers

cp -a /etc/skel/. /home/tc/ 2>/dev/null || true
rm -f /home/tc/.xsession
cat > /home/tc/.xsession <<'EOX'
#!/bin/sh
Xfbdev :0 -screen 640x480x32 -mouse /dev/input/mice,5 -nolisten tcp >/tmp/xfbdev.log 2>&1 &
export XPID=$!
waitforX || ! echo failed in waitforX || exit
"$DESKTOP" 2>/tmp/wm_errors &
export WM_PID=$!
[ -x "$HOME/.setbackground" ] && "$HOME/.setbackground"
[ -x "$HOME/.mouse_config" ] && "$HOME/.mouse_config" &
[ "$(which "$ICONS".sh 2>/dev/null)" ] && "$ICONS".sh &
[ -d "/usr/local/etc/X.d" ] && find "/usr/local/etc/X.d" -type f -o -type l | sort | while read F; do . "$F"; done
[ -d "$HOME/.X.d" ] && find "$HOME/.X.d" -type f -o -type l | sort | while read F; do . "$F"; done
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
setupdesktop >/tmp/setupdesktop.log 2>&1 || cat /tmp/setupdesktop.log
wbar_setup.sh >/tmp/wbar-setup.log 2>&1 || cat /tmp/wbar-setup.log
if [ -f /home/tc/.wbar ]; then
    sed -i 's#^c: .*aterm.*#c: exec xbox-aterm#' /home/tc/.wbar 2>/dev/null || true
fi
xbox-storage-tune >/tmp/xbox-storage-tune.log 2>&1 || true

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

TINYCORE_HDD_STAGE6_INIT = TINYCORE_STAGE6_INIT.replace(
    b'echo "*** Xbox Tiny Core stage6 Xfbdev desktop attempt ***"',
    b'echo "*** Xbox Tiny Core HDD self-contained Xfbdev desktop attempt ***"',
).replace(
    b"""mkdir -p /mnt/cd /mnt/tcroot
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
""",
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
    b"""mkdir -p /mnt/cd /mnt/tcroot
for dev in /dev/hdb /dev/hdc /dev/sr0 /dev/cdrom /dev/dvd; do
    if [ -e "$dev" ]; then
        echo "Trying CD mount: $dev"
        if mount -t iso9660 -o ro "$dev" /mnt/cd 2>/dev/null; then
            echo "Mounted $dev on /mnt/cd"
            break
        fi
    fi
done
""",
    b"""mkdir -p /mnt/cd /mnt/tcroot /mnt/xboxe
PAYLOAD_OFFSET=
PAYLOAD_FILE=/linuxroot.ext2
E_PARTITION_OFFSET=2884108288
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        tc_payload_offset=*) PAYLOAD_OFFSET="${arg#tc_payload_offset=}" ;;
        tc_payload_file=*) PAYLOAD_FILE="${arg#tc_payload_file=}" ;;
        tc_fatx_e_offset=*) E_PARTITION_OFFSET="${arg#tc_fatx_e_offset=}" ;;
    esac
done

PAYLOAD_DISK=
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        tc_payload_disk=*) PAYLOAD_DISK="${arg#tc_payload_disk=}" ;;
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
    else
        echo "FATX losetup failed:"
        cat /tmp/tc-fatx-losetup.err 2>/dev/null || true
    fi
    if mount -t fatx -o ro /dev/loop0 /mnt/xboxe 2>/tmp/tc-fatx-mount.err; then
        echo "Mounted FATX E on /mnt/xboxe"
        ls -la /mnt/xboxe 2>/dev/null || true
        if losetup /dev/loop1 "/mnt/xboxe$PAYLOAD_FILE" 2>/tmp/tc-file-losetup.err; then
            echo "Attached ext2 image /mnt/xboxe$PAYLOAD_FILE to /dev/loop1"
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
    OUT.parent.mkdir(parents=True, exist_ok=True)
    tc_root = ROOT / "downloads" / "tinycore" / "11.x" / "x86"
    tcz_dir = tc_root / "tcz"
    tcz_order = tcz_dir / "desktop-load-order.txt"
    tinycore_hdd_entries = [
        ("tc/core.gz", (tc_root / "core.gz").read_bytes(), 0o644),
        ("tc/tcz/desktop-load-order.txt", tcz_order.read_bytes(), 0o644),
    ]
    tinycore_hdd_entries.extend(
        (f"tc/tcz/{name}", (tcz_dir / name).read_bytes(), 0o644)
        for name in tcz_order.read_text(encoding="ascii").splitlines()
        if name.strip()
    )

    OUT.write_bytes(build((SRC / "init").read_bytes()))
    OUT_CONSOLE.write_bytes(build(CONSOLE_INIT))
    OUT_STAGE2.write_bytes(build(STAGE2_INIT))
    OUT_REBOOT_PROBE.write_bytes(build(REBOOT_PROBE_INIT))
    OUT_VISUAL_PROBE.write_bytes(build(VISUAL_PROBE_INIT, [("fbmark.raw", make_fb_marker(), 0o644)]))
    OUT_TINYCORE_STAGE3.write_bytes(build(TINYCORE_STAGE3_INIT))
    OUT_TINYCORE_STAGE4.write_bytes(build(TINYCORE_STAGE4_INIT))
    OUT_TINYCORE_STAGE5.write_bytes(build(TINYCORE_STAGE5_INIT))
    OUT_TINYCORE_STAGE6.write_bytes(build(TINYCORE_STAGE6_INIT))
    OUT_TINYCORE_HDD_STAGE6.write_bytes(build(TINYCORE_HDD_STAGE6_INIT, tinycore_hdd_entries))
    OUT_TINYCORE_HDD_EXT2_STAGE7.write_bytes(build(TINYCORE_HDD_EXT2_STAGE7_INIT))
    print(OUT)
    print(OUT_CONSOLE)
    print(OUT_STAGE2)
    print(OUT_REBOOT_PROBE)
    print(OUT_VISUAL_PROBE)
    print(OUT_TINYCORE_STAGE3)
    print(OUT_TINYCORE_STAGE4)
    print(OUT_TINYCORE_STAGE5)
    print(OUT_TINYCORE_STAGE6)
    print(OUT_TINYCORE_HDD_STAGE6)
    print(OUT_TINYCORE_HDD_EXT2_STAGE7)


if __name__ == "__main__":
    main()
