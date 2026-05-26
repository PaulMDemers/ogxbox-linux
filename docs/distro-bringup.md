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

Status: boots in xemu through the full FATX/ext2 path and `switch_root`s into
the Debian root image. It also boots on real softmodded Xbox hardware to the
Debian proof shell with Xromwell `5eaba1e`.

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
