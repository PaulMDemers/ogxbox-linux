# Release Sweep: May 26, 2026

This rebuild-and-test pass refreshed the current Original Xbox Linux softmod
package set and booted each xemu-relevant path.

## Build Commands

```powershell
python .\scripts\make_busybox_initramfs.py
python .\scripts\make_distro_initramfs.py
python .\scripts\make_fatx_write_smoke_initramfs.py
powershell -ExecutionPolicy Bypass -File .\scripts\stage_hdd_ext2_tinycore_payload.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build_cromwell_hdd_fatx_autoboot.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build_cromwell_hdd_fatx_autoboot_hdtv480p.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build_debian_bookworm_i386_payload.ps1 -Desktop
powershell -ExecutionPolicy Bypass -File .\scripts\build_devuan_daedalus_i386_payload.ps1 -Desktop
powershell -ExecutionPolicy Bypass -File .\scripts\package_softmod_test_packages.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\package_distro_softmod_packages.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\package_distro_rw_smoke.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\package_distro_rw_shell_smoke.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\package_distro_hdtv480p_softmod.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\package_devuan_daedalus_i386_softmod.ps1
```

The forced-HDTV Cromwell build emitted a WSL clock-skew warning after producing
the ROM, XBE, and ISO. The artifact booted in xemu with `avpack=hdtv`.

## xemu Results

| Target | Result | Proof |
| --- | --- | --- |
| BusyBox smoke | PASS: reaches shell | `C:\Users\Paul\Desktop\xbox_linux\run\screenshots\rc-busybox-smoke-20260526-214232.png` |
| Tiny Core FATX | PASS: reaches Xfbdev desktop | `C:\Users\Paul\Desktop\xbox_linux\run\screenshots\rc-tinycore-fatx-20260526-214452.png` |
| Tiny Core lean | PASS: reaches Xfbdev desktop | `C:\Users\Paul\Desktop\xbox_linux\run\screenshots\rc-tinycore-lean-20260526-214707.png` |
| Debian Bookworm i386 | PASS: reaches Xfbdev desktop | `C:\Users\Paul\Desktop\xbox_linux\run\screenshots\rc-debian-bookworm-20260526-214924.png` |
| Devuan Daedalus i386 | PASS: reaches Xfbdev desktop | `C:\Users\Paul\Desktop\xbox_linux\run\screenshots\rc-devuan-daedalus-20260526-215146.png` |
| Debian rw shell smoke | PASS: writes marker and remounts `/` read-only | `C:\Users\Paul\Desktop\xbox_linux\run\screenshots\rc-debian-rw-shell-written-20260526-220022.png` |
| Debian rw shell smoke second boot | PASS: marker and normal-use file are present | `C:\Users\Paul\Desktop\xbox_linux\run\screenshots\rc-debian-rw-shell-present-20260526-220135.png` |
| Debian forced-HDTV 480p | PASS: reaches Xfbdev desktop under xemu `avpack=hdtv` | `C:\Users\Paul\Desktop\xbox_linux\run\screenshots\rc-debian-hdtv480p-20260526-215529.png` |
| FATX write smoke | PASS: rejects create, overwrites existing file, verifies after remount-ro | `C:\Users\Paul\Desktop\xbox_linux\run\screenshots\rc-fatx-write-smoke-20260526-215640.png` |

## Filesystem Checks

The rebuilt read-only distro payloads passed host-side read-only fsck:

```text
artifacts/hdd/xbox-debian-bookworm-i386.ext2: 9663/98304 files (0.1% non-contiguous), 71090/98304 blocks
artifacts/hdd/xbox-devuan-daedalus-i386.ext2: 9696/98304 files (0.1% non-contiguous), 52064/98304 blocks
```

The rw shell smoke was booted twice without restaging. After the second boot,
`E:\debian.ext2` was extracted from the disposable xemu FATX HDD and checked:

```text
run/fatx-extract/rc-debian-rw-shell-present.ext2: 9666/98304 files (0.1% non-contiguous), 71093/98304 blocks
```

No bitmap-difference warnings were reported after the `xbox-sync-ro` path.

## Real-Hardware Test List

Test these packages on hardware, in this order:

1. `xromwell-hddfatx-busybox-smoke.zip`
2. `xromwell-hddfatx-tinycore-lean.zip`
3. `xromwell-hddfatx-debian-bookworm-i386.zip`
4. `xromwell-hddfatx-devuan-daedalus-i386.zip`
5. `xromwell-hddfatx-debian-bookworm-rw-shell-smoke.zip`
6. `xromwell-hddfatx-debian-bookworm-i386-hdtv480p.zip`

Keep `xromwell-hddfatx-tinycore-fatx.zip` as a comparison package, but the lean
Tiny Core package is the primary Tiny Core hardware target now.

The FATX write smoke is emulator-only for this sweep. The real-hardware storage
test should use the rw shell smoke package because it exercises the actual
`debian.ext2` persistence path and remounts `/` read-only before shutdown.

