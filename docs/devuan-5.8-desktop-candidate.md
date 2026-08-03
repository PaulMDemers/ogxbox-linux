# Devuan 5.8 Desktop Candidate

Updated: 2026-08-02

## Purpose

Desktop work now starts from an isolated copy of the hardware-validated Devuan
5.8.1 package. The protected package under
`artifacts/devuan-5.8.1-nondisc/` is hash-checked before every candidate build
and is never rebuilt in place.

The candidate builder refuses output outside `artifacts/` and refuses the
protected baseline directory itself.

## Build And Audit

```powershell
.\scripts\new_devuan_5_8_desktop_candidate.ps1
.\scripts\audit_devuan_desktop_payload.ps1
```

The candidate is written to:

```text
artifacts\devuan-5.8.1-desktop-candidate\
```

The audit extracts the exact candidate squashfs and runs `ldd -r` with
`LD_LIBRARY_PATH` unset against representative applications. It also verifies
the launcher contract, helper scripts, package inventory, profile markers, and
squashfs metadata. The report is generated at:

```text
artifacts\reports\devuan-5.8.1-desktop-candidate-audit.txt
```

## Fixed ABI Conflict

The protected desktop launcher exported:

```text
LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib
```

That made Devuan applications load Tiny Core's older local libraries. mtPaint
then failed through HarfBuzz with an undefined `FT_Get_Transform` symbol. The
candidate unsets `LD_LIBRARY_PATH` for distro applications, allowing the
Devuan i386 library set to resolve itself consistently.

The exact-payload audit now reports `LDD_RELOCATION_OK` for aterm, Fluxbox,
JWM, Xfe, Dillo, Links2, Midnight Commander, mtPaint, GPicView, WordGrinder,
sc, and nano. Script/static launchers such as xterm and xpdf are identified
separately. The audit ends with `XBOX_EXACT_PAYLOAD_AUDIT_OK`.

## xemu Runtime Result

The candidate was staged on a fresh raw copy of the base xemu HDD. The FATX
payload, config, kernel, and initrd were all contiguous and their readback
hashes matched the candidate files.

Observed cold-boot timeline:

- About 117 seconds: X and the proof terminal were visible, but Fluxbox chrome
  and the panel were not ready.
- About 208 seconds: the title bar, panel, and desktop were fully drawn.
- Dillo launched through `xbox-launch-app` and mapped a GUI window in under 90
  seconds.
- mtPaint no longer produced the FreeType/HarfBuzz linker error and remained
  alive, but did not map a window after more than three minutes.

This proves the candidate fixes the application ABI path, but it does not solve
the desktop's cold-read performance. A populated terminal is not a sufficient
desktop-ready signal; future timing tests must wait for Fluxbox chrome and the
panel.

## Guardrails

- Do not modify or rebuild `artifacts/devuan-5.8.1-nondisc/`.
- Do not change the pinned launcher, kernel, initrd, or config while profiling
  desktop payload performance.
- Keep candidate output self-contained; do not mix files from separate artifact
  directories.
- Run the exact-payload audit before every xemu or hardware candidate test.
- Treat `XBOX_APP_RUNNING` as an early liveness check, not proof that a GUI has
  mapped.

## Next Work

The first storage profile is complete. Package expansion should still wait
until Dillo and mtPaint reach usable windows within a reasonable and
repeatable bound.

## Storage Profile

The exact ABI-fixed candidate was booted from its existing staged, contiguous
FATX image. The active read-ahead values were:

```text
hda   1024 KiB
loop0 2048 KiB (FATX-backed payload file)
loop1 2048 KiB (SquashFS)
```

After dropping Linux page caches before every sample, 1 MiB reads from five
locations in `/dev/loop1` took:

```text
0 MiB offset:   1168 ms
64 MiB offset:  1383 ms
128 MiB offset: 1385 ms
192 MiB offset: 1317 ms
256 MiB offset: 1360 ms
```

The uniform times make a fragmented tail or slow image region unlikely. The
payload file is contiguous, and the packaged 5.8 FATX driver has the contiguous
cluster fast path from source commit `22fbdf0ede3c`.

Cold sequential reads of representative executables plus their `ldd` library
closures took 68.7 seconds for Dillo, 62.4 seconds for mtPaint, and 18.5
seconds for Xfe. These costs match the observed black or incompletely painted
windows and identify scattered SquashFS cold reads as the next useful target.

Reproduce the guest measurements with:

```powershell
.\scripts\profile_devuan_5_8_storage.ps1
```

## Rejected Fluxbox Preload

`scripts/new_devuan_5_8_performance_candidate.ps1` creates a config-only
candidate that adds `xbox_preload_fluxbox=1`. Its kernel, initramfs, XBE, and
SquashFS payload remain byte-identical to the audited candidate.

The baseline reached a usable shell at 115 seconds and fully painted Fluxbox
at 209 seconds. The preload candidate reached those points at 178 and 252
seconds. Preloading moved the same cold-read work ahead of the shell and made
the fully settled desktop 43 seconds slower, so it must not be promoted.

The next candidate should test SquashFS hot-file ordering or block layout while
keeping the proven loader and FATX path unchanged.

## SquashFS Hot-Order Experiment

The matched A/B builder is:

```powershell
.\scripts\new_devuan_5_8_hot_order_candidates.ps1
```

It extracts the exact ABI-fixed candidate once, then creates a control repack
and a hot-order repack with identical gzip, 128 KiB block, and fixed-time
settings. The 192-entry sort file gives startup binaries and their library
closures the highest priority, followed by Dillo, mtPaint, Xfe, and initial
desktop data. Local `mksquashfs` testing confirmed that higher sort priority
places data earlier in the image.

The control filesystem has the same size as the audited candidate and differs
at only superblock bytes 8-11, the filesystem creation timestamp. Both exact
payload audits passed, including all representative application relocation
checks.

Use the repeated cold-boot harness with:

```powershell
.\scripts\test_devuan_5_8_hot_order.ps1 -Runs 5 -RequiredPasses 2
```

The harness regenerates the raw HDD for every attempt, stages config, kernel,
and initramfs first at fixed contiguous clusters, stages the payload after
them, verifies every full-file FATX readback hash, and captures the complete
xemu window every ten seconds. In the decisive repeated run, both variants
passed twice with identical visual timings:

```text
                       Linux text   first X   proof visible
control run 1              53 s       85 s          96 s
control run 2              53 s       85 s          96 s
hot-order run 1            53 s       85 s          96 s
hot-order run 2            53 s       85 s          96 s
```

`proof visible` means X and the populated proof terminal were rendered. It is
not an interactive-ready signal: Fluxbox chrome and USB-keyboard input can
arrive substantially later. A control-only settled profile measured cold
closures at 10.7 seconds for Dillo, 38.2 seconds for mtPaint, and 21.9 seconds
for Xfe. The corresponding hot-order closure profile was inconclusive because
that xemu run did not accept emulated USB-keyboard input.

Do not promote the hot-order package. It has no reproduced visual boot benefit,
and its application-launch effect remains unproven. Keep the protected 5.8.1
package as the release baseline.
