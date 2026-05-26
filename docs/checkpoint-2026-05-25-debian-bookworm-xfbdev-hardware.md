# Checkpoint: Debian Bookworm Xfbdev Hardware Desktop

Date: May 25, 2026

This is the first confirmed real-hardware Debian desktop checkpoint for the
Original Xbox softmod FATX boot path.

## Confirmed Result

On a softmodded Xbox:

- Xromwell loads `E:\debkrnl` and `E:\debinit` from FATX.
- The distro initramfs mounts `E:` as FATX, loop-mounts `E:\debian.ext2`, and
  enters the Debian Bookworm i386 root.
- Debian starts the Tiny Core `Xfbdev`/`flwm_topside`/`aterm` desktop stack.
- The proof terminal opens.
- `xterm` launches a terminal through the `aterm` compatibility wrapper.

Known current limits:

- Xfbdev mouse input is disabled with `xbox_x_mouse=0`.
- The root image is mounted read-only from the FATX-backed ext2 file.
- The desktop is a minimal proof environment, not yet a polished daily-use
  Debian system.

## Revisions

```text
ogxbox-linux tag:      debian-bookworm-xfbdev-hw-20260525
ogxbox-linux scripts:  20ab453 Add Debian xterm terminal wrapper
cromwell tag:          debian-bookworm-xfbdev-hw-20260525
cromwell:              16788e0 fatx: reject invalid cluster chain entries
```

## Working Artifacts

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386.zip
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386\default.xbe
C:\Users\Paul\Desktop\xbox_linux\artifacts\hdd\xbox-debian-bookworm-i386.ext2
C:\Users\Paul\Desktop\xbox_linux\artifacts\xromwell-hddfatx-autoboot-initrd32.iso
```

Expected Xbox `E:` root files from the package:

```text
E:\linuxboot.cfg
E:\debkrnl
E:\debinit
E:\debian.ext2
```

Dashboard app folder:

```text
E:\Apps\XromwellDebianBookworm\
```

## Rebuild Commands

```powershell
python .\scripts\make_distro_initramfs.py
powershell -ExecutionPolicy Bypass -File .\scripts\build_debian_bookworm_i386_payload.ps1 -Desktop -ImageSizeMiB 384
powershell -ExecutionPolicy Bypass -File .\scripts\build_cromwell_hdd_fatx_autoboot.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\package_distro_softmod_packages.ps1
```

## xemu Proof

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\debian-xterm-aterm-wrapper-20260525-224511.png
```

## Next Step

Move from desktop proof to usability:

- re-enable/test mouse input safely
- add a writable overlay or writable root strategy
- trim/optimize the Debian userspace further
- decide whether to continue Debian first or bring DSL 2024 up through the same
  proven package flow
