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

1. Add a compile-time Cromwell flag that overrides AV-pack detection to
   `AV_HDTV`.
2. Build and package an `hdtv480p` XBE using the same FATX autoboot patches.
3. Test the `hdtv480p` XBE on xemu to make sure it still loads Linux.
4. Test on real hardware with the HDMI adapter.
5. If 480p works, keep it as the broad TV compatibility path.
6. Only then add 720p/1080i timing work, starting with Conexant/Focus and
   treating Xcalibur separately.

## Risk

Forcing HDTV output can make composite/AV cables go blank. Keep the normal
Xromwell package as the recovery path and ship the forced-HDTV build as a
separate dashboard app, not as a replacement.

