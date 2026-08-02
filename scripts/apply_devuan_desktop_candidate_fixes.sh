#!/bin/sh
set -eu

SQUASHFS="$1"
ROOT="$2"
LAUNCHER_REL="usr/local/bin/xbox-launch-app"

rm -rf "$ROOT"
mkdir -p "$ROOT"
unsquashfs -d "$ROOT" "$SQUASHFS" >/tmp/xbox-candidate-unsquashfs.out

LAUNCHER="$ROOT/$LAUNCHER_REL"
if ! grep -q '^export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib$' "$LAUNCHER"; then
    echo "Expected launcher library override was not found: $LAUNCHER" >&2
    exit 1
fi
sed -i 's|^export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib$|unset LD_LIBRARY_PATH|' "$LAUNCHER"

rm -f "$SQUASHFS"
mksquashfs "$ROOT" "$SQUASHFS" -noappend -comp gzip -b 131072 >/tmp/xbox-candidate-mksquashfs.out
rm -rf "$ROOT"
