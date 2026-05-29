param(
    [string]$OutRoot = "artifacts\softmod",
    [string]$XbePath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\default.xbe",
    [string]$KernelPath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\E-root\devkrnl",
    [string]$InitrdPath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\E-root\devinit",
    [string]$PayloadPath = "artifacts\hdd\xbox-devuan-daedalus-i386-desktop-plus-fluxlite.ext2",
    [int]$FatxReadAheadKb = 2048,
    [int]$RootReadAheadKb = 2048
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot "xromwell-hddfatx-devuan-daedalus-i386-sector512-desktop-plus-fluxlite"
$outFull = Join-Path $repoRoot $outDir
$zip = "$outFull.zip"
$append = "init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/fldevuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_terminal_light=1 xbox_diag=off xbox_fluxbox_lite=1 xbox_fatx_loop_readahead_kb=$FatxReadAheadKb xbox_loop_readahead_kb=$RootReadAheadKb"

& $packager `
    -OutDir $outDir `
    -XbePath $XbePath `
    -KernelPath $KernelPath `
    -KernelName 'flkrnl' `
    -InitrdPath $InitrdPath `
    -InitrdName 'flinit' `
    -PayloadPath $PayloadPath `
    -PayloadName 'fldevuan.ext2' `
    -Append $append `
    -PackageTitle 'Xromwell FATX Devuan Daedalus i386 Sector512 Desktop Plus FluxLite' `
    -DashboardFolder 'XromwellDevuanSector512DesktopPlusFluxLite' `
    -NoZip

$hashes = [ordered]@{
    'default.xbe' = (Get-FileHash -LiteralPath (Join-Path $outFull 'default.xbe') -Algorithm SHA256).Hash
    'E-root\flkrnl' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\flkrnl') -Algorithm SHA256).Hash
    'E-root\flinit' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\flinit') -Algorithm SHA256).Hash
    'E-root\fldevuan.ext2' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\fldevuan.ext2') -Algorithm SHA256).Hash
    'E-root\linuxboot.cfg' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\linuxboot.cfg') -Algorithm SHA256).Hash
}

@"
DEVUAN SECTOR512 DESKTOP PLUS FLUXLITE
======================================

Purpose:
  Runtime A/B package for the slow Fluxbox chrome/taskbar startup. TerminalFix
  proved the terminal content can print immediately; this package keeps
  Fluxbox but uses a tiny generated style and delays the proof terminal by a
  few seconds so the window manager can initialize first.

What changes:
  - Same sector512 default.xbe.
  - Same baseline kernel and initramfs bytes.
  - Same Xromwell loader path.
  - Updated desktop-plus root image with `xbox_fluxbox_lite=1` support.
  - Uses `xbox_diag=off`.
  - Keeps stage1 read-ahead tuning:
      xbox_fatx_loop_readahead_kb=$FatxReadAheadKb
      xbox_loop_readahead_kb=$RootReadAheadKb
  - Uses isolated root filenames:
      E:\flkrnl
      E:\flinit
      E:\fldevuan.ext2

Copy to the Xbox:

  1. Copy this dashboard folder to:
       E:\Apps\XromwellDevuanSector512DesktopPlusFluxLite\

  2. Copy every file from this package's E-root\ folder to E:\:
       E:\linuxboot.cfg
       E:\flkrnl
       E:\flinit
       E:\fldevuan.ext2

Expected marker:

  XBOX_DEVUAN_DESKTOP_PLUS_OK

Recommended comparison:
  Compare against TerminalFix. Watch whether the Fluxbox toolbar/window chrome
  and mouse become responsive sooner, and whether the proof terminal appears
  decorated instead of drawing text before the chrome.

Hashes:
  default.xbe:            $($hashes['default.xbe'])
  E-root\flkrnl:          $($hashes['E-root\flkrnl'])
  E-root\flinit:          $($hashes['E-root\flinit'])
  E-root\fldevuan.ext2:   $($hashes['E-root\fldevuan.ext2'])
  E-root\linuxboot.cfg:   $($hashes['E-root\linuxboot.cfg'])
"@ | Set-Content -LiteralPath (Join-Path $outFull 'COPY-ORDER.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
