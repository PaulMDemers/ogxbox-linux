# Release Rev 2026-06-06

This rev rebuilds the current Tiny Core and Devuan boot matrix into one
isolated artifact folder:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\rev-2026-06-06
```

The rev was built with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_release_rev_2026_06_06.ps1
```

The generated metadata lives at:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\rev-2026-06-06\manifest.json
C:\Users\Paul\Desktop\xbox_linux\artifacts\rev-2026-06-06\README.md
```

## Matrix

Normal Cromwell ISO9660 ISOs:

- `isos\tinycore11-desktop-5.8.1.iso`
- `isos\tinycore11-desktop-6.18.33.iso`
- `isos\devuan-daedalus-terminal-5.8.1.iso`
- `isos\devuan-daedalus-terminal-6.18.33.iso`

Xbox game-style XDVDFS ISOs with a minimal ISO9660 overlay:

- `game-isos\tinycore11-desktop-5.8.1-game.iso`
- `game-isos\tinycore11-desktop-6.18.33-game.iso`
- `game-isos\devuan-daedalus-terminal-5.8.1-game.iso`
- `game-isos\devuan-daedalus-terminal-6.18.33-game.iso`
- `game-isos\devuan-daedalus-desktop-live-5.8.1-game.iso`
- `game-isos\devuan-daedalus-desktop-live-6.18.33-game.iso`

XBE zip packages:

- `xbes\tinycore11-desktop-5.8.1-xbe.zip`
- `xbes\tinycore11-desktop-6.18.33-xbe.zip`
- `xbes\devuan-daedalus-terminal-5.8.1-xbe-disc-assisted.zip`
- `xbes\devuan-daedalus-terminal-6.18.33-xbe.zip`
- `xbes\devuan-daedalus-desktop-live-5.8.1-xbe-disc-assisted.zip`
- `xbes\devuan-daedalus-desktop-live-6.18.33-xbe.zip`

Tiny Core XBE packages are self-contained: the Tiny Core root and desktop
extensions are embedded in the initramfs.

Devuan 6.18 XBE packages include the payload file in `E-root` because the 6.18
kernel line includes the FATX file-backed payload path.

Devuan 5.8 XBE packages are disc-assisted. They include Xromwell, kernel,
initrd, and `linuxboot.cfg`, but not the Devuan payload. Keep the matching disc
inserted so stage1 can mount the payload from ISO9660.

## Verification

The rev builder completed successfully on June 6, 2026.

## Hardware Status

Latest real-hardware disc tests:

- `game-isos\devuan-daedalus-desktop-live-5.8.1-game.iso` boots to the
  desktop and is the current release baseline.
- The 5.8.1 desktop still needs launcher polish: terminal windows open, but
  the app menu can show white text on a white background and non-terminal apps
  do not yet launch cleanly.
- `game-isos\devuan-daedalus-desktop-live-6.18.33-game.iso` is still
  experimental. It presents as a desktop build, but the current hardware result
  reaches the terminal path rather than the desktop.
- Real hardware then confirmed `tinycore11-desktop-5.8.1-game.iso` boots to the
  Tiny Core desktop. There is still a noticeable pause before the wallpaper
  appears, but the image is functionally back in the good set.
- Real hardware showed `tinycore11-desktop-6.18.33-game.iso` reaches `/init`,
  but the Tiny Core stage could not find `core.gz` on `/mnt/cd`. That is a
  Linux-side CD device discovery problem, not an Xromwell handoff panic. The
  stage6 initramfs now creates missing block device nodes from `/sys/block`,
  retries the ISO mount path, and probes both legacy IDE and libata/SCSI CD
  naming before giving up.
- A later 6.18 hardware retry proved the expanded probe still did not expose a
  usable optical device and produced too much fallback mount noise before
  dropping to the BusyBox shell. The 6.18 Tiny Core game ISO now uses an
  XZ-compressed self-contained Tiny Core initramfs instead, so once Xromwell
  loads `zinitrd` the kernel does not need to mount the DVD again to reach
  `core.gz` and the desktop extensions.
- The first self-contained 6.18 game ISO put the large `initramf` before
  `default.xbe` in the XDVDFS root and real hardware reported `tray empty`.
  A nested `boot\initramf` layout then reached Xromwell handoff but Linux did
  not see the initrd and panicked at `unknown-block(3,1)`.
- The current 6.18 game ISO keeps the kernel and initrd at the XDVDFS root for
  Linux handoff, but names them `akrn` and `zinitrd`. With those names,
  `default.xbe` packs first in the root directory while Xromwell still has
  root-level boot payload files to load.
- The current 6.18 game initramfs omits `Xorg-fonts.tcz` only for the game-disc
  build, reducing the compressed handoff payload from about 16.2 MiB to
  15,351,456 bytes. This is intended to stay below the suspected 16 MiB
  Xromwell/Cromwell initrd handoff boundary. The full Tiny Core XBE payload is
  unchanged.

Xemu input automation against the Xromwell menu is not currently a reliable
boot proof: a recent run locked up when sending `A`. Prefer real hardware for
game-disc visibility tests and use xemu only for no-input smoke checks until we
have a safer controller automation path.

Structural verification passed:

- every `game-isos\*.iso` reports `Valid: true` through `tools\xdvdfs\xdvdfs.exe info`
- every `xbes\*.zip` contains `default.xbe` and `E-root\linuxboot.cfg`
- every file hash in `manifest.json` matches the file on disk

Light xemu Complex/Xromwell recognition screenshots were captured for all game
ISOs under:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\rev-2026-06-06-*.png
```

This was a recognition smoke only, not a full boot certification for every
image. The next real-hardware pass should start with the 5.8 game ISOs, then
compare 6.18 behavior.
