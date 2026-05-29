param(
    [string]$OutRoot = "artifacts\softmod",
    [string]$XbePath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\default.xbe",
    [string]$KernelPath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\E-root\devkrnl",
    [string]$InitrdPath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\E-root\devinit",
    [string]$PayloadPath = "artifacts\hdd\xbox-devuan-daedalus-i386-desktop-plus.ext2",
    [int]$FatxReadAheadKb = 2048,
    [int]$RootReadAheadKb = 2048
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot "xromwell-hddfatx-devuan-daedalus-i386-sector512-desktop-plus-nodiag-ra$FatxReadAheadKb"
$outFull = Join-Path $repoRoot $outDir
$zip = "$outFull.zip"
$append = "init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/rdevuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_terminal_light=1 xbox_diag=off xbox_fatx_loop_readahead_kb=$FatxReadAheadKb xbox_loop_readahead_kb=$RootReadAheadKb"

& $packager `
    -OutDir $outDir `
    -XbePath $XbePath `
    -KernelPath $KernelPath `
    -KernelName 'rakrnl' `
    -InitrdPath $InitrdPath `
    -InitrdName 'rainit' `
    -PayloadPath $PayloadPath `
    -PayloadName 'rdevuan.ext2' `
    -Append $append `
    -PackageTitle "Xromwell FATX Devuan Daedalus i386 Sector512 Desktop Plus NoDiag RA$FatxReadAheadKb" `
    -DashboardFolder "XromwellDevuanSector512DesktopPlusNoDiagRA$FatxReadAheadKb" `
    -NoZip

$hashes = [ordered]@{
    'default.xbe' = (Get-FileHash -LiteralPath (Join-Path $outFull 'default.xbe') -Algorithm SHA256).Hash
    'E-root\rakrnl' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\rakrnl') -Algorithm SHA256).Hash
    'E-root\rainit' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\rainit') -Algorithm SHA256).Hash
    'E-root\rdevuan.ext2' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\rdevuan.ext2') -Algorithm SHA256).Hash
    'E-root\linuxboot.cfg' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\linuxboot.cfg') -Algorithm SHA256).Hash
}

@"
DEVUAN SECTOR512 DESKTOP PLUS NODIAG RA$FatxReadAheadKb
=======================================================

Purpose:
  Runtime disk-read A/B package for the working sector512 desktop-plus line.
  This keeps Xromwell frozen and changes only the Linux command line plus
  package-local filenames.

What changes from sector512 desktop-plus NoDiag:
  - Same sector512 default.xbe.
  - Same baseline kernel and initramfs bytes.
  - Same desktop-plus root image bytes.
  - Same `xbox_diag=off`.
  - Adds stage1 read-ahead tuning:
      xbox_fatx_loop_readahead_kb=$FatxReadAheadKb
      xbox_loop_readahead_kb=$RootReadAheadKb
  - Uses isolated root filenames:
      E:\rakrnl
      E:\rainit
      E:\rdevuan.ext2

Copy to the Xbox:

  1. Copy this dashboard folder to:
       E:\Apps\XromwellDevuanSector512DesktopPlusNoDiagRA$FatxReadAheadKb\

  2. Copy every file from this package's E-root\ folder to E:\:
       E:\linuxboot.cfg
       E:\rakrnl
       E:\rainit
       E:\rdevuan.ext2

Expected marker:

  XBOX_DEVUAN_DESKTOP_PLUS_OK

Recommended comparison:
  Compare against the regular desktop-plus and NoDiag packages. Watch for
  terminal first-paint time and mouse stalls after X starts. Once settled, run
  `xbox-perf`; it should report loop read-ahead values if the kernel exposes
  them through sysfs.

Hashes:
  default.xbe:           $($hashes['default.xbe'])
  E-root\rakrnl:         $($hashes['E-root\rakrnl'])
  E-root\rainit:         $($hashes['E-root\rainit'])
  E-root\rdevuan.ext2:   $($hashes['E-root\rdevuan.ext2'])
  E-root\linuxboot.cfg:  $($hashes['E-root\linuxboot.cfg'])
"@ | Set-Content -LiteralPath (Join-Path $outFull 'COPY-ORDER.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
