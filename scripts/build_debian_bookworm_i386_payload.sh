#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/home/paul/ogxbox/distro-build/debian-bookworm-i386-root}"
IMAGE="${2:-/mnt/c/Users/Paul/Desktop/xbox_linux/artifacts/hdd/xbox-debian-bookworm-i386.ext2}"
SUITE="${3:-bookworm}"
ARCH="${4:-i386}"
MIRROR="${5:-http://deb.debian.org/debian}"
SIZE_MIB="${6:-512}"
FORCE="${7:-0}"

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

if [ ! -x "$ROOT/bin/sh" ]; then
    debootstrap \
        --arch="$ARCH" \
        --variant=minbase \
        --include=busybox,sysvinit-core,ifupdown,isc-dhcp-client,iproute2,netbase,procps,psmisc,less,nano,kmod \
        "$SUITE" "$ROOT" "$MIRROR"
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
mount -t tmpfs -o mode=0755,nosuid,nodev,size=8m tmpfs /run 2>/dev/null || true
mount -t tmpfs -o mode=1777,nosuid,nodev,size=16m tmpfs /tmp 2>/dev/null || true

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TERM=linux
export HOME=/root

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
echo "Launching Debian proof shell on /dev/console"
echo

exec /bin/sh -i
EOF
chmod 755 "$ROOT/xbox-init"

mkdir -p "$ROOT/dev" "$ROOT/proc" "$ROOT/sys" "$ROOT/run" "$ROOT/tmp" "$ROOT/root"
chmod 1777 "$ROOT/tmp"
mknod -m 600 "$ROOT/dev/console" c 5 1 2>/dev/null || true
mknod -m 666 "$ROOT/dev/null" c 1 3 2>/dev/null || true
mknod -m 666 "$ROOT/dev/zero" c 1 5 2>/dev/null || true
mknod -m 666 "$ROOT/dev/tty" c 5 0 2>/dev/null || true

rm -rf "$ROOT/var/cache/apt/archives/"*.deb "$ROOT/var/lib/apt/lists/"*

rm -f "$IMAGE"
/usr/sbin/mke2fs -q -t ext2 -F -d "$ROOT" "$IMAGE" "${SIZE_MIB}M"
du -sh "$ROOT"
ls -lh "$IMAGE"
