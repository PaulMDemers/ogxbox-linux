# Original Xbox Linux Bringup

This repo coordinates the original Xbox Linux bringup work: Cromwell boot media, Xbox-enabled kernel experiments, Tiny Core payload assembly, xemu launchers, and proof notes.

Current known-good release path:

```powershell
.\scripts\build_devuan_5_8_nondisc.ps1
```

That builds the real-hardware-validated, non-disc Devuan 5.8.1 terminal and
desktop XBE packages. The kernel uses the previous working Xbox 5.8.1
configuration with built-in read-only FATX support. Both packages boot from E:
without a Linux payload disc.

Important local files are intentionally not tracked:

- Xbox MCPX/BIOS/HDD/EEPROM files
- generated Cromwell ROMs and ISO images
- downloaded Tiny Core `core.gz` and `.tcz` packages
- xemu binaries
- screenshots and transient run logs

See:

- `PROJECT_STATUS.md` for the current project map, protected baselines,
  repository states, storage inventory, and next work
- `docs/hardware-validation-devuan-5.8.1-nondisc.md` for the exact validated
  Devuan package hashes
- `docs/checkpoint-2026-05-24-6.18-tinycore-xromwell.md` for the current save point, artifact paths, commits, and pre-HDD status
- `xemu-setup.md` for launch/capture commands
- `docs/tinycore11-desktop-iso.md` for the reproducible desktop ISO build
- `docs/kernel-6.18-bringup.md` for the first modern longterm kernel build
- `docs/xromwell-softmod-launcher.md` for the softmod-facing XBE launcher path
- `docs/hdd-fatx-boot.md` for the first FATX HDD boot staging workflow
- `cromwell-notes.md` for boot path notes
- `tinycore-notes.md` for Tiny Core payload notes
- `repos.lock` for the related source forks and branches
