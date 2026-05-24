# xemu Setup

Installed xemu:

- Version: `0.8.135`
- Executable: `tools/xemu/xemu.exe`
- Download URL: `downloads/xemu-url.txt`

Local Xbox files:

- MCPX ROM: `Xbox-Emulator-Files/mcpx/mcpx_1.0.bin`
- BIOS: `Xbox-Emulator-Files/bios/Complex_4627.bin`
- HDD: `Xbox-Emulator-Files/hdd/xbox_hdd.qcow2`
- EEPROM: `run/eeprom.bin`

Launch normally:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu.ps1
```

Launch with the known retail 1.0 EEPROM test vector:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-retail10.ps1
```

Launch without writing HDD changes:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-snapshot.ps1
```

Launch the known-good NXDK color-bars smoke ISO copied from `ogxbSharp`:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-nxdk-color-bars.ps1
```

Launch the patched xemu build for Cromwell/Xromwell testing:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-xromwell-xboxdev-patched.ps1
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-xboxdev-patched.ps1
```

Launch the working custom Cromwell Linux ISO path:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-fast-atapi.ps1
```

As of the clean verification on 2026-05-24, this path loads `/vmlinuz` and begins `/initramf`, but does not yet complete the full initramfs read.

Launch the current tiny userspace proof:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-tiny-init.ps1
```

As of 2026-05-24, this path boots the original Xbox 5.8.1 kernel from Cromwell and starts `/init` from `artifacts/initramfs/xbox-tiny-init.cpio`. The clean proof screenshot is `run/cromwell-tiny-init-raw-cpio-nousb-180s.png`.

Launch the BusyBox initramfs proof:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-busybox-init.ps1
```

As of 2026-05-24, this path boots `artifacts/initramfs/xbox-busybox-raw.cpio` and reaches `/init` with `noswitchroot`. The proof screenshot is `run/cromwell-busybox-init-progress-300s.png`.

Launch the BusyBox console-output proof:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-busybox-console.ps1
```

As of 2026-05-24, this path boots `artifacts/initramfs/xbox-busybox-console.cpio` and prints a userspace banner, command line, BusyBox version, and mounted filesystems to `/dev/console`. The proof screenshot is `run/cromwell-busybox-console-8sec-input.png`.

Launch the BusyBox interactive keyboard proof:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-busybox-console-noxpad-usbkbd.ps1
```

As of 2026-05-24, this path boots `artifacts/cromwell-busybox-console-noxpad.iso` with `artifacts/cromwell-autocd_1024.bin`, attaches QEMU `usb-kbd`, reaches `/bin/sh` on `/dev/console`, and accepts keyboard input. The proof screenshot is `run/screenshots/immediate-post-input-20260524-145437.png`.

Launch the BusyBox stage2 storage probe:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-busybox-stage2-noxpad-usbkbd.ps1
```

As of 2026-05-24, this path boots `artifacts/cromwell-busybox-stage2-noxpad.iso`, reaches userspace, identifies `hda` and `hdb`, mounts `/dev/hdb` as ISO9660 on `/mnt/cd`, and lists the boot CD contents. The proof screenshot is `run/screenshots/stage2-ready-20260524-150103.png`.

HDD probing from stage2:

- Proof screenshot: `run/screenshots/hda-probe-escaped-post-20260524-151601.png`
- Result: `/dev/hda` is an 8 GB disk, but it has no valid PC partition table and does not mount directly. Treat the stock Xbox HDD image as read-only for now.

Launch the Tiny Core stage3 payload probe:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-tinycore-stage3-noxpad-usbkbd.ps1
```

As of 2026-05-24, this path boots the proven Xbox kernel/initramfs path, mounts the CD, verifies Tiny Core `core.gz` as a userspace payload, previews its cpio archive contents, and drops to a shell. The proof screenshot is `run/screenshots/tinycore-stage3-ready-20260524-152347.png`.

Launch the Tiny Core stage4 chroot proof:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-tinycore-stage4-noxpad-usbkbd.ps1
```

As of 2026-05-24, this path extracts Tiny Core `core.gz` to `/mnt/tcroot`, prepares `/proc`, `/sys`, `/dev`, and `/tmp`, runs proof commands inside `chroot /mnt/tcroot`, and reaches a Tiny Core `/bin/sh`. The proof screenshot is `run/screenshots/tinycore-stage4-ready-20260524-153246.png`.

Launch the Tiny Core 11 Xfbdev desktop proof:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-tinycore11-stage6-xfbdev-desktop-noxpad-usbkbd-tablet.ps1
```

As of 2026-05-24, this path boots the Xbox 5.8.1 no-xpad kernel, extracts Tiny Core 11.x, mounts the GUI `.tcz` extensions from CD, starts `Xfbdev`, `flwm_topside`, and `aterm`, and accepts keyboard input inside the X terminal. The proof screenshots are `run/screenshots/tinycore11-stage6-xfbdev-desktop-20260524-162921.png` and `run/screenshots/tinycore11-stage6-xfbdev-desktop-input-20260524-162945.png`.

Tiny Core 16.x is still useful as a modern payload/chroot probe, but its FLTK/window-manager binaries require a Linux 6.1.2 ABI. For the current Xbox 5.8.1 kernel, use Tiny Core 11.x for the desktop path.

Capture the xemu window:

```powershell
.\tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe --out-dir .\run\screenshots --prefix xemu --rect frame
```

The capture tool is a compiled C# helper. It opts into per-monitor DPI awareness before reading the xemu HWND geometry; without that, Windows scaling can make `GetWindowRect` and screen-pixel capture disagree.

Send the standard shell probe to a running xemu window:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\send_xemu_shell_probe.ps1
```

Notes:

- `run/xemu.toml` contains the portable xemu config.
- The TOML configs must set `[general] show_welcome = false`; otherwise xemu prints valid launch arguments but does not autostart the VM, leaving only the welcome/settings placeholder.
- For Cromwell menu automation, the TOML configs bind the host keyboard as controller port 1:
  - `[input.bindings] port1 = 'keyboard'`
  - `[input.bindings] port1_driver = 'usb-xbox-gamepad'`
  - The host `a` key acts as the Xbox A button in the current mapping.
- This xemu build reads the local MCPX, HDD, and EEPROM from TOML, but the launch scripts also pass the BIOS with `-bios` because the TOML `flashrom_path` was not added to the generated QEMU command during smoke testing.
- The smoke test used `-display none -S`, which starts the emulator paused and verifies the files/config without booting the guest.
- The default `%APPDATA%/xemu/xemu/xemu.toml` was also mirrored from `run/xemu.toml` while debugging xemu's first-run configuration overlay.
- Baseline visible boot is now confirmed. With no DVD, xemu reaches the BIOS message `Please insert an Xbox disc...`; with `artifacts/reference/xbtest_02_video_color_bars.iso`, it boots the NXDK color-bars program.
- Patched build: `tools/xemu-v0.8.135-nvnet/xemu.exe`. This is the local build with the Cromwell nvnet assert patched out; keep `tools/xemu/xemu.exe` as the stock reference build.
- `tools/xemu-v0.8.135-nvnet/xemu.exe` has been restored to the non-instrumented patched executable. A temporary ATAPI-logging rebuild was used during debugging, but the packaged executable no longer writes `run/xemu-atapi.log`.
