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
- `linuxroot.ext2`: `artifacts\hdd\xbox-tinycore-payload.ext2`
- append line: `init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7`

The Tiny Core payload itself is a visible FATX file:

```text
E:\linuxroot.ext2
```

With the FATX-enabled 6.18 kernel, stage7 mounts the Xbox E partition as FATX, opens `E:\linuxroot.ext2` by filename, loop-mounts that ext2 image, extracts `core.gz`, loads the desktop `.tcz` extensions, and starts the Tiny Core Xfbdev desktop. No physical payload offset is needed for this path.

Current ROM/HDD Tiny Core desktop proof screenshot:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\tinycore-hdd-hwfix-clean-kernel-restaged-20260525-154918.png
```

Current ROM/HDD Tiny Core lean-kernel desktop proof screenshot:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\tinycore-hdd-lean-kernel-meminfo-tall-20260525-161026.png
```

Current XBE-launcher Tiny Core desktop proof screenshot:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xbe-package-tinycore-fatx-270-20260525-141349.png
```

That proves Cromwell can:

- unlock the raw test HDD
- detect FATX
- read and parse E-root `/linuxboot.cfg`
- select the nested Linux entry
- load `/vmlinuz` from FATX
- load `/initramf` from FATX
- enter the 6.18.33 stage7 initramfs
- mount the Xbox E partition as FATX from Linux
- open the Tiny Core ext2 payload from visible FATX file `E:\linuxroot.ext2`
- start the Tiny Core Xfbdev desktop
- launch through `build\xromwell-hddfatx-autoboot-disc\default.xbe` when booted from the XDVDFS wrapper under Complex BIOS

The earlier BusyBox proof is still useful as a small diagnostic payload:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xbe-package-busybox-smoke-90-20260525-140817.png
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

That generated image is staged into FATX as:

```text
E:\linuxroot.ext2
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

Build the separate forced-HDTV 480p Cromwell ROM and XBE:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_cromwell_hdd_fatx_autoboot_hdtv480p.ps1
```

That variant adds `XBOX_FORCE_AV_HDTV_480P` and writes:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-hddfatx-autoboot-hdtv480p_1024.bin
C:\Users\Paul\Desktop\xbox_linux\artifacts\xromwell-hddfatx-autoboot-hdtv480p.iso
C:\Users\Paul\Desktop\xbox_linux\build\xromwell-hddfatx-autoboot-hdtv480p-disc\default.xbe
```

Build the Tiny Core ext2 payload image:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage_hdd_ext2_tinycore_payload.ps1
```

Stage the E-root linuxboot files and visible FATX payload file for the Tiny Core HDD desktop:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage_hdd_fatx_linuxboot.ps1 -KernelPath artifacts\kernels\xbox-linux-6.18.33-fatx-bzImage -InitrdPath artifacts\initramfs\xbox-tinycore-hdd-ext2-stage7-xfbdev-desktop.cpio -Title 'Tiny Core HDD fatx' -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7' -PayloadPath artifacts\hdd\xbox-tinycore-payload.ext2 -PayloadName linuxroot.ext2
```

Stage the smaller BusyBox diagnostic payload instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage_hdd_fatx_linuxboot.ps1
```

Build the softmod-facing XBE test packages:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package_softmod_test_packages.ps1
```

That produces:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-busybox-smoke.zip
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-tinycore-fatx.zip
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip
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

## Real Hardware Safety

The current Tiny Core HDD path no longer writes to hidden/raw tail sectors. It uses a normal visible FATX file, `E:\linuxroot.ext2`.

The new FATX-enabled kernel makes the Tiny Core package self-locating: stage7 mounts E as FATX and opens `E:\linuxroot.ext2` by filename. That removes the old contiguity/offset requirement for the ext2 payload file.

Before real hardware testing:

- use the FATX-enabled kernel artifact, `artifacts\kernels\xbox-linux-6.18.33-fatx-bzImage`
- copy the full package contents to E exactly as documented
- test the BusyBox diagnostic package first if you want a smaller first hardware smoke test
- follow `docs\real-hardware-softmod-test.md`

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

## Kernel FATX Support

The 6.18 branch now includes a minimal read-only `fs/fatx` driver:

- `CONFIG_FATX_FS=y` in `arch\x86\configs\xbox_defconfig`
- read-only FATX mount support
- directory lookup/readdir
- regular file reads and bmap/read_folio support for loopback images
- contiguous-file fast path for loopback payloads such as `E:\linuxroot.ext2`

The contiguous-file fast path matters because the Tiny Core root is an ext2
image loop-mounted through FATX. Without a fast path, every block lookup can
walk the FAT chain from the beginning of the file.

## Tiny Core Hardware Diagnostics

The current Tiny Core launcher creates these helper commands inside the booted
system:

```text
/usr/local/bin/xbox-aterm
/usr/local/bin/xbox-diag
/usr/local/bin/xbox-storage-tune
```

At desktop start, it writes:

```text
/tmp/xbox-diag.txt
```

That diagnostic file includes framebuffer, input, mount, block-device,
memory, read-ahead, ATA mode, and storage-related `dmesg` lines. It is intended
for the next real-hardware pass if disk access still feels slower than expected.

The proof terminal also prints the key `/proc/meminfo` fields so a photo of the
desktop is enough for a first RAM comparison.

## Lean Tiny Core Kernel

The kernel branch now includes:

```text
arch/x86/configs/xbox_tinycore_defconfig
```

This config keeps the current Tiny Core boot path but trims features that are
not needed for the 64 MB desktop smoke test, including cgroups/memcg,
namespaces, BPF syscall, modules, kexec, most netfilter/IPv6 plumbing, sound,
USB storage/serial/audio, DRM, ext4/FUSE/UDF/VFAT, proc kcore, and several
debug/inspection options.

Current artifact:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage
C:\Users\Paul\Desktop\xbox_linux\artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore.config
```

Size comparison from the May 25 build:

```text
full FATX bzImage:  4530688 bytes
lean Tiny Core bzImage: 2617856 bytes
```

This matches the old Xbox Linux boot model: keep Linux files on FATX and use an ext2 root image file for the real Linux filesystem.

## Next Work

The immediate next targets are:

- package the FATX-enabled Tiny Core flow as the default softmod test package
- add a second Tiny Core profile that boots to a lighter shell plus optional desktop startup
- broaden FATX driver testing against C/E/F-style layouts and fragmented files
