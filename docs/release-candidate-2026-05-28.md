# Release Candidate, 2026-05-28

First public-test target:

```text
Tiny Core lean
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip
SHA256 17327756ed0cb274145cfdd974d119bef19db0f7588509726bb8c6bbfd4de866

Devuan terminal
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-terminal.zip
SHA256 7e7d36d4b4001157d7615ec5a94dbe1b56b15082e7f916e716629e44be9c9f28

Devuan desktop sector512 baseline
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline.zip
SHA256 E5347331F87448F5D081FB0576B0A9BD0E40D15E27865E1169577A22676CB2AC
```

Matching ISO artifacts:

```text
Tiny Core desktop ISO
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33.iso
SHA256 57485043745609f4ba0f34e5329a6d0fd885da3c12ab7c1e360afc665d925857

Devuan terminal ISO
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-devuan-daedalus-i386-terminal.iso
SHA256 4f85a1db344bb4be1e251bb6853ee895893e01653a611c919f5ac22a19104eb6

Devuan desktop ISO
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-devuan-daedalus-i386-desktop.iso
SHA256 4cdceee91327489554f13774c95c03e386aa20d66b5c338e43bb5772aabbb1e1
```

Current hardware status:

- Tiny Core lean boots and is the snappy Tiny Core target.
- Devuan desktop sector512 baseline boots on the softmodded Xbox and works
  well. This is the active Devuan desktop release candidate.
- Devuan networking appears to come up automatically during boot.
- HDMI/HDTV mode is shelved; AV/composite is the active reliable test path.

Release discipline:

- Install one Xromwell Linux profile at a time because `E:\linuxboot.cfg` is
  global.
- The Devuan desktop release candidate uses the sector512 Xromwell XBE with
  `devkrnl`, `devinit`, and `devuan.ext2`.
- The Devuan rw smoke package uses `rwkrnl`, `rwinit`, and `rwdevuan.ext2` so
  it cannot overwrite the release candidate files.
- The `xkrnl` and `xinit` packages are diagnostics only.

Before publishing, regenerate:

```powershell
.\scripts\write_release_manifest.ps1
```

Generated manifest files:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\release\manifest.json
C:\Users\Paul\Desktop\xbox_linux\artifacts\release\SHA256SUMS.txt
```

The next desktop milestone is now an experimental Devuan desktop-plus package.
It keeps the sector512 baseline Xromwell/kernel/initrd lineage but uses
isolated root filenames (`pkrnl`, `pinit`, `pdevuan.ext2`) and adds Fluxbox
for window decorations plus a bottom taskbar/menu.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-desktop-plus.zip
SHA256 9CB9A62D66A965AB6C37464DDF1E4445DAD0FD8D75ACEF0EF0062844F997ECAC
xemu userspace proof: C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-sector512-desktop-plus-userspace-xemu-20260529-134206.png
```

Do not add desktop-plus to the public release candidate set until it has passed
real hardware.

Note: the ad-hoc xemu DVD wrapper used for the exact sector512 `default.xbe`
does not pass the initrd in xemu and panics at `unknown-block(3,1)`, even for
the sector512 baseline. Treat that as an emulator wrapper limitation, not a
softmod package failure. The userspace proof above uses the established xemu
wrapper with the same kernel, initrd, append line, and desktop-plus root image.

May 28 hardware loader note: after desktop-plus testing, the same
release-baseline bytes also showed nondeterministic Xromwell FATX loader hangs
on the real Xbox, sometimes stopping at `Loading /devkrnl...` and sometimes
progressing further before retrying. This means the active problem is now the
real-hardware Xromwell FATX/IDE read path, not the Devuan rootfs or the
desktop-plus package contents.

Loader-only stability set:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\devuan-loader-stability-set.zip
SHA256 D97192D1061F88525FEDF1AEAD617847A2DA7D61FA3DB793E68E50E14E0C6060
```

The stability set uses the exact release-baseline Devuan files in every
variant: `devkrnl`, `devinit`, `devuan.ext2`, and `linuxboot.cfg`. Only
`default.xbe` changes. `3fa5e65-sector512` booted 4 out of 5 times on hardware;
the one failure stopped after `Loading /devkrnl...` before progress output. The
`ata-readsectors-filesector` follow-up still hung during the first `/devkrnl`
lookup at `FATX: find scan seek=devkrnl c=1`.

The noisy `idephase-readsectors-filesector` follow-up showed ATA `READ SECTORS`
commands completing through `linuxboot.cfg` lookup/read. The
`idephase-payload-readsectors` follow-up then showed `/devkrnl` lookup
succeeding and the first kernel data sector completing. The
`payload-progress-readsectors` package stopped at the first `/devkrnl` data
read region, while the verbose package had completed that same first sector.
The next test is `payload-settle-readsectors`, which keeps the same frozen
payload and adds a 1 ms settle delay plus retry/reporting around each
`devkrnl`/`devinit` sector read. Keep desktop/rootfs work frozen until one
loader is repeatable across several cold boots.

xemu sanity proof for `payload-settle-readsectors`:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-loader-payload-settle-xemu-20260529-121556.png
```

May 29 decision: `payload-settle-readsectors` failed at the same real-hardware
spot as `payload-progress-readsectors`. Stop advancing the `payload-*`,
`idephase-*`, and ATA timing experiment line. The useful split was earlier:
the `3fa5e65-sector512` XBE booted 4 out of 5 attempts because it uses the
older direct-autoboot lineage with conservative 512-byte FATX file reads,
where the release-baseline `4dcc618` XBE had added up-to-64 KiB coalesced FATX
file reads.

Rollback baseline for the next hardware pass:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline.zip
SHA256 E5347331F87448F5D081FB0576B0A9BD0E40D15E27865E1169577A22676CB2AC
Dashboard folder: E:\Apps\XromwellDevuanSector512Baseline\
XBE SHA256: 81B3A6850627A8BEC6FA0D92BB4652400DB3EC863072EAA7351BB159DED0BAFD
```

This package uses the 4/5 sector512 XBE with the restored release Devuan
payload hashes and normal root filenames: `devkrnl`, `devinit`, `devuan.ext2`,
and `linuxboot.cfg`. It passed xemu sanity:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-sector512-baseline-xemu-20260529-125306.png
```

Hardware result, May 29, 2026: this sector512 rollback package loaded on the
softmodded Xbox. It replaces the earlier `4dcc618` release-baseline package as
the active Devuan desktop release candidate. Keep the later loader stability
set only as diagnostic history.
