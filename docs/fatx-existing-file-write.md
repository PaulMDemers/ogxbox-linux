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
