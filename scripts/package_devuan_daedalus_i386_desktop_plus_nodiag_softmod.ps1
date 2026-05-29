param(
    [string]$OutRoot = "artifacts\softmod",
    [string]$XbePath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\default.xbe",
    [string]$KernelPath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\E-root\devkrnl",
    [string]$InitrdPath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\E-root\devinit",
    [string]$PayloadPath = "artifacts\hdd\xbox-devuan-daedalus-i386-desktop-plus.ext2"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot 'xromwell-hddfatx-devuan-daedalus-i386-sector512-desktop-plus-nodiag'
$outFull = Join-Path $repoRoot $outDir
$zip = "$outFull.zip"

& $packager `
    -OutDir $outDir `
    -XbePath $XbePath `
    -KernelPath $KernelPath `
    -KernelName 'ndkrnl' `
    -InitrdPath $InitrdPath `
    -InitrdName 'ndinit' `
    -PayloadPath $PayloadPath `
    -PayloadName 'nddevuan.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/nddevuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_terminal_light=1 xbox_diag=off' `
    -PackageTitle 'Xromwell FATX Devuan Daedalus i386 Sector512 Desktop Plus NoDiag' `
    -DashboardFolder 'XromwellDevuanSector512DesktopPlusNoDiag' `
    -NoZip

$hashes = [ordered]@{
    'default.xbe' = (Get-FileHash -LiteralPath (Join-Path $outFull 'default.xbe') -Algorithm SHA256).Hash
    'E-root\ndkrnl' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\ndkrnl') -Algorithm SHA256).Hash
    'E-root\ndinit' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\ndinit') -Algorithm SHA256).Hash
    'E-root\nddevuan.ext2' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\nddevuan.ext2') -Algorithm SHA256).Hash
    'E-root\linuxboot.cfg' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\linuxboot.cfg') -Algorithm SHA256).Hash
}

@"
DEVUAN SECTOR512 DESKTOP PLUS NODIAG
====================================

Purpose:
  This is the first runtime performance A/B package after the sector512
  desktop-plus package booted on real hardware but felt disk-bound after X
  started.

What changes from sector512 desktop-plus:
  - Same sector512 default.xbe.
  - Same baseline kernel and initramfs bytes.
  - Same desktop-plus root image bytes.
  - Different root filenames so it is self-contained:
      E:\ndkrnl
      E:\ndinit
      E:\nddevuan.ext2
  - `xbox_diag=off` so the delayed diagnostic helper does not contend with
    Fluxbox/aterm startup disk reads.

Copy to the Xbox:

  1. Copy this dashboard folder to:
       E:\Apps\XromwellDevuanSector512DesktopPlusNoDiag\

  2. Copy every file from this package's E-root\ folder to E:\:
       E:\linuxboot.cfg
       E:\ndkrnl
       E:\ndinit
       E:\nddevuan.ext2

Expected marker:

  XBOX_DEVUAN_DESKTOP_PLUS_OK

Recommended comparison:
  Boot this package immediately after the regular sector512 desktop-plus
  package and compare the time to first terminal paint and mouse stalls.
  Once it settles, run `xbox-perf` from the terminal.

Hashes:
  default.xbe:          $($hashes['default.xbe'])
  E-root\ndkrnl:       $($hashes['E-root\ndkrnl'])
  E-root\ndinit:       $($hashes['E-root\ndinit'])
  E-root\nddevuan.ext2: $($hashes['E-root\nddevuan.ext2'])
  E-root\linuxboot.cfg: $($hashes['E-root\linuxboot.cfg'])
"@ | Set-Content -LiteralPath (Join-Path $outFull 'COPY-ORDER.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
