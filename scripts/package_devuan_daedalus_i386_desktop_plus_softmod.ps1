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
$outDir = Join-Path $OutRoot 'xromwell-hddfatx-devuan-daedalus-i386-sector512-desktop-plus'
$outFull = Join-Path $repoRoot $outDir
$zip = "$outFull.zip"

& $packager `
    -OutDir $outDir `
    -XbePath $XbePath `
    -KernelPath $KernelPath `
    -KernelName 'pkrnl' `
    -InitrdPath $InitrdPath `
    -InitrdName 'pinit' `
    -PayloadPath $PayloadPath `
    -PayloadName 'pdevuan.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/pdevuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_terminal_light=1 xbox_diag=late' `
    -PackageTitle 'Xromwell FATX Devuan Daedalus i386 Sector512 Desktop Plus' `
    -DashboardFolder 'XromwellDevuanSector512DesktopPlus' `
    -NoZip

$hashes = [ordered]@{
    'default.xbe' = (Get-FileHash -LiteralPath (Join-Path $outFull 'default.xbe') -Algorithm SHA256).Hash
    'E-root\pkrnl' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\pkrnl') -Algorithm SHA256).Hash
    'E-root\pinit' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\pinit') -Algorithm SHA256).Hash
    'E-root\pdevuan.ext2' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\pdevuan.ext2') -Algorithm SHA256).Hash
    'E-root\linuxboot.cfg' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\linuxboot.cfg') -Algorithm SHA256).Hash
}

@"
DEVUAN SECTOR512 DESKTOP PLUS
=============================

This is the next desktop experiment after the verified release baseline. It
keeps the sector512 Xromwell loader, release kernel, and release stage1
initramfs, but uses a separate root image with Fluxbox for a taskbar and menu.

Copy to the Xbox:

  1. Copy this dashboard folder to:
       E:\Apps\XromwellDevuanSector512DesktopPlus\

  2. Copy every file from this package's E-root\ folder to E:\:
       E:\linuxboot.cfg
       E:\pkrnl
       E:\pinit
       E:\pdevuan.ext2

Expected marker:

  XBOX_DEVUAN_DESKTOP_PLUS_OK

This package intentionally does not overwrite the release baseline files:

  E:\devkrnl
  E:\devinit
  E:\devuan.ext2

`E:\linuxboot.cfg` is still global, so restore it from the sector512 baseline
package when returning to the release candidate profile.

Hashes:
  default.xbe:          $($hashes['default.xbe'])
  E-root\pkrnl:        $($hashes['E-root\pkrnl'])
  E-root\pinit:        $($hashes['E-root\pinit'])
  E-root\pdevuan.ext2: $($hashes['E-root\pdevuan.ext2'])
  E-root\linuxboot.cfg:   $($hashes['E-root\linuxboot.cfg'])
"@ | Set-Content -LiteralPath (Join-Path $outFull 'COPY-ORDER.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
