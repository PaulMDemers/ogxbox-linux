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
root filesystem with Fluxbox, an app launcher, file manager, browser, editor,
paint/image/PDF tools, Midnight Commander, networking tools, and the safe
sync/remount helper. It is meant for "boot the disc and land in a usable
desktop" testing, not as the tiny release baseline.

The first full-desktop hardware disc booted, but the `wbar` dock locked the
system when the mouse hovered over its icons. The default full-desktop session
therefore leaves `wbar` disabled and uses the Fluxbox right-click menu plus the
terminal app launcher. Add `xbox_wbar=1` to the kernel append line only when
testing the dock failure specifically.

The current preferred full-desktop DVD experiment is the read-only live payload:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\xbox-linux-devuan-desktop-full-live-game-disc.iso
```

This keeps the same XDVDFS `default.xbe` game-disc launch path, but replaces
the large ext2 root image with:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\hdd\xbox-devuan-daedalus-i386-desktop-full.squashfs
```

The goal is to avoid the slow and sometimes inconsistent ext2-in-a-file DVD
read pattern. Linux mounts the squashfs read-only and uses tmpfs/bind mounts for
runtime state such as `/tmp`, `/run`, DHCP leases, logs, and resolver updates.

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

Build the read-only live full desktop variant with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_desktop_full_payload.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_desktop_full_squashfs.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_game_disc_desktop_full_live.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\test_devuan_desktop_apps.ps1
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

The read-only live full desktop disc was also booted through Cromwell autocd in
xemu to the Fluxbox desktop:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-desktop-full-live-cromwell-autocd-xemu-240s-20260530-170422.png
```

Re-run that emulator path with:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-devuan-desktop-full-live-cromwell-autocd.ps1
```

The Complex BIOS game-disc path reached Xromwell's launcher screen in xemu:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-desktop-full-live-game-disc-xemu-180s-20260530-165805.png
```

Re-run the Complex BIOS game-disc path with:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-devuan-desktop-full-live-game-disc.ps1
```

The desktop app dependency smoke passed for `xterm`, `aterm`, `fluxbox`, `jwm`,
`xfe`, `dillo`, `links2`, `mc`, `mtpaint`, `gpicview`, `xpdf`, `wordgrinder`,
`sc`, `nano`, and the Xbox helper scripts. This proves installed binaries and
dynamic libraries, not real-hardware GUI responsiveness. Report:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\reports\devuan-desktop-app-smoke.txt
```

After the first live-disc hardware pass, Fluxbox and extra terminals worked but
launching a raw app from `Applications` froze the session. The current rebuild
routes all menu/app-launcher entries through `/usr/local/bin/xbox-launch-app`.
Stable defaults now use terminal-backed apps (`mc`, `links2`, `nano`), while GUI
apps are launched from a small terminal wrapper that records
`/tmp/xbox-app-logs/<app>.log` and reports whether the process is still alive.
This should tell us which app wedges the session instead of losing the whole
trail.

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
BBEEE0008199D1054A715E8989DFC6E506AB716FD8781785C60B781CA2796911
```

The 2026-05-30 read-only live full desktop ISO SHA256 is:

```text
DA42F2A464D972C6453C2ADDBC49363C54BAF690ADAB9F13BCDBB58B5B9D739D
```

The matching squashfs payload SHA256 is:

```text
A71349C870D61D03452DB065B02495E6D831ABA7597F45C757BABE48674B0320
```
