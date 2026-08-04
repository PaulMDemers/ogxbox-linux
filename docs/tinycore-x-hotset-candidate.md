# Tiny Core X-Hotset Candidate

## Hardware Baseline

The Tiny Core UI-first RA1024 candidate reached `.xsession` at 19.25 seconds
on a real Xbox, but its first successful X client did not complete until 156.65
seconds:

```text
19.25 xsession-start
156.65 x-ready
156.65 wm-started
156.88 user-xd-started
156.88 icons-started
156.89 wallpaper-start
158.43 wallpaper-finished
```

Wallpaper loading took only 1.54 seconds. The roughly 137-second pause was
inside the X server/first-Xlib-client boundary. Tiny Core normally exposes
extension files as symlinks into separately mounted SquashFS images. On this
build those images are themselves read through the ext2 image, FATX loop, and
Xbox disk, so the first X client demand-loads its library and font pages through
multiple filesystem layers.

## Candidate Design

The candidate adds `xbox_x_hotset=1` to `linuxboot.cfg`. The initramfs responds
by copying these already-installed extensions from their SquashFS mounts into
the RAM-backed Tiny Core root before X starts:

```text
libXau libXdmcp libxcb libX11 Xlibs libpng freetype libfontenc libXfont Xfbdev
```

Their extracted directory footprint is 6,143,911 bytes. This is intentionally
smaller than unpacking the complete 28-extension desktop. The kernel, payload,
Xromwell XBE, protected package, and RA1024 storage settings are unchanged.

The X session now records separate markers for:

```text
xfbdev-start
xfbdev-launched
x-socket-wait-start
x-socket-ready (or x-socket-timeout)
waitforx-start
waitforx-finished
x-ready
```

Wallpaper loading remains after FLWM and the proof terminal, but is now
synchronous with wbar startup. This lets wbar capture the finished wallpaper
for its faux-transparent background instead of retaining the grey X root.

## Artifact

Self-contained hardware package:

```text
artifacts\tinycore-hdd-x-hotset-candidate\xromwell-hddfatx-tinycore-lean-xhotset-ra1024k-candidate.zip
SHA256 45470E2A22F2DF5284A10BCFC9856D1931346D638052F6EE04343D1D8DABE401
```

Boot-file hashes:

```text
default.xbe        C78475E8713EC694F484C40209966805E9F9CD267E7C2EE6A3B9217E40FE0CD2
vmlinuz            D3C812196908F8F2CA96C7863184C59C39982E27A2DD1ED6DFF125D5DA9FCAFE
initramf           C8B91B0E7428DDF5123707049013DD3CE8AC7EF8105B5F2E20235264FBD43E43
linuxroot.ext2     CFBBC4ED822FFBA297954C80FA94B1878C5CBB07BE7FA8F7B855E3B55E3E4691
```

Protected source, verified unchanged:

```text
artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip
SHA256 17327756ED0CB274145CFDD974D119BEF19DB0F7588509726BB8C6BBFD4DE866
```

Do not mix individual files with another candidate. Use the complete extracted
directory or ZIP.

## Emulator Gate

The package passed three fresh-disk xemu boots. Every run staged the payload
first, verified contiguous FATX allocation and read-back hashes, booted through
the established Cromwell ROM, captured the entire xemu window, and stopped the
emulator afterward.

```text
run  Linux text  complete desktop  proof terminal
1    17 s        45 s              45 s
2    16 s        45 s              45 s
3    16 s        45 s              45 s
```

Evidence:

```text
run\tinycore-hdd-x-hotset-ra1024\20260804-012026
```

xemu validates compatibility and repeatability, but its storage speed does not
predict the real Xbox improvement.

## Real-Hardware Result

The RA1024 X-hotset package booted to an interactive desktop in approximately
50 seconds measured from launching Xromwell in the dashboard. Kernel uptime
markers put the completed wallpaper, dock, and system X hooks at 26.99 seconds:

```text
13.85 hotset-start
20.36 hotset-finished
24.95 xsession-start
25.99 x-socket-ready
25.99 waitforx-start
26.00 waitforx-finished
26.00 x-ready
26.98 wallpaper-finished
26.99 icons-started
26.99 system-xd-finished
```

The hotset copy took 6.51 seconds. Xfbdev then exposed its socket in about one
second and the first Xlib connection completed in 0.01 seconds. This replaces
the previous approximately 137.4-second delay between `xsession-start` and
`x-ready`.

Memory snapshots show the expected cost:

```text
                         before       after
MemFree                  6736 kB      3388 kB
MemAvailable            16968 kB     10880 kB
```

The 6,088 kB reduction in available memory closely matches the measured 6.14
MB extracted hotset. After the complete desktop loaded, `MemAvailable` remained
about 10.9 MB. This is workable for the lean desktop but leaves little room for
larger applications, so future expansion should avoid materializing unrelated
extensions.

Networking also passed: DHCP assigned `192.168.50.156`, installed the default
route and resolver, and reported `XBOX_NETWORK_DHCP_OK`. The internal hard disk
used UDMA2 rather than PIO. Under this 6.18 libata kernel the internal PATA disk
is `/dev/sda`; a subsequently connected USB flash drive should normally be
`/dev/sdb` or `/dev/sdb1`.

## Hardware Checklist

After the desktop appears, collect:

```sh
cat /tmp/xbox-hotset-timing.txt
cat /tmp/xbox-hotset-memory-before.txt
cat /tmp/xbox-hotset-memory-after.txt
cat /tmp/xbox-hotset-du.txt
cat /tmp/xbox-desktop-timing.txt
free -m
```

The candidate succeeds if the time from `hotset-start` through `x-ready` is
materially lower than the baseline's roughly 137-second X wait and the remaining
free memory is sufficient for normal desktop use. The dock should have the blue
wallpaper behind it rather than a grey rectangle.

## Reproduce

```powershell
.\scripts\new_tinycore_hdd_ra128_candidate.ps1 `
  -OutRoot artifacts\tinycore-hdd-x-hotset-candidate `
  -ReadAheadKb 1024 -DiskReadAheadKb 1024 -XHotset

.\scripts\test_tinycore_hdd_candidate.ps1 `
  -CandidateRoot artifacts\tinycore-hdd-x-hotset-candidate `
  -OutputRoot run\tinycore-hdd-x-hotset-ra1024 `
  -Runs 3 -RequiredPasses 3 -PollSeconds 5
```
