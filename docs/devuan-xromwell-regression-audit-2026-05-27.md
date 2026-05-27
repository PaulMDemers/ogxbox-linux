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

## Test Plan

1. Test `xromwell-fe80736-casefold-devuan-daedalus-i386.zip`.

   Delete or overwrite the four root files first, then copy this package's
   `E-root\` contents to `E:\`. If it boots quickly, the regression is after
   the original FATX autoboot implementation plus case-insensitive lookup.

2. If the casefold package hangs before `FATX: detect linux /linuxboot.cfg`,
   move to a lazy-table rollback package rather than further kernel/initrd
   changes.

3. If the casefold package prints `found` but hangs during `/devkrnl`, compare
   the current E: root file copy order and fragmentation against the original
   fast package, then instrument the first kernel file read.

4. Test `xromwell-16788e0-devuan-daedalus-i386.zip` only if the casefold
   package reaches config detection.

   If `fe80736` boots but `16788e0` hangs, the bug is in the cluster-size,
   chain-table, or guarded-chain path before lazy caching was added.

The next code fix should come after this hardware split. The probable fixes are
either a lazy-table rollback based closer to the fast Devuan build, or
real-hardware IDE/FATX instrumentation around `OpenFATXPartition` and the first
`/devkrnl` run.
