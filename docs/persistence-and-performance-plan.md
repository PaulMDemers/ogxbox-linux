# Persistence And Performance Plan

Date: May 25, 2026

This tracks the next phase after the Debian Bookworm Xfbdev hardware desktop
checkpoint.

## Current Persistence Status

The current softmod-safe boot layout is:

```text
E:\linuxboot.cfg
E:\debkrnl
E:\debinit
E:\debian.ext2
```

Xromwell reads the kernel and initramfs from FATX. The distro stage1 initramfs
mounts the Xbox `E:` FATX partition, opens `E:\debian.ext2`, loop-mounts that
ext2 image, and `switch_root`s into Debian.

This is intentionally read-only today:

- `fs/fatx/Kconfig` describes the driver as read-only.
- `fs/fatx/inode.c` reports zero free space in `statfs`.
- regular files use `generic_ro_fops`.
- the superblock is forced to `SB_RDONLY`.
- reconfigure/remount also forces `SB_RDONLY`.
- the driver has lookup/readdir/read paths, but no create, unlink, rename,
  write_begin, or write_end implementation.

Because the ext2 root image is a file inside that read-only FATX mount, simply
mounting the ext2 image read-write is not disk-safe yet.

## Safe Next Persistence Path

The staged plan is:

1. Keep shipped packages read-only by default.
2. Keep the new initramfs `xbox_fatx_mode=` and `xbox_root_mode=` command-line
   knobs, but do not enable them in real-hardware packages yet.
3. Build a FATX write-test payload that operates only on disposable xemu HDD
   images.
4. First support overwriting data inside an existing FATX file. This is enough
   for `E:\debian.ext2` because the ext2 filesystem inside the file owns the
   Linux-side allocation and metadata.
5. Once existing-file writes survive repeated xemu mount/write/unmount/verify
   cycles, test Debian with `xbox_fatx_mode=rw xbox_root_mode=rw`.
6. Only after that, allow a read-write `debian.ext2` loop image or an overlay
   upper/work directory backed by FATX.

The first existing-file write smoke test passes in xemu. See
`docs\fatx-existing-file-write.md`.

The first Debian ext2 persistence smoke also passes in xemu: Debian writes
`/root/xbox-persist-smoke.txt` with `xbox_fatx_mode=rw xbox_root_mode=rw`, then
sees the same marker on the next boot without restaging `E:\debian.ext2`.

The next xemu pass wrote both `/root/xbox-persist-smoke.txt` and
`/root/xbox-normal-use.txt`, synced, then survived a host-side hard kill and
reboot. A read-only fsck of the extracted ext2 image still reported bitmap
differences, so the current rw package is persistence-capable but not
power-loss safe. The Debian image now includes `xbox-sync-ro` for manual
sync/remount-read-only before power-off.

The clean-remount pass with `xbox_sync_ro_smoke=1` then reported
`XBOX_ROOT_REMOUNT_RO_OK`; after a host-side hard kill, `e2fsck -fn` on the
extracted ext2 image completed without bitmap warnings. For rw testing, run
`xbox-sync-ro` before powering off.

Devuan now has a matching rw shell-smoke packager:

```text
C:\Users\Paul\Desktop\xbox_linux\scripts\package_devuan_daedalus_i386_rw_shell_smoke.ps1
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-rw-shell-smoke.zip
SHA256 A29A31C259560A147FD9CACED2C4194561C42F3148480DB3BE99D87AD7CB014C
```

Current Devuan status: xemu writes the marker and normal-use file, the second
boot finds both, and an extracted `devuan.ext2` passes `e2fsck -fn` after a
hard stop. The remaining blocker is remount-read-only: `xbox-sync-ro` does not
yet print `XBOX_ROOT_REMOUNT_RO_OK` on Devuan, so this package is not ready for
real-hardware rw validation.

Proof screenshots:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-rw-shell-sysrq-syncro-written-20260528-142322.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-rw-shell-sysrq-syncro-present-20260528-142545.png
```

The safer alternative, if we want persistence before FATX write support, is a
native Linux partition or another Xbox disk area dedicated to Linux. That avoids
teaching the kernel to modify FATX, but it is less convenient for the desired
"FTP these files over" workflow.

## Current Performance Work

The Debian image now includes:

```text
/usr/local/bin/xbox-storage-tune
/usr/local/bin/xbox-diag
/usr/local/bin/xbox-perf
```

`xbox-perf` is a small on-box timing smoke test for commands that felt slow on
hardware, including `free -m`, BusyBox `free`, `/proc/meminfo`, and `ps`.

Useful hardware test commands:

```sh
xbox-perf
xbox-diag | tee /tmp/diag-live.txt
dmesg | tail -120
cat /proc/meminfo
cat /proc/mounts
```

Photos or copied terminal output from those commands will tell us whether the
lag is mostly process startup, `/proc` reads, storage latency, memory pressure,
or X/terminal rendering.

## Base Debian Tools

The Debian build now includes the missing base network tools requested for the
minimal system:

```text
iputils-ping
wget
ca-certificates
apt
isc-dhcp-client
ifupdown
iproute2
```

`apt` is part of the Debian minbase root; `ca-certificates` is included so
HTTPS downloads with `wget` do not fail immediately on certificate validation.

## Networking

The Xbox Ethernet driver can be present while the interface is still unusable
because our custom `/xbox-init` path bypasses the normal SysV networking boot
sequence. The rootfs now starts DHCP explicitly with:

```text
/usr/local/bin/xbox-network-up
```

Boot starts it in the background so a missing cable, slow link, or missing DHCP
server does not stall the desktop. For hardware testing, run:

```sh
xbox-network-up --wait
ip addr show dev eth0
ip route
cat /etc/resolv.conf
ping -c 3 8.8.8.8
ping -c 3 deb.debian.org
wget -O- http://deb.debian.org/robots.txt
cat /tmp/xbox-network-up.txt
```

Expected success marker:

```text
XBOX_NETWORK_DHCP_OK
```

If `ping 8.8.8.8` fails but `eth0` has no IPv4 address, the issue is DHCP or
link setup rather than name resolution. If `ping 8.8.8.8` works but
`ping deb.debian.org` fails, the issue is resolver setup.

The current xemu proof reaches the Devuan desktop with the helper installed,
but reports `NO-CARRIER` for `eth0`; use real hardware for the actual DHCP
pass/fail result.

## Mouse Note

`xbox_x_mouse=0` disables only the explicit Xfbdev argument:

```text
-mouse /dev/input/mice,5
```

It does not guarantee that the desktop will have no pointer input. On real
hardware, the Xfbdev/Tiny Core stack can still see a default or built-in pointer
path, which is why the mouse moved even while the boot log said mouse was
disabled. The boot text now says that the explicit mouse device is disabled,
and notes that default pointer input may still work.
