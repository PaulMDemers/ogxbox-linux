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

Tiny Core FATX desktop test with the 64 MB tuned kernel:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip
```

## Current Hardware Result

Tested on a softmodded Xbox on May 25, 2026:

- BusyBox smoke package boots.
- Tiny Core FATX desktop package boots to the Xfbdev desktop.
- Tiny Core lean package boots to the Xfbdev desktop and is noticeably snappier.
- USB keyboard and mouse connected through controller-port adapters are detected.
- Composite/AV cables work. An HDMI adapter produced no video with the current mode/handoff.
- The Tiny Core terminal icon still flashed and exited in the first hardware test.
- The first Debian package did not reach Linux: Cromwell failed while reading the FATX initrd chain.
- The second Debian package used the renamed files and Xromwell `6cb54cc`, but
  still failed while loading `/debinit` on the 250 GB disk. The cluster spacing
  in the photo matches a 64 KB FATX cluster size, while Cromwell was still
  assuming 16 KB clusters.
- Debian boots to the proof shell on real softmodded Xbox hardware with
  Xromwell `5eaba1e`.
- Debian now boots to the minimal Xfbdev/flwm desktop on real softmodded Xbox
  hardware with Xromwell `16788e0`. The proof terminal opens, and `xterm`
  launches a terminal through the `aterm` compatibility wrapper.

The May 25 refresh adds:

- a FATX contiguous-file read fast path in the 6.18 kernel for the `linuxroot.ext2` loop image
- a stable `xbox-aterm` wrapper for the wbar terminal icon, plus forced wbar/desktop rewrites to use it
- a Cromwell FATX loader fix that stops walking the FAT chain once the requested file size has been read
- a Cromwell FATX loader fix that reads sectors-per-cluster from the FATX header, needed for upgraded disks using 64 KB clusters
- unique Debian root filenames: `debkrnl`, `debinit`, and `debian.ext2`
- `/usr/local/bin/xbox-diag`, with a boot copy saved at `/tmp/xbox-diag.txt`
- read-ahead tuning for `hd*`, `sd*`, and `loop*` block devices
- a lean Tiny Core kernel package built from `xbox_tinycore_defconfig`

## Backup First

Back up any existing files with these names from `E:\`:

```text
E:\linuxboot.cfg
E:\vmlinuz
E:\initramf
E:\linuxroot.ext2
E:\debkrnl
E:\debinit
E:\debian.ext2
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
/tmp/xbox-aterm.log
```

## Tiny Core Lean Kernel

For RAM testing, use:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip
```

Copy the package folder to:

```text
E:\Apps\XromwellTinyCoreLean\
```

Copy the contents of its `E-root\` folder to `E:\`. This uses the same root
filenames as the standard Tiny Core package, so it replaces:

```text
E:\linuxboot.cfg
E:\vmlinuz
E:\initramf
E:\linuxroot.ext2
```

Launch:

```text
E:\Apps\XromwellTinyCoreLean\default.xbe
```

xemu lean proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\tinycore-hdd-lean-kernel-meminfo-tall-20260525-161026.png
```

The proof terminal should show:

```text
Linux xbox 6.18.33-xboxdev-00007-g502b7bb738cf
```

In xemu, the lean kernel desktop proof reported:

```text
MemTotal:      53948 kB
MemAvailable: 16940 kB
```

## Debian Bookworm i386

Use:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386.zip
```

Before copying the Debian `E-root\` contents, delete any previous root boot
files with these names from `E:\`:

```text
E:\linuxboot.cfg
E:\vmlinuz
E:\initramf
E:\linuxroot.ext2
E:\debkrnl
E:\debinit
E:\debian.ext2
```

Copy the package folder to:

```text
E:\Apps\XromwellDebianBookworm\
```

Copy the contents of its `E-root\` folder to `E:\`. The expected root files are:

```text
E:\linuxboot.cfg
E:\debkrnl
E:\debinit
E:\debian.ext2
```

Launch:

```text
E:\Apps\XromwellDebianBookworm\default.xbe
```

Expected result: Xromwell loads `/debkrnl` and `/debinit`, then Debian starts
the minimal Xfbdev/flwm desktop and opens an `aterm` proof terminal. If X exits,
it falls back to the console proof shell.

The May 25 X desktop refresh uses `xbox_x_mouse=0`, so the first hardware
desktop proof does not open `/dev/input/mice` from Xfbdev. It also skips the
previous `udevadm trigger` step that ran immediately after input enumeration.
If this reaches the desktop, mouse support can be re-enabled in a later package.

Hardware follow-up: this package reached the Debian X desktop, but it was still
too slow to use comfortably. The current package is a lean rebuild: it removes
the Debian Xorg/JWM/xterm packages, uses only the Tiny Core Xfbdev/flwm/aterm
closure, shrinks the ext2 payload to 384 MB, and applies the Tiny Core-style
read-ahead tuning to the disk block device. The terminal now prints memory,
read-ahead values, and the diagnostic path `/tmp/xbox-diag.txt`.

The first lean package then failed in Xromwell while loading `/debinit` from
real FATX with an invalid next-cluster value. Cromwell `16788e0` now rejects
invalid, unallocated, and out-of-partition cluster-chain entries instead of
feeding them into `LoadFATXCluster`. The refreshed softmod zip contains that
XBE and should show `rev. 16788e0` on the Xromwell banner.

Real hardware then reached the Debian desktop and opened the proof terminal.
Because the lean build removed Debian's `xterm` package, launching `xterm`
after closing the proof terminal did nothing. The current payload includes
`/usr/local/bin/xterm` as a compatibility wrapper around the Tiny Core `aterm`
binary, plus `/usr/local/bin/xbox-terminal` as the stable terminal launcher.

This is the current working real-hardware checkpoint:

```text
ogxbox-linux: 20ab453 Add Debian xterm terminal wrapper
cromwell:     16788e0 fatx: reject invalid cluster chain entries
package:      C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386.zip
```

The xemu proofs for this path are:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-unique-fatx-boot-20260525-190910.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-header-cluster-fatx-boot-20260525-202235.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-xfbdev-flwm-aterm-devpts-20260525-210306.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-xfbdev-no-udev-nomouse-20260525-213104.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-lean-xfbdev-storage-tune-v2-20260525-220159.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-lean-xfbdev-fatx-chain-guard-clean-20260525-223033.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-xterm-aterm-wrapper-20260525-224511.png
```

## Cleanup

Remove the app folders and the E-root payload files:

```text
E:\Apps\XromwellBusyBoxSmoke\
E:\Apps\XromwellTinyCoreFatx\
E:\Apps\XromwellTinyCoreLean\
E:\linuxboot.cfg
E:\vmlinuz
E:\initramf
E:\linuxroot.ext2
E:\debkrnl
E:\debinit
E:\debian.ext2
```

Restore any backed-up files with the same names.
