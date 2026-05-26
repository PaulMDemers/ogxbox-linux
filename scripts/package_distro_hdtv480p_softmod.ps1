param(
    [string]$OutRoot = "artifacts\softmod"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot 'xromwell-hddfatx-debian-bookworm-i386-hdtv480p'
$outFull = Join-Path $repoRoot $outDir
$zip = "$outFull.zip"

& $packager `
    -OutDir $outDir `
    -XbePath 'build\xromwell-hddfatx-autoboot-hdtv480p-disc\default.xbe' `
    -KernelPath 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' `
    -KernelName 'debkrnl' `
    -InitrdPath 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' `
    -InitrdName 'debinit' `
    -PayloadPath 'artifacts\hdd\xbox-debian-bookworm-i386.ext2' `
    -PayloadName 'debian.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/debian.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0' `
    -PackageTitle 'Xromwell FATX Debian Bookworm i386 HDTV 480p Test' `
    -DashboardFolder 'XromwellDebianBookwormHdtv480p' `
    -NoZip

@"
EXPERIMENTAL FORCED HDTV 480p XROMWELL BUILD
============================================

This package uses a Cromwell/Xromwell build compiled with:

  XBOX_FORCE_AV_HDTV_480P

It forces the Cromwell AV-pack mode to HDTV and uses the existing 480p HDTV
video path. This is intended for HDMI/component adapters that go blank when
Cromwell detects or initializes the cable as composite.

Keep the normal Debian package available as the recovery path:

  xromwell-hddfatx-debian-bookworm-i386.zip

This build may be blank on composite/AV cables. Test it as a separate dashboard
app, not as a replacement for the normal app.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'HDTV-480P-WARNING.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip

