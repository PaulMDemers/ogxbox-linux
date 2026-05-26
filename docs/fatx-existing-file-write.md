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

If Debian can write a marker inside the ext2 root and that marker survives a
reboot, then we can create a separate opt-in rw test package. The default real
hardware package should stay read-only until that full persistence cycle passes
cleanly.
