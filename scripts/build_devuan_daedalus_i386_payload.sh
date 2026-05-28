#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/home/paul/ogxbox/distro-build/devuan-daedalus-i386-root}"
IMAGE="${2:-/mnt/c/Users/Paul/Desktop/xbox_linux/artifacts/hdd/xbox-devuan-daedalus-i386.ext2}"
SUITE="${3:-daedalus}"
ARCH="${4:-i386}"
MIRROR="${5:-https://pkgmaster.devuan.org/merged}"
SIZE_MIB="${6:-384}"
FORCE="${7:-0}"
DESKTOP="${8:-0}"
COMPLETE="${9:-0}"
DESKTOP_PLUS="${10:-0}"

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_BUILDER="$THIS_DIR/build_debian_bookworm_i386_payload.sh"
if [ ! -x "$BASE_BUILDER" ]; then
    chmod 755 "$BASE_BUILDER"
fi

if [ ! -e /usr/share/debootstrap/scripts/"$SUITE" ]; then
    if [ -e /usr/share/debootstrap/scripts/ceres ]; then
        ln -sf /usr/share/debootstrap/scripts/ceres /usr/share/debootstrap/scripts/"$SUITE"
    else
        echo "missing Devuan debootstrap script: /usr/share/debootstrap/scripts/ceres" >&2
        exit 1
    fi
fi

WRAP_DIR="$(mktemp -d)"
trap 'rm -rf "$WRAP_DIR"' EXIT
cat > "$WRAP_DIR/debootstrap" <<'EOF'
#!/bin/sh
exec /usr/sbin/debootstrap --no-check-gpg "$@"
EOF
chmod 755 "$WRAP_DIR/debootstrap"

PATH="$WRAP_DIR:$PATH" "$BASE_BUILDER" "$ROOT" "$IMAGE" "$SUITE" "$ARCH" "$MIRROR" "$SIZE_MIB" "$FORCE" "$DESKTOP" "$COMPLETE" "$DESKTOP_PLUS"

cat > "$ROOT/etc/hostname" <<'EOF'
xbox-devuan
EOF

cat > "$ROOT/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 xbox-devuan
EOF

cat > "$ROOT/etc/apt/sources.list" <<EOF
deb $MIRROR $SUITE main contrib non-free non-free-firmware
deb $MIRROR ${SUITE}-security main contrib non-free non-free-firmware
deb $MIRROR ${SUITE}-updates main contrib non-free non-free-firmware
EOF

cat > "$ROOT/etc/issue" <<'EOF'
Xbox Devuan Daedalus i386 proof console
EOF

if [ -e "$ROOT/xbox-init" ]; then
    sed -i \
        -e 's/XBOX_DEBIAN_BOOKWORM_I386_ROOT_OK/XBOX_DEVUAN_DAEDALUS_I386_ROOT_OK/g' \
        -e 's/XBOX_DEBIAN_X_DESKTOP_OK/XBOX_DEVUAN_X_DESKTOP_OK/g' \
        -e 's/Launching Debian X proof desktop/Launching Devuan X proof desktop/g' \
        -e 's/Launching Debian proof shell/Launching Devuan proof shell/g' \
        "$ROOT/xbox-init"
fi

for file in \
    "$ROOT/usr/local/bin/xbox-diag" \
    "$ROOT/usr/local/bin/xbox-xsession" \
    "$ROOT/usr/local/bin/xbox-terminal"; do
    [ -e "$file" ] || continue
    sed -i \
        -e 's/Xbox Debian/Xbox Devuan/g' \
        -e 's/xbox debian diag/xbox devuan diag/g' \
        -e 's/XBOX_DEBIAN_X_DESKTOP_OK/XBOX_DEVUAN_X_DESKTOP_OK/g' \
        "$file"
done

rm -rf "$ROOT/var/cache/apt/archives/"*.deb "$ROOT/var/lib/apt/lists/"*
rm -f "$IMAGE"
/usr/sbin/mke2fs -q -t ext2 -F -d "$ROOT" "$IMAGE" "${SIZE_MIB}M"
du -sh "$ROOT"
ls -lh "$IMAGE"
