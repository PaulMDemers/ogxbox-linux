# Tiny Core 11 Desktop 6.18.33 Non-Disc Release

## Purpose

This release promotes the hardware-passed Tiny Core post-startup hotset-release
package into one complete, release-friendly directory. It boots from a dashboard
XBE and E:-root files without an optical disc.

The promoted ZIP is a byte-for-byte copy of the real-hardware-tested package.
The earlier X-hotset, remote-diagnostics, and memory-candidate packages remain
untouched rollback points.

## Artifact

```text
artifacts\tinycore-6.18.33-nondisc\
```

Primary package:

```text
tinycore11-desktop-6.18.33-hotset-release-xbe.zip
size:   20,184,231 bytes
SHA256: F75DC44CBA6CDD994E146C6E684AFE0EB149DFF75E48BA5A0CC8CA965A5FDAF1
```

The directory also contains:

- A complete extracted FTP folder with `default.xbe` and all four E:-root files.
- `README.md` with installation, network login, and known-issue notes.
- `SHA256SUMS.txt` for the distributable ZIP.
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

When Tiny Core Apps asks to check for the fastest mirror, select No. The mirror
benchmark can fail and lock the 64 MB system.

## Verification

The release package passed three fresh-disk xemu boots. Every run used a newly
generated FATX layout with contiguous, hash-verified readback of the kernel,
initramfs, configuration, and root payload.

| Run | Linux visible | Desktop proof visible |
|---|---:|---:|
| 1 | 17 s | 45 s |
| 2 | 17 s | 45 s |
| 3 | 17 s | 45 s |

A separate release gate also passed:

- Desktop boot from a fresh disk.
- DHCP and Dropbear host-key reachability.
- Password authentication as `tc`.
- Current-boot host-key verification using an isolated known-hosts file.
- Authorized launch of a second `aterm` on the root-owned X session.
- Live aterm process count increased from one to two.
- Full-window application smoke screenshot captured.

Final application-smoke markers:

```text
XBOX_PASSWORD_SSH_OK
XBOX_ATERM_COUNT_1_2
XBOX_RELEASE_APP_OK
```

Generated evidence is retained locally under:

```text
run\tinycore-6.18.33-release\20260804-231453
run\tinycore-6.18.33-release-clean-harness\20260804-235401
```

The release ZIP itself had already passed real-hardware boot, desktop, mouse,
application, DHCP, SSH, SCP, memory-reclaim, and responsiveness testing. See
`docs/tinycore-memory-candidate.md` for those measurements.

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
  -ApplicationSmoke
```

The builder refuses to overwrite an existing output directory unless `-Force`
is supplied. It requires the exact promoted source ZIP hash and verifies every
extracted payload file against the source candidate manifest.
