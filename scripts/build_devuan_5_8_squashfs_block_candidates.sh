#!/bin/bash
set -euo pipefail

SOURCE_SQUASHFS="$1"
OUTPUT_ROOT="$2"
SCRATCH_ROOT="$3"
COMPRESSION="$4"
shift 4

if [ "$#" -eq 0 ]; then
    echo "At least one SquashFS block size is required." >&2
    exit 2
fi

case "$COMPRESSION" in
    gzip|zstd|xz) ;;
    *)
        echo "Unsupported SquashFS compression: $COMPRESSION" >&2
        exit 2
        ;;
esac

rm -rf "$SCRATCH_ROOT"
mkdir -p "$SCRATCH_ROOT" "$OUTPUT_ROOT"
unsquashfs -d "$SCRATCH_ROOT" "$SOURCE_SQUASHFS" \
    >/tmp/xbox-block-ab-unsquashfs.out

cat > "$SCRATCH_ROOT/usr/local/bin/xbox-storage-selftest" <<'EOF'
#!/bin/sh
exec </dev/console >/dev/console 2>&1

drop_caches() {
    sync
    echo 3 >/proc/sys/vm/drop_caches 2>/dev/null || true
}

now_ns() {
    date +%s%N
}

elapsed_ms() {
    start="$1"
    finish="$2"
    echo $(((finish - start) / 1000000))
}

timed_raw() {
    skip="$1"
    drop_caches
    start="$(now_ns)"
    dd if="$ROOT_DEVICE" of=/dev/null bs=1M skip="$skip" count=1 2>/dev/null
    finish="$(now_ns)"
    elapsed_ms "$start" "$finish"
}

timed_closure() {
    binary="$1"
    drop_caches
    start="$(now_ns)"
    cat "$binary" >/dev/null
    if command -v ldd >/dev/null 2>&1; then
        ldd "$binary" 2>/dev/null | awk '
            $1 ~ /^\// { print $1 }
            $3 ~ /^\// { print $3 }
        ' | while IFS= read -r dependency; do
            [ -f "$dependency" ] && cat "$dependency" >/dev/null
        done
    fi
    finish="$(now_ns)"
    elapsed_ms "$start" "$finish"
}

ROOT_DEVICE="$(awk '$2 == "/" { print $1; exit }' /proc/mounts 2>/dev/null)"
case "$ROOT_DEVICE" in
    /dev/loop*) ;;
    *)
        for candidate in /dev/loop1 /dev/loop0; do
            if [ -b "$candidate" ]; then
                ROOT_DEVICE="$candidate"
                break
            fi
        done
        ;;
esac

echo "XBOX_STORAGE_SELFTEST_BEGIN"
echo "root=$ROOT_DEVICE"
echo "RUN raw-0"
RAW0="$(timed_raw 0)"
echo "RUN raw-64"
RAW64="$(timed_raw 64)"
echo "RUN raw-128"
RAW128="$(timed_raw 128)"
echo "RUN raw-192"
RAW192="$(timed_raw 192)"
echo "RUN raw-256"
RAW256="$(timed_raw 256)"

echo "RUN Xfbdev"
XFBDEV="$(timed_closure /usr/local/bin/Xfbdev)"
echo "RUN xterm"
XTERM="$(timed_closure /usr/local/bin/xterm)"
echo "RUN fluxbox"
FLUXBOX="$(timed_closure /usr/bin/fluxbox)"
echo "RUN dillo"
DILLO="$(timed_closure /usr/bin/dillo)"
echo "RUN mtpaint"
MTPAINT="$(timed_closure /usr/bin/mtpaint)"
echo "RUN xfe"
XFE="$(timed_closure /usr/bin/xfe)"

printf '\033[2J\033[H\033[42;30m'
echo "XBOX_STORAGE_SELFTEST_OK"
echo "milliseconds (lower is better)"
echo "root=$ROOT_DEVICE"
echo "raw0=$RAW0"
echo "raw64=$RAW64"
echo "raw128=$RAW128"
echo "raw192=$RAW192"
echo "raw256=$RAW256"
echo "Xfbdev=$XFBDEV"
echo "xterm=$XTERM"
echo "fluxbox=$FLUXBOX"
echo "dillo=$DILLO"
echo "mtpaint=$MTPAINT"
echo "xfe=$XFE"
echo "XBOX_STORAGE_SELFTEST_HOLD"

while :; do
    sleep 3600
done
EOF
chmod 0755 "$SCRATCH_ROOT/usr/local/bin/xbox-storage-selftest"

awk '
    !inserted && /^echo$/ {
        print "if grep -q 'xbox_storage_selftest=1' /proc/cmdline 2>/dev/null; then"
        print "    /usr/local/bin/xbox-storage-selftest"
        print "fi"
        print ""
        inserted = 1
    }
    { print }
    END {
        if (!inserted) {
            print "Could not insert storage self-test hook into xbox-init." > "/dev/stderr"
            exit 1
        }
    }
' "$SCRATCH_ROOT/xbox-init" > "$SCRATCH_ROOT/xbox-init.new"
mv "$SCRATCH_ROOT/xbox-init.new" "$SCRATCH_ROOT/xbox-init"
chmod 0755 "$SCRATCH_ROOT/xbox-init"

for block_size in "$@"; do
    case "$block_size" in
        65536|131072|262144|524288|1048576) ;;
        *)
            echo "Unsupported SquashFS block size: $block_size" >&2
            exit 2
            ;;
    esac
    output="$OUTPUT_ROOT/devuan-${COMPRESSION}-block-${block_size}.squashfs"
    rm -f "$output"
    mksquashfs "$SCRATCH_ROOT" "$output" \
        -noappend -comp "$COMPRESSION" -b "$block_size" -mkfs-time 0 -no-progress \
        >"/tmp/xbox-${COMPRESSION}-block-${block_size}-mksquashfs.out"
    unsquashfs -s "$output" >"$OUTPUT_ROOT/devuan-${COMPRESSION}-block-${block_size}.superblock.txt"
done

rm -rf "$SCRATCH_ROOT"
