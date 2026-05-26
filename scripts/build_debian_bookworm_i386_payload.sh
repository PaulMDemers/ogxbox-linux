#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/home/paul/ogxbox/distro-build/debian-bookworm-i386-root}"
IMAGE="${2:-/mnt/c/Users/Paul/Desktop/xbox_linux/artifacts/hdd/xbox-debian-bookworm-i386.ext2}"
SUITE="${3:-bookworm}"
ARCH="${4:-i386}"
MIRROR="${5:-http://deb.debian.org/debian}"
SIZE_MIB="${6:-384}"
FORCE="${7:-0}"
DESKTOP="${8:-0}"
BASE_PACKAGES="busybox,sysvinit-core,ifupdown,isc-dhcp-client,iproute2,netbase,procps,psmisc,less,nano,kmod,iputils-ping,wget,ca-certificates"

if ! command -v debootstrap >/dev/null 2>&1; then
    apt-get update
    apt-get install -y debootstrap
fi

if [ ! -r /usr/share/keyrings/debian-archive-keyring.gpg ]; then
    apt-get update
    apt-get install -y debian-archive-keyring
fi

if [ "$FORCE" = "1" ]; then
    rm -rf "$ROOT"
fi

mkdir -p "$(dirname "$ROOT")" "$(dirname "$IMAGE")"
REPO_ROOT="$(cd "$(dirname "$IMAGE")/../.." && pwd)"

if [ ! -x "$ROOT/bin/sh" ]; then
    debootstrap \
        --arch="$ARCH" \
        --variant=minbase \
        --include="$BASE_PACKAGES" \
        "$SUITE" "$ROOT" "$MIRROR"
fi

if ! chroot "$ROOT" sh -c 'dpkg-query -W iputils-ping wget ca-certificates >/dev/null 2>&1'; then
    cat > "$ROOT/usr/sbin/policy-rc.d" <<'EOF'
#!/bin/sh
exit 101
EOF
    chmod 755 "$ROOT/usr/sbin/policy-rc.d"
    chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get update
    chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends iputils-ping wget ca-certificates
    rm -f "$ROOT/usr/sbin/policy-rc.d"
fi

if [ "$DESKTOP" = "1" ] && [ ! -e "$ROOT/.xbox-tinycore-xfbdev-installed" ]; then
    TC_TCZ_DIR="$REPO_ROOT/artifacts/hdd/tinycore-ext2-root/tcz"
    if [ -r "$TC_TCZ_DIR/desktop-load-order.txt" ]; then
        while IFS= read -r tcz; do
            tcz="${tcz%$'\r'}"
            [ -n "$tcz" ] || continue
            [ -r "$TC_TCZ_DIR/$tcz" ] || continue
            unsquashfs -f -d "$ROOT" "$TC_TCZ_DIR/$tcz" >/dev/null
        done < "$TC_TCZ_DIR/desktop-load-order.txt"
        touch "$ROOT/.xbox-tinycore-xfbdev-installed"
    else
        echo "warning: Tiny Core Xfbdev extension set not found at $TC_TCZ_DIR"
    fi
fi

cat > "$ROOT/etc/hostname" <<'EOF'
xbox-debian
EOF

cat > "$ROOT/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 xbox-debian
EOF

cat > "$ROOT/etc/fstab" <<'EOF'
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
devtmpfs /dev devtmpfs mode=0755 0 0
devpts /dev/pts devpts mode=0620,ptmxmode=0666,gid=5 0 0
tmpfs /run tmpfs mode=0755,nosuid,nodev,size=8m 0 0
tmpfs /tmp tmpfs mode=1777,nosuid,nodev,size=16m 0 0
EOF

mkdir -p "$ROOT/etc/network"
cat > "$ROOT/etc/network/interfaces" <<'EOF'
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp
EOF

cat > "$ROOT/etc/apt/sources.list" <<EOF
deb $MIRROR $SUITE main
deb http://security.debian.org/debian-security ${SUITE}-security main
deb $MIRROR ${SUITE}-updates main
EOF

cat > "$ROOT/etc/issue" <<'EOF'
Xbox Debian bookworm i386 proof console
EOF

cat > "$ROOT/xbox-init" <<'EOF'
#!/bin/sh
exec </dev/console >/dev/console 2>&1

mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts -o mode=0620,ptmxmode=0666,gid=5 2>/dev/null || true
mount -t tmpfs -o mode=0755,nosuid,nodev,size=8m tmpfs /run 2>/dev/null || true
mount -t tmpfs -o mode=1777,nosuid,nodev,size=16m tmpfs /tmp 2>/dev/null || true

export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
export TERM=linux
export HOME=/root
DESKTOP=0
PERSIST_SMOKE=0
SYNC_RO_SMOKE=0
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        xbox_desktop=1) DESKTOP=1 ;;
        xbox_persist_smoke=1) PERSIST_SMOKE=1 ;;
        xbox_sync_ro_smoke=1) SYNC_RO_SMOKE=1 ;;
    esac
done
xbox-storage-tune >/tmp/xbox-storage-tune.log 2>&1 || true
xbox-diag >/tmp/xbox-diag.txt 2>&1 || true
if [ "$PERSIST_SMOKE" = "1" ] && [ -x /usr/local/bin/xbox-persist-smoke ]; then
    /usr/local/bin/xbox-persist-smoke >/tmp/xbox-persist-smoke.txt 2>&1 || true
fi
if [ "$SYNC_RO_SMOKE" = "1" ] && [ -x /usr/local/bin/xbox-sync-ro ]; then
    /usr/local/bin/xbox-sync-ro >/tmp/xbox-sync-ro.txt 2>&1 || true
fi

echo
echo "XBOX_DEBIAN_BOOKWORM_I386_ROOT_OK"
uname -a
echo
cat /etc/os-release 2>/dev/null || true
echo
echo "memory:"
grep -E 'MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree' /proc/meminfo 2>/dev/null || true
echo
echo "block:"
cat /proc/partitions 2>/dev/null || true
echo
echo "mounts:"
mount
echo
echo "network devices:"
ip link 2>/dev/null || true
echo
echo "tools: ping wget apt xbox-perf"
echo
if [ -s /tmp/xbox-persist-smoke.txt ]; then
    echo "persistence smoke:"
    cat /tmp/xbox-persist-smoke.txt
    echo
fi
if [ -s /tmp/xbox-sync-ro.txt ]; then
    echo "sync-ro smoke:"
    cat /tmp/xbox-sync-ro.txt
    echo
fi
if [ "$DESKTOP" = "1" ] && [ -x /usr/local/bin/xbox-startx ]; then
    echo "Launching Debian X proof desktop"
    echo
    /usr/local/bin/xbox-startx
    status=$?
    echo
    echo "X exited with status $status"
    echo "Last Xorg log lines:"
    tail -80 /tmp/Xorg.0.log 2>/dev/null || true
    echo
fi
echo "Launching Debian proof shell on /dev/console"
echo

exec /bin/sh -i
EOF
chmod 755 "$ROOT/xbox-init"

mkdir -p "$ROOT/etc/X11" "$ROOT/usr/local/bin"

cat > "$ROOT/usr/local/bin/xbox-storage-tune" <<'EOF'
#!/bin/sh
for q in /sys/block/hd*/queue/read_ahead_kb /sys/block/sd*/queue/read_ahead_kb; do
    [ -w "$q" ] || continue
    echo 1024 > "$q" 2>/dev/null || true
done
EOF

cat > "$ROOT/usr/local/bin/xbox-diag" <<'EOF'
#!/bin/sh
echo "== xbox debian diag =="
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
EOF

cat > "$ROOT/usr/local/bin/xbox-perf" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
TMP_OUT=/tmp/xbox-perf.out
TMP_ERR=/tmp/xbox-perf.err

ms_now() {
    ns=$(date +%s%N 2>/dev/null || true)
    case "$ns" in
        *N*|"") date +%s000 2>/dev/null ;;
        *) echo $((ns / 1000000)) ;;
    esac
}

run_probe() {
    label="$1"
    shift
    echo "-- $label"
    start=$(ms_now)
    "$@" >"$TMP_OUT" 2>"$TMP_ERR"
    status=$?
    end=$(ms_now)
    echo "status=$status elapsed_ms=$((end - start))"
    if [ -s "$TMP_ERR" ]; then
        sed -n '1,6p' "$TMP_ERR"
    fi
}

echo "== xbox perf smoke =="
uname -a
echo
run_probe "true" /bin/true
run_probe "sh -c true" /bin/sh -c true
run_probe "free -m" /usr/bin/free -m
run_probe "busybox free" /bin/busybox free
run_probe "cat /proc/meminfo" /bin/cat /proc/meminfo
run_probe "ps" /bin/ps
echo
echo "== memory snapshot =="
grep -E 'MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree' /proc/meminfo 2>/dev/null || true
echo
echo "== read ahead =="
for q in /sys/block/hd*/queue/read_ahead_kb /sys/block/sd*/queue/read_ahead_kb /sys/block/loop*/queue/read_ahead_kb; do
    [ -r "$q" ] && echo "$q=$(cat "$q")"
done
rm -f "$TMP_OUT" "$TMP_ERR"
EOF

cat > "$ROOT/usr/local/bin/xbox-persist-smoke" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
MARKER=/root/xbox-persist-smoke.txt
TMP=/root/xbox-persist-smoke.txt.tmp
NORMAL=/root/xbox-normal-use.txt
NORMAL_TMP=/root/xbox-normal-use.txt.tmp

echo "== xbox persistence smoke =="
echo "root mount:"
awk '$2 == "/" { print }' /proc/mounts 2>/dev/null || true
echo

if [ -s "$MARKER" ] && [ -s "$NORMAL" ]; then
    echo "XBOX_PERSIST_MARKER_PRESENT"
    cat "$MARKER"
    echo
    echo "XBOX_NORMAL_USE_FILE_PRESENT"
    cat "$NORMAL"
    exit 0
fi

echo "writing marker: $MARKER"
{
    echo "XBOX_PERSIST_MARKER_20260526"
    echo "uname=$(uname -a)"
    echo "cmdline=$(cat /proc/cmdline 2>/dev/null)"
    echo "created_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
} > "$TMP"
status=$?
if [ "$status" -ne 0 ]; then
    echo "XBOX_PERSIST_MARKER_WRITE_FAILED status=$status"
    rm -f "$TMP" 2>/dev/null || true
    exit "$status"
fi

mv "$TMP" "$MARKER"
status=$?
if [ "$status" -ne 0 ]; then
    echo "XBOX_PERSIST_MARKER_RENAME_FAILED status=$status"
    rm -f "$TMP" 2>/dev/null || true
    exit "$status"
fi

echo "writing normal file: $NORMAL"
{
    echo "XBOX_NORMAL_USE_FILE_20260526"
    echo "This file simulates a small user-created persistent file."
    echo "created_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
} > "$NORMAL_TMP"
status=$?
if [ "$status" -ne 0 ]; then
    echo "XBOX_NORMAL_USE_FILE_WRITE_FAILED status=$status"
    rm -f "$NORMAL_TMP" 2>/dev/null || true
    exit "$status"
fi

mv "$NORMAL_TMP" "$NORMAL"
status=$?
if [ "$status" -ne 0 ]; then
    echo "XBOX_NORMAL_USE_FILE_RENAME_FAILED status=$status"
    rm -f "$NORMAL_TMP" 2>/dev/null || true
    exit "$status"
fi

sync
echo "XBOX_PERSIST_MARKER_WRITTEN"
cat "$MARKER"
echo
echo "XBOX_NORMAL_USE_FILE_WRITTEN"
cat "$NORMAL"
EOF

cat > "$ROOT/usr/local/bin/xbox-sync-ro" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin

echo "syncing filesystems"
sync
echo "remounting / read-only"
if mount -o remount,ro /; then
    echo "XBOX_ROOT_REMOUNT_RO_OK"
    echo "It is now safer to power off or reset."
    exit 0
fi

echo "XBOX_ROOT_REMOUNT_RO_FAILED"
echo "Some process may still have writable files open. Run sync again before power-off."
exit 1
EOF
chmod 755 "$ROOT/usr/local/bin/xbox-storage-tune" "$ROOT/usr/local/bin/xbox-diag" "$ROOT/usr/local/bin/xbox-perf" "$ROOT/usr/local/bin/xbox-persist-smoke" "$ROOT/usr/local/bin/xbox-sync-ro"

cat > "$ROOT/usr/local/bin/xbox-terminal" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
export TERM=xterm
export HOME="${HOME:-/tmp/root-home}"
mkdir -p "$HOME"
exec aterm -fn fixed -fg white -bg black -title "Xbox Debian" "$@" >/tmp/xbox-terminal.log 2>&1
EOF

cat > "$ROOT/usr/local/bin/xterm" <<'EOF'
#!/bin/sh
exec /usr/local/bin/xbox-terminal "$@"
EOF
chmod 755 "$ROOT/usr/local/bin/xbox-terminal" "$ROOT/usr/local/bin/xterm"

cat > "$ROOT/etc/X11/xbox-xorg.conf" <<'EOF'
Section "ServerFlags"
    Option "AllowMouseOpenFail" "true"
    Option "AutoAddDevices" "true"
    Option "DontZap" "false"
EndSection

Section "Device"
    Identifier "XboxFramebuffer"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
EndSection

Section "Monitor"
    Identifier "XboxMonitor"
EndSection

Section "Screen"
    Identifier "XboxScreen"
    Device "XboxFramebuffer"
    Monitor "XboxMonitor"
EndSection

Section "ServerLayout"
    Identifier "XboxLayout"
    Screen "XboxScreen"
EndSection
EOF

cat > "$ROOT/usr/local/bin/xbox-xsession" <<'EOF'
#!/bin/sh
export HOME="${HOME:-/tmp/root-home}"
mkdir -p "$HOME"

cat > "$HOME/.jwmrc" <<'EORC'
<?xml version="1.0"?>
<JWM>
  <RootMenu onroot="12">
    <Program label="Terminal">xterm</Program>
    <Restart label="Restart JWM"/>
    <Exit label="Exit X"/>
  </RootMenu>
  <Tray x="0" y="-1" height="26">
    <TrayButton label="Menu">root:1</TrayButton>
    <TaskList maxwidth="256"/>
    <Clock format="%H:%M"/>
  </Tray>
  <WindowStyle>
    <Font>fixed-10</Font>
    <Width>3</Width>
    <Height>18</Height>
    <Foreground>white</Foreground>
    <Background>#304860</Background>
    <Active><Foreground>white</Foreground><Background>#507090</Background></Active>
  </WindowStyle>
  <Desktop><Background type="solid">#1f3f4f</Background></Desktop>
</JWM>
EORC

xsetroot -solid '#1f3f4f' 2>/dev/null || true
if command -v flwm_topside >/dev/null 2>&1 && command -v aterm >/dev/null 2>&1; then
    aterm -fn fixed -fg white -bg black -geometry 78x24+20+32 -title "Xbox Debian" -e /bin/sh -lc 'echo XBOX_DEBIAN_X_DESKTOP_OK; uname -a; echo; echo memory:; grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree" /proc/meminfo 2>/dev/null; echo; echo tools: ping wget apt xbox-perf xbox-sync-ro; echo; echo read-ahead:; grep read_ahead_kb /tmp/xbox-diag.txt 2>/dev/null || true; echo; if [ -s /tmp/xbox-persist-smoke.txt ]; then echo persistence:; grep -E "XBOX_(PERSIST_MARKER|NORMAL_USE_FILE)_(WRITTEN|PRESENT|WRITE_FAILED|RENAME_FAILED|20260526)" /tmp/xbox-persist-smoke.txt 2>/dev/null || tail -10 /tmp/xbox-persist-smoke.txt; echo; fi; if [ -s /tmp/xbox-sync-ro.txt ]; then echo sync-ro:; grep -E "XBOX_ROOT_REMOUNT_RO_(OK|FAILED)" /tmp/xbox-sync-ro.txt 2>/dev/null || cat /tmp/xbox-sync-ro.txt; echo; fi; echo diag: /tmp/xbox-diag.txt; exec /bin/sh -i' >/tmp/aterm.log 2>&1 &
    exec flwm_topside
fi
xterm -geometry 78x24+20+32 -title "Xbox Debian" -e /bin/sh -lc 'echo XBOX_DEBIAN_X_DESKTOP_OK; uname -a; exec /bin/sh -i' &
exec jwm
EOF
chmod 755 "$ROOT/usr/local/bin/xbox-xsession"

cat > "$ROOT/usr/local/bin/xbox-startx" <<'EOF'
#!/bin/sh
exec </dev/console >/dev/console 2>&1

export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
export HOME=/tmp/root-home
export XDG_RUNTIME_DIR=/tmp/root-runtime
export XAUTHORITY=/tmp/root-home/.Xauthority
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$HOME" "$XDG_RUNTIME_DIR"

X_MOUSE=0
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        xbox_x_mouse=1) X_MOUSE=1 ;;
        xbox_x_mouse=0) X_MOUSE=0 ;;
    esac
done

[ -e /dev/fb0 ] || mknod -m 660 /dev/fb0 c 29 0 2>/dev/null || true
[ -e /dev/tty0 ] || mknod -m 620 /dev/tty0 c 4 0 2>/dev/null || true
[ -e /dev/tty1 ] || mknod -m 620 /dev/tty1 c 4 1 2>/dev/null || true
mkdir -p /dev/input
[ -e /dev/input/mice ] || mknod -m 660 /dev/input/mice c 13 63 2>/dev/null || true

echo "framebuffer:"
cat /proc/fb 2>/dev/null || true
ls -l /dev/fb* 2>/dev/null || true
echo
echo "input:"
ls -l /dev/input 2>/dev/null || true
echo

rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 /tmp/Xorg.0.log
mkdir -p /tmp/.X11-unix

if [ -x /usr/local/bin/Xfbdev ]; then
    export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
    export DISPLAY=:0
    echo "Starting Xfbdev server"
    if [ "$X_MOUSE" = "1" ]; then
        echo "Xfbdev explicit mouse device: /dev/input/mice"
        /usr/local/bin/Xfbdev :0 -screen 640x480x32 -mouse /dev/input/mice,5 -nolisten tcp >/tmp/xfbdev.log 2>&1 &
    else
        echo "Xfbdev explicit mouse device: disabled; default pointer input may still work"
        /usr/local/bin/Xfbdev :0 -screen 640x480x32 -nolisten tcp >/tmp/xfbdev.log 2>&1 &
    fi
    XPID=$!
    sleep 2
    if ! kill -0 "$XPID" 2>/dev/null; then
        echo "Xfbdev exited before session start"
        cat /tmp/xfbdev.log 2>/dev/null || true
        exit 1
    fi
    echo "Starting X session"
    /usr/local/bin/xbox-xsession >/tmp/xsession.log 2>&1
    status=$?
    echo "X session exited with status $status"
    cat /tmp/xsession.log 2>/dev/null || true
    cat /tmp/xfbdev.log 2>/dev/null || true
    kill "$XPID" 2>/dev/null || true
    wait "$XPID" 2>/dev/null || true
    exit "$status"
fi

SERVER=/usr/lib/xorg/Xorg
[ -x "$SERVER" ] || SERVER=/usr/bin/Xorg

exec xinit /usr/local/bin/xbox-xsession -- "$SERVER" :0 \
    -config /etc/X11/xbox-xorg.conf \
    -logfile /tmp/Xorg.0.log \
    -nolisten tcp \
    -keeptty
EOF
chmod 755 "$ROOT/usr/local/bin/xbox-startx"

mkdir -p "$ROOT/dev" "$ROOT/proc" "$ROOT/sys" "$ROOT/run" "$ROOT/tmp" "$ROOT/root"
chmod 1777 "$ROOT/tmp"
mknod -m 600 "$ROOT/dev/console" c 5 1 2>/dev/null || true
mknod -m 666 "$ROOT/dev/null" c 1 3 2>/dev/null || true
mknod -m 666 "$ROOT/dev/zero" c 1 5 2>/dev/null || true
mknod -m 666 "$ROOT/dev/tty" c 5 0 2>/dev/null || true
mknod -m 660 "$ROOT/dev/fb0" c 29 0 2>/dev/null || true
mknod -m 620 "$ROOT/dev/tty0" c 4 0 2>/dev/null || true
mknod -m 620 "$ROOT/dev/tty1" c 4 1 2>/dev/null || true
mkdir -p "$ROOT/dev/input"
mknod -m 660 "$ROOT/dev/input/mice" c 13 63 2>/dev/null || true

rm -rf "$ROOT/var/cache/apt/archives/"*.deb "$ROOT/var/lib/apt/lists/"*

rm -f "$IMAGE"
/usr/sbin/mke2fs -q -t ext2 -F -d "$ROOT" "$IMAGE" "${SIZE_MIB}M"
du -sh "$ROOT"
ls -lh "$IMAGE"
