# Xromwell Softmod Launcher

The softmod-facing launcher is Cromwell's XBE build packaged as:

```text
build\xromwell-modern-disc\default.xbe
```

Build it from the root repo with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_xromwell_xbe_launcher.ps1
```

That also creates an emulator XDVDFS test image:

```text
artifacts\xromwell-modern-initrd32.iso
```

Launch proof in xemu:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-xromwell-modern-initrd32.ps1
```

Known-good proof:

```text
run\screenshots\xromwell-modern-clean-xbe-launch-20260524-222321.png
```

For a softmodded Xbox, copy the folder contents so the dashboard sees `default.xbe` as an app. The intended Linux path is to launch Xromwell from HDD, then boot an ISO9660 Linux disc such as `artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33.iso`.

Current emulator status: xemu proves the rebuilt XBE launches under the retail/Complex BIOS. A QMP DVD swap from the XBE disc to the Tiny Core Linux ISO reaches Xromwell's CD detection path, but it currently stalls at `Detecting system on CD...`; treat full XBE-to-Linux boot as pending real-hardware or better HDD-launched XBE testing.
