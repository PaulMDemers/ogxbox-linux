# Xbox Linux Game Disc

This path builds an Xbox-style XDVDFS disc image that has `default.xbe` at the
disc root, so a chipped Xbox or BIOS that boots game discs can launch Xromwell
directly from DVD-R.

The current recommended real-hardware artifact is:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\xbox-linux-devuan-fluxlite-game-disc.iso
```

It uses the 5.8.1 legacy IDE/ATAPI kernel because that is the path validated on
real Xbox DVD hardware.

A larger "full desktop" experiment is available separately:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\xbox-linux-devuan-desktop-full-game-disc.iso
```

This variant keeps the same 5.8.1 DVD boot chain, but swaps in a larger Devuan
root filesystem with Fluxbox, a dock, an app launcher, file manager, browser,
editor, paint/image/PDF tools, Midnight Commander, networking tools, and the
safe sync/remount helper. It is meant for "boot the disc and land in a usable
desktop" testing, not as the tiny release baseline.

A 6.18.33 modern-kernel diagnostic artifact is also available:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\xbox-linux-devuan-fluxlite-game-disc-modern-diagnostic.iso
```

Build it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_game_disc.ps1
```

Build the full desktop variant with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_desktop_full_payload.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_game_disc_desktop_full.ps1
```

Build the 6.18.33 diagnostic variant with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_game_disc_modern_diagnostic.ps1
```

The disc is intentionally hybrid:

- XDVDFS view: `default.xbe` at root for the Xbox game-disc launch path.
- ISO9660 view: `/linuxboot.cfg`, `/devkrnl`, `/devinit`, and `/devuan.ext2`
  point at the same file sectors for Cromwell's CD loader and Linux's ISO
  payload mount.

Without the ISO9660 overlay, xemu proved that the XBE launches, but Xromwell
stalls at `Detecting system on CD...` because Cromwell only knows how to read
ISO9660 for the CD Linux payload path. The hybrid overlay fixes that while
keeping the game-disc layout intact.

xemu proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-game-disc-iso-probe-fix-155s-20260530-121753.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-game-disc-diagnostic-late-desktop-20260530-132955.png
```

The full desktop game disc has a payload/build sanity check, but the local xemu
Complex BIOS run stopped at the Xromwell launcher screen instead of accepting
keyboard input for the menu selection. The ISO still uses the same real-hardware
game-disc boot path as the FluxLite disc.

Burn the ISO as an image, not as a data disc.

## Real Hardware Notes

Boot the DVD with only a controller connected at first. On real hardware,
Xromwell did not consistently see the DVD drive when a keyboard and mouse were
plugged into the controller ports during firmware/Xromwell startup. With only a
controller connected, the same disc was detected and booted. Plug keyboard and
mouse in after Linux has started or after the desktop is up.

The first real DVD-R boot found Xromwell after a manual retry, but the 6.18.33
kernel could not expose a usable optical block device to stage1. It reported
`Can't open blockdev` for the likely CD/DVD nodes and never mounted the ISO
payload.

If Xromwell initially reports a CD sector read failure, pressing A to retry is
still the expected workaround for this build. That is a separate Xromwell
optical-readiness issue from Linux's DVD block-device handling.

The `game-disc` initramfs now prints a block-device inventory, `/proc/partitions`,
optional CD-ROM info, and each failed ISO mount attempt before dropping to a
shell. It also creates static fallback nodes for old IDE optical names such as
`/dev/hdb` and `/dev/hdc`, because real hardware may not populate the same
devtmpfs nodes xemu does.

Real hardware result: the 6.18.33 diagnostic disc reaches stage1 but cannot
mount the disc payload. It is known-failing for DVD boot on the original Xbox
right now. The 5.8.1 legacy-IDE disc boots successfully. For the DVD/game-disc
release path, use the legacy-IDE default until the newer kernel's Xbox
optical-drive handling is fixed or ported from the old IDE stack (`CONFIG_IDE`,
`CONFIG_BLK_DEV_IDECD`, `CONFIG_BLK_DEV_AMD74XX`).

The 2026-05-30 full desktop ISO SHA256 is:

```text
6E9CD4D0BE11A41250229BE10412BCFE727381CFDF29A5B424E9358F9459161A
```
