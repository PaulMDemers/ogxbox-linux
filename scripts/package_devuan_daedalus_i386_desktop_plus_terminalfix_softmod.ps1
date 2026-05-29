param(
    [string]$OutRoot = "artifacts\softmod",
    [string]$XbePath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\default.xbe",
    [string]$KernelPath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\E-root\devkrnl",
    [string]$InitrdPath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\E-root\devinit",
    [string]$PayloadPath = "artifacts\hdd\xbox-devuan-daedalus-i386-desktop-plus-terminalfix.ext2",
    [int]$FatxReadAheadKb = 2048,
    [int]$RootReadAheadKb = 2048
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot "xromwell-hddfatx-devuan-daedalus-i386-sector512-desktop-plus-terminalfix"
$outFull = Join-Path $repoRoot $outDir
$zip = "$outFull.zip"
$append = "init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/tfdevuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_terminal_light=1 xbox_diag=off xbox_fatx_loop_readahead_kb=$FatxReadAheadKb xbox_loop_readahead_kb=$RootReadAheadKb"

& $packager `
    -OutDir $outDir `
    -XbePath $XbePath `
    -KernelPath $KernelPath `
    -KernelName 'tfkrnl' `
    -InitrdPath $InitrdPath `
    -InitrdName 'tfinit' `
    -PayloadPath $PayloadPath `
    -PayloadName 'tfdevuan.ext2' `
    -Append $append `
    -PackageTitle 'Xromwell FATX Devuan Daedalus i386 Sector512 Desktop Plus TerminalFix' `
    -DashboardFolder 'XromwellDevuanSector512DesktopPlusTerminalFix' `
    -NoZip

$hashes = [ordered]@{
    'default.xbe' = (Get-FileHash -LiteralPath (Join-Path $outFull 'default.xbe') -Algorithm SHA256).Hash
    'E-root\tfkrnl' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\tfkrnl') -Algorithm SHA256).Hash
    'E-root\tfinit' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\tfinit') -Algorithm SHA256).Hash
    'E-root\tfdevuan.ext2' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\tfdevuan.ext2') -Algorithm SHA256).Hash
    'E-root\linuxboot.cfg' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\linuxboot.cfg') -Algorithm SHA256).Hash
}

@"
DEVUAN SECTOR512 DESKTOP PLUS TERMINALFIX
=========================================

Purpose:
  Runtime A/B package for the desktop-plus black-terminal issue. The previous
  desktop-plus and NoDiag/RA packages reached X and opened the first terminal
  window, but the window stayed black. This package rebuilds only the Devuan
  root image so Fluxbox starts terminals through small helper scripts and the
  existing xterm/aterm wrapper.

What changes:
  - Same sector512 default.xbe.
  - Same baseline kernel and initramfs bytes.
  - Same Xromwell loader path.
  - Uses an updated desktop-plus root image.
  - Uses `xbox_diag=off`.
  - Keeps stage1 read-ahead tuning:
      xbox_fatx_loop_readahead_kb=$FatxReadAheadKb
      xbox_loop_readahead_kb=$RootReadAheadKb
  - Uses isolated root filenames:
      E:\tfkrnl
      E:\tfinit
      E:\tfdevuan.ext2

Copy to the Xbox:

  1. Copy this dashboard folder to:
       E:\Apps\XromwellDevuanSector512DesktopPlusTerminalFix\

  2. Copy every file from this package's E-root\ folder to E:\:
       E:\linuxboot.cfg
       E:\tfkrnl
       E:\tfinit
       E:\tfdevuan.ext2

Expected marker:

  XBOX_DEVUAN_DESKTOP_PLUS_OK

If the window still stays black:
  Reboot into a shell-capable package and inspect these files inside this root
  image, or preserve them for the next diagnostic package:
    /tmp/aterm.log
    /tmp/xbox-plus-session.log
    /tmp/xsession.log
    /tmp/fluxbox.log

Hashes:
  default.xbe:            $($hashes['default.xbe'])
  E-root\tfkrnl:          $($hashes['E-root\tfkrnl'])
  E-root\tfinit:          $($hashes['E-root\tfinit'])
  E-root\tfdevuan.ext2:   $($hashes['E-root\tfdevuan.ext2'])
  E-root\linuxboot.cfg:   $($hashes['E-root\linuxboot.cfg'])
"@ | Set-Content -LiteralPath (Join-Path $outFull 'COPY-ORDER.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
