# Real Hardware RW Shell Smoke Checklist

Date: May 26, 2026

This is the disk-safety checkpoint before using the writable Debian desktop on
real hardware. It intentionally does not start X.

## Package

Use:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-rw-shell-smoke.zip
```

Build it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package_distro_rw_shell_smoke.ps1
```

The package writes test files inside `E:\debian.ext2`, then immediately runs
`xbox-sync-ro` to sync and remount the ext2 root read-only.

## Backup

Before testing, back up these `E:\` files if they exist:

```text
E:\linuxboot.cfg
E:\debkrnl
E:\debinit
E:\debian.ext2
```

Also keep the known-good read-only Debian package nearby:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386.zip
```

## Install

FTP or copy the app folder to:

```text
E:\Apps\XromwellDebianBookwormRwShell\
```

Copy the package `E-root\` files to `E:\`:

```text
E:\linuxboot.cfg
E:\debkrnl
E:\debinit
E:\debian.ext2
```

Launch:

```text
E:\Apps\XromwellDebianBookwormRwShell\default.xbe
```

## First Boot Pass Criteria

The console should show:

```text
XBOX_PERSIST_MARKER_WRITTEN
XBOX_NORMAL_USE_FILE_WRITTEN
XBOX_ROOT_REMOUNT_RO_OK
```

After `XBOX_ROOT_REMOUNT_RO_OK`, it is safe to reset or power off for this
smoke test. If that marker does not appear, do not intentionally power-cycle
unless the system is already hung.

## Second Boot Pass Criteria

Launch the same package again without replacing `E:\debian.ext2`. The console
should show:

```text
XBOX_PERSIST_MARKER_PRESENT
XBOX_NORMAL_USE_FILE_PRESENT
XBOX_ROOT_REMOUNT_RO_OK
```

This proves that the FATX existing-file write path can persist data inside the
preallocated Debian ext2 image and can return to a clean read-only state before
shutdown.

## xemu Proof

The package was staged into the disposable xemu FATX HDD and booted to the
proof shell. The console showed both write markers and:

```text
XBOX_ROOT_REMOUNT_RO_OK
```

Screenshot:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-rw-shell-smoke-20260526-121332.png
```

After a host-side hard kill, `E:\debian.ext2` was extracted and checked with:

```powershell
python .\scripts\extract_fatx_root_file.py .\run\hdd\xbox_hdd_hddboot.raw debian.ext2 .\run\fatx-extract\debian-shell-smoke-after-syncro.ext2
wsl -e bash -lc "cd /mnt/c/Users/Paul/Desktop/xbox_linux && e2fsck -fn run/fatx-extract/debian-shell-smoke-after-syncro.ext2"
```

Result:

```text
Pass 1: Checking inodes, blocks, and sizes
Pass 2: Checking directory structure
Pass 3: Checking directory connectivity
Pass 4: Checking reference counts
Pass 5: Checking group summary information
run/fatx-extract/debian-shell-smoke-after-syncro.ext2: 9666/98304 files (0.1% non-contiguous), 71093/98304 blocks
```

No bitmap-difference warning was reported.

## Recovery

If the rw smoke fails, restore the backed-up root files and return to the
read-only Debian package. The FATX kernel write support is intentionally narrow:
it overwrites data inside existing files only. It does not create, delete,
rename, extend, or allocate FATX files.

