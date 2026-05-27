param(
    [string]$OutRoot = "artifacts\softmod",
    [string]$XbePath = "build\xromwell-hddfatx-autoboot-disc\default.xbe",
    [string]$KernelPath = "artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage",
    [string]$InitrdPath = "artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio",
    [string]$PayloadPath = "artifacts\hdd\xbox-devuan-daedalus-i386-complete.ext2",
    [string]$DashboardFolder = "XromwellDevuanDaedalusComplete"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outFull = Join-Path $repoRoot (Join-Path $OutRoot 'xromwell-hddfatx-devuan-daedalus-i386-complete')
$eRoot = Join-Path $outFull 'E-root'
$payloadRoot = Join-Path $eRoot 'LINUX'
$appRoot = Join-Path $outFull (Join-Path 'Apps' $DashboardFolder)
$zip = "$outFull.zip"

$xbeFull = Join-Path $repoRoot $XbePath
$kernelFull = Join-Path $repoRoot $KernelPath
$initrdFull = Join-Path $repoRoot $InitrdPath
$payloadFull = Join-Path $repoRoot $PayloadPath

foreach ($path in @($xbeFull, $kernelFull, $initrdFull, $payloadFull)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required artifact: $path"
    }
}

Remove-Item -Recurse -Force -LiteralPath $outFull -ErrorAction SilentlyContinue
Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $eRoot, $payloadRoot, $appRoot | Out-Null

Copy-Item -Force -LiteralPath $xbeFull -Destination (Join-Path $appRoot 'default.xbe')
Copy-Item -Force -LiteralPath $kernelFull -Destination (Join-Path $eRoot 'devkrnl')
Copy-Item -Force -LiteralPath $initrdFull -Destination (Join-Path $eRoot 'devinit')
Copy-Item -Force -LiteralPath $payloadFull -Destination (Join-Path $payloadRoot 'DEVUAN.EXT2')

$payloadPath = "/LINUX/DEVUAN.EXT2"
$append = "init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=$payloadPath xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0"

@"
title Xbox HDD
kernel devkrnl
initrd devinit
append $append
"@ | Set-Content -LiteralPath (Join-Path $eRoot 'linuxboot.cfg') -Encoding ASCII

@"
Xromwell FATX Devuan Daedalus i386 Complete Desktop Test
========================================================

This package keeps the large complete desktop payload inside E:\LINUX instead
of at E:\ root. Xromwell still loads only the small root-level kernel and
initrd files. Linux then mounts E: and loop-mounts E:\LINUX\DEVUAN.EXT2.
This avoids stressing Xromwell's first FATX root directory lookup with an
805 MB root-level devuan.ext2 entry. Current Xromwell builds also read very
large FATX chain maps lazily, which is important for upgraded Xbox disks whose
E: partition uses small clusters.

Copy to the Xbox:

  1. Copy Apps\$DashboardFolder\ to:
       E:\Apps\$DashboardFolder\

  2. Copy the contents of E-root\ to E:\:
       E:\linuxboot.cfg
       E:\devkrnl
       E:\devinit
       E:\LINUX\DEVUAN.EXT2

Dashboard app entry point:

  E:\Apps\$DashboardFolder\default.xbe

Expected Linux files:

  E:\devkrnl
  E:\devinit
  E:\LINUX\DEVUAN.EXT2

Expected proof marker:

  XBOX_DEVUAN_COMPLETE_DESKTOP_OK

Notes:

  - Xromwell still reads the global E:\linuxboot.cfg, so install one Xromwell
    Linux profile at a time.
  - The expected Xromwell banner revision for this package is 5518ffc or newer.
    On large/small-cluster E: partitions it should print a FATX lazy table
    progress line before loading linuxboot.cfg.
  - This is still experimental and should be tested from a backed-up softmod.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'README.txt') -Encoding ASCII

Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
