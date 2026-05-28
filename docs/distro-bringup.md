# Distro Bringup

This tracks non-Tiny-Core distro experiments using the current softmod-safe
boot model:

```text
E:\linuxboot.cfg
E:\debkrnl
E:\debinit
E:\debian.ext2
```

Xromwell loads the kernel and initramfs from FATX. The generic Debian distro
package intentionally uses unique root filenames to avoid colliding with the
Tiny Core packages on real FATX disks. The generic distro initramfs mounts `E:`
as FATX, opens `E:\debian.ext2`, loop-mounts that ext2
image, and `switch_root`s into the distro.

## Repository Setup

For now, distro recipes live in this orchestrator repo:

```text
PaulMDemers/ogxbox-linux
```

Recommended GitHub repo to create next if this expands:

```text
PaulMDemers/xbox-linux-distros
```

That repo would hold distro-specific recipes, patches, and package manifests.
Generated root filesystems, ISO downloads, and ext2 images should stay out of
Git.

## Current Targets

### Debian Bookworm i386

Debian 13 `trixie` is current, but i386 is no longer a regular installable
architecture for Debian 13. Debian 12 `bookworm` remains the practical target
for a real 32-bit Xbox-class machine.

Current goal: minimal Debian 12 i386 desktop proof.

Status: boots in xemu and on real softmodded Xbox hardware through the full
FATX/ext2 path into a minimal Xfbdev/flwm desktop. The proof terminal opens,
and `xterm` commands now work through the `aterm` compatibility wrapper.

Real hardware status: the first softmod test did not reach Linux. Cromwell
loaded `/vmlinuz`, then failed while reading `/initramf` from FATX with an
invalid next-cluster value. The May 25 refresh addresses that by rebuilding
Xromwell with a stricter FATX EOF/file-size stop and by packaging Debian as
`debkrnl`, `debinit`, and `debian.ext2`.

The next real-hardware Debian test with Xromwell `6cb54cc` still failed before
Linux, but the new photo exposed the missing piece: on the 250 GB disk, the
kernel and initrd cluster spacing matches a 64 KB FATX cluster size. Cromwell
had been hardcoded to 16 KB clusters, which works in the xemu test image but
walks the wrong real FATX chain on larger/reformatted disks. Xromwell
`5eaba1e` reads sectors-per-cluster from the FATX header and uses a 64 KB load
buffer.

After the hardware proof shell milestone, the Debian image grew a minimal X
desktop path. Debian Bookworm's Xorg fbdev server did not bind to the Xbox
framebuffer in xemu, so the current desktop proof vendors the same Tiny Core
`Xfbdev` extension stack that already works on this kernel, then starts
`flwm_topside` with an `aterm` proof terminal. The desktop path is enabled by
`xbox_desktop=1`; if X exits, `/xbox-init` falls back to the console shell.

The first real-hardware X test reached the `xbox-startx` input-device listing,
then hung with a slow cursor blink and later crashed/oopsed. The follow-up
package removes the `udevadm trigger` step and ships with Xfbdev mouse input
disabled via `xbox_x_mouse=0`, to avoid probing the real Xbox input stack during
the first desktop proof. Once the desktop is stable on hardware, re-enable mouse
input with `xbox_x_mouse=1`.

The next hardware test did reach the Debian desktop, but it was too laggy to be
usable. The current lean package removes the Debian Xorg/JWM/xterm package set,
keeps only the Tiny Core `Xfbdev`/`flwm_topside`/`aterm` closure, and adds the
same disk read-ahead diagnostics/tuning used by the Tiny Core lean path. The
rebuilt Debian root is about 170 MB in a 384 MB ext2 image, and the softmod zip
is about 71 MB. For Debian, read-ahead tuning is applied to the disk block
device only; loop-device read-ahead is left at the kernel default after an xemu
test showed corrupt-looking early userspace segfaults when loop readahead was
tuned before diagnostics.

The first lean real-hardware package failed before Linux while loading
`/debinit`: Xromwell saw an invalid FATX next-cluster value and then tried to
read that bogus cluster. Cromwell `16788e0` hardens the FATX loader so invalid
or out-of-partition cluster-chain entries are rejected instead of being used as
disk addresses. If this still fails on hardware, the next data point should be
the cleaner chain-break message and the cluster where the real FATX chain stops.

After that fix, real hardware reached the Debian desktop and opened the proof
terminal. The lean root now includes `/usr/local/bin/xterm` as an `aterm`
compatibility wrapper so menu items or shell commands that still launch `xterm`
can open a terminal even though Debian's full `xterm` package is not installed.

The next usability package adds `ping`, `wget`, `ca-certificates`,
`isc-dhcp-client`, `ifupdown`, and `iproute2` to the base Debian root, plus
`/usr/local/bin/xbox-perf` for quick hardware timing checks and
`/usr/local/bin/xbox-network-up` for explicit DHCP bring-up. It also updates the
Xfbdev boot text: `xbox_x_mouse=0` disables only the explicit
`-mouse /dev/input/mice,5` argument, and the default pointer path may still work
on real hardware.

May 26 hardware comparison: Debian can reach the desktop, but Devuan Daedalus
feels much faster on the same real Xbox. Keep Debian as the known Debian-family
baseline and use Devuan as the primary usability target unless a later test
shows a regression.

Working checkpoint:

```text
ogxbox-linux: 20ab453 Add Debian xterm terminal wrapper
cromwell:     16788e0 fatx: reject invalid cluster chain entries
softmod zip:  C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386.zip
xemu ISO:     C:\Users\Paul\Desktop\xbox_linux\artifacts\xromwell-hddfatx-autoboot-initrd32.iso
```

Current usability rebuild:

```text
root tools:   ping, wget, ca-certificates, apt, xbox-perf, xbox-network-up
root image:   C:\Users\Paul\Desktop\xbox_linux\artifacts\hdd\xbox-debian-bookworm-i386.ext2
softmod zip:  C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386.zip
xemu proof:   C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-base-tools-perf-20260525-231713.png
```

The DHCP helper rebuild adds `/usr/local/bin/xbox-network-up`; boot starts it
in the background so the desktop does not wait on DHCP. Manual hardware test:

```sh
xbox-network-up --wait
ping -c 3 8.8.8.8
ping -c 3 deb.debian.org
```

Build:

```powershell
python .\scripts\make_distro_initramfs.py
powershell -ExecutionPolicy Bypass -File .\scripts\build_debian_bookworm_i386_payload.ps1 -Desktop
powershell -ExecutionPolicy Bypass -File .\scripts\package_distro_softmod_packages.ps1
```

Artifacts:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio
C:\Users\Paul\Desktop\xbox_linux\artifacts\hdd\xbox-debian-bookworm-i386.ext2
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386.zip
```

xemu proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-bookworm-i386-switchroot-v2-20260525-165609.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-unique-fatx-boot-20260525-190910.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-header-cluster-fatx-boot-20260525-202235.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-xfbdev-flwm-aterm-devpts-20260525-210306.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-xfbdev-no-udev-nomouse-20260525-213104.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-lean-xfbdev-storage-tune-v2-20260525-220159.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-lean-xfbdev-fatx-chain-guard-clean-20260525-223033.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-xterm-aterm-wrapper-20260525-224511.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-base-tools-perf-20260525-231713.png
```

Expected proof banner:

```text
XBOX_DEBIAN_BOOKWORM_I386_ROOT_OK
XBOX_DEBIAN_X_DESKTOP_OK
```

The root image is currently read-only because it is loop-mounted from the
read-only FATX driver. That is enough for a first console proof. A writable
Debian system will need either FATX write support, a separate native Linux
partition/file placement scheme, or a tmpfs/overlay plan.

The first xemu-only FATX existing-file write path is now working. With the
experimental rw-existing FATX kernel, `xbox_fatx_mode=rw xbox_root_mode=rw`,
and `xbox_persist_smoke=1`, Debian writes `/root/xbox-persist-smoke.txt` inside
the ext2 root and sees it again on the next boot without restaging the FATX
payload. The default real-hardware Debian package remains read-only.

A separate opt-in rw smoke package is available for controlled testing:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-rw-smoke.zip
```

It includes `RW-SMOKE-WARNING.txt` and should not replace the normal Debian
package yet.

The rw package also passed a xemu sync-plus-hard-kill reboot test for both the
marker file and a small normal-use file, but read-only `e2fsck` on an extracted
copy of `E:\debian.ext2` still reported ext2 bitmap differences. Use
`xbox-sync-ro` before power-off when possible and do not treat the rw package as
power-loss safe yet.

The clean-remount variant with `xbox_sync_ro_smoke=1` reported
`XBOX_ROOT_REMOUNT_RO_OK`; after a host-side hard kill, extracting
`E:\debian.ext2` and running `e2fsck -fn` completed without bitmap warnings.
That makes `xbox-sync-ro` the current required shutdown path for rw testing.

A shell-only rw smoke package is now available for the first real-hardware rw
test:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-rw-shell-smoke.zip
```

It writes the persistence marker and normal-use file, remounts `/` read-only,
and lands at the proof shell without starting X. The xemu package proof is:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-rw-shell-smoke-20260526-121332.png
```

The extracted image passed `e2fsck -fn` after the `xbox-sync-ro` path. Use
`docs\real-hardware-rw-smoke-checklist.md` before copying it to hardware.

See `docs\persistence-and-performance-plan.md` and
`docs\fatx-existing-file-write.md` for the staged persistence plan and proof.

### Damn Small Linux 2024 i386

DSL 2024 is based on antiX 23 i386 and is a good second target after the
generic distro initramfs is proven with Debian. The likely path is to download
the DSL 2024 ISO, extract its live root filesystem, and repack it as
`linuxroot.ext2` with an Xbox-specific `/xbox-init`.

Current upstream download:

```text
https://www.damnsmalllinux.org/download/dsl-2024.rc7.iso
```

MD5 published by upstream:

```text
cd8afa1de6e60af50605a1a4af21da64  dsl-2024.rc7.iso
```

Planned artifact:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-dsl2024-i386.zip
```

### Devuan

Devuan is worth a port attempt, especially because it keeps the Debian package
model while avoiding systemd in early userspace. That is a good fit for the
Xbox because PID 1, udev, journald, logind, and tmpfs pressure all matter on a
64 MB machine.

Current upstream status as of May 26, 2026:

- Devuan 6 Excalibur is based on Debian 13 Trixie.
- Excalibur has i386 packages in the repository, but its release notes say the
  i386 packages do not include a `linux-image` and there is no i386 installer
  ISO.
- Devuan 5 Daedalus remains the cleaner i386 baseline because it shipped i386
  installer media and maps to Debian 12 Bookworm, which is already our working
  Debian base.

Recommended path: build a Devuan Daedalus i386 root first, using our existing
generic distro initramfs, Xfbdev/flwm/aterm desktop closure, and Xbox kernel.
Treat Excalibur as a later package-repository experiment rather than the first
Devuan target.

Current result: Devuan Daedalus i386 boots in xemu through the same
FATX/ext2 path to the minimal Xfbdev/flwm/aterm desktop. The first build uses
the Debian Bookworm image composer as a base, but bootstraps `daedalus` from
Devuan's merged repository and rewrites the root identity and apt sources.

Real hardware result from May 26, 2026: Devuan Daedalus i386 boots to the
desktop on the softmodded Xbox and feels very fast. This is the current
front-runner for the minimal Debian-family desktop.

Build:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_payload.ps1 -Desktop
powershell -ExecutionPolicy Bypass -File .\scripts\package_devuan_daedalus_i386_softmod.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_complete_payload.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\package_devuan_daedalus_i386_complete_softmod.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_complete_iso.ps1
```

Artifacts:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\hdd\xbox-devuan-daedalus-i386.ext2
C:\Users\Paul\Desktop\xbox_linux\artifacts\hdd\xbox-devuan-daedalus-i386-complete.ext2
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-devuan-daedalus-i386-terminal.iso
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-devuan-daedalus-i386-desktop.iso
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-devuan-daedalus-i386-complete.iso
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-terminal.zip
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386.zip
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-complete.zip
```

The terminal and minimal desktop packages use the same `devkrnl`, `devinit`,
and `devuan.ext2` root files but different `linuxboot.cfg` append lines.
Because Xromwell reads global `E:\linuxboot.cfg`, install one package's
`E-root\` profile at a time.

The complete desktop softmod package keeps the launcher in the dashboard app
folder, but keeps Xromwell's kernel and initrd loads at `E:\` root:

```text
E:\Apps\XromwellDevuanDaedalusComplete\default.xbe
E:\linuxboot.cfg
E:\devkrnl
E:\devinit
E:\LINUX\DEVUAN.EXT2
```

The root `linuxboot.cfg` points Xromwell at root-level `devkrnl`/`devinit` and
tells stage1 to loop-mount `/LINUX/DEVUAN.EXT2`. This avoids placing the
805 MB complete image in the FATX root directory and avoids nested
kernel/initrd lookup in Xromwell.

The Devuan ISOs use `xbox_payload_source=iso`, so stage1 mounts the ISO itself
and loop-mounts `devuan.ext2` from the disc image instead of from FATX.

The complete desktop profile adds a lightweight application set while staying
inside the same Xbox-specific boot path:

```text
dillo links2 xfe mc mtpaint gpicview xpdf wordgrinder sc
curl rsync openssh-client ftp netcat-openbsd jwm
```

It still uses the Tiny Core `Xfbdev` server, but swaps the session manager to
`jwm` and writes an app menu for browser, file manager, terminal, editor,
paint, image viewer, PDF, spreadsheet, and word processor smoke testing.

xemu proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-daedalus-i386-xfbdev-20260526-145241.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-dhcp-helper-20260526-225056.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\release-devuan-terminal-iso-network-20260526-231349.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\release-devuan-desktop-iso-network-20260526-231622.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\release-devuan-complete-network-printwindow-20260526-234850.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-nested-fatx-20260527-011856.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-root-kernel-nested-payload-20260527-013706.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-fatx-ci-xromwell-20260527-015756.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-fatx-lazy-chain-xromwell-20260527-021847.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-root-init-progress-final-20260527-124834.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xromwell-1045ad9-eager-table-12s-20260527-130735.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-xromwell-1045ad9-final-20260527-130924.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-minimal-rebuilt-xromwell-1045ad9-20260527-131602.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xromwell-62835f4-cached-table-12s-20260527-134628.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-minimal-xromwell-62835f4-20260527-134816.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xromwell-complete-62835f4-cached-table-12s-20260527-134907.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-xromwell-62835f4-20260527-135137.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xromwell-linux-only-autoboot-dirty-15s-20260527-141740.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-minimal-linux-only-autoboot-dirty-20260527-141926.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xromwell-3fa5e65-linux-only-autoboot-15s-20260527-142310.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xromwell-4dcc618-coalesced-fatxload-12s-20260527-144050.png
```

The second proof confirms the Devuan desktop still boots after adding
`xbox-network-up`. In xemu, `eth0` shows `NO-CARRIER`, so real hardware is the
meaningful DHCP test.

The May 27 Xromwell refresh now uses `4dcc618`, which keeps the
case-insensitive FATX path lookup and caches lazy FATX chain-map reads in
4 KiB pages. This targets the real-hardware slowdown after
`FATX: spc=2 csize=1024 table=1253376` without repeating the failed
`1045ad9` whole-table read. The expected next progress line is
`FATX: cached lazy table 1253376 page=4096 ...`. After
`linuxboot.cfg` is found, this Xromwell build now returns the Linux config
immediately instead of probing ReactOS first; the expected follow-up markers
are `FATX: parsed linuxboot.cfg`, `AUTOBOOT: selected Linux`,
`FATX: boot open E`, and `FATX: loading kernel /devkrnl`. File loads are now
coalesced into contiguous runs up to 64 KiB and print 64 KiB progress markers
so stalls during `/devkrnl` or `/devinit` are visible quickly.

The rebuilt minimal Devuan desktop is the performance baseline again. It uses
the same Xromwell `4dcc618`, the same stage1 initramfs, and the same 6.18.33
FATX kernel, but the smaller 384 MiB root image and flwm desktop. The complete
desktop remains a heavier experiment until real hardware confirms it boots and
responds acceptably.

The `62835f4` complete xemu run gets past Xromwell and into Devuan userspace,
but currently falls back to the proof shell after a `cat` segfault instead of
reaching X. Treat that as a complete-image userspace/root-init regression, not
as a FATX loader failure.

The follow-up root-init refresh keeps normal `switch_root`, prints the root
init target before the handoff, prints `XBOX_ROOT_INIT_STARTED` immediately
inside `/xbox-init`, and backgrounds `xbox-diag`. The matching no-pause xemu
proof reaches the complete desktop.

Expected proof banner:

```text
XBOX_DEVUAN_DAEDALUS_I386_ROOT_OK
XBOX_DEVUAN_X_DESKTOP_OK
XBOX_DEVUAN_COMPLETE_DESKTOP_OK
```

Next Devuan tasks:

- Use the restored `4dcc618` Devuan desktop package as the hardware-passed
  release baseline. It uses the same XBE, kernel, initramfs, root image,
  filenames, and append line as the earlier snappy Devuan desktop build:

  ```text
  C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386.zip
  SHA256 3742B8EAD01EDD5697240B8DD1679A36B6FD83E8A7055901F82A86BE3FC8227A
  Dashboard folder: E:\Apps\XromwellDevuanRestored4dcc618\
  ```

  Real hardware result: booted and appears to work well. Keep this package as
  the baseline for network, persistence, and desktop usability work. Do not mix
  `devkrnl`/`devinit`/`devuan.ext2` files from the `xkrnl` probe packages.

- For release-prep copying, prefer the rebuilt release-baseline package:

  ```text
  C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-release-baseline.zip
  SHA256 9C0A2362A6E4317DC6BEEB6651E9FD10AD09E029C7CD33D24BF5C0F61DB94D65
  ```

  It reconstructs the hardware-passed line and is the reset path after rw or
  diagnostic package tests.
- Do not let rw experiments overwrite the release files. The Devuan rw smoke
  package now uses `rwkrnl`, `rwinit`, and `rwdevuan.ext2`; only
  `linuxboot.cfg` is intentionally shared because Xromwell reads it from E:\.
- Run `xbox-perf` on real hardware and compare against Debian and Tiny Core.
- Confirm DHCP with `xbox-network-up --wait`, then test `ping`, `wget`, `apt`,
  and CA certificates in the live desktop.
- Continue Devuan persistence work from the new rw shell-smoke package, but do
  not run it on real hardware yet. xemu writes the persistence marker and
  normal-use file, the second boot finds both, and the extracted ext2 image
  passes `e2fsck -fn` after a hard stop. The remaining blocker is that
  `xbox-sync-ro` still does not reach `XBOX_ROOT_REMOUNT_RO_OK` on Devuan.
- Consider moving the next memory and disk optimization pass to Devuan first,
  then backport only the useful parts to Debian.

The generated ext2 image passed `e2fsck -fn`:

```text
artifacts/hdd/xbox-devuan-daedalus-i386.ext2: 9701/98304 files (0.1% non-contiguous), 71164/98304 blocks
artifacts/hdd/xbox-devuan-daedalus-i386-complete.ext2: 24054/49152 files (0.1% non-contiguous), 166290/196608 blocks
```
