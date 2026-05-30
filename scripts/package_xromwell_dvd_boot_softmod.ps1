param(
    [string]$OutDir = "artifacts\softmod\xromwell-dvd-boot",
    [string]$OutZip = "artifacts\softmod\xromwell-dvd-boot.zip"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outFull = Join-Path $repoRoot $OutDir
$zipFull = Join-Path $repoRoot $OutZip
$launcherScript = Join-Path $repoRoot 'scripts\build_xromwell_xbe_launcher.ps1'

if (Test-Path -LiteralPath $outFull) {
    Remove-Item -LiteralPath $outFull -Recurse -Force
}

& powershell -ExecutionPolicy Bypass -File $launcherScript `
    -OutDir $OutDir `
    -OutIso "artifacts\xromwell-dvd-boot-wrapper.iso"

$xbe = Join-Path $outFull 'default.xbe'
if (-not (Test-Path -LiteralPath $xbe)) {
    throw "DVD launcher build did not produce: $xbe"
}

$hash = (Get-FileHash -LiteralPath $xbe -Algorithm SHA256).Hash
$readme = @"
# Xromwell DVD Boot Launcher

Copy this folder to the Xbox as a softmod app, for example:

E:\Apps\XromwellDVD\default.xbe

Use this launcher with a burned Cromwell/Linux ISO in the DVD drive. This is not
the HDD-FATX autoboot launcher; it is intentionally built without
XBOX_LINUX_AUTOBOOT_FATX so it should not force AUTOBOOT FATX (E:).

Before testing DVD boot, remove any old root-level Linux FATX boot files from
E:\, especially:

E:\linuxboot.cfg
E:\*krnl
E:\*init
E:\*devuan.ext2

The dashboard app folder can stay. The important part is that E:\linuxboot.cfg
must not exist, because Xromwell may select the old FATX profile before trying
the DVD.

Current DVD test ISO:

C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-devuan-daedalus-i386-desktop-plus-fluxlite.iso

default.xbe SHA256:

$hash
"@
$readme | Set-Content -LiteralPath (Join-Path $outFull 'README.txt') -Encoding ASCII

if (Test-Path -LiteralPath $zipFull) {
    Remove-Item -LiteralPath $zipFull -Force
}
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zipFull -Force

Get-Item -LiteralPath $xbe, (Join-Path $outFull 'README.txt'), $zipFull
