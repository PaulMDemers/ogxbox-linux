# Xbox Linux Game Disc

This path builds an Xbox-style XDVDFS disc image that has `default.xbe` at the
disc root, so a chipped Xbox or BIOS that boots game discs can launch Xromwell
directly from DVD-R.

The current artifact is:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\xbox-linux-devuan-fluxlite-game-disc.iso
```

Build it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_game_disc.ps1
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
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-fluxlite-game-disc-hybrid-150s-20260530-011841.png
```

Burn the ISO as an image, not as a data disc.
