#!/bin/sh
set -eu

ROOT="${1:-/home/paul/ogxbox/distro-build/devuan-daedalus-i386-desktop-full-root}"
REPORT="${2:-/mnt/c/Users/Paul/Desktop/xbox_linux/artifacts/reports/devuan-desktop-app-smoke.txt}"

mkdir -p "$(dirname "$REPORT")"
{
    echo "Devuan desktop app smoke"
    date -u
    echo "root=$ROOT"
    echo
    apps="xterm aterm fluxbox jwm xfe dillo links2 mc mtpaint gpicview xpdf wordgrinder sc nano"
    failed=0
    for app in $apps; do
        echo "== $app =="
        if ! chroot "$ROOT" /bin/sh -lc "command -v $app" >/tmp/xbox-app-path.txt 2>/tmp/xbox-app-command.err; then
            echo "MISSING"
            sed -n '1,20p' /tmp/xbox-app-command.err
            failed=1
            echo
            continue
        fi
        path=$(cat /tmp/xbox-app-path.txt)
        echo "path=$path"
        if chroot "$ROOT" /bin/sh -lc "ldd '$path'" >/tmp/ldd.out 2>/tmp/ldd.err; then
            if grep -q "not found" /tmp/ldd.out; then
                echo "LDD_MISSING_DEPS"
                grep "not found" /tmp/ldd.out
                failed=1
            else
                echo "LDD_OK"
            fi
        else
            if grep -qi "not a dynamic executable" /tmp/ldd.err /tmp/ldd.out 2>/dev/null; then
                echo "SCRIPT_OR_STATIC"
                chroot "$ROOT" /bin/sh -lc "sed -n '1p' '$path' 2>/dev/null || true"
            else
                echo "LDD_FAILED"
                sed -n '1,40p' /tmp/ldd.err
                failed=1
            fi
        fi
        echo
    done
    echo "== helper scripts =="
    for helper in xbox-app-launcher xbox-launch-app xbox-open-files xbox-browser xbox-editor xbox-desktop-info xbox-safe-poweroff xbox-plus-shell xbox-plus-proof xbox-network-up; do
        printf '%s: ' "$helper"
        if chroot "$ROOT" /bin/sh -lc "command -v $helper" >/dev/null 2>&1; then
            echo OK
        else
            echo MISSING
            failed=1
        fi
    done
    echo
    if [ "$failed" -eq 0 ]; then
        echo "XBOX_APP_SMOKE_OK"
    else
        echo "XBOX_APP_SMOKE_FAILED"
    fi
    exit "$failed"
} | tee "$REPORT"
