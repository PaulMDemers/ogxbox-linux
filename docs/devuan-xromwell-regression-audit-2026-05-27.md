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

Hardware result: the alternate `xkrnl` placement is found, but it still hangs
on the first file-cluster read:

```text
FATX: loading kernel /xkrnl
Loading /xkrnl from FATX tmp=0x1000000 size=2617856 cluster=28500
FATX: read xkrnl c=28500 abs=0x681718 off=0 len=16384
```

That rules out the old `/devkrnl` directory entry and strongly suggests either
the physical sector range or the 16 KiB multi-sector IDE read is the problem.
The next package caps FATX raw reads at 512 bytes and prints each early sector
before calling `BootIdeReadSector`.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sectortrace-altname-devuan-daedalus-i386.zip
SHA256 56F855A23B381EECA85B29198BFDEF7875785484711227487422DACC4C112738
Dashboard folder: E:\Apps\XromwellDevuanDaedalusSectorTrace\
XBE SHA256: 330E41394B02EFFCC8E4ABF1F2C31F91B8A6FAD0205576477422713B6001812C
Root files: E:\linuxboot.cfg, E:\xkrnl, E:\xinit, E:\xdevuan.ext2
```

Expected distinguishing lines:

```text
FATX: read xkrnl c=... abs=0x... off=0 len=16384
FATX: raw xkrnl sec=0x... off=0 len=512
```

If the sector-trace package gets past the kernel load, the fix is to avoid
large IDE reads in the Xromwell FATX path on real hardware. If it hangs on the
first `FATX: raw` line, the absolute sector is suspect and the next move is to
copy the boot files after forcing a different allocation area on E:.

Hardware result: the sector-trace package did not immediately hang at
`linuxboot.cfg`. Instead it printed a long list of 512-byte raw reads while
reading the config file:

```text
FATX: read linuxboot.cfg c=1744 abs=0x570178 off=0 len=16384
FATX: raw linuxboot.cfg sec=0x570178 off=0 len=512
...
```

That is an important split: 512-byte reads are viable on this real hardware,
but the per-sector trace is too noisy to see whether the kernel and initrd
load cleanly. A quieter sector512 package was built from the same `3fa5e65`
lineage. It keeps the 512-byte read cap, removes the per-sector spam, and
prints one first-cluster line per file.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-altname-devuan-daedalus-i386.zip
SHA256 3FEBAD94F47E1619EDB8750530D2ADBAD463CB9E63F09E5F19BFCB86ABC648D9
Dashboard folder: E:\Apps\XromwellDevuanDaedalusSector512\
XBE SHA256: 81B3A6850627A8BEC6FA0D92BB4652400DB3EC863072EAA7351BB159DED0BAFD
Root files: E:\linuxboot.cfg, E:\xkrnl, E:\xinit, E:\xdevuan.ext2
```

Expected useful lines:

```text
FATX: read linuxboot.cfg c=...
FATX: read xkrnl c=... abs=0x... off=0 len=16384
FATX: read xinit c=... abs=0x... off=0 len=16384
```

If this gets through `xkrnl` and `xinit`, then the release fix should be a
conservative real-hardware FATX read cap rather than the noisy trace build. If
it still hangs on the first `xkrnl` line, the problem is lower than request
size and the next target is IDE status/timeout instrumentation around that
absolute sector.

Hardware result: the quiet sector512 package boots through Xromwell and reaches
the Devuan desktop on real hardware. Boot speed is reasonable. Once X starts,
the desktop is usable but very slow: mouse input works, then periodically lags,
and the first terminal window remains a black square longer than expected
before painting.

That moves the active problem from Xromwell's pre-kernel FATX loader to runtime
I/O or early-desktop contention. The root filesystem is still an ext2 image
loop-mounted through the Linux FATX driver from E:, so slow or under-read-ahead
loopback reads can stall userspace after X starts.

A performance probe package was built from the same successful sector512
Xromwell XBE. It adds opt-in stage1/root settings:

- set read-ahead on `/dev/loop0`, the FATX E: loop device;
- set read-ahead on `/dev/loop1`, the ext2 root image loop device;
- delay the verbose `xbox-diag` helper until after the desktop has had time to
  paint;
- use a lighter initial terminal command so the window appears faster.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-devuan-perf1-daedalus-i386.zip
SHA256 25B51D19096033D8004BAE0E935877D6AE72BEB33E6D55A791423584232C6F75
Dashboard folder: E:\Apps\XromwellDevuanPerf1\
XBE SHA256: 81B3A6850627A8BEC6FA0D92BB4652400DB3EC863072EAA7351BB159DED0BAFD
Initramfs SHA256: 648AE901C0BD15744F885687343FDA3118C4C3495E3E89DD5B7DEB62DAD31C50
Payload SHA256: 6C1A8D3D47BBD151DED8002F5175B98B5594929F8DC1C6BA16965E313D1E7F22
Root files: E:\linuxboot.cfg, E:\xkrnl, E:\xinit, E:\xdevuan.ext2
```

The package append line adds:

```text
xbox_fatx_loop_readahead_kb=1024 xbox_loop_readahead_kb=1024 xbox_diag=late xbox_terminal_light=1
```

The generated ext2 image passed `e2fsck -fn`:

```text
artifacts/hdd/xbox-devuan-daedalus-i386-perf1.ext2: 9701/98304 files (0.1% non-contiguous), 71165/98304 blocks
```

Hardware result: the full `perf1` package did not reach Linux. It stopped back
in Xromwell while loading the same `xkrnl` bytes:

```text
FATX: loading kernel /xkrnl
Loading /xkrnl from FATX tmp=0x1000000
```

The XBE and kernel file hashes match the successful quiet sector512 package,
so the likely variable is FATX allocation/placement caused by recopying the
root files, not the Linux-side performance flags. Do not mix files from
multiple package folders while testing this; each package folder must contain
all of its own artifacts.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-devuan-perf1-selfcontained-daedalus-i386.zip
SHA256 591D8B77DBD5BA3EBE32DB465101F2F074269E2F8B19952ACC04E7A2DB372970
Dashboard folder: E:\Apps\XromwellDevuanPerf1SelfContained\
XBE SHA256: 81B3A6850627A8BEC6FA0D92BB4652400DB3EC863072EAA7351BB159DED0BAFD
Kernel SHA256: D3C812196908F8F2CA96C7863184C59C39982E27A2DD1ED6DFF125D5DA9FCAFE
Initramfs SHA256: 648AE901C0BD15744F885687343FDA3118C4C3495E3E89DD5B7DEB62DAD31C50
Payload SHA256: 6C1A8D3D47BBD151DED8002F5175B98B5594929F8DC1C6BA16965E313D1E7F22
Root files in this package: E:\linuxboot.cfg, E:\xkrnl, E:\xinit, E:\xdevuan.ext2
```

This self-contained package includes `COPY-ORDER.txt` and a README suggesting
a clean-copy order. If it still hangs at `/xkrnl` after copying from a clean E:
root, the loader needs a stronger real-hardware fix than the current 512-byte
cap.

Hardware result: the self-contained `perf1` package still hangs at the same
point while loading `/xkrnl`. That rules out cross-package artifact smearing
and makes this a Xromwell FATX loader issue on real hardware.

A phase-trace package was built from the same sector512 lineage. It is
self-contained and adds markers around the fixed FATX file-load path so the
next hardware photo can show the exact failing phase:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-phasetrace-devuan-perf1-daedalus-i386.zip
SHA256 5526F7EC1E357CA1024E3198DF787E6AA940966E26C74A5FCCCF0BC9824B1529
Dashboard folder: E:\Apps\XromwellDevuanPhaseTracePerf1\
XBE SHA256: D2518C4EB83140C977B2D9F67920F871CB6A9B9A0BF91E66239ABAAC178AB49F
Root files in this package: E:\linuxboot.cfg, E:\xkrnl, E:\xinit, E:\xdevuan.ext2
```

Expected phase markers:

```text
FATX: fixed open /xkrnl
FATX: fixed found /xkrnl size=... cluster=...
FATX: read xkrnl c=... abs=...
FATX: fixed loaded /xkrnl read=...
```

The last visible marker tells us whether the hang is in root lookup,
chain-table/root-directory reads, the first raw sector read, or the post-read
file copy. The Cromwell source for this diagnostic is preserved on:

```text
PaulMDemers/cromwell.git codex/sector512-phasetrace @ 9fc54d0
```

Hardware result: the phase-trace package hangs directly after:

```text
FATX: fixed open /xkrnl
```

That puts the failure before the file metadata is found, inside the FATX root
directory lookup path rather than the large `/xkrnl` file read. A follow-up
package moves the FATX directory scan scratch cluster out of the bootloader
stack and adds lookup-phase markers:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-findstatic-devuan-perf1-daedalus-i386.zip
SHA256 A82F58AD2758BD2B0F6F558B6DF6E33D9B734A2DF4332E310C9F3D1536A2242E
Dashboard folder: E:\Apps\XromwellDevuanFindStaticPerf1\
XBE SHA256: EF3F704564E04CC9796F337861BA0DD8A6A5E800618AEB2784D288AFB7F8418C
Root files in this package: E:\linuxboot.cfg, E:\xkrnl, E:\xinit, E:\xdevuan.ext2
```

Expected lookup markers:

```text
FATX: find scan seek=xkrnl c=1
FATX: find load c=1 ok
FATX: find match xkrnl c=... sz=...
FATX: fixed found /xkrnl size=... cluster=...
```

Hardware result: the static-directory-buffer package reaches lookup, then
hangs before the full root directory cluster returns:

```text
FATX: fixed open /xkrnl
FATX: find scan seek=xkrnl c=1
FATX: find load c=1
```

The next package changes the directory lookup to read 512-byte sectors and stop
as soon as the target entry is found, instead of requiring a full 16 KB root
cluster read:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-findsector-devuan-perf1-daedalus-i386.zip
SHA256 BE0E45F4A59D7EBDAE0DBBD4B293394C919F1B5BBA5179E48A39CAE1BE80934F
Dashboard folder: E:\Apps\XromwellDevuanFindSectorPerf1\
XBE SHA256: 0F13CE8D0BA92744AAB5D113BA17976DAD2A6F1EC0D026C0A51338F3E45870A9
Root files in this package: E:\linuxboot.cfg, E:\xkrnl, E:\xinit, E:\xdevuan.ext2
```

Expected sector lookup markers:

```text
FATX: find sec c=1 o=0 ok
FATX: find sec c=1 o=512 ok
FATX: find match xkrnl e=... c=... sz=...
FATX: fixed found /xkrnl size=... cluster=...
```

Hardware result: the sector-at-a-time lookup package finds `/xkrnl` and enters
the kernel file read path:

```text
FATX: find match xkrnl c=28501 sz=2617856
FATX: fixed found /xkrnl size=2617856 cluster=28501
FATX: read xkrnl c=28501 abs=... off=0 len=16384
```

The next package applies the same sector-at-a-time strategy to file loading
itself, so `/xkrnl` and `/xinit` no longer depend on the old full-cluster read:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-filesector-devuan-perf1-daedalus-i386.zip
SHA256 526BC6571CE6965557AF79DA1892088BA457CBEF47C06FE3EB530DB841F16714
Dashboard folder: E:\Apps\XromwellDevuanFileSectorPerf1\
XBE SHA256: 3780AE6674B2C3259CA0C13DF27DC229F5AA8E838086FA39E55213A26C537F9A
Root files in this package: E:\linuxboot.cfg, E:\xkrnl, E:\xinit, E:\xdevuan.ext2
```

Expected file-load markers:

```text
FATX: file start xkrnl sz=2617856 c=28501
FATX: file at xkrnl read=0 c=28501 abs=...
FATX: file sec c=28501 o=0 ok
FATX: file done xkrnl read=2617856
```

## Probe Test Plan

This probe plan is now superseded for release-prep by the May 28 reset
baseline below. Keep these packages as diagnostic checkpoints only; do not use
them as the next normal hardware test unless we deliberately return to loader
debugging.

1. Test the sector-at-a-time file-load package:

   ```text
   C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-filesector-devuan-perf1-daedalus-i386.zip
   SHA256 526BC6571CE6965557AF79DA1892088BA457CBEF47C06FE3EB530DB841F16714
   Dashboard folder: E:\Apps\XromwellDevuanFileSectorPerf1\
   ```

   Copy every file from its own `E-root` folder. Report the last `FATX: file`
   or `FATX: fixed` line visible if it hangs.

2. Keep the sector-at-a-time lookup package as the file-read entry checkpoint:

   ```text
   C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-findsector-devuan-perf1-daedalus-i386.zip
   SHA256 BE0E45F4A59D7EBDAE0DBBD4B293394C919F1B5BBA5179E48A39CAE1BE80934F
   Dashboard folder: E:\Apps\XromwellDevuanFindSectorPerf1\
   ```

   Copy every file from its own `E-root` folder. Report the last `FATX: find`
   or `FATX: fixed` line visible if it hangs.

3. Keep the static-directory-buffer lookup package as the full cluster-read
   failure checkpoint:

   ```text
   C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-findstatic-devuan-perf1-daedalus-i386.zip
   SHA256 A82F58AD2758BD2B0F6F558B6DF6E33D9B734A2DF4332E310C9F3D1536A2242E
   Dashboard folder: E:\Apps\XromwellDevuanFindStaticPerf1\
   ```

   Copy every file from its own `E-root` folder. Report the last `FATX: find`
   or `FATX: fixed` line visible if it hangs.

4. Keep the phase-trace package as the `fixed open` failure checkpoint:

   ```text
   C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-phasetrace-devuan-perf1-daedalus-i386.zip
   SHA256 5526F7EC1E357CA1024E3198DF787E6AA940966E26C74A5FCCCF0BC9824B1529
   Dashboard folder: E:\Apps\XromwellDevuanPhaseTracePerf1\
   ```

   Copy every file from its own `E-root` folder. Report the last `FATX: fixed`
   or `FATX: read` line visible if it hangs.

5. Keep the self-contained perf1 package as the clean failed package:

   ```text
   C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-devuan-perf1-selfcontained-daedalus-i386.zip
   SHA256 591D8B77DBD5BA3EBE32DB465101F2F074269E2F8B19952ACC04E7A2DB372970
   Dashboard folder: E:\Apps\XromwellDevuanPerf1SelfContained\
   ```

   Copy every file from its own `E-root` folder. Do not pull files from another
   package. For repeatability, follow its `COPY-ORDER.txt`.

6. Keep the full perf1 package as a failed allocation-sensitive probe:

   ```text
   C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-devuan-perf1-daedalus-i386.zip
   SHA256 25B51D19096033D8004BAE0E935877D6AE72BEB33E6D55A791423584232C6F75
   Dashboard folder: E:\Apps\XromwellDevuanPerf1\
   ```

   This is the current best next test. It should boot like the successful
   sector512 package but tell us whether loop read-ahead plus delayed
   diagnostics reduce the black-terminal delay and mouse stalls.

7. Keep the quiet sector512 alternate-filename package as the Xromwell boot
   success checkpoint:

   ```text
   C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-3fa5e65-sector512-altname-devuan-daedalus-i386.zip
   SHA256 3FEBAD94F47E1619EDB8750530D2ADBAD463CB9E63F09E5F19BFCB86ABC648D9
   Dashboard folder: E:\Apps\XromwellDevuanDaedalusSector512\
   ```

   For the fastest first pass, copy only `E-root\linuxboot.cfg`, `E-root\xkrnl`,
   and `E-root\xinit` to `E:\`. Copy `E-root\xdevuan.ext2` after Xromwell proves
   it can load `xkrnl` and `xinit`.

8. Keep the root-scan packages only as diagnostics. Do not promote them into
   the release path.

9. If `3fa5e65` also stops at `/devkrnl`, build an instrumented package that
   prints the physical cluster address and read length before every kernel
   cluster read, then test after deleting and re-copying only `devkrnl` to
   change its FATX placement.

10. Test `xromwell-16788e0-devuan-daedalus-i386.zip` only if the casefold
   package reaches config detection.

   If `fe80736` boots but `16788e0` hangs, the bug is in the cluster-size,
   chain-table, or guarded-chain path before lazy caching was added.

## Reset Baseline, May 28

The probe series answered useful questions, but it also created too many
moving pieces for release prep. The current reset is to stop testing the
`xkrnl`/`xinit` probe packages as candidate releases and return to the exact
known-good Devuan desktop artifact line.

What changed across the three important states:

```text
Earlier snappy Devuan desktop:
  Package: artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386.zip
  XBE:     C78475E8713EC694F484C40209966805E9F9CD267E7C2EE6A3B9217E40FE0CD2
  Kernel:  D3C812196908F8F2CA96C7863184C59C39982E27A2DD1ED6DFF125D5DA9FCAFE devkrnl
  Initrd:  7CADFFDE0B78BA6C263DAD34B69862642A622A9491AD69B9CCFA1B40C0CF6CCB devinit
  Rootfs:  5F5DCEC72E2B0762ABF8790B5A58D383F51249AEA317394107BF7F804EAF1EB5 devuan.ext2
  Config:  BBC6D53EC8A72D2FCC7954610FFFC12D3AE14AE8F10B16958BD9705D2401C631 linuxboot.cfg

Slow/stuttery sector512 success checkpoint:
  Package: artifacts\audit\xromwell-3fa5e65-sector512-altname-devuan-daedalus-i386.zip
  XBE:     81B3A6850627A8BEC6FA0D92BB4652400DB3EC863072EAA7351BB159DED0BAFD
  Kernel:  same kernel bytes, renamed xkrnl
  Initrd:  same initrd bytes, renamed xinit
  Rootfs:  same rootfs bytes, renamed xdevuan.ext2
  Config:  same intent, but points at xkrnl/xinit/xdevuan.ext2
  Result:  booted on hardware, desktop lagged badly.

Perf/probe line:
  XBE:     progressively instrumented sector512/findsector/filesector builds
  Initrd:  changed to performance-probe initrd in perf1 packages
  Rootfs:  changed to performance-probe rootfs in perf1 packages
  Config:  added read-ahead and late-diagnostic flags
  Result:  useful diagnostics, not a stable release baseline.
```

The restored package is self-contained and intentionally uses the earlier
snappy line's file names and bytes:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386.zip
SHA256 3742B8EAD01EDD5697240B8DD1679A36B6FD83E8A7055901F82A86BE3FC8227A
Dashboard folder: E:\Apps\XromwellDevuanRestored4dcc618\
Root files: E:\linuxboot.cfg, E:\devkrnl, E:\devinit, E:\devuan.ext2
```

xemu proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\audit-restored-4dcc618-20260528-130956.png
```

Result: the restored package reaches the Devuan X desktop in xemu. The terminal
shows the expected tool list and read-ahead diagnostics. That validates the
package contents and boot config.

Hardware result: the restored package booted on the softmodded Xbox and
appears to work well. Treat it as the Devuan desktop release baseline.

Keep the probe zips only as audit checkpoints until we deliberately resume
loader debugging. The `xkrnl`/`xinit` line should not feed release-prep work.
Future network, persistence, and desktop performance work should build from
the restored `4dcc618`/`devkrnl`/`devinit`/`devuan.ext2` package unless a new
hardware result gives us a reason to move again.
