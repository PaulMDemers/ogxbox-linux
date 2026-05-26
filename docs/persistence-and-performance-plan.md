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
```

`apt` is part of the Debian minbase root; `ca-certificates` is included so
HTTPS downloads with `wget` do not fail immediately on certificate validation.

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
