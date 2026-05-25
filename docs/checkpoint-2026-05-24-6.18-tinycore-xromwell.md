# Checkpoint: 6.18 Tiny Core Desktop + Xromwell XBE

Date: 2026-05-24

This is the save point before starting HDD boot work.

## Source State

Root coordination repo:

- `PaulMDemers/ogxbox-linux.git`
- branch: `main`
- source workflow tip before this checkpoint note: `7516d38 Add Xromwell softmod launcher workflow`

Kernel repo:

- `PaulMDemers/xbox-linux.git`
- branch: `xbox-6.18.y-bringup`
- tip: `46679a486 x86: enable Xbox framebuffer and PATA devices`
- local checkout: `/home/paul/ogxbox/linux-6.18-xbox`

Cromwell repo:

- `PaulMDemers/cromwell.git`
- branch: `xbox-linux-fast-atapi-autoboot`
- tip: `5518df9 imagebld: repair XBE output on 64-bit hosts`
- local checkout: `C:\Users\Paul\Desktop\xbox_linux\sources\cromwell-xboxdev`

## Save This ISO

The current known-good Tiny Core desktop ISO is:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33.iso
```

Size:

```text
22,880,256 bytes
```

Last written:

```text
2026-05-24 22:02:21
```

It boots through Cromwell in xemu to a Tiny Core Xfbdev desktop with `flwm_topside`, `wbar`, `aterm`, and the proof banner:

```text
XBOX_TINYCORE_NORMAL_DESKTOP_OK
Linux xbox 6.18.33-xboxdev-00004-g46679a4860b1 ... i686 GNU/Linux
```

Known-good proof screenshot:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\tinycore11-normal-desktop-6.18.33-initrd32-20260524-220431.png
```

## Related Artifacts

Kernel:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\kernels\xbox-linux-6.18.33-bzImage
C:\Users\Paul\Desktop\xbox_linux\artifacts\kernels\xbox-linux-6.18.33.config
```

Xromwell softmod-facing app package:

```text
C:\Users\Paul\Desktop\xbox_linux\build\xromwell-modern-disc\default.xbe
```

Xromwell xemu test disc:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\xromwell-modern-initrd32.iso
```

Known-good XBE launch proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xromwell-modern-clean-xbe-launch-20260524-222321.png
```

## Rebuild Commands

Rebuild the Tiny Core desktop ISO:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_tinycore11_desktop_iso.ps1 `
  -KernelPath artifacts\kernels\xbox-linux-6.18.33-bzImage `
  -OutputIso artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33.iso `
  -Append 'console=tty0 ignore_loglevel loglevel=7'
```

Boot the Tiny Core desktop ISO in xemu:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-modernhdr-initrd32-tinycore11-stage6-xfbdev-desktop-6.18.33.ps1
```

Build the Xromwell softmod-facing XBE package:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_xromwell_xbe_launcher.ps1
```

Boot the Xromwell XBE test image in xemu:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-xromwell-modern-initrd32.ps1
```

Capture xemu proof screenshots with the C# window capture tool:

```powershell
.\tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe --out-dir .\run\screenshots --prefix tinycore11-normal-desktop-6.18.33-initrd32 --rect frame
```

## Current Caveats

- The normal Cromwell ISO path reaches the desktop and is the known-good save point.
- The Xromwell XBE launches correctly under xemu/Complex BIOS.
- The xemu QMP disc-swap attempt from Xromwell XBE to the Tiny Core Linux ISO reaches `Detecting system on CD...` but stalls there; full XBE-to-Linux boot remains pending.
- HDD boot work has not started in this checkpoint.

## Next Work

After the current ISO is saved externally, start the HDD boot path:

- Create a FATX-friendly test layout for `E:\` or `F:\`.
- Decide whether Xromwell should load `linuxboot.cfg`, `vmlinuz`, and initramfs directly from HDD, or whether the first step is an HDD-hosted XBE that chainloads the current ISO-style payload.
- Adapt the Tiny Core initramfs so its extension and boot media discovery can find payload files from HDD, not only from CD.
- Test in xemu with a disposable HDD image before trying a softmodded Xbox.
