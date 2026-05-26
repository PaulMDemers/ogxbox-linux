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

The next usability package adds `ping`, `wget`, and `ca-certificates` to the
base Debian root, plus `/usr/local/bin/xbox-perf` for quick hardware timing
checks. It also updates the Xfbdev boot text: `xbox_x_mouse=0` disables only the
explicit `-mouse /dev/input/mice,5` argument, and the default pointer path may
still work on real hardware.

Working checkpoint:

```text
ogxbox-linux: 20ab453 Add Debian xterm terminal wrapper
cromwell:     16788e0 fatx: reject invalid cluster chain entries
softmod zip:  C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386.zip
xemu ISO:     C:\Users\Paul\Desktop\xbox_linux\artifacts\xromwell-hddfatx-autoboot-initrd32.iso
```

Current usability rebuild:

```text
root tools:   ping, wget, ca-certificates, apt, xbox-perf
root image:   C:\Users\Paul\Desktop\xbox_linux\artifacts\hdd\xbox-debian-bookworm-i386.ext2
softmod zip:  C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386.zip
xemu proof:   C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-base-tools-perf-20260525-231713.png
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

Planned artifact:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386.zip
```
