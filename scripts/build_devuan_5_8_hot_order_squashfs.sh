#!/bin/bash
set -euo pipefail

SOURCE_SQUASHFS="$1"
CONTROL_SQUASHFS="$2"
HOT_SQUASHFS="$3"
SCRATCH_ROOT="$4"
SORT_FILE="$5"
REPORT_FILE="$6"

rm -rf "$SCRATCH_ROOT"
mkdir -p "$SCRATCH_ROOT" "$(dirname "$CONTROL_SQUASHFS")" \
    "$(dirname "$HOT_SQUASHFS")" "$(dirname "$SORT_FILE")" \
    "$(dirname "$REPORT_FILE")"
unsquashfs -d "$SCRATCH_ROOT" "$SOURCE_SQUASHFS" >/tmp/xbox-hot-order-unsquashfs.out

RAW_SORT="${SORT_FILE}.raw"
: > "$RAW_SORT"

add_path() {
    local path="${1#/}"
    local priority="$2"
    local resolved

    [ -e "$SCRATCH_ROOT/$path" ] || [ -L "$SCRATCH_ROOT/$path" ] || return 0
    printf '%s\t%s\n' "$path" "$priority" >> "$RAW_SORT"

    resolved=$(readlink -f "$SCRATCH_ROOT/$path" 2>/dev/null || true)
    case "$resolved" in
        "$SCRATCH_ROOT"/*)
            resolved="${resolved#"$SCRATCH_ROOT"/}"
            printf '%s\t%s\n' "$resolved" "$priority" >> "$RAW_SORT"
            ;;
    esac
}

add_binary_closure() {
    local path="${1#/}"
    local priority="$2"
    local dependency

    add_path "$path" "$priority"
    [ -f "$SCRATCH_ROOT/$path" ] || return 0

    while IFS= read -r dependency; do
        [ -n "$dependency" ] && add_path "$dependency" "$priority"
    done < <(
        chroot "$SCRATCH_ROOT" /bin/sh -c \
            "unset LD_LIBRARY_PATH; ldd '/$path' 2>/dev/null || true" |
            awk '
                $2 == "=>" && $3 ~ /^\// { print $3 }
                $1 ~ /^\// { print $1 }
            '
    )
}

# Startup path: init, framebuffer X server, first terminal, and Fluxbox.
for path in \
    xbox-init \
    bin/busybox \
    bin/dash \
    usr/local/bin/xbox-startx \
    usr/local/bin/xbox-xsession \
    usr/local/bin/xbox-network-up \
    usr/local/bin/xbox-storage-tune \
    usr/local/bin/xbox-plus-proof \
    usr/local/bin/xbox-plus-shell \
    usr/local/bin/xbox-launch-app
do
    add_path "$path" 32767
done

for path in \
    usr/local/bin/Xfbdev \
    usr/local/bin/xset \
    usr/local/bin/xauth \
    usr/local/bin/xterm \
    usr/local/bin/aterm \
    usr/bin/fluxbox
do
    add_binary_closure "$path" 32767
done

# Representative GUI applications measured as expensive cold-read closures.
for path in usr/bin/dillo usr/bin/mtpaint usr/bin/xfe; do
    add_binary_closure "$path" 30000
done

# Small runtime data used while painting the initial desktop.
for path in \
    usr/local/lib/X11/fonts \
    usr/local/share/X11 \
    usr/local/share/pixmaps \
    usr/share/fluxbox/styles/Meta \
    etc/fonts \
    etc/xbox-desktop-plus-profile \
    etc/xbox-desktop-full-profile
do
    add_path "$path" 28000
done

# Keep the maximum priority for paths shared by more than one tier.
awk -F '\t' '{ if (!($1 in priority) || $2 > priority[$1]) priority[$1]=$2 }
    END { for (path in priority) print path, priority[path] }' "$RAW_SORT" |
    LC_ALL=C sort -k2,2nr -k1,1 > "$SORT_FILE"
rm -f "$RAW_SORT"

rm -f "$CONTROL_SQUASHFS" "$HOT_SQUASHFS"
mksquashfs "$SCRATCH_ROOT" "$CONTROL_SQUASHFS" \
    -noappend -comp gzip -b 131072 -mkfs-time 0 -no-progress \
    >/tmp/xbox-hot-order-control-mksquashfs.out
mksquashfs "$SCRATCH_ROOT" "$HOT_SQUASHFS" \
    -noappend -comp gzip -b 131072 -mkfs-time 0 -sort "$SORT_FILE" -no-progress \
    >/tmp/xbox-hot-order-candidate-mksquashfs.out

{
    echo "source=$SOURCE_SQUASHFS"
    echo "control=$CONTROL_SQUASHFS"
    echo "hot=$HOT_SQUASHFS"
    echo "sort_file=$SORT_FILE"
    echo "sort_entries=$(wc -l < "$SORT_FILE")"
    echo
    echo "== priority counts =="
    awk '{ count[$NF]++ } END { for (p in count) print p, count[p] }' "$SORT_FILE" |
        sort -nr
    echo
    echo "== ordered paths =="
    cat "$SORT_FILE"
} > "$REPORT_FILE"

rm -rf "$SCRATCH_ROOT"
