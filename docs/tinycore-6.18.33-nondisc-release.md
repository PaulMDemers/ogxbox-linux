# Tiny Core 11 Desktop 6.18.33 Non-Disc Release

## Purpose

This release promotes the hardware-passed Tiny Core Apps default-mirror package
into one complete, release-friendly directory. It boots from a dashboard XBE
and E:-root files without an optical disc.

The promoted ZIP is a byte-for-byte copy of the real-hardware-tested package.
The previous hardware-tested hotset release is retained in the same directory
as a named, complete rollback ZIP. No boot artifact was rebuilt for promotion.

## Artifact

```text
artifacts\tinycore-6.18.33-nondisc\
```

Primary package:

```text
tinycore11-desktop-6.18.33-apps-default-mirror-xbe.zip
size:   20,185,092 bytes
SHA256: B914A6B513009CE84422EE881996B09F96F75196F65D3F3FB39B0B272478F6F0
```

Named rollback package:

```text
tinycore11-desktop-6.18.33-pre-apps-rollback-xbe.zip
size:   20,184,231 bytes
SHA256: F75DC44CBA6CDD994E146C6E684AFE0EB149DFF75E48BA5A0CC8CA965A5FDAF1
```

The directory also contains:

- A complete extracted FTP folder with `default.xbe` and all four E:-root files.
- `README.md` with installation, network login, and known-issue notes.
- `SHA256SUMS.txt` for both complete distributable ZIPs.
- `release-manifest.json` with file hashes and hardware validation results.
- `candidate-manifest.json` for the established xemu test harness.

Do not mix files from this package with another kernel, initramfs, payload, XBE,
or configuration.

## Install

1. Extract the ZIP and FTP the resulting folder to a dashboard application
   directory such as `E:\Apps\TinyCoreLinux\`.
2. FTP `linuxboot.cfg`, `vmlinuz`, `initramf`, and `linuxroot.ext2` from the
   package's `E-root` directory to the root of `E:\`.
3. Launch `default.xbe` from the dashboard.

DHCP starts automatically. Dropbear listens on tcp/22 with user `tc`, password
`tcuser`, and root SSH login disabled.

Tiny Core Apps opens with the normal repository already configured. Its
resource-heavy first-run fastest-mirror benchmark is intentionally marked
complete and does not prompt.

## Verification

The Apps candidate passed three fresh-disk xemu boots before hardware testing.
Every run used a newly generated FATX layout with contiguous, hash-verified
readback of the kernel, initramfs, configuration, and root payload.

| Run | Linux visible | Desktop proof visible |
|---|---:|---:|
| 1 | 22 s | 45 s |
| 2 | 17 s | 45 s |
| 3 | 17 s | 45 s |

A separate promotion gate then passed against the self-contained release layout:

- Fresh-disk desktop boot: Linux at 17 seconds, desktop proof at 46 seconds.
- DHCP and Dropbear host-key reachability.
- Password authentication as `tc`.
- `/tmp/tce/optional` and `/tmp/tce/firstrun` were present.
- Apps launched without the first-run dialog or `mirrorpicker`.
- `/opt/tcemirror` remained `http://repo.tinycorelinux.net/`.
- A full-window Apps smoke screenshot was captured.

Final application-smoke markers:

```text
XBOX_APPS_FIRSTRUN_MARKER_OK
XBOX_APPS_OPTIONAL_DIR_OK
XBOX_APPS_DEFAULT_MIRROR_OK
XBOX_APPS_LAUNCH_OK
XBOX_APPS_NO_MIRRORPICKER_OK
XBOX_APPS_MIRROR_UNCHANGED_OK
```

Generated evidence is retained locally under:

```text
run\tinycore-6.18.33-promoted-gate\20260805-112053
run\tinycore-6.18.33-promoted-apps-gate\20260805-112211
```

The exact active ZIP had already passed real-hardware boot, desktop, mouse,
Apps, DHCP, SSH, SCP, hotset restore, and responsiveness testing. Apps skipped
the mirror prompt, X was ready at 26.48 seconds, desktop startup completed at
27.63 seconds, and 6,260 kB remained available after interactive testing. See
`docs/tinycore-apps-default-mirror-candidate.md` for the full evidence.

## Reproduce

Build a new release directory without modifying the tested source package:

```powershell
.\scripts\build_tinycore_6_18_nondisc_release.ps1 `
  -OutRoot artifacts\tinycore-6.18.33-nondisc-new
```

Run the cold-boot and remote application gates:

```powershell
.\scripts\test_tinycore_hdd_candidate.ps1 `
  -CandidateRoot artifacts\tinycore-6.18.33-nondisc-new `
  -OutputRoot run\tinycore-6.18.33-release-new `
  -Runs 3 -RequiredPasses 3 -PollSeconds 5

.\scripts\test_tinycore_remote_diag.ps1 `
  -CandidateRoot artifacts\tinycore-6.18.33-nondisc-new `
  -OutputRoot run\tinycore-6.18.33-release-new-ssh `
  -AppsDefaultMirrorSmoke
```

The builder refuses to overwrite an existing output directory unless `-Force`
is supplied. It requires the exact promoted source ZIP hash and verifies every
extracted payload file against the source candidate manifest.
