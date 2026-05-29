# Release Candidate, 2026-05-28

First public-test target:

```text
Tiny Core lean
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip
SHA256 17327756ed0cb274145cfdd974d119bef19db0f7588509726bb8c6bbfd4de866

Devuan terminal
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-terminal.zip
SHA256 7e7d36d4b4001157d7615ec5a94dbe1b56b15082e7f916e716629e44be9c9f28

Devuan desktop baseline
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-release-baseline.zip
SHA256 9C0A2362A6E4317DC6BEEB6651E9FD10AD09E029C7CD33D24BF5C0F61DB94D65
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
- Devuan desktop release-baseline boots on the softmodded Xbox and works well.
- Devuan networking appears to come up automatically during boot.
- HDMI/HDTV mode is shelved; AV/composite is the active reliable test path.

Release discipline:

- Install one Xromwell Linux profile at a time because `E:\linuxboot.cfg` is
  global.
- The Devuan desktop release candidate uses `devkrnl`, `devinit`, and
  `devuan.ext2`.
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
It keeps the release-baseline Xromwell/kernel/initrd lineage but uses isolated
root filenames (`pluskrnl`, `plusinit`, `plusdevuan.ext2`) and adds Fluxbox for
window decorations plus a bottom taskbar/menu.

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-desktop-plus.zip
SHA256 0064F7B12869F4CFF2365CF74BDAFEB9EB87D3D9C7A29537215F85D19A4C30B1
xemu proof: C:\Users\Paul\Desktop\xbox_linux\run\screenshots\devuan-desktop-plus-fluxbox-profile-libpath-proof-20260528-192631.png
```

Do not add desktop-plus to the public release candidate set until it has passed
real hardware.

May 28 hardware loader note: after desktop-plus testing, the same
release-baseline bytes also showed nondeterministic Xromwell FATX loader hangs
on the real Xbox, sometimes stopping at `Loading /devkrnl...` and sometimes
progressing further before retrying. This means the active problem is now the
real-hardware Xromwell FATX/IDE read path, not the Devuan rootfs or the
desktop-plus package contents.

Loader-only stability set:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\devuan-loader-stability-set.zip
SHA256 AF2E553D50D4C042A6F7C0105D2660E2A2471CEB6989B4B27EF426A117112F77
```

The stability set uses the exact release-baseline Devuan files in every
variant: `devkrnl`, `devinit`, `devuan.ext2`, and `linuxboot.cfg`. Only
`default.xbe` changes. Test `3fa5e65-sector512` first, then `3fa5e65-filesector`
if it still hangs and we need file-read tracing. Keep desktop/rootfs work frozen
until one loader is repeatable across several cold boots.
