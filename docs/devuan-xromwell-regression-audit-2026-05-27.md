# Devuan Xromwell Regression Audit, 2026-05-27

## Symptom

Real hardware with Xromwell hangs while loading the minimal Devuan desktop from
FATX E:. The current failing screen gets through config discovery and stops at
the kernel load:

```text
FATX: found /linuxboot.cfg ...
FATX: parsed linuxboot.cfg
AUTOBOOT: selected Linux
FATX: boot open E
FATX: loading kernel /devkrnl
Loading /devkrnl from FATX tmp=0x1000000 size=2617856 cluster=...
```

With `4dcc618`, no first `[65536]` progress marker appears on the real Xbox.
That means the stall happens before the first 64 KiB of `/devkrnl` has been
read and copied.

## Known Good Checkpoint

The initially fast Devuan result was recorded after `b9d818e` and
`c14b0c6`: Devuan Daedalus i386 booted to the desktop on real softmodded Xbox
hardware and felt fast/snappy. The package shape at that point was:

```text
E:\Apps\XromwellDevuanDaedalus\default.xbe
E:\linuxboot.cfg
E:\devkrnl
E:\devinit
E:\devuan.ext2
```

The desktop package command has not materially changed since that checkpoint:
it still uses `devkrnl`, `devinit`, `devuan.ext2`, and the same desktop append
line. The only later addition in `scripts/package_devuan_daedalus_i386_softmod.ps1`
is a separate terminal package before the desktop package.

## What Changed

The major difference is Xromwell's FATX reader, not the Devuan desktop package.

Current Xromwell history:

```text
fe80736 linuxboot: add FATX HDD autoboot support
a7dd859 fatx: speed up HDD Linux loads
6cb54cc fatx: stop reading once file size is satisfied
5eaba1e fatx: honor cluster size from partition header
16788e0 fatx: reject invalid cluster chain entries
5518ffc fatx: lazily read large chain maps
1045ad9 fatx: eagerly cache medium chain maps
62835f4 fatx: cache lazy chain map pages
3fa5e65 fatx: make autoboot Linux direct
4dcc618 fatx: coalesce file cluster reads
```

The first suspected change was `5eaba1e`, where Cromwell stopped assuming a
16 KiB FATX cluster size:

```c
partition->clusterSize = 0x4000;
partition->clusterCount = partition->partitionSize / 0x4000;
```

After `5eaba1e`, it reads the sectors-per-cluster value from the FATX header.
Re-reading the hardware screenshots shows the test Xbox is still reporting
16 KiB clusters:

```text
FATX: spc=32 csize=16384 clusters=312280 ent=4 table=1253376
```

So the cluster-size math itself is probably not the current regression. The
common hardware pain point is the 1.25 MiB FATX chain table and the first
`/devkrnl` file read. xemu is passing this path, but the real IDE/FATX path is
hanging before the first coalesced 64 KiB progress marker.

Other changes after the good point may still matter, but they are secondary:

- `16788e0` added invalid-cluster guards.
- `5518ffc` and `62835f4` changed chain-map loading from eager reads to lazy
  cached pages.
- `3fa5e65` skipped the ReactOS probe after Linux config is found.
- `4dcc618` coalesced contiguous file data reads into 64 KiB runs.
- `bfe8301` and later memory-layout changes moved the kernel temp buffer and
  initrd window, but the current hang is before Linux receives control.

## Audit Artifacts

Two rollback/midpoint packages were built against the current minimal Devuan
payload so hardware testing can isolate the regression.

Old initial FATX autoboot Xromwell:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-fe80736-devuan-daedalus-i386.zip
SHA256 C554E0C328F39879D2939B04C97C1FD286F99D203A9F3D8F4CACC2191F84A7D7
Dashboard folder: E:\Apps\XromwellDevuanDaedalusFe80736\
```

Midpoint after header cluster-size support and invalid-chain guards:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-16788e0-devuan-daedalus-i386.zip
SHA256 7F8AD417F8E7CA13CAF0252C1463615D228749264B12D997E25A90A4DE7FC81A
Dashboard folder: E:\Apps\XromwellDevuanDaedalus16788e0\
```

The historical Cromwell build system stamps `-dirty` into these banners after
building generated objects inside the worktree, so use the package filenames
and dashboard folder names as the commit identifiers.

## Hardware Follow-Up

The first rollback packages, `fe80736` and `16788e0`, both stopped at
`AUTOBOOT FATX (E:)` on real hardware. Both of those Xromwell builds predate
the case-insensitive FATX filename lookup, so that result is ambiguous: they
may be stuck in the eager FATX table read, or they may not be finding
`linuxboot.cfg` if the FATX directory entry case differs from the requested
path.

A third audit package was built from `fe80736` with only the case-insensitive
lookup and a small `linuxboot.cfg` detection print added. It keeps the old
16 KiB-cluster FATX behavior and does not include the later lazy table,
direct-Linux, or coalesced-read changes.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-fe80736-casefold-devuan-daedalus-i386.zip
SHA256 30178F640FB57AABB2539995C6D4F5C6B20FF92C6D8BEDA2CA72FB86E9CC452E
Dashboard folder: E:\Apps\XromwellDevuanDaedalusFe80736CF\
```

Expected distinguishing lines:

```text
FATX: detect linux /linuxboot.cfg
FATX: found /linuxboot.cfg size=...
```

If this still never prints `FATX: detect linux /linuxboot.cfg`, the stall is
inside `OpenFATXPartition`, most likely the eager chain-table read. If it does
print `found` and then hangs during `/devkrnl`, the table read is not the only
issue and the old loader behavior is no longer enough with the current E: file
layout.

Hardware result: the casefold package still stopped at `AUTOBOOT FATX (E:)`.
That means the case-sensitive name lookup was not the blocker. The next test
keeps the same `fe80736` lineage and case-insensitive lookup, but skips the old
full chain-table read during FATX partition open. It reads individual chain
entries lazily instead.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-fe80736-casefold-lazytable-devuan-daedalus-i386.zip
SHA256 E8BEB1F2692595FBFBCB3250675BE5989FF878B2EF92A816B790C92DA454B1DE
Dashboard folder: E:\Apps\XromwellDevuanDaedalusFe80736Lazy\
```

Expected distinguishing line immediately after `AUTOBOOT FATX (E:)`:

```text
FATX: open part sector=0x55F400
FATX: lazy table clusters=... csize=16384 ent=4 table=... cluster1=...
```

If this gets past `AUTOBOOT FATX (E:)`, the old eager chain-table read is
confirmed as the hardware hang. If this still shows no `FATX: open part` line,
the call may be hanging before or during the first FATX header sector read and
the next target is `BootFromDevice`/IDE instrumentation before
`OpenFATXPartition`.

Hardware result: this lazy-table package reached
`FATX: detect linux /linuxboot.cfg`, then printed `[0]` and corrupted the video
into vertical bars. That points to the old `FATXRawRead` unaligned-read path.
The old code read a full 512-byte sector into the caller's small buffer instead
of a local 512-byte bounce buffer; the lazy single-entry FAT reads pass a
4-byte stack buffer, so this can overwrite nearby state. It also copied from
the wrong buffer afterward.

A raw-read fix package was built with the lazy table change plus:

- fixed unaligned `FATXRawRead` to read into the local sector bounce buffer;
- advanced sectors by the actual number read;
- capped aligned reads to 16 KiB like later known-working code;
- stopped file loads once the requested file size is satisfied, so a tiny
  `linuxboot.cfg` does not request another cluster after completion;
- moved progress prints after successful reads, so `[0]` should no longer be
  the last marker.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-fe80736-lazytable-rawfix-devuan-daedalus-i386.zip
SHA256 6C8AE561439FD209312DE44B23E339B6B55966A1F5021D8BDDB993179C7E937E
Dashboard folder: E:\Apps\XromwellDevuanDaedalusFe80736Rawfix\
```

Hardware result: this raw-read fix package no longer corrupts the video and it
gets through FATX open, lazy table setup, and Linux config detection. It now
fails cleanly because the normal FATX lookup does not find the root config:

```text
FATX: detect linux /linuxboot.cfg
FATX: linuxboot.cfg not found
AUTOBOOT FatX failed.
```

That confirms two earlier problems on real hardware:

- The old eager chain-table read was a real blocker.
- The old unaligned `FATXRawRead` path could corrupt nearby state when lazy
  chain-entry reads used a 4-byte stack buffer.

The next question is why root lookup misses `linuxboot.cfg` even though the
softmod package places it at `E:\linuxboot.cfg`. A root-scan package was built
from the same rawfix base. It scans early root directory clusters directly and
prints the first few entries it sees.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-fe80736-root-scan-devuan-daedalus-i386.zip
SHA256 9A28A8A170ACBE3167295E14BADA6EFFF96974B19FE9045D70202639A48A1FBB
Dashboard folder: E:\Apps\XromwellDevuanDaedalusFe80736RootScan\
```

Expected distinguishing lines:

```text
FATX: root scan fallback linuxboot.cfg
FATX: root c1 e0 ...
FATX: root scan found linuxboot.cfg at c... e... filecl=... size=...
```

If the root scan finds `linuxboot.cfg`, the normal root-chain traversal is the
remaining bug. If it prints entries but misses the file, verify that the package
root files were copied to `E:\` and not only under the dashboard app folder.
If it finds `linuxboot.cfg` but then misses `devkrnl`, the same root lookup
fallback needs to cover the kernel/initrd payloads too.

Hardware result: this package prints real E: root entries such as `DATA`,
`Applications`, `CACHE`, `Backup`, and report files, confirming that Xromwell
is reading the real root directory and not the dashboard app directory. The
first package only printed the first eight valid entries from root cluster 1,
so the screenshot was not a complete directory listing.

A deeper root-scan package was built to make the next result less ambiguous.
It scans more candidate clusters and prints any filename that looks relevant to
the boot files (`linux`, `boot`, `cfg`, `devkrnl`, or `devinit`) before falling
back to a miss summary.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-fe80736-root-deep-devuan-daedalus-i386.zip
SHA256 7391D599A41B41F2122F701081AF5C76D1359343CBA3DBC93A21E4562E8CB01E
Dashboard folder: E:\Apps\XromwellDevuanDaedalusFe80736RootDeep\
```

Expected distinguishing lines:

```text
FATX: root maybe c... e... linuxboot.cfg ...
FATX: root scan found linuxboot.cfg ...
```

If it does not find the config, the miss line now includes the amount of root
data scanned:

```text
FATX: root scan missed linuxboot.cfg clusters=... entries=... limit=1024
```

Hardware result: the deeper scan is too noisy to keep pursuing as a release
candidate. It prints many `FATX: root maybe ...` entries from dashboard-related
clusters, which confirms that it can walk around the FATX data area, but the
diagnostic heuristic is not a clean signal for boot correctness.

The important comparison is now:

```text
Known snappy/minimal Devuan package:
  C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386.zip
  Payload:  C:\Users\Paul\Desktop\xbox_linux\artifacts\hdd\xbox-devuan-daedalus-i386.ext2
  Payload size: 402653184 bytes
  XBE SHA256: C78475E8713EC694F484C40209966805E9F9CD267E7C2EE6A3B9217E40FE0CD2
  Xromwell lineage: 4dcc618 coalesced/cached FATX loader

Current root-deep diagnostic package:
  C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-fe80736-root-deep-devuan-daedalus-i386.zip
  Payload: same 402653184-byte Devuan ext2 image
  Same linuxboot.cfg append line
  XBE SHA256: 23531BE51890F968209CB82BF85D81FA562B41CE6B0BE9EF55FA99E79617F97A
  Xromwell lineage: dirty fe80736 audit fork with lazy table, raw-read fix,
  and experimental root scanner
```

So the regression is not explained by the minimal Devuan image size. The clean
baseline should move back to the release Devuan desktop package and the
4dcc618 Xromwell loader. Treat the fe80736 root-scan builds as throwaway
diagnostics only.

Hardware result: the 4dcc618 release package is not a clean real-hardware
baseline on this disk. It finds and parses `linuxboot.cfg`, selects Linux,
reopens E:, finds `/devkrnl`, then stops here:

```text
FATX: loading kernel /devkrnl
Loading /devkrnl from FATX tmp=0x1000000 size=2617856 cluster=1301
```

No `[65536]` marker appears, so the first coalesced kernel read does not return.
The next split is `3fa5e65`, which keeps the cached lazy FATX table and direct
Linux autoboot, but is one commit before `4dcc618` added contiguous 64 KiB file
read coalescing.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-devuan-daedalus-i386.zip
SHA256 ACB91289E87C97909F48F22E56CDE4A7110114E6FADA750973FFF8D2CB1DF325
Dashboard folder: E:\Apps\XromwellDevuanDaedalus3fa5e65\
XBE SHA256: FA1D074FC2582DA4E4636783A4A909AA272A3D2C6D5AD4D512CAA0915B7A2284
```

This package uses the same `devkrnl`, `devinit`, `devuan.ext2`, and
`linuxboot.cfg` append line as the release package. If it gets past `/devkrnl`,
`4dcc618`'s coalesced FATX file load is the regression. If it also stops at
`/devkrnl`, the issue is lower than coalescing: the cached table/file cluster
read path or the physical placement/fragmentation of `devkrnl` on this E:
partition.

Hardware result: `3fa5e65` also stops at the first kernel load, so the
regression is not only the 4dcc618 coalesced read. It still gets through
`linuxboot.cfg`, reopens E:, and then stops while loading the kernel file.

The next package keeps `3fa5e65`, adds a print before the first few file-cluster
reads, and changes the root filenames so the kernel is copied as a new FATX
file rather than reusing the existing `/devkrnl` chain:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-readtrace-altname-devuan-daedalus-i386.zip
SHA256 EC4463F70B40EB35CF8563862ED59E7FEA44974A42C0B9F8B05074B64BB5A49B
Dashboard folder: E:\Apps\XromwellDevuanDaedalusReadTraceAlt\
Root files: E:\linuxboot.cfg, E:\xkrnl, E:\xinit, E:\xdevuan.ext2
```

Expected distinguishing line before any hang:

```text
FATX: read xkrnl c=... abs=0x... off=... len=1024
```

If the new `xkrnl` placement loads, the stale/fragmented `/devkrnl` chain is
the likely culprit. If it hangs after printing the `xkrnl` read line, the
absolute sector on that line tells us the next IDE/FATX probe target.

## Test Plan

1. Test the read-trace alternate-filename package:

   ```text
   C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-readtrace-altname-devuan-daedalus-i386.zip
   SHA256 EC4463F70B40EB35CF8563862ED59E7FEA44974A42C0B9F8B05074B64BB5A49B
   Dashboard folder: E:\Apps\XromwellDevuanDaedalusReadTraceAlt\
   ```

   For the fastest first pass, copy only `E-root\linuxboot.cfg`, `E-root\xkrnl`,
   and `E-root\xinit` to `E:\`. Copy `E-root\xdevuan.ext2` after Xromwell proves
   it can load `xkrnl` and `xinit`.

2. Keep the root-scan packages only as diagnostics. Do not promote them into
   the release path.

3. If `3fa5e65` also stops at `/devkrnl`, build an instrumented package that
   prints the physical cluster address and read length before every kernel
   cluster read, then test after deleting and re-copying only `devkrnl` to
   change its FATX placement.

4. Test `xromwell-16788e0-devuan-daedalus-i386.zip` only if the casefold
   package reaches config detection.

   If `fe80736` boots but `16788e0` hangs, the bug is in the cluster-size,
   chain-table, or guarded-chain path before lazy caching was added.

The next code fix should come after this hardware split. The probable fixes are
either a lazy-table rollback based closer to the fast Devuan build, or
real-hardware IDE/FATX instrumentation around `OpenFATXPartition` and the first
`/devkrnl` run.
