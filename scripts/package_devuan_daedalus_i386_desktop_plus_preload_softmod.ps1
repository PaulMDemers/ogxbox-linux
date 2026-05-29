param(
    [string]$OutRoot = "artifacts\softmod",
    [string]$XbePath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\default.xbe",
    [string]$KernelPath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\E-root\devkrnl",
    [string]$InitrdPath = "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline\E-root\devinit",
    [string]$PayloadPath = "artifacts\hdd\xbox-devuan-daedalus-i386-desktop-plus-preload.ext2",
    [int]$FatxReadAheadKb = 2048,
    [int]$RootReadAheadKb = 2048
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot "xromwell-hddfatx-devuan-daedalus-i386-sector512-desktop-plus-preload"
$outFull = Join-Path $repoRoot $outDir
$zip = "$outFull.zip"
$append = "init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/pldevuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_terminal_light=1 xbox_diag=off xbox_fluxbox_lite=1 xbox_preload_fluxbox=1 xbox_fatx_loop_readahead_kb=$FatxReadAheadKb xbox_loop_readahead_kb=$RootReadAheadKb"

& $packager `
    -OutDir $outDir `
    -XbePath $XbePath `
    -KernelPath $KernelPath `
    -KernelName 'plkrnl' `
    -InitrdPath $InitrdPath `
    -InitrdName 'plinit' `
    -PayloadPath $PayloadPath `
    -PayloadName 'pldevuan.ext2' `
    -Append $append `
    -PackageTitle 'Xromwell FATX Devuan Daedalus i386 Sector512 Desktop Plus Preload' `
    -DashboardFolder 'XromwellDevuanSector512DesktopPlusPreload' `
    -NoZip

$hashes = [ordered]@{
    'default.xbe' = (Get-FileHash -LiteralPath (Join-Path $outFull 'default.xbe') -Algorithm SHA256).Hash
    'E-root\plkrnl' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\plkrnl') -Algorithm SHA256).Hash
    'E-root\plinit' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\plinit') -Algorithm SHA256).Hash
    'E-root\pldevuan.ext2' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\pldevuan.ext2') -Algorithm SHA256).Hash
    'E-root\linuxboot.cfg' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\linuxboot.cfg') -Algorithm SHA256).Hash
}

@"
DEVUAN SECTOR512 DESKTOP PLUS PRELOAD
=====================================

Purpose:
  Runtime disk-path A/B package. TerminalFix proved terminal output can appear
  immediately, but real hardware still takes minutes for Fluxbox chrome and
  pointer responsiveness. Preload keeps FluxLite and sequentially reads the
  Fluxbox binary plus its shared-library closure before execing normal Fluxbox.

What changes:
  - Same sector512 default.xbe.
  - Same baseline kernel and initramfs bytes.
  - Same Xromwell loader path.
  - Updated desktop-plus root image with `xbox_preload_fluxbox=1` support.
  - Uses `xbox_diag=off`.
  - Uses `xbox_fluxbox_lite=1`.
  - Keeps stage1 read-ahead tuning:
      xbox_fatx_loop_readahead_kb=$FatxReadAheadKb
      xbox_loop_readahead_kb=$RootReadAheadKb
  - Uses isolated root filenames:
      E:\plkrnl
      E:\plinit
      E:\pldevuan.ext2

Copy to the Xbox:

  1. Copy this dashboard folder to:
       E:\Apps\XromwellDevuanSector512DesktopPlusPreload\

  2. Copy every file from this package's E-root\ folder to E:\:
       E:\linuxboot.cfg
       E:\plkrnl
       E:\plinit
       E:\pldevuan.ext2

Expected marker:

  XBOX_DEVUAN_DESKTOP_PLUS_OK

Recommended comparison:
  Compare against FluxLite. If random demand paging through the loop-mounted
  FATX root image is the bottleneck, this may spend a short time preloading
  and then make the toolbar/window chrome responsive sooner.

Logs:
  /tmp/xbox-plus-session.log lists the preloaded Fluxbox libraries.
  /tmp/fluxbox.log contains the Fluxbox process log.

Hashes:
  default.xbe:            $($hashes['default.xbe'])
  E-root\plkrnl:          $($hashes['E-root\plkrnl'])
  E-root\plinit:          $($hashes['E-root\plinit'])
  E-root\pldevuan.ext2:   $($hashes['E-root\pldevuan.ext2'])
  E-root\linuxboot.cfg:   $($hashes['E-root\linuxboot.cfg'])
"@ | Set-Content -LiteralPath (Join-Path $outFull 'COPY-ORDER.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
