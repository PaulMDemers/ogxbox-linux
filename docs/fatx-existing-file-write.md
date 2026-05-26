# FATX Existing-File Write Support

Date: May 25, 2026

This is the first FATX write checkpoint for the modern Xbox Linux kernel. It is
intentionally narrow and should be treated as xemu-only until we finish more
abuse testing.

## Scope

Implemented:

- mount FATX read-write
- overwrite data inside an existing regular file
- flush those writes through sync/unmount/remount
- reject writes beyond the existing file size

Not implemented:

- creating FATX files
- deleting FATX files
- renaming FATX files
- extending FATX files
- allocating/freeing FATX clusters
- updating FATX directory metadata such as size or timestamps

This is enough for the planned persistence path because `E:\debian.ext2` is a
preallocated FATX file. Debian writes to the ext2 filesystem inside that file;
the FATX driver only needs to overwrite already-allocated file blocks.

## Kernel Artifact

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\kernels\xbox-linux-6.18.33-fatx-rw-existing-bzImage
C:\Users\Paul\Desktop\xbox_linux\artifacts\kernels\xbox-linux-6.18.33-fatx-rw-existing.config
```

The corresponding kernel repo commit is in:

```text
C:\Users\Paul\ogxbox\linux-6.18-xbox
```

## Smoke Test

Build the test initramfs:

```powershell
python .\scripts\make_fatx_write_smoke_initramfs.py
```

Stage the disposable xemu HDD:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage_fatx_write_smoke.ps1
```

Run xemu:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-hdd-fatx-busybox-6.18.33.ps1
```

Expected output:

```text
FATX_CREATE_REJECTED_OK
FATX_WRITE_EXISTING_OK
```

Proof screenshot:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\fatx-write-smoke-v2-20260525-235042.png
```

Host-side byte verification after stopping xemu:

```text
FATX_WRITE_EXISTING_OK_20260525
```

## Next Step

Use the same kernel against the Debian package in xemu only, with:

```text
xbox_fatx_mode=rw xbox_root_mode=rw
```

That persistence cycle now passes in xemu.

## Debian Persistence Smoke

The Debian root includes an opt-in smoke helper:

```text
/usr/local/bin/xbox-persist-smoke
```

It runs only when the kernel command line includes:

```text
xbox_persist_smoke=1
```

The helper writes this marker inside the Debian ext2 root:

```text
/root/xbox-persist-smoke.txt
```

Rebuild Debian and stage the disposable xemu HDD:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_debian_bookworm_i386_payload.ps1 -Desktop -ImageSizeMiB 384
powershell -ExecutionPolicy Bypass -File .\scripts\stage_debian_rw_persistence_smoke.ps1
```

Run xemu, wait for the desktop, then capture:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-hdd-fatx-busybox-6.18.33.ps1
.\tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe --out-dir .\run\screenshots --prefix debian-rw-persist-written --rect frame
```

Expected first boot output:

```text
XBOX_PERSIST_MARKER_WRITTEN
XBOX_PERSIST_MARKER_20260526
```

Stop xemu, then start it again without restaging the HDD. Expected second boot
output:

```text
XBOX_PERSIST_MARKER_PRESENT
XBOX_PERSIST_MARKER_20260526
```

Proof screenshots:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-rw-persist-written-20260526-100738.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-rw-persist-present-20260526-100948.png
```

The default real-hardware Debian package should stay read-only until we decide
to create a separate opt-in rw package.

## RW Softmod Smoke Package

An opt-in softmod package now exists separately from the normal read-only
Debian package:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-rw-smoke.zip
```

Build it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package_distro_rw_smoke.ps1
```

Package folder:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-rw-smoke
```

Expected Xbox dashboard folder:

```text
E:\Apps\XromwellDebianBookwormRwSmoke\
```

Expected Xbox `E:` root files from `E-root\`:

```text
E:\linuxboot.cfg
E:\debkrnl
E:\debinit
E:\debian.ext2
```

The package includes:

```text
RW-SMOKE-WARNING.txt
```

That warning is intentionally blunt: this package is xemu-proven but not yet
real-hardware validated, and the normal read-only Debian package should remain
the known-good fallback.

Package-sourced xemu proof was done by staging the disposable xemu HDD from the
package's own `E-root` files. First boot:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-rw-softmod-package-written-20260526-102052.png
```

Second boot without restaging:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-rw-softmod-package-present-20260526-102256.png
```

## Normal File And Hard-Kill Check

The persistence helper now writes two files:

```text
/root/xbox-persist-smoke.txt
/root/xbox-normal-use.txt
```

The second file is a small normal-use stand-in for "create/edit a file in
Debian, sync, reboot, and make sure it is still there."

The package was booted in xemu, allowed to write and sync both files, then xemu
was force-stopped from the host instead of shutting Debian down cleanly.

First boot after write/sync:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-rw-normal-hardkill-written-20260526-105121.png
```

Second boot after host-side hard kill, without restaging:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-rw-normal-hardkill-present-20260526-105325.png
```

Both files survived and were visible after reboot:

```text
XBOX_PERSIST_MARKER_PRESENT
XBOX_PERSIST_MARKER_20260526
XBOX_NORMAL_USE_FILE_PRESENT
XBOX_NORMAL_USE_FILE_20260526
```

However, this is not power-loss clean yet. After extracting `E:\debian.ext2`
from the disposable FATX HDD and running read-only fsck, ext2 reported bitmap
differences:

```text
Block bitmap differences:  -77824 +96260
WARNING: Filesystem still has errors
```

A repair test on a copy completed and the two persisted files were still
readable with `debugfs`, but the result means the rw package should not be
treated as power-loss safe.

Useful extraction/fsck commands:

```powershell
python .\scripts\extract_fatx_root_file.py .\run\hdd\xbox_hdd_hddboot.raw debian.ext2 .\run\fatx-extract\debian-after-hardkill.ext2
wsl -e bash -lc "cd /mnt/c/Users/Paul/Desktop/xbox_linux && e2fsck -fn run/fatx-extract/debian-after-hardkill.ext2"
```

The Debian image now includes:

```text
/usr/local/bin/xbox-sync-ro
```

Run `xbox-sync-ro` before powering off when possible. It syncs and attempts to
remount `/` read-only.

## Clean Remount Test

The opt-in command-line flag:

```text
xbox_sync_ro_smoke=1
```

runs `xbox-sync-ro` automatically after the persistence helper. In xemu it
reported:

```text
XBOX_ROOT_REMOUNT_RO_OK
```

Proof screenshot:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-rw-syncro-proof-20260526-115314.png
```

After that proof, xemu was force-stopped from the host. `E:\debian.ext2` was
then extracted by filename from the FATX HDD and checked with:

```powershell
python .\scripts\extract_fatx_root_file.py .\run\hdd\xbox_hdd_hddboot.raw debian.ext2 .\run\fatx-extract\debian-after-syncro.ext2
wsl -e bash -lc "cd /mnt/c/Users/Paul/Desktop/xbox_linux && e2fsck -fn run/fatx-extract/debian-after-syncro.ext2"
```

Result:

```text
Pass 1: Checking inodes, blocks, and sizes
Pass 2: Checking directory structure
Pass 3: Checking directory connectivity
Pass 4: Checking reference counts
Pass 5: Checking group summary information
run/fatx-extract/debian-after-syncro.ext2: 9666/98304 files (0.1% non-contiguous), 71093/98304 blocks
```

No bitmap-difference warning was reported after the read-only remount path.

## Shell-Only RW Hardware Checklist

A lower-risk package now exists for real hardware:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-rw-shell-smoke.zip
```

Build it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package_distro_rw_shell_smoke.ps1
```

It uses the same rw FATX and rw ext2 path, but does not start the desktop. It
writes the marker files, runs `xbox-sync-ro`, and stops at the proof shell.

xemu proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-rw-shell-smoke-20260526-121332.png
```

The extracted `E:\debian.ext2` from this run passed `e2fsck -fn` without bitmap
warnings after a host-side hard kill. Use
`docs\real-hardware-rw-smoke-checklist.md` for the hardware test order.
