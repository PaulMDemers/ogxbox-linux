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

`file arch/x86/boot/bzImage` reported:

```text
Linux kernel x86 boot executable bzImage, version 6.18.33-xboxdev-00002-g561381adb5fb
```

## What Has Been Forward-Ported

- `CONFIG_X86_XBOX`
- Xbox PCI blacklist hooks in early/direct PCI config access
- Xbox SMC helpers and reboot/poweroff hooks
- Xbox PIT tick-rate override
- forced PIT clocksource selection during boot
- old Xbox EXTSMI eject interrupt handler
- decompressor `misc.o` optimization workaround for newer Xbox revisions
- refreshed 6.18-compatible `xbox_defconfig`

## Next Boot Step

Do not replace the proven 5.8.1 desktop ISO path yet. First build a parallel Cromwell ISO that swaps only the kernel to `artifacts/kernels/xbox-linux-6.18.33-bzImage`, keeping the same Tiny Core 11 payload and no-xpad USB keyboard/tablet launch path.
