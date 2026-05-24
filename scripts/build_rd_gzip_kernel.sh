#!/usr/bin/env bash
set -euo pipefail

src=/mnt/c/Users/Paul/Desktop/xbox_linux/sources/haxar-xbox-linux-archive
build=/tmp/xbox-linux-5.8.1-rd-gzip-build
out=/mnt/c/Users/Paul/Desktop/xbox_linux/artifacts/kernels

case "$build" in
  /tmp/xbox-linux-5.8.1-rd-gzip-build) ;;
  *) echo "Refusing unexpected build path: $build" >&2; exit 1 ;;
esac

mkdir -p "$build"
if [ ! -f "$build/Makefile" ] && command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude .git "$src"/ "$build"/
elif [ ! -f "$build/Makefile" ]; then
  cp -a "$src"/. "$build"/
fi

cd "$build"
cp include/uapi/linux/netfilter_ipv4/ipt_ecn.h include/uapi/linux/netfilter_ipv4/ipt_ECN.h
cp net/netfilter/xt_hl.c net/netfilter/xt_HL.c
cp "$out/xbox-linux-5.8.1.config" .config
scripts/config --enable RD_GZIP
scripts/config --disable IP_NF_TARGET_ECN
scripts/config --disable NETFILTER_XT_TARGET_HL
make ARCH=x86 olddefconfig
grep -E 'CONFIG_RD_|CONFIG_BLK_DEV_INITRD|CONFIG_DECOMPRESS_GZIP|CONFIG_ZLIB_INFLATE' .config || true
make ARCH=x86 -j"$(nproc)" bzImage
cp arch/x86/boot/bzImage "$out/xbox-linux-5.8.1-rd-gzip-bzImage"
cp .config "$out/xbox-linux-5.8.1-rd-gzip.config"
ls -l "$out/xbox-linux-5.8.1-rd-gzip-bzImage"
