# Debian 6.18 Persistent Shell Candidate

Updated: 2026-08-05

## Purpose

This candidate is the first normal interactive Debian package derived from the
hardware-passed Linux 6.18.33 FATX existing-file write baseline. It boots to a
writable Debian shell, keeps changes inside an ext2 payload file on E:, and
provides a Linux-controlled shutdown command.

It does not add general FATX allocation. FATX can still overwrite blocks only
inside existing files; it cannot create, delete, rename, extend, or allocate
FATX files.

## Protected Source

The builder requires the exact hardware-passed safety ZIP and refuses any
other bytes:

```text
494E1798C2686A9DD774717B5C62D4971189816DD4DEC2DB69B4AF41605DD738
artifacts/debian-6.18.33-rw-candidate/xromwell-hddfatx-debian-bookworm-6.18.33-rw-shell.zip
```

That ZIP is never modified. The persistent package uses separate E: names:

```text
linuxboot.cfg
pskrnl
psinit
psdebian.ext2
```

## Candidate Artifact

```text
artifacts/debian-6.18.33-persistent-shell-candidate/
```

Checksums:

```text
BFA2FB154331D85C29492942A98673F275281F970887548E8803A2D34DC9621D  xromwell-hddfatx-debian-bookworm-6.18.33-persistent-shell.zip
A14066FA0C7E8DF2E7D366C1B4417FBE4103D375CB94903A7E1CE1B3BD92F468  manifest.json
```

The ZIP and extracted dashboard/E-root folder are complete install sets. Do
not mix their files with another package.

## Operation

The shell prints `XBOX_DEBIAN_PERSISTENT_SHELL_READY`. Files written under
`/root` persist after a clean shutdown. Finish each session with:

```sh
xbox-persistent-shutdown
```

The helper syncs, writes a fixed-size status marker, retries a read-only root
remount, prints `XBOX_PERSISTENT_SHUTDOWN_SAFE`, and invokes the Xbox kernel
power-off hook. If the remount fails, it leaves the machine running and warns
the user not to power off.

## Automated Gate

The accepted run is:

```text
run/debian-persistent-safety-gate/20260805-203416/summary.json
```

Both boots used one freshly staged raw Xbox disk. The disk was not restaged
between boots.

| Check | Boot 1 | Boot 2 |
|---|---:|---:|
| First Linux frame | 28 s | 28 s |
| Linux-controlled xemu power-off | pass | pass |
| ext2 mount count | 1 | 2 |
| User marker | present | present |
| Shutdown status | `SAFE____` | `SAFE____` |
| `e2fsck -fn` | clean | clean |

The gate attaches an actual xemu `usb-kbd` device, types a user-file write and
the shutdown command into Debian, waits for Linux to power xemu off, extracts
the payload from FATX, and checks it from the host.

## Known Caveat

One fresh xemu cold boot displayed transient `ext2_iget: bad extended
attribute block` messages while opening the Debian root. The same extracted
payload passed `e2fsck -fn`, and the second boot did not show the messages in
the retained final frame. This may be a cold FATX/loop read-path issue and is
not considered resolved. Real hardware testing should record whether these
messages appear and whether ordinary commands remain reliable.

## Reproduction

```powershell
.\scripts\build_debian_6_18_persistent_candidate.ps1 -Force
.\scripts\test_debian_6_18_persistent_candidate.ps1 -BootCount 2
```

The package remains a candidate until a real Xbox completes at least two
write/shutdown boots without replacing `psdebian.ext2`.
