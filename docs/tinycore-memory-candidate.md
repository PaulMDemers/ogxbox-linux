# Tiny Core Post-Startup Hotset Release

## Purpose

The earlier hardware-passed Tiny Core remote image uses an X hotset to avoid slow
first-client reads from the Xbox disk. Materializing that hotset into RAM costs
about 6 MB on a 64 MB console. This isolated candidate preserves the exact fast
startup path, then restores the original Tiny Core squashfs links after X,
FLWM, the proof terminal, wallpaper, and wbar have started.

Already-running processes retain their mapped pages. Files that were copied
into the hotset but were not needed remain reclaimable, while later application
launches resolve through the original mounted extensions.

The protected X-hotset and remote-diagnostics ZIPs are not modified. This
post-startup release variant is now hardware-passed and is the current improved
Tiny Core diagnostics baseline.

## Artifact

Use the complete ZIP without mixing files from another package:

```text
artifacts\tinycore-hdd-x-hotset-memory-candidate\xromwell-hddfatx-tinycore-lean-xhotset-release-remote-ra1024k-candidate.zip
```

```text
size:   20,184,231 bytes
SHA256: F75DC44CBA6CDD994E146C6E684AFE0EB149DFF75E48BA5A0CC8CA965A5FDAF1
```

The candidate keeps the validated kernel, XBE, Dropbear configuration,
terminal font, and 1024 KiB read-ahead settings. Its only new kernel argument
is:

```text
xbox_x_hotset_release=1
```

## Emulator Results

Three fresh-disk xemu boots passed through the established Cromwell-ROM path:

| Run | Linux visible | Desktop/proof visible |
|---|---:|---:|
| 1 | 17 s | 45 s |
| 2 | 17 s | 45 s |
| 3 | 16 s | 45 s |

The SSH reachability gate also passed. Read-only `e2fsck` reported 43 files,
6,041 of 32,768 blocks used, and zero non-contiguous files.

The release log reported:

```text
restored=450
failed=0
XBOX_X_HOTSET_RELEASE_OK
```

Memory changed immediately as follows in xemu:

| Metric | Before release | After release | Change |
|---|---:|---:|---:|
| MemAvailable | 6,340 kB | 8,852 kB | +2,512 kB |
| MemFree | 1,788 kB | 3,956 kB | +2,168 kB |
| Shmem | 25,256 kB | 20,960 kB | -4,296 kB |

A later snapshot with the desktop, proof terminal, Dropbear, and an active SSH
session reported 10,248 kB available. A fresh aterm launched successfully
after release and wrote `XBOX_POST_RELEASE_APP_OK`, proving that applications
can still load through the restored squashfs links.

Evidence is under:

```text
run\tinycore-hdd-x-hotset-memory\20260804-211905
run\tinycore-hdd-x-hotset-memory-ssh\20260804-212226
```

## Real-Hardware Result

The exact candidate above passed on an Original Xbox. After boot, every
available desktop application was opened, including Tiny Core Apps, and then
closed again. The desktop, mouse, terminal, text editor, DHCP, password SSH,
and SCP remained usable.

The release restored all 450 hotset paths with no failures:

```text
restored=450
failed=0
XBOX_X_HOTSET_RELEASE_OK
```

Memory changed immediately as follows on hardware:

| Metric | Before release | After release | Change |
|---|---:|---:|---:|
| MemAvailable | 5,696 kB | 8,124 kB | +2,428 kB |
| MemFree | 3,452 kB | 5,540 kB | +2,088 kB |
| Shmem | 25,256 kB | 20,960 kB | -4,296 kB |

After the application exercise and closing the applications, the settled
system reported 10,976 kB available. A diagnostic snapshot moments later
reported 10,880 kB available. The remaining processes were the normal desktop,
Dropbear, and the active SSH collection session; no tested application was
left running.

Startup remained effectively unchanged relative to the earlier validated
remote image:

| Event | Earlier remote image | Hotset release | Difference |
|---|---:|---:|---:|
| X ready | 26.14 s | 26.43 s | +0.29 s |
| Wallpaper and dock complete | 27.19 s | 27.53 s | +0.34 s |

The internal disk remained at UDMA2, FATX remained read-only, and DHCP assigned
`192.168.50.156`. The collected logs and their SHA256 manifest are retained
locally under:

```text
run\tinycore-hardware-memory\20260804-220000
```

## Reproduce

```powershell
.\scripts\new_tinycore_hdd_remote_diag_candidate.ps1 `
  -OutRoot artifacts\tinycore-hdd-x-hotset-memory-candidate `
  -BuildRoot build\tinycore-hdd-x-hotset-memory `
  -ReadAheadKb 1024 -DiskReadAheadKb 1024 -ReleaseXHotset

.\scripts\test_tinycore_hdd_candidate.ps1 `
  -CandidateRoot artifacts\tinycore-hdd-x-hotset-memory-candidate `
  -OutputRoot run\tinycore-hdd-x-hotset-memory `
  -Runs 3 -RequiredPasses 3 -PollSeconds 5

.\scripts\test_tinycore_remote_diag.ps1 `
  -CandidateRoot artifacts\tinycore-hdd-x-hotset-memory-candidate `
  -OutputRoot run\tinycore-hdd-x-hotset-memory-ssh
```

## Hardware Checklist

1. Extract only this ZIP and copy `default.xbe` plus its four `E-root` files.
2. Confirm launch-to-interactive time remains close to the validated 50-second
   hardware result.
3. Confirm the wallpaper, dock, mouse, proof terminal, and SSH remain usable.
4. Wait at least ten seconds after the desktop appears, then open a second
   terminal and the text editor.
5. Retrieve `/tmp/xbox-hotset-release.txt`; require `restored=450`, `failed=0`,
   and `XBOX_X_HOTSET_RELEASE_OK`.
6. Retrieve `/proc/meminfo` or run `free -m` after the desktop settles. Compare
   it with the validated candidate, but do not promote this image on emulator
   memory numbers alone.

## Promotion Decision

Real hardware preserved the fast startup and application behavior while
recovering useful memory, so this candidate is promoted as the improved Tiny
Core diagnostics baseline. The earlier X-hotset and remote-diagnostics ZIPs
remain untouched rollback points. Future Tiny Core release artifacts should be
derived into new output directories and must not overwrite any of these three
packages.
