# Tiny Core 11 Xfbdev Desktop ISO

This builds the current known-good ISO that reaches a Tiny Core Xfbdev desktop with `flwm_topside`, `wbar`, the Tiny Core background, and an `aterm` proof window showing:

- `XBOX_TINYCORE_NORMAL_DESKTOP_OK`
- `Linux xbox 6.18.33-xboxdev-00004-g46679a4860b1 ... i686 GNU/Linux`
- framebuffer: `simple`, `640,480`, `32`
- USB keyboard and QEMU USB tablet input devices

## Prerequisites

Keep these local inputs out of Git:

- `Xbox-Emulator-Files\mcpx\mcpx_1.0.bin`
- `Xbox-Emulator-Files\hdd\xbox_hdd.qcow2`
- `run\eeprom.bin`
- `artifacts\cromwell-autocd_1024.bin`
- `artifacts\kernels\xbox-linux-5.8.1-noxpad-bzImage`

If the no-xpad kernel is missing, rebuild it under WSL:

```powershell
wsl bash /mnt/c/Users/Paul/Desktop/xbox_linux/scripts/build_noxpad_kernel.sh
```

## Build

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_tinycore11_desktop_iso.ps1
```

Output:

```text
artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-noxpad.iso
```

The script downloads and verifies Tiny Core 11.x `core.gz`, downloads the recursive desktop `.tcz` extension closure, builds the stage6 initramfs, and creates the Cromwell ISO.

To build the same Tiny Core desktop payload with the 6.18.33 test kernel:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_tinycore11_desktop_iso.ps1 `
  -KernelPath artifacts\kernels\xbox-linux-6.18.33-bzImage `
  -OutputIso artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33.iso `
  -Append 'console=tty0 ignore_loglevel loglevel=7'
```

## Boot

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-tinycore11-stage6-xfbdev-desktop-noxpad-usbkbd-tablet.ps1
```

The launcher uses:

- `artifacts\cromwell-autocd_1024.bin`
- `artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-noxpad.iso`
- `-device usb-kbd`
- `-device usb-tablet`

For the 6.18.33 path, use the initrd32 Cromwell handoff launcher:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-modernhdr-initrd32-tinycore11-stage6-xfbdev-desktop-6.18.33.ps1
```

The launcher uses:

- `artifacts\cromwell-autocd-modernhdr-initrd32_1024.bin`
- `artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33.iso`
- `-device usb-kbd`
- `-device usb-tablet`

## Capture Proof

```powershell
.\tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe --out-dir .\run\screenshots --prefix tinycore11-desktop --rect frame
```

Known-good proof screenshots from the first successful run:

- `run\screenshots\tinycore11-stage6-xfbdev-desktop-20260524-162921.png`
- `run\screenshots\tinycore11-stage6-xfbdev-desktop-input-20260524-162945.png`

Known-good 6.18.33 normal desktop proof screenshot:

- `run\screenshots\tinycore11-normal-desktop-6.18.33-initrd32-20260524-220431.png`
