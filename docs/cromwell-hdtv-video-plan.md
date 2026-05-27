# Cromwell HDTV Video Plan

Date: May 26, 2026

The current blocker is that Cromwell works over composite/AV output, but the
HDMI adapter path can go blank. The likely issue is not Linux yet; Cromwell is
doing the first video setup before the kernel boots.

## Current Code State

Cromwell detects the AV pack through the PIC/SMC value:

```text
sources\cromwell-xboxdev\drivers\video\BootVgaInitialization.c
VIDEO_AV_MODE = I2CTransmitByteGetReturn(0x10, 0x04)
```

That value is mapped in:

```text
sources\cromwell-xboxdev\drivers\video\VideoInitialization.c
case 1: AV_HDTV
```

There is already an HDTV path in `BootVgaInitialization.c`, but it is pinned to
480p:

```text
xbox_hdtv_mode hdtv_mode = HDTV_480p;
//Only 480p supported at present
```

The 720p and 1080i selection logic is present but commented out, and the GPU
timing block below it is hardcoded for 720x480 at 60 Hz.

Encoder support is uneven:

```text
conexant.c: 480p, 720p, 1080i cases exist
focus.c:    480p, 720p, 1080i cases exist
xcalibur.c: 480p only
```

So the Xbox can support HDTV modes in principle, but this Cromwell boot path is
only wired for 480p today. For the original Xbox, "1080 mode" means 1080i, not
1080p.

## Practical First Fix

Build a separate Xromwell variant that forces `AV_HDTV` and keeps the existing
480p timings.

Why first:

- it is the smallest code change
- it avoids the uncertain AV-pack detection path used by HDMI adapters
- many HDMI adapters and modern TVs handle 480p better than 1080i
- it uses the already-working Cromwell HDTV timing block
- it does not risk breaking the AV/composite package that already boots

Expected result: the HDMI adapter should receive component-style 480p output
from Cromwell, making the boot screen and Linux handoff visible on more TVs.

## Forced HDTV 480p Checkpoint

Implemented in Cromwell:

```text
e719de4 video: add forced HDTV 480p build option
```

The build flag is:

```text
XBOX_FORCE_AV_HDTV_480P
```

Build the forced-HDTV Cromwell artifacts with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_cromwell_hdd_fatx_autoboot_hdtv480p.ps1
```

Artifacts:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-hddfatx-autoboot-hdtv480p_1024.bin
C:\Users\Paul\Desktop\xbox_linux\artifacts\xromwell-hddfatx-autoboot-hdtv480p.iso
C:\Users\Paul\Desktop\xbox_linux\build\xromwell-hddfatx-autoboot-hdtv480p-disc\default.xbe
```

Package the Debian desktop test app with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package_distro_hdtv480p_softmod.ps1
```

Softmod package:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386-hdtv480p.zip
```

xemu sanity proof used `avpack=hdtv` and booted through to the Debian desktop:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-hdtv480p-xemu-20260526-124002.png
```

Real hardware test expectation: the Xromwell banner should report Cromwell
revision `e719de4` and the cable should display as `HDTV`.

## Hardware Result / Shelved

May 26, 2026 hardware result: the forced-HDTV 480p Debian package went black
through the HDMI adapter. Drive activity suggested the system may have
continued booting, so the failure appears to be in early video output or video
handoff rather than necessarily in Linux boot.

Forcing `AV_HDTV` with the existing 480p path was not enough for this adapter
and TV path. Future work should start with better diagnostics before moving to
720p or 1080i: capture the real encoder type/revision, confirm behavior with a
known component cable if available, and log the selected encoder mode and
timing values in Cromwell.

Shelve this path for now. AV/composite remains the reliable real-hardware test
route.

## Later 720p / 1080i Work

Real 720p or 1080i support needs more than changing the enum. We need:

- mode-specific GPU totals, sync starts, margins, and pixel clock values
- encoder register validation on Conexant, Focus, and Xcalibur Xbox revisions
- Xcalibur 720p/1080i register tables or a proper calculator
- a way to select the mode without breaking early boot

Runtime selection through `linuxboot.cfg` is awkward because video is
initialized before the FATX config is loaded. Compile-time XBE variants are the
clean first step:

```text
default.xbe              existing auto-detected/composite-safe build
default-hdtv480p.xbe     force AV_HDTV, 480p
default-hdtv720p.xbe     later, after GPU timing work
default-hdtv1080i.xbe    later, after GPU timing work
```

## Proposed Order

1. Completed: add a compile-time Cromwell flag that overrides AV-pack
   detection to `AV_HDTV`.
2. Completed: build and package an `hdtv480p` XBE using the same FATX autoboot
   patches.
3. Completed: test the `hdtv480p` XBE on xemu to make sure it still loads
   Linux.
4. Completed: test on real hardware with the HDMI adapter. Result: black
   screen, likely continuing boot activity.
5. Deferred: add better Cromwell video diagnostics before attempting another
   HDMI/component-focused build.
6. Deferred: add 720p/1080i timing work, starting with Conexant/Focus and
   treating Xcalibur separately.

## Risk

Forcing HDTV output can make composite/AV cables go blank. Keep the normal
Xromwell package as the recovery path and ship the forced-HDTV build as a
separate dashboard app, not as a replacement.
