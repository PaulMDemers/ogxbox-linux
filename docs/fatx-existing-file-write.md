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

## Resume Audit

Rechecked on August 5, 2026 after the Tiny Core release was finalized:

- `sources/haxar-xbox-linux-sparse` is clean at `829b71ab17ed` on
  `xbox-6.18.y-bringup` and matches its remote branch.
- The write kernel remains
  `0AC26C6FB52F89503DE2E7ADAD65DC856A12A06B13D51F9AC430B7CE9AB40546`.
- The prior Debian shell-smoke ZIP remains
  `76129A3C09DBB7463F16B38D84AC44C00BC5524E6A90FFFDB89DF3A5267ED3F4`.
- The prior Devuan shell-smoke ZIP remains
  `CBF90C1F12253FCA4BA4777AAA350FC81803A0CBA0ACF7EE744C1E3BF319F499`.

The next hardware candidate must not overwrite the normal read-only release
filenames. Build a new Debian shell-only package using isolated names such as
`rwkrnl`, `rwinit`, and `rwdebian.ext2`, then automate this disposable-xemu
gate before publishing it for hardware testing:

1. First boot writes both persistence markers and reaches
   `XBOX_ROOT_REMOUNT_RO_OK`.
2. Second boot, without restaging, finds both markers and again remounts root
   read-only.
3. Extract the FATX-backed ext2 file and require `e2fsck -fn` to complete
   without filesystem errors.

Normal Tiny Core and Devuan packages remain read-only throughout this work.

## Automated Debian 6.18 Safety Gate

Completed August 5, 2026 with the pinned production write kernel:

```text
kernel SHA-256: 0AC26C6FB52F89503DE2E7ADAD65DC856A12A06B13D51F9AC430B7CE9AB40546
source commit:  829b71ab17ed
package:        artifacts/debian-6.18.33-rw-candidate/
package ZIP:    23F5B8717A11F7C4DDCA1E1947A362BCBCC7FBBC4DE7DBFFE1845E29B19FCF04
```

The candidate uses only isolated E: names:

```text
E:\rwkrnl
E:\rwinit
E:\rwdebian.ext2
E:\linuxboot.cfg
```

The automated gate creates a fresh sparse raw Xbox disk, stages all four files
contiguously with readback hashes, and boots that same writable disk twice
without restaging. After each forced xemu stop it extracts `rwdebian.ext2`,
checks both persistence files and the remount status file, runs read-only fsck,
and records the ext2 mount count.

Final production-kernel result:

```text
boot 1: Linux at 26 s, mount count 1, remount OK, fsck clean
boot 2: Linux at 26 s, mount count 2, remount OK, fsck clean
```

Evidence is retained under:

```text
run/debian-rw-safety-gate/20260805-182211/
```

The intermittent remount failure was diagnosed with a disposable VFS-trace
kernel. PID 1 had opened `/tmp/xbox-sync-ro.txt` for the helper's redirected
output; because `/tmp` was still ext2-backed in that boot path, the child could
not remount its own root read-only. The candidate now replaces PID 1 with
`xbox-sync-ro` and writes directly to the console. No diagnostic kernel changes
remain in the source checkout or production artifact.

The real-hardware checklist is now unblocked for an opt-in, backed-up shell-only
test. This does not promote general FATX writes or a writable desktop: the
driver still only overwrites blocks within existing FATX files and cannot
create, delete, rename, extend, or allocate FATX files.
