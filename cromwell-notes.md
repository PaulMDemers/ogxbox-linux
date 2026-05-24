# Cromwell 2.40 Notes

Downloaded from SourceForge:

- `downloads/cromwell/cromwell-2.40.tar.gz`

Extracted files:

- `sources/cromwell-2.40/cromwell.bin`
- `sources/cromwell-2.40/cromwell_1024.bin`
- `sources/cromwell-2.40/xromwell.xbe`

MD5s match the upstream `md5sums` file.

Created a boot ISO:

- `artifacts/cromwell-smoke.iso`

ISO contents:

- `linuxboot.cfg`
- `vmlinuz`
- `initramf`

Launcher:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-smoke.ps1
```

Current status:

- xemu accepts both Cromwell ROM sizes and the ISO-backed DVD drive.
- Cromwell stays alive under xemu, but video still shows xemu's "no guest display yet" placeholder. Tested HDTV and composite AV pack.

XboxDev Cromwell / Xromwell:

- Downloaded XboxDev Cromwell release `build-20250529-86f5473`.
- Artifacts:
  - `downloads/cromwell-xboxdev/build-20250529-86f5473/cromwell.bin`
  - `downloads/cromwell-xboxdev/build-20250529-86f5473/cromwell_1024.bin`
  - `downloads/cromwell-xboxdev/build-20250529-86f5473/xromwell.xbe`
- Added `run/xemu-cromwell-xboxdev.toml` and `run-xemu-cromwell-xboxdev-smoke.ps1`.
- Created Xromwell XISO:
  - Source folder: `build/xromwell-disc/default.xbe`
  - Image: `artifacts/xromwell-xboxdev.iso`
  - Tool: `tools/xdvdfs/xdvdfs.exe`
- Added `run/xemu-xromwell-xboxdev.toml` and `run-xemu-xromwell-xboxdev.ps1`.

Current blocker:

- Plain xemu boot is fixed after setting `[general] show_welcome = false` in xemu TOML configs.
- Local file hashes:
  - `mcpx_1.0.bin`: MD5 `D49C52A4102F6DF7BCF8D0617AC475ED`
  - `Complex_4627.bin`: MD5 `EC00E31E746DE2473ACFE7903C5A4CB7`
  - `xbox_hdd.qcow2`: MD5 `F13BFBB7C43E9404DEF0FDB48B2BD497`
- Tested both xemu `v0.8.135` and `v0.8.134`.
- The XboxDev Cromwell ROM path and Xromwell XBE path now both reach xemu execution, but xemu aborts on `nvnet_mmio_write: assertion failed: ((addr & 3) == 0 && "Unaligned MMIO write")`.
- A known-good NXDK homebrew ISO from `ogxbSharp` boots correctly in this same xemu setup, so the current Cromwell blocker is specific to Cromwell/Xromwell touching nvnet, not a general xemu configuration failure.
- Next practical options:
  - Use direct xemu Linux loading and keep debugging why the Xbox kernel stays black/no-serial.
  - Patch/build xemu so `nvnet` tolerates or ignores Cromwell's unaligned MMIO write.
  - Try an older/newer Cromwell build that does not initialize nvnet this way.

Patched xemu status:

- Built local patched xemu from tag `v0.8.135` in `sources/xemu-v0.8.135-nvnet`.
- Packaged executable and DLLs in `tools/xemu-v0.8.135-nvnet`.
- Local patches:
  - `hw/xbox/mcpx/nvnet/nvnet.c`: replace the dword-only MMIO alignment assert with size-aware alignment handling, log true misaligned writes, and avoid asserting on partial `NVNET_MDIO_ADDR` writes.
  - `meson.build`: keep Vulkan disabled on Windows for this local build to avoid bundled CMake subproject path trouble.
  - `scripts/symlink-install-tree.py`: fall back/skip when symlinks require Developer Mode.
  - `ui/xui/common.hh` and `ui/xemu-snapshots.h`: keep `qemu/osdep.h` outside `extern "C"` for current MSYS2 GLib headers.
- New launchers:
  - `run-xemu-xromwell-xboxdev-patched.ps1`
  - `run-xemu-cromwell-xboxdev-patched.ps1`
- Smoke result on 2026-05-24:
  - Xromwell XBE path stayed running for 20 seconds; no `nvnet_mmio_write` abort and empty stderr/stdout logs.
  - Cromwell ROM path stayed running for 20 seconds; no `nvnet_mmio_write` abort and empty stderr/stdout logs.
  - Screenshots captured:
    - `run/xromwell-patched-desktop.png`
    - `run/cromwell-patched-desktop.png`

Working Cromwell Linux boot path:

- The Xromwell XBE can be launched from an XDVDFS/XISO disc, but once inside Cromwell its Linux CD loader reads files through its ISO9660 code (`BootIso9660GetFile`). A plain XISO containing `linuxboot.cfg` is therefore not enough for Linux boot.
- `scripts/make_cromwell_iso.py` now builds ISO9660 Linux boot discs for Cromwell:
  - `artifacts/cromwell-smoke.iso`
  - `artifacts/cromwell-serial-smoke.iso`
  - `artifacts/cromwell-tiny-read.iso`
- Important ISO9660 filename detail: Cromwell lowercases raw ISO names and strips trailing `.;1`/`;1`, but it does not use Joliet. The kernel entry must be `VMLINUZ.;1` so Cromwell sees `/vmlinuz`; `VMLINUX.;1` was the earlier accidental `/vmlinux` spelling.
- Stock XboxDev Cromwell finds `linuxboot.cfg` and `/vmlinuz`, but its ISO reader issued one ATAPI `READ_10` command per 2048-byte sector. That made the 3.5 MB kernel and 14 MB initramfs impractically slow under xemu.
- Local Cromwell source patch:
  - `drivers/ide/BootIde.c`: add `BootIdeIssueAtapiPacketCommandAndPacketLimit`, allow ATAPI reads larger than one sector, and shorten retry waits for this xemu test path.
  - `fs/cdrom/iso9660.c`: read ISO files in up-to-8-sector chunks and fix the final partial-sector copy. A 31-sector chunk was faster but intermittently stuck on the 2.2 MB BusyBox initramfs in xemu.
  - `Makefile`: build the host-side `imagebld` helper without `-m32` under WSL. The helper still segfaults during XBE repair on 64-bit, but the ROM images are emitted before that step.
- Custom Cromwell ROM artifacts:
  - `artifacts/cromwell-fast-atapi.bin`
  - `artifacts/cromwell-fast-atapi_1024.bin`
- Launchers:
  - `run-xemu-cromwell-fast-atapi.ps1`
  - `run-xemu-cromwell-fast-serial.ps1`
- Confirmed on 2026-05-24:
  - `run/cromwell-clean-verify-desktop.png`: with only `xemu.exe` running, Cromwell loads `/vmlinuz` successfully and starts reading `/initramf`.
  - `run/cromwell-clean-long-desktop.png`: after a clean six-minute run, Cromwell is still at `Loading /initramf from CD`.
  - Earlier screenshots that appeared to show the SrvOS monitor were contaminated by another local QEMU/SrvOS project window and should not be treated as Xbox boot proof.
- Tiny initramfs proof on 2026-05-24:
  - Built `artifacts/initramfs/xbox-tiny-init.cpio`, an uncompressed `newc` archive containing a static 32-bit `/init`.
  - Built `artifacts/cromwell-tiny-init.iso` with the original `artifacts/kernels/xbox-linux-5.8.1-bzImage`, the raw cpio initramfs, and `append init=/init nousb debug`.
  - `run/cromwell-tiny-init-raw-cpio-nousb-180s.png` is the clean xemu-only proof: Linux reaches `Run /init as init process`, passes `/init` and `nousb` arguments, and starts `/init`.
  - Gzip-compressed initramfs with the original kernel reaches kernel boot but panics at `gzip decompressor not configured`; that kernel has `CONFIG_RD_XZ=y` but not `CONFIG_RD_GZIP`.
  - Rebuilt test kernel `artifacts/kernels/xbox-linux-5.8.1-rd-gzip-bzImage` enables `CONFIG_RD_GZIP`, but it stalled at the Cromwell handoff in xemu, so the current reliable proof path uses the original kernel plus raw cpio.
- BusyBox initramfs proof on 2026-05-24:
  - `scripts/make_busybox_initramfs.py` builds `artifacts/initramfs/xbox-busybox-raw.cpio` and `artifacts/initramfs/xbox-busybox-console.cpio` from `sources/xbox-linux-initramfs`, preserving the original symlinks that the Windows checkout flattened.
  - The static i386 BusyBox archive is about 2.2 MB raw cpio.
  - ISOs:
    - `artifacts/cromwell-busybox-init.iso`
    - `artifacts/cromwell-busybox-console.iso`
  - Launcher: `run-xemu-cromwell-busybox-init.ps1`.
  - `run/cromwell-busybox-init-progress-300s.png` shows the original Xbox 5.8.1 kernel starting `/init` from the BusyBox initramfs with `noswitchroot`.
  - Launcher: `run-xemu-cromwell-busybox-console.ps1`.
  - `run/cromwell-busybox-console-8sec-input.png` shows the custom console `/init` reaching userspace, printing the kernel command line, BusyBox version, and mounted filesystems.
  - Keyboard input proof:
    - Built `artifacts/kernels/xbox-linux-5.8.1-noxpad-bzImage` with `CONFIG_JOYSTICK_XPAD` disabled while keeping `CONFIG_USB_HID=y`.
    - Built `artifacts/cromwell-busybox-console-noxpad.iso` with the no-xpad kernel and the same BusyBox console initramfs.
    - Built `artifacts/cromwell-autocd_1024.bin`, a test Cromwell ROM that automatically selects the CD-ROM Linux boot path so xemu can attach the host keyboard as `usb-kbd` instead of using keyboard-as-gamepad input for Cromwell's menu.
    - Config: `run/xemu-cromwell-busybox-console-noxpad-usbkbd.toml`.
    - Launcher: `run-xemu-cromwell-busybox-console-noxpad-usbkbd.ps1`.
    - Helper scripts:
      - `scripts/start_xemu_noxpad_usbkbd.ps1`
      - `scripts/send_xemu_shell_probe.ps1`
    - Capture tool: `tools/capture-xemu-window/bin/Release/net10.0-windows/CaptureXemuWindow.exe`.
    - `run/screenshots/immediate-post-input-20260524-145437.png` is the clean proof: the shell accepts `echo CODEX_OK`, `uname -a`, and `cat /proc/cmdline`; output shows `Linux xbox 5.8.1-xboxdev ... i686 GNU/Linux` and `init=/init noswitchroot debug`.
  - Cromwell currently has lightweight ISO read progress prints in `fs/cdrom/iso9660.c`; they were useful for confirming the larger raw initramfs read completed.
- BusyBox stage2 storage proof on 2026-05-24:
  - `scripts/make_busybox_initramfs.py` now also builds `artifacts/initramfs/xbox-busybox-stage2.cpio`.
  - `scripts/make_cromwell_iso.py` has `CROMWELL_ISO_MODE=busybox-stage2-noxpad`.
  - ISO: `artifacts/cromwell-busybox-stage2-noxpad.iso`.
  - Config: `run/xemu-cromwell-busybox-stage2-noxpad-usbkbd.toml`.
  - Launcher: `run-xemu-cromwell-busybox-stage2-noxpad-usbkbd.ps1`.
  - `run/screenshots/stage2-ready-20260524-150103.png` is the clean proof: the kernel identifies the HDD as `hda`, the DVD as `hdb`, mounts `/dev/hdb` on `/mnt/cd` as ISO9660, and lists `initramf`, `linuxboot.cfg`, and `vmlinuz` from the mounted CD.
  - `run/screenshots/hda-probe-escaped-post-20260524-151601.png` is the HDD layout proof: `/dev/hda` is visible as an 8 GB disk, but `busybox fdisk -l /dev/hda` reports no valid PC partition table and `mount -o ro /dev/hda /mnt/hda` fails with `Invalid argument`.
  - First persistence experiments should not write to the stock Xbox HDD image. Use a separate image or a stage3 filesystem on CD first, then revisit FATX/Xbox HDD support deliberately.
- Tiny Core stage3 payload proof on 2026-05-24:
  - Downloaded Tiny Core 16.x x86 `core.gz` from the public mirror `https://mirror.dotsrc.org/tinycorelinux/16.x/x86/release/distribution_files/core.gz`.
  - MD5 verified against `core.gz.md5.txt`: `dc5be5cccbdc3ecf64f885ff442d4558`.
  - Local payload: `downloads/tinycore/16.x/x86/core.gz`.
  - `scripts/make_busybox_initramfs.py` now also builds `artifacts/initramfs/xbox-tinycore-stage3.cpio`.
  - `scripts/make_cromwell_iso.py` has `CROMWELL_ISO_MODE=tinycore-stage3-noxpad`, which adds Tiny Core `core.gz` to the boot CD while keeping Cromwell's initramfs read small.
  - ISO: `artifacts/cromwell-tinycore-stage3-noxpad.iso`.
  - Config: `run/xemu-cromwell-tinycore-stage3-noxpad-usbkbd.toml`.
  - Launcher: `run-xemu-cromwell-tinycore-stage3-noxpad-usbkbd.ps1`.
  - `run/screenshots/tinycore-stage3-ready-20260524-152347.png` is the clean proof: Xbox Linux mounts the CD, reads Tiny Core `core.gz` with BusyBox `zcat | cpio`, lists Tiny Core archive contents, and drops to a shell in `/tmp/tinycore`.
- Tiny Core stage4 chroot proof on 2026-05-24:
  - `scripts/make_busybox_initramfs.py` now also builds `artifacts/initramfs/xbox-tinycore-stage4.cpio`.
  - `scripts/make_cromwell_iso.py` has `CROMWELL_ISO_MODE=tinycore-stage4-noxpad`, which adds Tiny Core `core.gz` to the boot CD and uses a stage4 initramfs that extracts it to `/mnt/tcroot`.
  - ISO: `artifacts/cromwell-tinycore-stage4-noxpad.iso`.
  - Config: `run/xemu-cromwell-tinycore-stage4-noxpad-usbkbd.toml`.
  - Launcher: `run-xemu-cromwell-tinycore-stage4-noxpad-usbkbd.ps1`.
  - `run/screenshots/tinycore-stage4-ready-20260524-153246.png` is the clean proof: `chroot /mnt/tcroot /bin/sh` runs successfully, prints `CHROOT_OK`, reports `Linux xbox 5.8.1-xboxdev ... i686 GNU/Linux`, shows Tiny Core BusyBox `v1.36.1`, and lists a Tiny Core root filesystem.
  - The final interactive chroot shell currently prints `/bin/sh: can't access tty; job control turned off`; this is expected for the simple `/dev/console` chroot handoff and should be cleaned up later with a better `setsid`/`cttyhack`/devpts setup or a proper `switch_root`.
- Tiny Core desktop proof on 2026-05-24:
  - `scripts/make_busybox_initramfs.py` now also builds `artifacts/initramfs/xbox-tinycore-stage5-desktop-probe.cpio` and `artifacts/initramfs/xbox-tinycore-stage6-xfbdev-desktop.cpio`.
  - Stage5 proved the desktop prerequisites under xemu: `/dev/fb0` is `simple` framebuffer at `640,480`, `32` bpp; QEMU USB keyboard is `event0`; QEMU USB tablet is `mouse0`, `js0`, and `event1`.
  - Stage6 mounts Tiny Core `.tcz` extensions from CD as SquashFS loops under `/tmp/tcloop`, symlinks them into the chroot, mounts `devpts`, runs `tce.installed` hooks, then starts `Xfbdev`, `flwm_topside`, and `aterm`.
  - Tiny Core 16.x can start `Xfbdev`, but many FLTK/window-manager clients are stamped with Linux ABI `6.1.2`, so they are not suitable for the current Xbox 5.8.1 kernel.
  - Tiny Core 11.x x86 matches the current kernel: inspected TC11 `flwm_topside` ABI is `4.8.17`, `flrun` is `3.8.13`, and `Xfbdev` is `4.2.9`.
  - Downloaded and MD5-verified Tiny Core 11.x `core.gz`: `0fd08c73e84b26aabbd0d12006d64855`.
  - TC11 desktop extension closure is in `downloads/tinycore/11.x/x86/tcz/desktop-load-order.txt`.
  - ISO: `artifacts/cromwell-tinycore11-stage6-xfbdev-desktop-noxpad.iso`.
  - Config: `run/xemu-cromwell-tinycore11-stage6-xfbdev-desktop-noxpad-usbkbd-tablet.toml`.
  - Launcher: `run-xemu-cromwell-tinycore11-stage6-xfbdev-desktop-noxpad-usbkbd-tablet.ps1`.
  - Proof screenshots:
    - `run/screenshots/tinycore-stage5-compact-fb-input-20260524-155313.png`: framebuffer and input devices.
    - `run/screenshots/tinycore11-stage6-xfbdev-desktop-20260524-162921.png`: Xfbdev desktop with `flwm_topside` window decorations and aterm proof window.
    - `run/screenshots/tinycore11-stage6-xfbdev-desktop-input-20260524-162945.png`: keyboard input accepted inside the X terminal.
- Current caveats:
  - `-serial file:...` did not capture kernel output through the Cromwell boot path, even with the serial kernel ISO.
  - The distro-sized 14 MB TinyCore gzip initramfs still does not complete reliably through Cromwell's ISO9660/ATAPI path under xemu, and it would also need either raw cpio conversion or a kernel with the matching decompressor enabled.
