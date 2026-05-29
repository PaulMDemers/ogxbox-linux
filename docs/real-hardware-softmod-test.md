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

Devuan Daedalus i386 terminal test:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-terminal.zip
```

Devuan Daedalus i386 desktop test:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386.zip
```

Devuan Daedalus i386 desktop-plus experimental test:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-desktop-plus.zip
SHA256 0064F7B12869F4CFF2365CF74BDAFEB9EB87D3D9C7A29537215F85D19A4C30B1
```

Devuan loader-only stability set:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\devuan-loader-stability-set.zip
SHA256 DE11857A72984324A9813B5197FD26AEB351AB4A1822D7AE84A779A1D27FBA3E
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

Additional hardware results from May 26, 2026:

- Devuan Daedalus i386 boots to the desktop on real softmodded Xbox hardware
  and feels fast. This is now the preferred distro path for the next round of
  usability and persistence work.
- The forced-HDTV 480p Debian package did not produce video through the HDMI
  adapter. The screen went black, while drive activity suggested the system may
  have continued booting. Shelve the HDTV path for now and keep AV/composite as
  the reliable hardware test path.

Additional hardware results from May 28, 2026:

- The rebuilt Devuan release-baseline package boots on the softmodded Xbox and
  works well. Treat this package as the Devuan desktop release candidate:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-release-baseline.zip
SHA256 9C0A2362A6E4317DC6BEEB6651E9FD10AD09E029C7CD33D24BF5C0F61DB94D65
```

- Later repeat tests showed nondeterministic Xromwell FATX loader hangs even
  with the same saved release-baseline bytes. One boot progressed past the
  `/devkrnl` read and then failed on `/devinit`; another stopped earlier at
  `Loading /devkrnl...`. Treat this as a real-hardware loader/read stability
  issue and not as a Devuan userspace regression.
- The loader stability variant `3fa5e65-sector512` booted 4 out of 5 times.
  The one failed boot stopped after `Loading /devkrnl...` before the progress
  numbers appeared.
- The follow-up `ata-readsectors-filesector` variant still hung during the
  first `/devkrnl` lookup, with the last visible line at
  `FATX: find scan seek=devkrnl c=1`.
- The noisy `idephase-readsectors-filesector` variant shows individual ATA
  `READ SECTORS` commands completing through `linuxboot.cfg` lookup/read, but
  it scrolls too much before the `/devkrnl` phase.
- The follow-up variant to test next is
  `xromwell-hddfatx-devuan-loader-idephase-payload.zip`, which keeps the frozen
  Devuan payload and prints FATX/IDE phase markers only while loading
  `devkrnl` and `devinit`.

The May 25 refresh adds:

- a FATX contiguous-file read fast path in the 6.18 kernel for the `linuxroot.ext2` loop image
- a stable `xbox-aterm` wrapper for the wbar terminal icon, plus forced wbar/desktop rewrites to use it
- a Cromwell FATX loader fix that stops walking the FAT chain once the requested file size has been read
- a Cromwell FATX loader fix that reads sectors-per-cluster from the FATX header, needed for upgraded disks using 64 KB clusters
- unique Debian root filenames: `debkrnl`, `debinit`, and `debian.ext2`
- `/usr/local/bin/xbox-diag`, with a boot copy saved at `/tmp/xbox-diag.txt`
- read-ahead tuning for `hd*`, `sd*`, and `loop*` block devices
- a lean Tiny Core kernel package built from `xbox_tinycore_defconfig`

## Near-Term Hardware Verification

Verify these on real hardware when the Xbox is available:

- First release-candidate package set:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-terminal.zip
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-release-baseline.zip
```

- RW shell smoke package on AV/composite: first boot writes both marker files,
  reports `XBOX_ROOT_REMOUNT_RO_OK`, and second boot reports both files present.
- Devuan Daedalus desktop package: run `xbox-network-up --wait`, test `ping`,
  `wget`, and `apt`, then run `xbox-perf` and compare memory and disk timing
  against Debian and Tiny Core.
- Tiny Core lean, Devuan terminal, and Devuan desktop now all start network
  bring-up automatically during boot. Check `/tmp/xbox-network-up.txt`.
- Forced-HDTV 480p Debian package: shelved. It went black on the HDMI adapter,
  although drive activity suggested boot continued. Keep the normal
  AV/composite package as the active test route.
- Devuan desktop-plus experimental package: verify that it reaches
  `XBOX_DEVUAN_DESKTOP_PLUS_OK`, shows Fluxbox window decorations, and displays
  a bottom toolbar/taskbar. This package is xemu-proven only so far and uses
  isolated `pluskrnl`, `plusinit`, and `plusdevuan.ext2` files.
- Devuan loader-only stability set: use this before further desktop-plus work
  if Xromwell hangs while reading the kernel or initrd. Start the next round
  with `xromwell-hddfatx-devuan-loader-idephase-payload.zip`; if it fails,
  photograph the final `FIND`, `FS`, or `IDE#` marker before comparing against
  `xromwell-hddfatx-devuan-loader-3fa5e65-filesector.zip` and
  `xromwell-hddfatx-devuan-loader-3fa5e65-sector512.zip`.

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
E:\devkrnl
E:\devinit
E:\devuan.ext2
E:\pluskrnl
E:\plusinit
E:\plusdevuan.ext2
E:\LINUX\DEVUAN.EXT2
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

Separate experimental rw persistence smoke package:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-rw-smoke.zip
```

Shell-only rw storage smoke package:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-rw-shell-smoke.zip
```

Forced-HDTV 480p Debian desktop package for HDMI/component adapters:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386-hdtv480p.zip
```

Devuan Daedalus i386 desktop test:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386.zip
```

Use the HDTV 480p package only as a separate dashboard app. It went black on
the tested HDMI adapter, although drive activity suggested boot continued. It
may also be blank on composite/AV cables because it forces Cromwell into the
HDTV output path.
Expected dashboard folder:

```text
E:\Apps\XromwellDebianBookwormHdtv480p\
```

The Xromwell banner should show Cromwell `e719de4` and cable `HDTV`.

Current hardware result: black screen through the HDMI adapter. Shelved until
we can revisit Cromwell encoder/timing diagnostics.

Expected Devuan dashboard folder:

```text
E:\Apps\XromwellDevuanDaedalus\
```

Expected Devuan terminal dashboard folder:

```text
E:\Apps\XromwellDevuanDaedalusTerminal\
```

Expected Devuan complete desktop dashboard folder:

```text
E:\Apps\XromwellDevuanDaedalusComplete\
```

Expected Devuan desktop-plus experimental dashboard folder:

```text
E:\Apps\XromwellDevuanDesktopPlus\
```

For Devuan terminal and minimal desktop, copy the package `E-root\` files to
`E:\`:

```text
E:\linuxboot.cfg
E:\devkrnl
E:\devinit
E:\devuan.ext2
```

For Devuan complete desktop, use the split package layout instead:

```text
E:\Apps\XromwellDevuanDaedalusComplete\default.xbe
E:\linuxboot.cfg
E:\devkrnl
E:\devinit
E:\LINUX\DEVUAN.EXT2
```

Copy `Apps\XromwellDevuanDaedalusComplete\` to `E:\Apps\`, then copy the
contents of `E-root\` to `E:\`. This keeps the huge ext2 image out of the
FATX root directory while keeping Xromwell's kernel/initrd loads at root,
which is the hardware-proven path.

For Devuan desktop-plus, copy `Apps\XromwellDevuanDesktopPlus\` to
`E:\Apps\`, then copy this package's `E-root\` files to `E:\`:

```text
E:\linuxboot.cfg
E:\pluskrnl
E:\plusinit
E:\plusdevuan.ext2
```

When switching between Devuan loader stability variants, delete these four
files from `E:\` and recopy the package's `E-root\` files in this order:

```text
E:\devkrnl
E:\devinit
E:\devuan.ext2
E:\linuxboot.cfg
```

Each variant has a separate dashboard folder under `E:\Apps\`, but all variants
share the same four release-baseline root files. That is intentional: the test
changes only Xromwell.

Only `linuxboot.cfg` is shared with the release baseline. The plus kernel,
initrd, and root image intentionally do not overwrite `devkrnl`, `devinit`,
or `devuan.ext2`.

The current Devuan softmod packages use Xromwell `4dcc618`. Its FATX lookup is
case-insensitive, and it uses a 4 KiB lazy chain-map page cache for the known
hardware `FATX: spc=2 csize=1024 table=1253376` case. This avoids both the
slow one-entry-at-a-time path from `5518ffc` and the whole-table read stall
seen with `1045ad9`. It also makes FATX autoboot Linux-only after
`linuxboot.cfg` is found, avoiding the extra ReactOS probe before kernel load.
File loads are coalesced into contiguous runs up to 64 KiB so 1 KiB-cluster
upgraded disks do not require one data read per cluster.
The expected early lines on that disk are:

```text
FATX: cached lazy table 1253376 page=4096 ...
FATX: found /linuxboot.cfg size=...
FATX: parsed linuxboot.cfg
AUTOBOOT: selected Linux
FATX: boot open E
FATX: loading kernel /devkrnl
Loading /devkrnl from FATX ... [65536] [131072] ...
```

If it prints `FATX: table read ...` for that same 1.25 MiB table, the old
eager-table XBE is being tested. If it stops before Linux, photograph the final
`FATX:` line.

The current stage1 also prints:

```text
Root init target:
Switching to distro root
```

The first expected line after the handoff is:

```text
XBOX_ROOT_INIT_STARTED
```

If real hardware pauses after `Switching to distro root`, wait a couple of
minutes. If it never prints `XBOX_ROOT_INIT_STARTED`, the handoff itself is
still suspect. If it does print that marker but pauses later, the next issue is
inside Devuan userspace rather than Cromwell/FATX/stage1.

Expected Devuan proof markers:

```text
XBOX_DEVUAN_DAEDALUS_I386_ROOT_OK
XBOX_DEVUAN_X_DESKTOP_OK
XBOX_DEVUAN_COMPLETE_DESKTOP_OK
```

Current hardware result: boots to the desktop and feels fast/snappy. Use this
as the lead distro package for the next usability pass.

The terminal, desktop, and complete desktop packages are separate install
profiles because Xromwell reads the global `E:\linuxboot.cfg`.

The Devuan desktop release baseline is the restored package built from the
same artifacts as the earlier snappy `4dcc618` desktop build:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386.zip
SHA256 3742B8EAD01EDD5697240B8DD1679A36B6FD83E8A7055901F82A86BE3FC8227A
Dashboard folder: E:\Apps\XromwellDevuanRestored4dcc618\
Root files: E:\linuxboot.cfg, E:\devkrnl, E:\devinit, E:\devuan.ext2
```

For normal testing and release prep, use the rebuilt baseline package instead
of copying directly from `artifacts\audit\`:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-release-baseline.zip
SHA256 9C0A2362A6E4317DC6BEEB6651E9FD10AD09E029C7CD33D24BF5C0F61DB94D65
Dashboard folder: E:\Apps\XromwellDevuanRestored4dcc618\
Root files: E:\linuxboot.cfg, E:\devkrnl, E:\devinit, E:\devuan.ext2
```

Real hardware result: booted and appears to work well. Copy only files from
that package folder for this baseline. The `xkrnl`/`xinit` packages in
`artifacts\audit\` are diagnostic probes and should not be used as release
baselines.

The Devuan rw smoke package now uses isolated filenames:

```text
E:\rwkrnl
E:\rwinit
E:\rwdevuan.ext2
```

That prevents it from overwriting the hardware-passed release kernel and root
image. `linuxboot.cfg` is still the active global profile; restore it from the
release-baseline package after any rw smoke test.

Hardware network note: the restored Devuan desktop appears to bring networking
up automatically during boot. Keep `xbox-network-up --wait` as the manual
verification command, but do not rebuild the baseline just to change network
bring-up.

Test the `4dcc618` Devuan desktop package first. It is the current baseline
because xemu reaches X after the cached-page FATX loader. The complete package
should be tested after the baseline passes; the latest xemu run confirms
Xromwell passes the FATX stage but the complete root falls back to the console
after a userspace `cat` segfault.

For the complete desktop profile, right-click the desktop for the `jwm` app
menu. The intended first-pass checks are that `dillo`, `links2`, `xfe`, `mc`,
`mtpaint`, `gpicview`, `xpdf`, `wordgrinder`, and `sc` launch without taking
the machine into swap-like behavior.

Network test commands:

```sh
xbox-network-up --wait
ip addr show dev eth0
ip route
ping -c 3 8.8.8.8
ping -c 3 deb.debian.org
wget -O- http://deb.debian.org/robots.txt
cat /tmp/xbox-network-up.txt
```

Expected network marker:

```text
XBOX_NETWORK_DHCP_OK
```

If xemu shows `eth0` as `NO-CARRIER`, that is expected for the current emulator
test setup and does not disprove the real hardware driver path.

The Debian shell-only rw package remains the real-hardware rw validation
candidate. The Devuan rw shell-smoke package exists now, but it is not
hardware-safe yet: xemu writes and re-reads the marker files and the extracted
ext2 image passes `e2fsck -fn`, but `xbox-sync-ro` still does not report
`XBOX_ROOT_REMOUNT_RO_OK` on Devuan.

For the Debian rw validation flow, see:

```text
C:\Users\Paul\Desktop\xbox_linux\docs\real-hardware-rw-smoke-checklist.md
```

The rw smoke package is xemu-proven but not yet real-hardware validated. It
writes inside `E:\debian.ext2`, so keep the normal read-only Debian package as
the known-good fallback and back up `E:\debian.ext2` before trying it on
hardware.

In xemu, synced marker and normal-use files survived a host-side hard kill and
the next boot found them again. A read-only fsck of the extracted ext2 image
still reported bitmap differences, so this package is not power-loss safe yet.
Run `xbox-sync-ro` before powering off when possible.

The clean-remount xemu test did pass: `xbox-sync-ro` reported
`XBOX_ROOT_REMOUNT_RO_OK`, then a host-side hard kill followed by extracted
image `e2fsck -fn` completed without bitmap warnings. If you test rw on real
hardware, run `xbox-sync-ro` before resetting or powering off.

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
