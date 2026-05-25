# Original Xbox Linux Bringup

This repo coordinates the original Xbox Linux bringup work: Cromwell boot media, Xbox-enabled kernel experiments, Tiny Core payload assembly, xemu launchers, and proof notes.

Current known-good path:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-modernhdr-initrd32-tinycore11-stage6-xfbdev-desktop-6.18.33.ps1
```

That boots the Xbox Linux 6.18.33 kernel through Cromwell, extracts Tiny Core 11.x, mounts the GUI `.tcz` extension set from CD, and starts a Tiny Core `Xfbdev` desktop with `flwm_topside`, `wbar`, and `aterm`.

Important local files are intentionally not tracked:

- Xbox MCPX/BIOS/HDD/EEPROM files
- generated Cromwell ROMs and ISO images
- downloaded Tiny Core `core.gz` and `.tcz` packages
- xemu binaries
- screenshots and transient run logs

See:

- `xemu-setup.md` for launch/capture commands
- `docs/tinycore11-desktop-iso.md` for the reproducible desktop ISO build
- `docs/kernel-6.18-bringup.md` for the first modern longterm kernel build
- `docs/xromwell-softmod-launcher.md` for the softmod-facing XBE launcher path
- `cromwell-notes.md` for boot path notes
- `tinycore-notes.md` for Tiny Core payload notes
- `repos.lock` for the related source forks and branches
