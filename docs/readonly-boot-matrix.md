# Read-only Boot Matrix

This is the reconciled non-disc desktop baseline as of August 5, 2026. The
generated packages live under `artifacts\readonly-boot-matrix` and are excluded
from Git. Each package directory and ZIP is self-contained; do not combine an
XBE, kernel, initramfs, config, or root image from different cells.

## Supported Cells

| Distro | Kernel | Root image | Xromwell | Current proof |
| --- | --- | --- | --- | --- |
| Debian Bookworm i386 | 5.8.1 | ext2 | 3fa5e65-sector512 | xemu X desktop |
| Debian Bookworm i386 | 6.18.33 | ext2 | 4dcc618 | xemu X desktop |
| Devuan Daedalus i386 | 5.8.1 | SquashFS | 3fa5e65-sector512 | hardware baseline and xemu X desktop |
| Devuan Daedalus i386 | 6.18.33 | ext2 | 4dcc618 | hardware baseline and xemu X desktop |
| Tiny Core 11.x | 6.18.33 | ext2 | 4dcc618 | hardware baseline and xemu desktop |

The split is required. The sector512 Xromwell lineage boots the 5.8 stage one
but produces `unknown-block(3,1)` root-mount panics with the 6.18 stage one.
The 4dcc618 lineage and its original 6.18 stage one boot all three 6.18 cells.

Devuan 6.18 must use the ext2 root from the protected snappy baseline. A matrix
attempt that paired 6.18 with the later Devuan SquashFS root reached Linux but
failed with repeatable `SQUASHFS error: Unable to read data cache entry` I/O
errors. Devuan 5.8 retains the protected SquashFS package that passes hardware.

## Rebuild

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_readonly_boot_matrix.ps1 -Force
```

The builder validates every source SHA-256 before writing output. It also emits
`manifest.json`, `SHA256SUMS.txt`, and the 4dcc618 xemu loader ISO.

## Test

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test_readonly_boot_matrix.ps1 -Cell all -Runs 1 -RequiredPasses 1
```

Every run starts from a fresh Xbox HDD image, stages payload-first contiguous
FATX files, verifies their readback hashes, captures the complete xemu window,
and selects the matching loader lineage. Raw test disks are removed after each
run; pass `-KeepDisk` only when a failed disk must be retained for inspection.

Clean matrix result from `run\readonly-boot-matrix\20260805-124415`:

| Cell | Linux | X/desktop | Result |
| --- | ---: | ---: | --- |
| Debian 5.8.1 | 53 s | 75 s | passed |
| Debian 6.18.33 | 31 s | 31 s | passed |
| Devuan 5.8.1 | 53 s | 85 s | passed |
| Devuan 6.18.33 | 31 s | 31 s | passed |
| Tiny Core 6.18.33 | 31 s | 64 s | passed |

For Debian and Devuan, matrix success means the X desktop is visible. The
automatic proof terminal is recorded separately as `desktopPopulated` because
the protected Devuan 6.18 package does not launch it deterministically in xemu.
Tiny Core uses its desktop-specific visual proof.

## Next Boundary

These packages intentionally mount FATX read-only. The next milestone is FATX
existing-file write validation and clean shutdown persistence; do not enable
that work by modifying these baseline packages in place.
