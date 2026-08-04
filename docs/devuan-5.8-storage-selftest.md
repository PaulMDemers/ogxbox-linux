# Devuan 5.8 Storage Self-Test

Date: August 3, 2026

## Goal

Measure the cold-read behavior behind the minutes-long desktop stalls without
depending on emulated keyboard input or changing the protected hardware-passed
Devuan packages.

## Method

`scripts/build_devuan_5_8_squashfs_block_candidates.sh` adds a benchmark-only
`xbox-storage-selftest` to an extracted copy of the audited desktop candidate.
It runs before helpers and X when `xbox_storage_selftest=1` is present. It:

- drops caches before each operation;
- reads 1 MiB at offsets 0, 64, 128, 192, and 256 MiB from the root loop;
- reads executable and shared-library closures for Xfbdev, xterm, Fluxbox,
  Dillo, mtPaint, and Xfe;
- prints a compact millisecond summary and holds for screenshot collection.

Every xemu attempt starts from a newly converted HDD. The runner stages config,
kernel, initramfs, and payload contiguously in boot-first order, verifies each
full FATX readback hash, never injects input, and captures the complete xemu
window with the C# window-handle tool.

## SquashFS Results

All gzip block-size candidates used 2048 KiB loop read-ahead.

```text
format/block       image size       elapsed runs       median
gzip 64 KiB        274.4 MiB        149, 150, 149 s     149 s
gzip 128 KiB       271.7 MiB        160, 139, 150 s     150 s
gzip 256 KiB       270.5 MiB        203 s               203 s
gzip 1 MiB         269.7 MiB        311 s               311 s
zstd 128 KiB       245.5 MiB        160 s               160 s
```

The 64 KiB result is neutral within the ten-second polling resolution. Larger
blocks clearly regress scattered cold reads. Zstd saves 26.2 MiB but does not
establish a speed improvement. Keep gzip with the existing 128 KiB block size.

## Read-Ahead Results

These variants used the same byte-identical gzip/128 KiB self-test payload.
Only `xbox_fatx_loop_readahead_kb` and `xbox_loop_readahead_kb` changed.

```text
read-ahead       elapsed runs       median
128 KiB          129, 117, 107 s     117 s
512 KiB          118, 128, 128 s     128 s
1024 KiB         128 s               128 s
2048 KiB         160, 139, 150 s     150 s
```

The 128 KiB setting is the only clear repeated improvement. Its median closure
sum was about 43.3 seconds, compared with about 50.0 seconds at 512 KiB.

## Normal Desktop Gate

`scripts/new_devuan_5_8_readahead_desktop_candidate.ps1` derives a complete
RA128 package from the ordinary audited desktop candidate. Its XBE, kernel,
initramfs, and SquashFS hashes are unchanged, and it contains no benchmark
hook or flag. Only the two read-ahead arguments change.

`scripts/test_devuan_5_8_desktop_candidate.ps1` passed three of three fresh
cold boots. Linux text appeared at 53 seconds, first X at 75-85 seconds, and
the populated proof terminal at 107 seconds in all runs. The final full-window
captures show Fluxbox chrome and panel as well as the populated terminal.

The untouched audited RA2048 desktop then passed the same three-boot harness
with the same payload and FATX cluster placement:

```text
read-ahead   Linux text   first X   proof visible
128 KiB          53 s     75-85 s    107,107,107 s
2048 KiB         53 s        85 s    107, 96, 96 s
```

RA128 therefore does not improve the early visual milestone. Its benefit is
in the repeated scattered cold-read workload, which is closer to the reported
post-desktop responsiveness problem but still needs real-hardware validation.

This establishes deterministic xemu bootability and visual desktop startup.
It does not prove real-hardware interactivity, optical behavior, or persistence.
Those remain separate hardware gates.

## Decision

- Carry 128 KiB loop read-ahead into isolated Devuan and Tiny Core candidates
  for real-hardware responsiveness testing; do not promote it as the default.
- Retain gzip/128 KiB SquashFS.
- Do not promote the 64 KiB, larger-block, zstd, hot-order, or preload variants.
- Keep the protected hardware-passed Devuan ZIPs unchanged until hardware
  validation of the config-only RA128 candidate.
