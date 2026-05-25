# Linux 6.18.y Xbox Bringup

Use `linux-6.18.y` as the first modern target. As of 2026-05-24, kernel.org lists 6.18 as longterm, and the current branch tip used here is `Linux 6.18.33`.

## Branch

Repository:

```text
https://github.com/PaulMDemers/xbox-linux.git
```

Branch:

```text
xbox-6.18.y-bringup
```

Current remote tip:

```text
46679a4860b1 x86: enable Xbox framebuffer and PATA devices
```

Initial commits:

```text
561381adb x86: refresh Xbox defconfig for 6.18.y
67768b90d x86: start original Xbox bringup on 6.18.y
83657f418 Linux 6.18.33
```

## Build Location

Build modern Linux trees on WSL ext4, not under `/mnt/c`. The Windows filesystem is case-insensitive by default, and the Linux tree contains paths that differ only by case.

Current local build tree:

```text
/home/paul/ogxbox/linux-6.18-xbox
```

## Build Commands

```bash
cd ~/ogxbox/linux-6.18-xbox
make ARCH=x86 xbox_defconfig
make ARCH=x86 -j"$(nproc)" bzImage
```

Known-good build output:

```text
Kernel: arch/x86/boot/bzImage is ready
```

The built kernel copied back into the Windows workspace is:

```text
artifacts/kernels/xbox-linux-6.18.33-bzImage
artifacts/kernels/xbox-linux-6.18.33.config
```

The verified Tiny Core normal desktop boot reports:

```text
XBOX_TINYCORE_NORMAL_DESKTOP_OK
Linux xbox 6.18.33-xboxdev-00004-g46679a4860b1 #1 PREEMPT_DYNAMIC Sun May 24 21:45:06 EDT 2026 i686 GNU/Linux
```

## What Has Been Forward-Ported

- `CONFIG_X86_XBOX`
- Xbox PCI blacklist hooks in early/direct PCI config access
- Xbox SMC helpers and reboot/poweroff hooks
- Xbox PIT tick-rate override
- forced PIT clocksource selection during boot
- old Xbox EXTSMI eject interrupt handler
- decompressor `misc.o` optimization workaround for newer Xbox revisions
- sysfb/simplefb handoff for visible framebuffer console and Xfbdev
- libata/PATA AMD support for xemu's CD-ROM path
- refreshed 6.18-compatible `xbox_defconfig`

## Verified Boot

The working 6.18 desktop path is:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_tinycore11_desktop_iso.ps1 `
  -KernelPath artifacts\kernels\xbox-linux-6.18.33-bzImage `
  -OutputIso artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33.iso `
  -Append 'console=tty0 ignore_loglevel loglevel=7'

powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-modernhdr-initrd32-tinycore11-stage6-xfbdev-desktop-6.18.33.ps1
```

Proof:

```text
run\screenshots\tinycore11-normal-desktop-6.18.33-initrd32-20260524-220431.png
```
