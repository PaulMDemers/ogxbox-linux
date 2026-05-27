# Release Prep 2026-05-26

This checkpoint starts shaping the first public test release around four
profiles, each with an ISO path and a softmod XBE/FATX zip path.

## Release-Candidate Artifacts

Tiny Core lean desktop:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33.iso
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip
```

Devuan Daedalus i386 terminal:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-devuan-daedalus-i386-terminal.iso
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-terminal.zip
```

Devuan Daedalus i386 desktop:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-devuan-daedalus-i386-desktop.iso
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386.zip
```

Devuan Daedalus i386 complete desktop:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-devuan-daedalus-i386-complete.iso
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-complete.zip
```

The release set should expose:

- Tiny Core lean desktop
- Devuan Daedalus i386 terminal
- Devuan Daedalus i386 desktop
- Devuan Daedalus i386 complete desktop

All four start network bring-up automatically during boot. The boot path does
not wait indefinitely on DHCP, so a missing cable or unavailable DHCP server
should not block the desktop or terminal.

The complete Devuan profile adds a small desktop toolkit on top of the
minimal desktop:

```text
dillo links2 xfe mc mtpaint gpicview xpdf wordgrinder sc
curl rsync openssh-client ftp netcat-openbsd jwm
```

It uses the same Tiny Core `Xfbdev` display stack, but starts `jwm` so the
applications are reachable from a right-click desktop menu.

## Network Helpers

Tiny Core ships a BusyBox/Tiny-Core style helper:

```text
/usr/local/bin/xbox-network-up
```

It brings `eth0` up and runs `udhcpc` when available. The log is:

```text
/tmp/xbox-network-up.txt
```

Devuan ships the Debian-family helper at the same path. It brings `eth0` up,
tries `ifup eth0`, then falls back to `dhclient` and `udhcpc` if needed. The
log is also:

```text
/tmp/xbox-network-up.txt
```

Expected real-hardware success marker:

```text
XBOX_NETWORK_DHCP_OK
```

The current xemu setup exposes `eth0` but reports `NO-CARRIER`, so xemu proves
that boot continues and the helper runs; a real Xbox is required for DHCP
pass/fail.

## xemu Proofs

ISO proofs:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\release-tinycore-iso-network-20260526-231819.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\release-devuan-terminal-iso-network-20260526-231349.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\release-devuan-desktop-iso-network-20260526-231622.png
```

Complete desktop proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\release-devuan-complete-network-printwindow-20260526-234850.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-nested-fatx-20260527-011856.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-root-kernel-nested-payload-20260527-013706.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-fatx-ci-xromwell-20260527-015756.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-fatx-lazy-chain-xromwell-20260527-021847.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-root-init-progress-final-20260527-124834.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-xromwell-1045ad9-final-20260527-130924.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xromwell-complete-62835f4-cached-table-12s-20260527-134907.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-complete-xromwell-62835f4-20260527-135137.png
```

Softmod/HDD-path proofs:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\release-tinycore-network-20260526-230238.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\release-devuan-terminal-network-20260526-230426.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\release-devuan-desktop-network-20260526-230629.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-minimal-rebuilt-xromwell-1045ad9-20260527-131602.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xromwell-62835f4-cached-table-12s-20260527-134628.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-minimal-xromwell-62835f4-20260527-134816.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xromwell-linux-only-autoboot-dirty-15s-20260527-141740.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-minimal-linux-only-autoboot-dirty-20260527-141926.png
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xromwell-3fa5e65-linux-only-autoboot-15s-20260527-142310.png
```

These proofs reach the intended terminal or desktop and show the automatic
network bring-up path. The emulator reports no carrier for `eth0`, as expected
for the current xemu network setup.

The `3fa5e65` Linux-only autoboot proof reaches the desktop and shows the new
checkpoint sequence after `linuxboot.cfg`: `FATX: parsed linuxboot.cfg`,
`AUTOBOOT: selected Linux`, `FATX: boot open E`, and
`FATX: loading kernel /devkrnl`. The `62835f4` complete run proves Xromwell
gets past the FATX loader, but the complete root currently falls back to the
console after a userspace `cat` segfault instead of reaching X; keep complete
behind minimal for real-hardware testing until that root-init path is checked
again.

## Filesystem Checks

```text
artifacts/hdd/xbox-tinycore-payload.ext2: 42/32768 files (0.0% non-contiguous), 6005/32768 blocks
artifacts/hdd/xbox-devuan-daedalus-i386.ext2: 9701/98304 files (0.1% non-contiguous), 71164/98304 blocks
artifacts/hdd/xbox-devuan-daedalus-i386-complete.ext2: 24054/49152 files (0.1% non-contiguous), 166290/196608 blocks
```

All listed images passed `e2fsck -fn`.

## Manifest And Checksums

The release artifact manifest and SHA256 sums are generated with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\write_release_manifest.ps1
```

Outputs:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\release\manifest.json
C:\Users\Paul\Desktop\xbox_linux\artifacts\release\SHA256SUMS.txt
```

## Install Caveat

The current Xromwell HDD packages still read the global FATX file:

```text
E:\linuxboot.cfg
```

That means the release zips are separate install profiles, not independent
simultaneously-selectable dashboard entries.

Tiny Core lean, Devuan terminal, and Devuan desktop copy their `E-root\`
contents to `E:\`.

The complete desktop zip is different because its ext2 image is much larger.
It keeps only the dashboard launcher under the app folder:

```text
E:\Apps\XromwellDevuanDaedalusComplete\default.xbe
```

Its `E-root\` contents are copied to `E:\`:

```text
E:\linuxboot.cfg
E:\devkrnl
E:\devinit
E:\LINUX\DEVUAN.EXT2
```

This avoids putting the 805 MB ext2 image as a root-level FATX file during
Xromwell's first `AUTOBOOT: FatX (E:)` lookup, while also avoiding nested
kernel/initrd loads in Xromwell. Xromwell loads the small root-level `devkrnl`
and `devinit`; Linux then opens `/LINUX/DEVUAN.EXT2` from the mounted FATX
partition. The current layout is xemu-proven by the
`devuan-complete-fatx-ci-xromwell` screenshot above.

The current softmod zips include Xromwell `3fa5e65`. It keeps
case-insensitive FATX path matching and replaces the failed eager 1.25 MiB
table read with a 4 KiB lazy chain-map page cache. This specifically targets
real Xbox E: partitions like the May 27 hardware photos that reported
`spc=2 csize=1024 table=1253376`: `5518ffc` walked the table one entry at a
time and was slow, while `1045ad9` tried to read the whole table up front and
stalled before printing `table read`. The expected line on that disk is now
`FATX: cached lazy table 1253376 page=4096 ...`. After `linuxboot.cfg` is
found, `3fa5e65` also skips the ReactOS FATX probe and goes straight to the
Linux loader.

If real hardware still stops before Linux, photograph the final `FATX:` line.
The matching xemu Xromwell proofs for the prior `1045ad9` build reached both
the rebuilt minimal Devuan desktop and the complete Devuan desktop, but xemu is
not a complete substitute for the real 1 KiB-cluster upgraded Xbox disk because
host storage hides much of the per-read cost.

The May 27 root-init refresh also prints the target root init before
`switch_root` and prints `XBOX_ROOT_INIT_STARTED` as the first visible line
inside `/xbox-init`. Early diagnostics now run in the background so a slow
`xbox-diag` pass cannot hide the first userspace marker.

The ISO profiles do not share this limitation because their `linuxboot.cfg`
and payload live on the disc image.
