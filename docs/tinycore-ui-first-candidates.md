# Tiny Core UI-First Candidates

## Hardware Finding

The isolated Tiny Core RA128 candidate booted quickly on a real Xbox, but then
showed only Xfbdev's grey/black background and X cursor for several minutes.
The Tiny Core wallpaper, wbar, and proof terminal appeared together afterward.

The generated `.xsession` explained that boundary. It started Xfbdev and FLWM,
then ran `$HOME/.setbackground` synchronously before launching wbar or sourcing
the user's `.X.d` proof-terminal hook. Loading the wallpaper pulls hsetroot,
Imlib, image decoders, and image data through the ext2-over-FATX loop stack.
Slow hardware reads therefore blocked every visible desktop component even
though X and the window manager were already running.

## Candidate Change

The new session uses this order:

1. Start Xfbdev and wait for X.
2. Start FLWM.
3. Launch the user `.X.d` proof terminal.
4. Launch wbar.
5. Load the wallpaper asynchronously.
6. Run remaining extension X hooks.

The session records monotonic timestamps in:

```text
/tmp/xbox-desktop-timing.txt
```

Expected markers include `xsession-start`, `x-ready`, `wm-started`,
`user-xd-started`, `icons-started`, `wallpaper-start`,
`wallpaper-finished`, and `system-xd-finished`.

No Xromwell, kernel, payload, XBE, or protected-package file was modified.
Both candidates use the same generated UI-first initramfs. Their only
difference is the FATX and ext2 loop read-ahead setting:

```text
RA128     128 KiB FATX loop, 128 KiB ext2 loop
RA1024   1024 KiB FATX loop, 1024 KiB ext2 loop
```

The physical disk remains at 1024 KiB in both variants.

## Artifacts

Protected source, unchanged:

```text
artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip
SHA256 17327756ED0CB274145CFDD974D119BEF19DB0F7588509726BB8C6BBFD4DE866
```

Matched candidate index:

```text
artifacts\tinycore-hdd-ui-first-candidates\candidate-index.json
```

RA128 ZIP:

```text
artifacts\tinycore-hdd-ui-first-candidates\ra128\xromwell-hddfatx-tinycore-lean-ra128k-candidate.zip
SHA256 F8A65FC3D92572A669F7357B0D8289F9BEE6F08A462B26D9BFB4C3377F18C226
```

RA1024 ZIP:

```text
artifacts\tinycore-hdd-ui-first-candidates\ra1024\xromwell-hddfatx-tinycore-lean-ra1024k-candidate.zip
SHA256 D518E2C41D8CC1EFF0FF366837161F19F72FA5CFFA0A7E254228893C725F9F48
```

Each variant directory is self-contained. Do not mix files between them.

## Emulator Gate

Both variants were staged payload-first onto three fresh raw HDD images. The
test verified contiguous FATX allocation and read-back SHA-256 for every boot
file, booted through the established FATX-autoboot Cromwell ROM, captured only
the complete xemu window through the C# capture helper, and stopped xemu after
each run.

```text
variant   passes   Linux text          complete desktop
RA128     3/3      17, 17, 17 s       39, 45, 39 s
RA1024    3/3      17, 16, 17 s       40, 39, 39 s
```

Run evidence:

```text
run\tinycore-hdd-ui-first-ra128\20260804-000115
run\tinycore-hdd-ui-first-ra1024\20260804-000414
```

xemu loads the wallpaper too quickly to reproduce the several-minute hardware
pause, so this is a compatibility and reliability gate rather than proof of a
hardware speedup.

## Hardware Test Order

Test RA1024 first. It retains the protected package's original loop read-ahead
and therefore isolates the UI-ordering fix from the earlier RA128 tuning. The
expected result is that the terminal, FLWM chrome, and wbar become usable while
the wallpaper is still loading. After boot, capture:

```sh
cat /tmp/xbox-desktop-timing.txt
```

Keep RA128 as the matched follow-up if RA1024 succeeds and a responsiveness
comparison is still useful. Neither candidate replaces the protected release
baseline until real hardware confirms the post-X behavior.

The RA1024 hardware trace later showed that wallpaper loading took only 1.54
seconds while the X server/first-Xlib-client boundary took roughly 137 seconds.
The follow-up RAM-materialized X startup experiment is documented in
`docs/tinycore-x-hotset-candidate.md`.

## Reproduce

```powershell
.\scripts\new_tinycore_hdd_ui_first_candidates.ps1
.\scripts\test_tinycore_hdd_candidate.ps1 `
  -CandidateRoot artifacts\tinycore-hdd-ui-first-candidates\ra128 `
  -OutputRoot run\tinycore-hdd-ui-first-ra128 `
  -Runs 3 -RequiredPasses 3 -PollSeconds 5
.\scripts\test_tinycore_hdd_candidate.ps1 `
  -CandidateRoot artifacts\tinycore-hdd-ui-first-candidates\ra1024 `
  -OutputRoot run\tinycore-hdd-ui-first-ra1024 `
  -Runs 3 -RequiredPasses 3 -PollSeconds 5
```
