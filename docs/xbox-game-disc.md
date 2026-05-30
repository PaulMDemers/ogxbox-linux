# Xbox Linux Game Disc

This path builds an Xbox-style XDVDFS disc image that has `default.xbe` at the
disc root, so a chipped Xbox or BIOS that boots game discs can launch Xromwell
directly from DVD-R.

The current artifact is:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\xbox-linux-devuan-fluxlite-game-disc.iso
```

A legacy-IDE test artifact is also available:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\xbox-linux-devuan-fluxlite-game-disc-legacy-ide.iso
```

Build it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_game_disc.ps1
```

Build the legacy-IDE variant with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_game_disc_legacy_ide.ps1
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

Burn the ISO as an image, not as a data disc.

## Real Hardware Notes

The first real DVD-R boot found Xromwell after a manual retry, but stage1 then
dropped to a shell because it assumed the optical drive would appear as
`/dev/hdb`. The rebuilt initramfs now inventories `/sys/block`, creates missing
block device nodes when devtmpfs/mdev did not create them, and tries each likely
optical device until it mounts the ISO that actually contains `/devuan.ext2`.

If Xromwell initially reports a CD sector read failure, pressing A to retry is
still the expected workaround for this build. That is a separate Xromwell
optical-readiness issue from the Linux `/dev/hdb` assumption.

The `game-disc` initramfs now prints a block-device inventory, `/proc/partitions`,
optional CD-ROM info, and each failed ISO mount attempt before dropping to a
shell. It also creates static fallback nodes for old IDE optical names such as
`/dev/hdb` and `/dev/hdc`, because real hardware may not populate the same
devtmpfs nodes xemu does.

If the 6.18.33 disc still cannot mount the ISO payload on real hardware, test
the `legacy-ide` ISO next. It keeps the same game-disc layout and Devuan
payload, but swaps `devkrnl` to the older 5.8.1 kernel with legacy IDE/ATAPI
CD-ROM support (`CONFIG_IDE`, `CONFIG_BLK_DEV_IDECD`, `CONFIG_BLK_DEV_AMD74XX`).
