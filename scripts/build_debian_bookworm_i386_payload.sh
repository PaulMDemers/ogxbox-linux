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
COMPLETE="${9:-0}"
DESKTOP_PLUS="${10:-0}"
BASE_PACKAGES="busybox,sysvinit-core,ifupdown,isc-dhcp-client,iproute2,netbase,procps,psmisc,less,nano,kmod,iputils-ping,wget,ca-certificates"
DESKTOP_PLUS_PACKAGES="fluxbox"
COMPLETE_PACKAGES="dillo links2 mc rsync curl openssh-client netcat-openbsd ftp xfe mtpaint gpicview jwm xpdf sc wordgrinder"
case "$MIRROR $SUITE" in
    *devuan*|*daedalus*|*excalibur*|*ceres*)
        DESKTOP_PLUS_PACKAGES="devuan-keyring $DESKTOP_PLUS_PACKAGES"
        COMPLETE_PACKAGES="devuan-keyring $COMPLETE_PACKAGES"
        ;;
esac

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

if [ "$COMPLETE" = "1" ] && [ ! -e "$ROOT/.xbox-complete-packages-installed" ]; then
    cat > "$ROOT/usr/sbin/policy-rc.d" <<'EOF'
#!/bin/sh
exit 101
EOF
    chmod 755 "$ROOT/usr/sbin/policy-rc.d"
    chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get \
        -o Acquire::AllowInsecureRepositories=true \
        -o APT::Get::AllowUnauthenticated=true \
        update
    chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get \
        -o APT::Get::AllowUnauthenticated=true \
        install -y --no-install-recommends $COMPLETE_PACKAGES
    rm -f "$ROOT/usr/sbin/policy-rc.d"
    touch "$ROOT/.xbox-complete-packages-installed"
fi

if [ "$DESKTOP_PLUS" = "1" ] && [ ! -e "$ROOT/.xbox-desktop-plus-fluxbox-packages-installed" ]; then
    cat > "$ROOT/usr/sbin/policy-rc.d" <<'EOF'
#!/bin/sh
exit 101
EOF
    chmod 755 "$ROOT/usr/sbin/policy-rc.d"
    chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get \
        -o Acquire::AllowInsecureRepositories=true \
        -o APT::Get::AllowUnauthenticated=true \
        update
    chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get \
        -o APT::Get::AllowUnauthenticated=true \
        install -y --no-install-recommends $DESKTOP_PLUS_PACKAGES
    rm -f "$ROOT/usr/sbin/policy-rc.d"
    touch "$ROOT/.xbox-desktop-plus-fluxbox-packages-installed"
fi

if [ "$COMPLETE" = "1" ]; then
    touch "$ROOT/etc/xbox-complete-profile"
else
    rm -f "$ROOT/etc/xbox-complete-profile"
fi
if [ "$DESKTOP_PLUS" = "1" ]; then
    touch "$ROOT/etc/xbox-desktop-plus-profile"
else
    rm -f "$ROOT/etc/xbox-desktop-plus-profile"
fi
if [ "$COMPLETE" = "1" ] && [ "$DESKTOP_PLUS" = "1" ]; then
    touch "$ROOT/etc/xbox-desktop-full-profile"
else
    rm -f "$ROOT/etc/xbox-desktop-full-profile"
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
DIAG_MODE=early
NO_EARLY_HELPERS=0
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        xbox_desktop=1) DESKTOP=1 ;;
        xbox_persist_smoke=1) PERSIST_SMOKE=1 ;;
        xbox_sync_ro_smoke=1) SYNC_RO_SMOKE=1 ;;
        xbox_diag=late) DIAG_MODE=late ;;
        xbox_diag=off) DIAG_MODE=off ;;
        xbox_diag=early) DIAG_MODE=early ;;
        xbox_no_early_helpers=1) NO_EARLY_HELPERS=1 ;;
    esac
done

echo
echo "XBOX_ROOT_INIT_STARTED"
echo "desktop=$DESKTOP persist_smoke=$PERSIST_SMOKE sync_ro_smoke=$SYNC_RO_SMOKE no_early_helpers=$NO_EARLY_HELPERS"
echo
if grep -q 'xbox_init_pause=1' /proc/cmdline 2>/dev/null; then
    echo "xbox_init_pause=1: pausing before early helpers"
    sleep 10
fi
if [ "$NO_EARLY_HELPERS" = "1" ]; then
    echo "early helpers: skipped"
else
    echo "Starting early Xbox helpers"
    xbox-storage-tune >/tmp/xbox-storage-tune.log 2>&1 || true
    echo "storage tune: done"
    xbox-network-up --background >/tmp/xbox-network-up-launch.log 2>&1 || true
    echo "network helper: backgrounded"
    if [ "$DIAG_MODE" = "early" ]; then
        ( xbox-diag >/tmp/xbox-diag.txt 2>&1; echo "diag complete" >/tmp/xbox-diag.done ) &
        echo "diag helper: backgrounded"
    else
        echo "diag helper: $DIAG_MODE"
    fi
fi

if [ "$PERSIST_SMOKE" = "1" ] && [ -x /usr/local/bin/xbox-persist-smoke ]; then
    echo "persistence smoke: running"
    /usr/local/bin/xbox-persist-smoke >/tmp/xbox-persist-smoke.txt 2>&1 || true
    echo "persistence smoke: done"
fi
if [ "$SYNC_RO_SMOKE" = "1" ] && [ -x /usr/local/bin/xbox-sync-ro ]; then
    echo "sync-ro smoke: running"
    /usr/local/bin/xbox-sync-ro >/tmp/xbox-sync-ro.txt 2>&1 || true
    echo "sync-ro smoke: done"
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
ip addr show dev eth0 2>/dev/null || true
ip route 2>/dev/null || true
if [ -s /tmp/xbox-network-up.txt ]; then
    echo
    echo "network startup:"
    tail -40 /tmp/xbox-network-up.txt
fi
echo
echo "tools: ping wget apt xbox-perf xbox-network-up"
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
echo "== network =="
ip link 2>/dev/null || true
echo
ip addr show dev eth0 2>/dev/null || true
echo
ip route 2>/dev/null || true
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
EOF

cat > "$ROOT/usr/local/bin/xbox-network-up" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
LOG=/tmp/xbox-network-up.txt

if [ "${1:-}" = "--background" ]; then
    "$0" --foreground >"$LOG" 2>&1 &
    exit 0
fi

echo "== xbox network up =="
date 2>/dev/null || true
echo

if ! ip link show dev eth0 >/dev/null 2>&1; then
    echo "XBOX_NETWORK_NO_ETH0"
    ip link 2>/dev/null || true
    exit 1
fi

echo "link before:"
ip link show dev eth0 2>/dev/null || true
echo

ip link set dev eth0 up 2>/dev/null || true

if ip addr show dev eth0 2>/dev/null | grep -q ' inet '; then
    echo "XBOX_NETWORK_ALREADY_CONFIGURED"
else
    if command -v ifup >/dev/null 2>&1; then
        echo "running ifup eth0"
        timeout 20 ifup eth0 2>/tmp/xbox-ifup.err || {
            status=$?
            echo "ifup status=$status"
            [ -s /tmp/xbox-ifup.err ] && sed -n '1,40p' /tmp/xbox-ifup.err
        }
    fi

    if ! ip addr show dev eth0 2>/dev/null | grep -q ' inet ' && command -v dhclient >/dev/null 2>&1; then
        echo
        echo "running dhclient eth0"
        mkdir -p /run
        rm -f /run/dhclient.eth0.pid
        timeout 20 dhclient -1 -v -pf /run/dhclient.eth0.pid -lf /run/dhclient.eth0.leases eth0 2>/tmp/xbox-dhclient.err || {
            status=$?
            echo "dhclient status=$status"
            [ -s /tmp/xbox-dhclient.err ] && sed -n '1,60p' /tmp/xbox-dhclient.err
        }
    fi

    if ! ip addr show dev eth0 2>/dev/null | grep -q ' inet ' && command -v udhcpc >/dev/null 2>&1; then
        echo
        echo "running udhcpc eth0"
        timeout 20 udhcpc -i eth0 -n -q 2>/tmp/xbox-udhcpc.err || {
            status=$?
            echo "udhcpc status=$status"
            [ -s /tmp/xbox-udhcpc.err ] && sed -n '1,60p' /tmp/xbox-udhcpc.err
        }
    fi
fi

echo
echo "link after:"
ip link show dev eth0 2>/dev/null || true
echo
echo "addresses:"
ip addr show dev eth0 2>/dev/null || true
echo
echo "routes:"
ip route 2>/dev/null || true
echo
echo "resolver:"
[ -r /etc/resolv.conf ] && cat /etc/resolv.conf || true
echo

if ip addr show dev eth0 2>/dev/null | grep -q ' inet '; then
    echo "XBOX_NETWORK_DHCP_OK"
    exit 0
fi

echo "XBOX_NETWORK_DHCP_FAILED"
exit 1
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
ROOT_DEV="$(awk '$2 == "/" { print $1; exit }' /proc/mounts 2>/dev/null)"
if [ -w /proc/sysrq-trigger ]; then
    echo 1 > /proc/sys/kernel/sysrq 2>/dev/null || true
    echo u > /proc/sysrq-trigger 2>/dev/null || true
    sleep 2
    if awk '$2 == "/" && $4 ~ /(^|,)ro(,|$)/ { found=1 } END { exit found ? 0 : 1 }' /proc/mounts 2>/dev/null; then
        echo "XBOX_ROOT_REMOUNT_RO_OK"
        echo "It is now safer to power off or reset."
        exit 0
    fi
fi
if [ -n "$ROOT_DEV" ] && [ -x /bin/busybox ] && /bin/busybox mount -o remount,ro "$ROOT_DEV" /; then
    echo "XBOX_ROOT_REMOUNT_RO_OK"
    echo "It is now safer to power off or reset."
    exit 0
fi
if [ -n "$ROOT_DEV" ] && mount -n -o remount,ro "$ROOT_DEV" /; then
    echo "XBOX_ROOT_REMOUNT_RO_OK"
    echo "It is now safer to power off or reset."
    exit 0
fi
if mount -n -o remount,ro /; then
    echo "XBOX_ROOT_REMOUNT_RO_OK"
    echo "It is now safer to power off or reset."
    exit 0
fi

echo "XBOX_ROOT_REMOUNT_RO_FAILED"
echo "Some process may still have writable files open. Run sync again before power-off."
exit 1
EOF
chmod 755 "$ROOT/usr/local/bin/xbox-storage-tune" "$ROOT/usr/local/bin/xbox-network-up" "$ROOT/usr/local/bin/xbox-diag" "$ROOT/usr/local/bin/xbox-perf" "$ROOT/usr/local/bin/xbox-persist-smoke" "$ROOT/usr/local/bin/xbox-sync-ro"

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

cat > "$ROOT/usr/local/bin/xbox-plus-shell" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
export TERM="${TERM:-xterm}"
export HOME="${HOME:-/tmp/root-home}"
cd "$HOME" 2>/dev/null || cd /
printf 'XBOX_DEVUAN_DESKTOP_PLUS_SHELL\n'
exec /bin/sh -i
EOF

cat > "$ROOT/usr/local/bin/xbox-plus-proof" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
export TERM="${TERM:-xterm}"
export HOME="${HOME:-/tmp/root-home}"
cd "$HOME" 2>/dev/null || cd /
printf 'XBOX_DEVUAN_DESKTOP_PLUS_OK\n'
printf 'tools: xbox-perf xbox-sync-ro xbox-network-up\n'
printf 'logs: /tmp/xbox-diag.txt /tmp/xbox-network-up.txt /tmp/xsession.log\n'
printf 'right-click or use toolbar/menu\n'
exec /bin/sh -i
EOF

cat > "$ROOT/usr/local/bin/xbox-plus-perf" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
export TERM="${TERM:-xterm}"
export HOME="${HOME:-/tmp/root-home}"
cd "$HOME" 2>/dev/null || cd /
xbox-perf
exec /bin/sh -i
EOF

cat > "$ROOT/usr/local/bin/xbox-plus-network" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
export TERM="${TERM:-xterm}"
export HOME="${HOME:-/tmp/root-home}"
cd "$HOME" 2>/dev/null || cd /
cat /tmp/xbox-network-up.txt 2>/dev/null || printf 'network log not present yet\n'
exec /bin/sh -i
EOF

cat > "$ROOT/usr/local/bin/xbox-desktop-info" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
exec xterm -geometry 82x24+24+48 -title "Xbox System" -e /bin/sh -lc '
echo XBOX_DEVUAN_DESKTOP_FULL_INFO
echo
cat /etc/os-release 2>/dev/null | sed -n "1,5p"
echo
echo network:
ip addr show dev eth0 2>/dev/null || true
grep -E "XBOX_NETWORK_(DHCP_OK|DHCP_FAILED|NO_ETH0)" /tmp/xbox-network-up.txt 2>/dev/null || true
echo
echo memory:
grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree" /proc/meminfo 2>/dev/null
echo
echo storage:
df -h /
echo
echo useful commands:
echo "  xbox-perf"
echo "  xbox-network-up"
echo "  xbox-sync-ro"
echo "  apt update"
echo
exec /bin/sh -i'
EOF

cat > "$ROOT/usr/local/bin/xbox-app-launcher" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
clear
while :; do
    cat <<'EOM'
Xbox Devuan app launcher

1  Terminal
2  File manager
3  Browser
4  Editor
5  Paint
6  PDF viewer
7  Network status
8  System status
9  Safe sync/remount read-only
q  Quit

EOM
    printf 'choice> '
    read ans || exit 0
    case "$ans" in
        1) exec /bin/sh -i ;;
        2) command -v mc >/dev/null 2>&1 && mc || ls -la / ;;
        3) command -v links2 >/dev/null 2>&1 && links2 || printf 'links2 not installed\n' ;;
        4) command -v nano >/dev/null 2>&1 && nano || vi ;;
        5) command -v mtpaint >/dev/null 2>&1 && mtpaint >/tmp/mtpaint.log 2>&1 & ;;
        6) command -v xpdf >/dev/null 2>&1 && xpdf >/tmp/xpdf.log 2>&1 & ;;
        7) xbox-plus-network ;;
        8) xbox-plus-perf ;;
        9) xbox-sync-ro; printf '\nPress Enter to continue'; read _ ;;
        q|Q) exit 0 ;;
    esac
done
EOF

cat > "$ROOT/usr/local/bin/xbox-open-files" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
if [ -n "${DISPLAY:-}" ] && command -v xfe >/dev/null 2>&1; then
    exec xfe
fi
if command -v mc >/dev/null 2>&1; then
    exec xterm -geometry 82x24+28+52 -title "Files" -e mc
fi
exec xterm -geometry 82x24+28+52 -title "Files" -e /bin/sh -lc 'ls -la /; exec /bin/sh -i'
EOF

cat > "$ROOT/usr/local/bin/xbox-browser" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
if [ -n "${DISPLAY:-}" ] && command -v dillo >/dev/null 2>&1; then
    exec dillo about:splash
fi
if command -v links2 >/dev/null 2>&1; then
    exec xterm -geometry 82x24+28+52 -title "Browser" -e links2
fi
exec xterm -geometry 82x24+28+52 -title "Browser" -e /bin/sh -lc 'echo no browser installed; exec /bin/sh -i'
EOF

cat > "$ROOT/usr/local/bin/xbox-editor" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
exec xterm -geometry 82x24+28+52 -title "Editor" -e /bin/sh -lc 'cd /root 2>/dev/null || cd /; exec nano'
EOF

cat > "$ROOT/usr/local/bin/xbox-safe-poweroff" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin
exec xterm -geometry 82x18+28+52 -title "Safe Shutdown" -e /bin/sh -lc '
echo "Syncing filesystem and attempting read-only remount..."
echo
xbox-sync-ro
echo
echo "If the remount succeeded, it is safer to power off or reset."
echo "Press Enter to close this window."
read _
'
EOF
chmod 755 "$ROOT/usr/local/bin/xbox-terminal" "$ROOT/usr/local/bin/xterm" "$ROOT/usr/local/bin/xbox-plus-shell" "$ROOT/usr/local/bin/xbox-plus-proof" "$ROOT/usr/local/bin/xbox-plus-perf" "$ROOT/usr/local/bin/xbox-plus-network" "$ROOT/usr/local/bin/xbox-desktop-info" "$ROOT/usr/local/bin/xbox-app-launcher" "$ROOT/usr/local/bin/xbox-open-files" "$ROOT/usr/local/bin/xbox-browser" "$ROOT/usr/local/bin/xbox-editor" "$ROOT/usr/local/bin/xbox-safe-poweroff"

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

TERMINAL_LIGHT=0
DIAG_MODE=early
FLUXBOX_LITE=0
PRELOAD_FLUXBOX=0
for arg in $(cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        xbox_terminal_light=1) TERMINAL_LIGHT=1 ;;
        xbox_diag=late) DIAG_MODE=late ;;
        xbox_diag=off) DIAG_MODE=off ;;
        xbox_diag=early) DIAG_MODE=early ;;
        xbox_fluxbox_lite=1) FLUXBOX_LITE=1 ;;
        xbox_preload_fluxbox=1) PRELOAD_FLUXBOX=1 ;;
    esac
done

start_late_diag() {
    [ "$DIAG_MODE" = "late" ] || return 0
    ( sleep 8; xbox-diag >/tmp/xbox-diag.txt 2>&1; echo "diag complete" >/tmp/xbox-diag.done ) &
}

cat > "$HOME/.jwmrc" <<'EORC'
<?xml version="1.0"?>
<JWM>
  <RootMenu onroot="123">
    <Program label="Terminal">xterm</Program>
    <Program label="System Monitor">xterm -e sh -lc 'xbox-perf; exec sh -i'</Program>
    <Program label="Network Status">xterm -e sh -lc 'cat /tmp/xbox-network-up.txt; exec sh -i'</Program>
    <Program label="Shell">xterm -e sh -i</Program>
    <Restart label="Restart JWM"/>
    <Exit label="Exit X"/>
  </RootMenu>
  <Tray x="0" y="32" width="-1" height="28" autohide="off">
    <TrayButton label="Menu">root:1</TrayButton>
    <Spacer width="2"/>
    <TrayButton label="_">showdesktop</TrayButton>
    <Spacer width="2"/>
    <TaskList maxwidth="256"/>
    <Clock format="%H:%M"/>
  </Tray>
</JWM>
EORC

if [ -f /etc/xbox-complete-profile ]; then
    sed -i '/<Program label="System Monitor">/a\
    <Program label="Dillo Browser">dillo</Program>\
    <Program label="Links2 Browser">xterm -e links2</Program>\
    <Program label="Xfe File Manager">xfe</Program>\
    <Program label="Midnight Commander">xterm -e mc</Program>\
    <Program label="mtPaint">mtpaint</Program>\
    <Program label="Image Viewer">gpicview</Program>\
    <Program label="PDF Viewer">xpdf</Program>\
    <Program label="WordGrinder">xterm -e wordgrinder</Program>\
    <Program label="SC Spreadsheet">xterm -e sc</Program>' "$HOME/.jwmrc"
fi

xsetroot -solid '#1f3f4f' 2>/dev/null || true
if [ -f /etc/xbox-desktop-plus-profile ] && command -v fluxbox >/dev/null 2>&1 && command -v aterm >/dev/null 2>&1; then
    mkdir -p "$HOME/.fluxbox"
    if [ -f /etc/xbox-desktop-full-profile ]; then
        cat > "$HOME/.fluxbox/menu" <<'EOFBMENU'
[begin] (Xbox Devuan)
  [exec] (Terminal) {xterm -e /usr/local/bin/xbox-plus-shell}
  [exec] (App Launcher) {xterm -geometry 82x24+32+56 -title "Apps" -e /usr/local/bin/xbox-app-launcher}
  [submenu] (Applications)
    [exec] (File Manager) {/usr/local/bin/xbox-open-files}
    [exec] (Browser) {/usr/local/bin/xbox-browser}
    [exec] (Editor) {/usr/local/bin/xbox-editor}
    [exec] (Paint) {mtpaint}
    [exec] (Image Viewer) {gpicview}
    [exec] (PDF Viewer) {xpdf}
    [exec] (Word Processor) {xterm -geometry 82x24+32+56 -title "WordGrinder" -e wordgrinder}
    [exec] (Spreadsheet) {xterm -geometry 82x24+32+56 -title "SC" -e sc}
  [end]
  [submenu] (System)
    [exec] (System Status) {/usr/local/bin/xbox-desktop-info}
    [exec] (System Monitor) {xterm -e /usr/local/bin/xbox-plus-perf}
    [exec] (Network Status) {xterm -e /usr/local/bin/xbox-plus-network}
    [exec] (Safe Shutdown) {/usr/local/bin/xbox-safe-poweroff}
  [end]
  [submenu] (Shells)
    [exec] (Root Shell) {xterm -e /bin/sh -i}
    [exec] (Midnight Commander) {xterm -geometry 82x24+32+56 -title "Files" -e mc}
    [exec] (Links Browser) {xterm -geometry 82x24+32+56 -title "Links2" -e links2}
  [end]
  [restart] (Restart Fluxbox)
  [exit] (Exit X)
[end]
EOFBMENU
    else
        cat > "$HOME/.fluxbox/menu" <<'EOFBMENU'
[begin] (Xbox Devuan)
  [exec] (Terminal) {xterm -e /usr/local/bin/xbox-plus-shell}
  [exec] (System Monitor) {xterm -e /usr/local/bin/xbox-plus-perf}
  [exec] (Network Status) {xterm -e /usr/local/bin/xbox-plus-network}
  [exec] (Shell) {xterm -e /bin/sh -i}
  [restart] (Restart Fluxbox)
  [exit] (Exit X)
[end]
EOFBMENU
    fi
    cat > "$HOME/.fluxbox/init" <<'EOFBINIT'
session.screen0.toolbar.visible: true
session.screen0.toolbar.placement: BottomCenter
session.screen0.toolbar.widthPercent: 100
session.screen0.strftimeFormat: %H:%M
session.screen0.slit.autoHide: false
session.menuFile: ~/.fluxbox/menu
session.styleFile: /usr/share/fluxbox/styles/Meta
EOFBINIT
    if [ "$FLUXBOX_LITE" = "1" ]; then
        cat > "$HOME/.fluxbox/xbox-lite-style" <<'EOFBSTYLE'
*.font: fixed
toolbar: flat
toolbar.color: #6f859a
toolbar.label: flat
toolbar.label.color: #6f859a
toolbar.windowLabel: flat
toolbar.windowLabel.color: #6f859a
toolbar.clock: flat
toolbar.clock.color: #6f859a
window.title.focus: flat
window.title.focus.color: #6f859a
window.title.unfocus: flat
window.title.unfocus.color: #596672
window.label.focus: flat
window.label.focus.color: #6f859a
window.label.unfocus: flat
window.label.unfocus.color: #596672
window.button.focus: flat
window.button.focus.color: #6f859a
window.button.unfocus: flat
window.button.unfocus.color: #596672
window.handle.focus: flat
window.handle.focus.color: #6f859a
window.handle.unfocus: flat
window.handle.unfocus.color: #596672
menu.title: flat
menu.title.color: #6f859a
menu.frame: flat
menu.frame.color: #d8dde8
menu.hilite: flat
menu.hilite.color: #6f859a
EOFBSTYLE
        sed -i "s#^session.styleFile:.*#session.styleFile: $HOME/.fluxbox/xbox-lite-style#" "$HOME/.fluxbox/init"
    fi
    {
        echo "launching desktop-plus proof terminal"
        date 2>/dev/null || true
        command -v aterm 2>/dev/null || true
        command -v xterm 2>/dev/null || true
    } >/tmp/xbox-plus-session.log 2>&1
    if [ -f /etc/xbox-desktop-full-profile ]; then
        mkdir -p "$HOME/Desktop"
        cat > "$HOME/Desktop/README.txt" <<'EOFDESKTOP'
Xbox Devuan full desktop

Right-click the desktop for the Fluxbox menu. The dock at the bottom launches
the app menu, terminal, file manager, browser, editor, system status, and safe
shutdown helper.
EOFDESKTOP
        if command -v wbar >/dev/null 2>&1; then
            cat > "$HOME/.wbar" <<'EOFWBAR'
i: /usr/local/share/pixmaps/apps.png
t: Apps
c: xterm -geometry 82x24+32+56 -title Apps -e /usr/local/bin/xbox-app-launcher

i: /usr/local/share/pixmaps/aterm.png
t: Terminal
c: xterm -e /usr/local/bin/xbox-plus-shell

i: /usr/local/share/pixmaps/core.png
t: Files
c: /usr/local/bin/xbox-open-files

i: /usr/local/share/pixmaps/flrun.png
t: Browser
c: /usr/local/bin/xbox-browser

i: /usr/local/share/pixmaps/editor.png
t: Editor
c: /usr/local/bin/xbox-editor

i: /usr/local/share/pixmaps/cpanel.png
t: System
c: /usr/local/bin/xbox-desktop-info

i: /usr/local/share/pixmaps/exittc.png
t: Safe Shutdown
c: /usr/local/bin/xbox-safe-poweroff
EOFWBAR
            ( sleep 5; wbar -config "$HOME/.wbar" -above-desk -pos bottom -isize 32 -idist 8 -zoomf 1.15 >/tmp/wbar.log 2>&1 ) &
        fi
    fi
    FLUXBOX_BIN="$(command -v fluxbox)"
    if [ "$PRELOAD_FLUXBOX" = "1" ]; then
        preload_file() {
            src="$1"
            [ -n "$src" ] && [ -f "$src" ] || return 0
            dd if="$src" of=/dev/null bs=64k 2>/dev/null || cat "$src" >/dev/null 2>&1 || true
        }
        {
            echo "fluxbox page-cache preload begin"
            date 2>/dev/null || true
            preload_file "$FLUXBOX_BIN"
            if command -v ldd >/dev/null 2>&1; then
                ldd "$FLUXBOX_BIN" 2>/dev/null | while read -r a b c rest; do
                    case "$a" in /*) echo "$a"; preload_file "$a" ;; esac
                    case "$b" in /*) echo "$b"; preload_file "$b" ;; esac
                    case "$c" in /*) echo "$c"; preload_file "$c" ;; esac
                done
            fi
            date 2>/dev/null || true
            echo "fluxbox page-cache preload end"
        } >>/tmp/xbox-plus-session.log 2>&1
    fi
    if [ "$FLUXBOX_LITE" = "1" ]; then
        ( sleep 3; xterm -geometry 78x20+20+32 -title "Xbox Devuan Plus" -e /usr/local/bin/xbox-plus-proof >/tmp/aterm.log 2>&1 ) &
    else
        xterm -geometry 78x20+20+32 -title "Xbox Devuan Plus" -e /usr/local/bin/xbox-plus-proof >/tmp/aterm.log 2>&1 &
    fi
    start_late_diag
    exec "$FLUXBOX_BIN" >/tmp/fluxbox.log 2>&1
fi
if [ \( -f /etc/xbox-complete-profile -o -f /etc/xbox-desktop-plus-profile \) ] && command -v jwm >/dev/null 2>&1 && command -v aterm >/dev/null 2>&1; then
    if [ -f /etc/xbox-desktop-plus-profile ]; then
        MARKER="XBOX_DEVUAN_DESKTOP_PLUS_OK"
        TITLE="Xbox Devuan Plus"
    else
        MARKER="XBOX_DEVUAN_COMPLETE_DESKTOP_OK"
        TITLE="Xbox Devuan Complete"
    fi
    if [ "$TERMINAL_LIGHT" = "1" ]; then
        aterm -fn fixed -fg white -bg black -geometry 78x20+20+72 -title "$TITLE" -e /bin/sh -lc "echo $MARKER; echo tools: xbox-perf xbox-sync-ro xbox-network-up; echo logs: /tmp/xbox-diag.txt /tmp/xbox-network-up.txt; echo right-click or use taskbar Menu; exec /bin/sh -i" >/tmp/aterm.log 2>&1 &
    else
        aterm -fn fixed -fg white -bg black -geometry 78x20+20+72 -title "$TITLE" -e /bin/sh -lc "echo $MARKER; uname -a; echo; cat /etc/os-release 2>/dev/null | sed -n '1,4p'; echo; echo tools: ping wget apt xbox-perf xbox-sync-ro xbox-network-up; echo; echo network:; ip addr show dev eth0 2>/dev/null || true; grep -E 'XBOX_NETWORK_(DHCP_OK|DHCP_FAILED|NO_ETH0)' /tmp/xbox-network-up.txt 2>/dev/null || true; echo; echo right-click or use taskbar Menu; echo diag: /tmp/xbox-diag.txt; echo network log: /tmp/xbox-network-up.txt; exec /bin/sh -i" >/tmp/aterm.log 2>&1 &
    fi
    start_late_diag
    exec jwm -f "$HOME/.jwmrc" >/tmp/jwm.log 2>&1
fi
if command -v flwm_topside >/dev/null 2>&1 && command -v aterm >/dev/null 2>&1; then
    if [ "$TERMINAL_LIGHT" = "1" ]; then
        aterm -fn fixed -fg white -bg black -geometry 78x24+20+32 -title "Xbox Debian" -e /bin/sh -lc 'echo XBOX_DEBIAN_X_DESKTOP_OK; echo tools: ping wget apt xbox-perf xbox-sync-ro xbox-network-up; echo logs: /tmp/xbox-diag.txt /tmp/xbox-network-up.txt; exec /bin/sh -i' >/tmp/aterm.log 2>&1 &
    else
        aterm -fn fixed -fg white -bg black -geometry 78x24+20+32 -title "Xbox Debian" -e /bin/sh -lc 'echo XBOX_DEBIAN_X_DESKTOP_OK; uname -a; echo; echo memory:; grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree" /proc/meminfo 2>/dev/null; echo; echo tools: ping wget apt xbox-perf xbox-sync-ro xbox-network-up; echo; echo network:; ip addr show dev eth0 2>/dev/null || true; grep -E "XBOX_NETWORK_(DHCP_OK|DHCP_FAILED|NO_ETH0)" /tmp/xbox-network-up.txt 2>/dev/null || true; echo; echo read-ahead:; grep read_ahead_kb /tmp/xbox-diag.txt 2>/dev/null || true; echo; if [ -s /tmp/xbox-persist-smoke.txt ]; then echo persistence:; grep -E "XBOX_(PERSIST_MARKER|NORMAL_USE_FILE)_(WRITTEN|PRESENT|WRITE_FAILED|RENAME_FAILED|20260526)" /tmp/xbox-persist-smoke.txt 2>/dev/null || tail -10 /tmp/xbox-persist-smoke.txt; echo; fi; if [ -s /tmp/xbox-sync-ro.txt ]; then echo sync-ro:; grep -E "XBOX_ROOT_REMOUNT_RO_(OK|FAILED)" /tmp/xbox-sync-ro.txt 2>/dev/null || cat /tmp/xbox-sync-ro.txt; echo; fi; echo diag: /tmp/xbox-diag.txt; echo network log: /tmp/xbox-network-up.txt; exec /bin/sh -i' >/tmp/aterm.log 2>&1 &
    fi
    start_late_diag
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
    XFBDEV_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
    export DISPLAY=:0
    echo "Starting Xfbdev server"
    if [ "$X_MOUSE" = "1" ]; then
        echo "Xfbdev explicit mouse device: /dev/input/mice"
        LD_LIBRARY_PATH="$XFBDEV_LIBRARY_PATH" /usr/local/bin/Xfbdev :0 -screen 640x480x32 -mouse /dev/input/mice,5 -nolisten tcp >/tmp/xfbdev.log 2>&1 &
    else
        echo "Xfbdev explicit mouse device: disabled; default pointer input may still work"
        LD_LIBRARY_PATH="$XFBDEV_LIBRARY_PATH" /usr/local/bin/Xfbdev :0 -screen 640x480x32 -nolisten tcp >/tmp/xfbdev.log 2>&1 &
    fi
    XPID=$!
    sleep 2
    if ! kill -0 "$XPID" 2>/dev/null; then
        echo "Xfbdev exited before session start"
        cat /tmp/xfbdev.log 2>/dev/null || true
        exit 1
    fi
    echo "Starting X session"
    if [ -f /etc/xbox-desktop-plus-profile ] || [ -f /etc/xbox-complete-profile ]; then
        unset LD_LIBRARY_PATH
    else
        export LD_LIBRARY_PATH="$XFBDEV_LIBRARY_PATH"
    fi
    /usr/local/bin/xbox-xsession >/tmp/xsession.log 2>&1
    status=$?
    echo "X session exited with status $status"
    cat /tmp/xsession.log 2>/dev/null || true
    if [ -s /tmp/fluxbox.log ]; then
        echo "Fluxbox log:"
        cat /tmp/fluxbox.log
    fi
    if [ -s /tmp/aterm.log ]; then
        echo "Terminal log:"
        cat /tmp/aterm.log
    fi
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
