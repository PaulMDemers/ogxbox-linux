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

The critical change is `5eaba1e`. Before that, Cromwell assumed a 16 KiB FATX
cluster size:

```c
partition->clusterSize = 0x4000;
partition->clusterCount = partition->partitionSize / 0x4000;
```

After `5eaba1e`, it reads the sectors-per-cluster value from the FATX header.
On the test Xbox, Xromwell reports:

```text
FATX: spc=2 csize=1024 clusters=313280 ent=4 table=1253376
```

That is a very different access pattern: kernel reads become thousands of
1 KiB cluster reads or chain lookups, and the chain table is 1.25 MiB. xemu is
passing this path, but the real IDE/FATX path is hanging before the first
coalesced 64 KiB progress marker.

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

## Test Plan

1. Test `xromwell-fe80736-devuan-daedalus-i386.zip`.

   If it boots quickly, the regression is after the original FATX autoboot
   implementation. The likely boundary is `5eaba1e`, where the loader starts
   honoring the 1 KiB cluster size reported by the upgraded E: partition.

2. Test `xromwell-16788e0-devuan-daedalus-i386.zip`.

   If `fe80736` boots but `16788e0` hangs, the bug is in the cluster-size,
   chain-table, or guarded-chain path before lazy caching was added.

3. If both audit packages hang, compare the installed E: root files and copy
   order against the original fast package. At that point the old-good artifact
   likely differed from the repo lock, or the FATX file layout/fragmentation on
   E: changed enough that even the old reader hits a bad path.

4. If both audit packages boot and only `4dcc618` hangs, bisect the later
   reader changes: lazy chain table, direct Linux autoboot, then coalesced
   reads.

The next code fix should come after this hardware split. The probable fixes are
either to bring back the old 16 KiB compatibility behavior for Xromwell file
loads on upgraded FATX volumes, or to keep the correct 1 KiB header parsing but
make real-hardware IDE reads strictly sector-sized and visibly timed around the
first `/devkrnl` run.
