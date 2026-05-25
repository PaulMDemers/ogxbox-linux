param(
    [string]$OutDir = "artifacts\softmod\xromwell-hddfatx-autoboot",
    [string]$XbePath = "build\xromwell-hddfatx-autoboot-disc\default.xbe",
    [string]$KernelPath = "artifacts\kernels\xbox-linux-6.18.33-bzImage",
    [string]$InitrdPath = "artifacts\initramfs\xbox-busybox-console.cpio",
    [string]$Append = "init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7",
    [switch]$NoZip
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outFull = Join-Path $repoRoot $OutDir
$eRoot = Join-Path $outFull 'E-root'
$xbeFull = Join-Path $repoRoot $XbePath
$kernelFull = Join-Path $repoRoot $KernelPath
$initrdFull = Join-Path $repoRoot $InitrdPath

foreach ($path in @($xbeFull, $kernelFull, $initrdFull)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file was not found: $path"
    }
}

Remove-Item -Recurse -Force -LiteralPath $outFull -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $outFull, $eRoot | Out-Null

Copy-Item -Force -LiteralPath $xbeFull -Destination (Join-Path $outFull 'default.xbe')
Copy-Item -Force -LiteralPath $kernelFull -Destination (Join-Path $eRoot 'vmlinuz')
Copy-Item -Force -LiteralPath $initrdFull -Destination (Join-Path $eRoot 'initramf')

@"
title Xbox HDD
kernel vmlinuz
initrd initramf
append $Append
"@ | Set-Content -LiteralPath (Join-Path $eRoot 'linuxboot.cfg') -Encoding ASCII

@"
Xromwell FATX HDD Autoboot Test Package
=======================================

This is an experimental Original Xbox Linux boot package for softmod testing.

Dashboard app folder:
  Copy this package folder to a dashboard apps location such as:
    E:\Apps\XromwellHddFatx\

  The app entry point is:
    E:\Apps\XromwellHddFatx\default.xbe

Required E: root payload files:
  Copy the contents of E-root\ to the Xbox E:\ root:
    E:\linuxboot.cfg
    E:\vmlinuz
    E:\initramf

Expected result:
  Launching default.xbe should start Xromwell, read E:\linuxboot.cfg, load
  E:\vmlinuz and E:\initramf from FATX, and enter the BusyBox proof shell.

Current payload:
  Kernel:  $KernelPath
  Initrd:  $InitrdPath
  Append:  $Append

Notes:
  - Test on a backed-up softmod setup first.
  - These root filenames are simple on purpose; do not overwrite unrelated
    files with the same names unless you intend to.
  - xemu proof for this path is documented in docs\hdd-fatx-boot.md.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'README.txt') -Encoding ASCII

if (-not $NoZip) {
    $zip = "$outFull.zip"
    Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
    Get-Item -LiteralPath $outFull, $zip
} else {
    Get-Item -LiteralPath $outFull
}
