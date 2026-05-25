# Real Hardware Softmod Test

Use this order on a backed-up softmodded Xbox.

## Packages

BusyBox smoke test:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-busybox-smoke.zip
```

Tiny Core FATX desktop test:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-tinycore-fatx.zip
```

## Current Hardware Result

Tested on a softmodded Xbox on May 25, 2026:

- BusyBox smoke package boots.
- Tiny Core FATX desktop package boots to the Xfbdev desktop.
- USB keyboard and mouse connected through controller-port adapters are detected.
- Composite/AV cables work. An HDMI adapter produced no video with the current mode/handoff.

The May 25 refresh adds:

- a FATX contiguous-file read fast path in the 6.18 kernel for the `linuxroot.ext2` loop image
- a stable `xbox-aterm` wrapper for the wbar terminal icon
- `/usr/local/bin/xbox-diag`, with a boot copy saved at `/tmp/xbox-diag.txt`
- read-ahead tuning for `hd*`, `sd*`, and `loop*` block devices

## Backup First

Back up any existing files with these names from `E:\`:

```text
E:\linuxboot.cfg
E:\vmlinuz
E:\initramf
E:\linuxroot.ext2
```

## BusyBox First

Copy the BusyBox package folder to:

```text
E:\Apps\XromwellBusyBoxSmoke\
```

Copy the contents of its `E-root\` folder to `E:\`.

Launch:

```text
E:\Apps\XromwellBusyBoxSmoke\default.xbe
```

Expected result: Linux reaches a BusyBox shell. This proves the dashboard, XBE, Cromwell FATX loader, kernel handoff, and initramfs path.

xemu proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xbe-package-busybox-smoke-90-20260525-140817.png
```

## Tiny Core Second

Copy the Tiny Core package folder to:

```text
E:\Apps\XromwellTinyCoreFatx\
```

Copy the contents of its `E-root\` folder to `E:\`.

Launch:

```text
E:\Apps\XromwellTinyCoreFatx\default.xbe
```

Expected result: Linux mounts `E:` as FATX, opens `E:\linuxroot.ext2`, and starts the Tiny Core Xfbdev desktop.

xemu proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\tinycore-hdd-hwfix-clean-kernel-restaged-20260525-154918.png
```

The proof terminal should show a kernel like:

```text
Linux xbox 6.18.33-xboxdev-00006-gc29e0032f477
```

If the desktop is slow or a terminal still exits unexpectedly, collect the diagnostic output:

```text
/tmp/xbox-diag.txt
```

## Cleanup

Remove the app folders and the E-root payload files:

```text
E:\Apps\XromwellBusyBoxSmoke\
E:\Apps\XromwellTinyCoreFatx\
E:\linuxboot.cfg
E:\vmlinuz
E:\initramf
E:\linuxroot.ext2
```

Restore any backed-up files with the same names.
