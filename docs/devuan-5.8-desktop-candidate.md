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

Profile squashfs decompression, loop/FATX readahead, and executable page-fault
behavior with this fixed candidate. Package expansion should wait until Dillo
and mtPaint reach usable windows within a reasonable and repeatable bound.
