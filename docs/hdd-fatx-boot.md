# FATX HDD Boot Bringup

This is the current HDD boot workflow after the 6.18 Tiny Core HDD desktop checkpoint.

## Current Status

The disposable HDD test image is:

```text
C:\Users\Paul\Desktop\xbox_linux\run\hdd\xbox_hdd_hddboot.raw
```

It was created from:

```text
C:\Users\Paul\Desktop\xbox_linux\Xbox-Emulator-Files\hdd\xbox_hdd.qcow2
```

The original qcow2 is not modified.

The FATX E partition is staged with:

```text
/linuxboot.cfg
/vmlinuz
/initramf
```

Current staged FATX boot payload:

- `vmlinuz`: `artifacts\kernels\xbox-linux-6.18.33-bzImage`
- `initramf`: `artifacts\initramfs\xbox-tinycore-hdd-ext2-stage7-xfbdev-desktop.cpio`
- append line: `init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 tc_payload_offset=8053063680`

The Tiny Core payload itself is not stored in FATX. It lives in an ext2 filesystem image written into the raw HDD tail region:

```text
offset: 8053063680
source image: C:\Users\Paul\Desktop\xbox_linux\artifacts\hdd\xbox-tinycore-payload.ext2
payload root: C:\Users\Paul\Desktop\xbox_linux\artifacts\hdd\tinycore-ext2-root
```

The stage7 initramfs mounts that ext2 payload through `/dev/loop0`, extracts `core.gz`, loads the desktop `.tcz` extensions, and starts the Tiny Core Xfbdev desktop.

Current ROM/HDD Tiny Core desktop proof screenshot:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\tinycore-hdd-ext2-stage7-scan-120-20260525-125202.png
```

Current XBE-launcher Tiny Core desktop proof screenshot:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xbe-tinycore-hdd-ext2-stage7-120-20260525-125439.png
```

That proves Cromwell can:

- unlock the raw test HDD
- detect FATX
- read and parse E-root `/linuxboot.cfg`
- select the nested Linux entry
- load `/vmlinuz` from FATX
- load `/initramf` from FATX
- enter the 6.18.33 stage7 initramfs
- mount the Tiny Core ext2 payload from the raw HDD tail
- start the Tiny Core Xfbdev desktop
- launch through `build\xromwell-hddfatx-autoboot-disc\default.xbe` when booted from the XDVDFS wrapper under Complex BIOS

The earlier BusyBox proof is still useful as a small diagnostic payload:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\hdd-busybox-relocated-heap-45-20260525-123353.png
```

## Artifacts

HDD-autoboot Cromwell ROM:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-hddfatx-autoboot-modernhdr-initrd32_1024.bin
```

HDD-autoboot Xromwell app package:

```text
C:\Users\Paul\Desktop\xbox_linux\build\xromwell-hddfatx-autoboot-disc\default.xbe
```

xemu XDVDFS test image for that XBE:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\xromwell-hddfatx-autoboot-initrd32.iso
```

Tiny Core HDD payload image:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\hdd\xbox-tinycore-payload.ext2
```

## Build And Stage

Convert the baseline qcow2 to a disposable raw HDD:

```powershell
New-Item -ItemType Directory -Force .\run\hdd | Out-Null
wsl -e bash -lc "cd /mnt/c/Users/Paul/Desktop/xbox_linux && python3 scripts/qcow2_to_raw_sparse.py Xbox-Emulator-Files/hdd/xbox_hdd.qcow2 run/hdd/xbox_hdd_hddboot.raw --force"
```

Build the initramfs artifacts:

```powershell
python .\scripts\make_busybox_initramfs.py
```

Build the FATX-autoboot Cromwell ROM and XBE:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_cromwell_hdd_fatx_autoboot.ps1
```

Write the Tiny Core ext2 payload into the raw HDD tail:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage_hdd_ext2_tinycore_payload.ps1
```

Stage the E-root linuxboot files for the Tiny Core HDD desktop:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage_hdd_fatx_linuxboot.ps1 -InitrdPath artifacts\initramfs\xbox-tinycore-hdd-ext2-stage7-xfbdev-desktop.cpio -Title 'Tiny Core HDD ext2' -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 tc_payload_offset=8053063680'
```

Stage the smaller BusyBox diagnostic payload instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage_hdd_fatx_linuxboot.ps1
```

Build the softmod-facing XBE test package:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package_xromwell_hddfatx_softmod.ps1
```

That produces:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-autoboot\
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-autoboot.zip
```

Run the current xemu HDD test:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-hdd-fatx-busybox-6.18.33.ps1
```

Run the xemu XBE launcher test:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-xromwell-hddfatx-autoboot.ps1
```

Capture proof with the C# window capture tool:

```powershell
.\tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe --out-dir .\run\screenshots --prefix hdd-fatx-autoboot-busybox-6.18.33 --rect frame
```

## Cromwell Changes

Cromwell branch:

```text
PaulMDemers/cromwell.git xbox-linux-fast-atapi-autoboot @ bfe8301
```

Relevant changes:

- `XBOX_LINUX_AUTOBOOT_FATX` compile-time path that selects the default nested Linux entry from E-root FATX.
- FATX config file loads allocate one extra NUL byte for `ParseConfig`.
- `ParseConfig` bounds title copies to the 15-byte title field.
- FATX fixed-position loads no longer prefill the destination buffer.
- FATX loads use a static 16 KiB cluster buffer instead of a variable-length stack buffer.
- FATX raw reads can request full 16 KiB clusters.
- HDD PIO reads use ATA `READ MULTIPLE` when available, with fallback to normal `READ SECTOR(S)`.
- IDE wait loops now have bounded timeouts instead of unbounded polling.
- Kernel staging uses `KERNEL_LOAD_TMP` below `INITRD_START`, leaving the initramfs region clear.
- The initrd window was widened to allow larger experiments, and Cromwell's heap was moved below `INITRD_START` so early video/FATX setup still has enough heap.

## Next Work

The immediate next targets are:

- turn the ext2 payload staging into a real-Xbox-safe installer flow; for xemu it writes the raw HDD tail directly
- add a second Tiny Core profile that boots to a lighter shell plus optional desktop startup
- decide whether to keep the current tail-offset layout or move to a formal Linux partition map for real hardware experiments
