#!/bin/sh
set -eu

SQUASHFS="$1"
ROOT="$2"
REPORT="$3"
SMOKE_SCRIPT="$4"

rm -rf "$ROOT"
mkdir -p "$ROOT" "$(dirname "$REPORT")"
unsquashfs -d "$ROOT" "$SQUASHFS" >/tmp/xbox-unsquashfs.out

"$SMOKE_SCRIPT" "$ROOT" "$REPORT"

{
    echo
    echo "== exact payload summary =="
    echo "squashfs=$SQUASHFS"
    unsquashfs -s "$SQUASHFS" | sed -n '1,24p'
    echo
    echo "root-size=$(du -sh "$ROOT" | awk '{print $1}')"
    # shellcheck disable=SC2016 # dpkg-query, not the shell, expands ${Package}.
    echo "dpkg-packages=$(chroot "$ROOT" /usr/bin/dpkg-query -W -f='${Package}\n' 2>/dev/null | wc -l)"
    echo
    echo "== desktop profile markers =="
    for marker in xbox-desktop-plus-profile xbox-desktop-full-profile xbox-complete-profile; do
        if [ -f "$ROOT/etc/$marker" ]; then
            echo "$marker=present"
        else
            echo "$marker=missing"
        fi
    done
    echo
    echo "== launcher contract =="
    launcher="$ROOT/usr/local/bin/xbox-launch-app"
    grep -q 'run_foreground()' "$launcher"
    grep -q 'run_gui()' "$launcher"
    grep -q 'XBOX_APP_RUNNING' "$launcher"
    grep -q '^unset LD_LIBRARY_PATH$' "$launcher"
    echo "xbox-launch-app=instrumented"
    echo
    echo "== largest installed packages (KiB) =="
    # shellcheck disable=SC2016 # These are dpkg-query format fields.
    chroot "$ROOT" /usr/bin/dpkg-query -W -f='${Installed-Size}\t${Package}\t${Version}\n' 2>/dev/null |
        sort -nr | sed -n '1,20p'
    echo
    echo "XBOX_EXACT_PAYLOAD_AUDIT_OK"
} | tee -a "$REPORT"
