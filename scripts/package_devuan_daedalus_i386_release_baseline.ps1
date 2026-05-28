param(
    [string]$OutRoot = "artifacts\softmod"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot 'xromwell-hddfatx-devuan-daedalus-i386-release-baseline'
$outFull = Join-Path $repoRoot $outDir
$zip = "$outFull.zip"

& $packager `
    -OutDir $outDir `
    -XbePath 'artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386\default.xbe' `
    -KernelPath 'artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386\E-root\devkrnl' `
    -KernelName 'devkrnl' `
    -InitrdPath 'artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386\E-root\devinit' `
    -InitrdName 'devinit' `
    -PayloadPath 'artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386\E-root\devuan.ext2' `
    -PayloadName 'devuan.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/devuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0' `
    -PackageTitle 'Xromwell FATX Devuan Daedalus i386 Release Baseline' `
    -DashboardFolder 'XromwellDevuanRestored4dcc618' `
    -NoZip

@"
RESTORED DEVUAN RELEASE BASELINE
================================

This package rebuilds the exact hardware-passed Devuan desktop line from:

  artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386

Use this package to return E:\ to the read-only Devuan desktop baseline after
testing rw or diagnostic packages.

Copy to the Xbox:

  1. Copy this dashboard folder to:
       E:\Apps\XromwellDevuanRestored4dcc618\

  2. Delete experimental root files from E:\ if present:
       E:\rwkrnl
       E:\rwinit
       E:\rwdevuan.ext2
       E:\xkrnl
       E:\xinit
       E:\xdevuan.ext2

  3. Copy every file from this package's E-root\ folder to E:\:
       E:\linuxboot.cfg
       E:\devkrnl
       E:\devinit
       E:\devuan.ext2

Expected result:

  - Xromwell loads /devkrnl and /devinit
  - Devuan reaches the X desktop
  - networking may already be up by the time the desktop appears

Important:

  Keep this release baseline separate from rw smoke and diagnostic packages.
  Those packages now use their own kernel/initrd/root image names to avoid
  overwriting this known-good line.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'COPY-ORDER.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
