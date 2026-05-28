param(
    [string]$OutRoot = "artifacts\softmod",
    [string]$XbePath = "artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386\default.xbe",
    [string]$KernelPath = "artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386\E-root\devkrnl",
    [string]$InitrdPath = "artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386\E-root\devinit",
    [string]$PayloadPath = "artifacts\hdd\xbox-devuan-daedalus-i386-desktop-plus.ext2"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot 'xromwell-hddfatx-devuan-daedalus-i386-desktop-plus'
$outFull = Join-Path $repoRoot $outDir
$zip = "$outFull.zip"

& $packager `
    -OutDir $outDir `
    -XbePath $XbePath `
    -KernelPath $KernelPath `
    -KernelName 'pluskrnl' `
    -InitrdPath $InitrdPath `
    -InitrdName 'plusinit' `
    -PayloadPath $PayloadPath `
    -PayloadName 'plusdevuan.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/plusdevuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_terminal_light=1 xbox_diag=late' `
    -PackageTitle 'Xromwell FATX Devuan Daedalus i386 Desktop Plus' `
    -DashboardFolder 'XromwellDevuanDesktopPlus' `
    -NoZip

@"
DEVUAN DESKTOP PLUS
===================

This is the next desktop experiment after the verified release baseline. It
keeps the known-good Xromwell, kernel, and stage1 initramfs, but uses a
separate root image with Fluxbox for a taskbar and menu.

Copy to the Xbox:

  1. Copy this dashboard folder to:
       E:\Apps\XromwellDevuanDesktopPlus\

  2. Copy every file from this package's E-root\ folder to E:\:
       E:\linuxboot.cfg
       E:\pluskrnl
       E:\plusinit
       E:\plusdevuan.ext2

Expected marker:

  XBOX_DEVUAN_DESKTOP_PLUS_OK

This package intentionally does not overwrite the release baseline files:

  E:\devkrnl
  E:\devinit
  E:\devuan.ext2

`E:\linuxboot.cfg` is still global, so restore it from the release-baseline
package when returning to the release candidate profile.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'COPY-ORDER.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
