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
