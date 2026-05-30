param(
    [string]$OutDir = "build\xbox-linux-devuan-fluxlite-game-disc",
    [string]$OutputIso = "artifacts\xbox-linux-devuan-fluxlite-game-disc.iso",
    [string]$XbePath = "artifacts\softmod\xromwell-dvd-boot\default.xbe",
    [string]$KernelPath = "artifacts\kernels\xbox-linux-5.8.1-rd-gzip-bzImage",
    [string]$InitrdPath = "artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio",
    [string]$PayloadPath = "artifacts\hdd\xbox-devuan-daedalus-i386-desktop-plus-fluxlite.ext2"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outFull = Join-Path $repoRoot $OutDir
$isoFull = Join-Path $repoRoot $OutputIso
$xdvdfs = Join-Path $repoRoot 'tools\xdvdfs\xdvdfs.exe'

if (-not (Test-Path -LiteralPath $xdvdfs)) {
    throw "Missing required artifact: $xdvdfs"
}

foreach ($path in @($XbePath, $KernelPath, $InitrdPath, $PayloadPath)) {
    $full = Join-Path $repoRoot $path
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Missing required artifact: $full"
    }
}

if (Test-Path -LiteralPath $outFull) {
    Remove-Item -LiteralPath $outFull -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outFull | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $isoFull) | Out-Null

Copy-Item -Force -LiteralPath (Join-Path $repoRoot $XbePath) -Destination (Join-Path $outFull 'default.xbe')
Copy-Item -Force -LiteralPath (Join-Path $repoRoot $KernelPath) -Destination (Join-Path $outFull 'devkrnl')
Copy-Item -Force -LiteralPath (Join-Path $repoRoot $InitrdPath) -Destination (Join-Path $outFull 'devinit')
Copy-Item -Force -LiteralPath (Join-Path $repoRoot $PayloadPath) -Destination (Join-Path $outFull 'devuan.ext2')

$cfg = @"
title Xbox Linux Devuan FluxLite Game Disc
kernel devkrnl
initrd devinit
append init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_source=iso xbox_payload_file=/devuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_terminal_light=1 xbox_diag=off xbox_fluxbox_lite=1 xbox_fatx_loop_readahead_kb=2048 xbox_loop_readahead_kb=2048
"@
$cfg | Set-Content -LiteralPath (Join-Path $outFull 'linuxboot.cfg') -Encoding ASCII

$readme = @"
# Xbox Linux Devuan FluxLite Game Disc

This is an Xbox XDVDFS disc image with default.xbe at the disc root, intended to
test whether a chipped/BIOS-launched Xbox can start Xromwell directly from a
DVD-R as if it were a game disc.

Root files:

default.xbe
linuxboot.cfg
devkrnl
devinit
devuan.ext2

Important: this is different from the normal Cromwell Linux ISO9660 disc. The
current Cromwell CD loader is known to read ISO9660. This artifact tests whether
the XBE launch path works and whether Xromwell can still discover the Linux
payload from the same XDVDFS disc.
"@
$readme | Set-Content -LiteralPath (Join-Path $outFull 'README.txt') -Encoding ASCII

if (Test-Path -LiteralPath $isoFull) {
    Remove-Item -LiteralPath $isoFull -Force
}
$packOutput = & $xdvdfs pack $outFull $isoFull 2>&1
$packOutput | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    throw "xdvdfs pack failed"
}

$extentArgs = @()
foreach ($line in $packOutput) {
    if ($line -match 'Added file: ".+\\([^\\"]+)" at sector ([0-9]+)') {
        $name = $Matches[1]
        $sector = [int]$Matches[2]
        $size = (Get-Item -LiteralPath (Join-Path $outFull $name)).Length
        $extentArgs += @('--extent', "${name}=${sector}:$size")
    }
}
if (($extentArgs -join ' ') -notmatch 'linuxboot\.cfg') {
    throw "Could not derive linuxboot.cfg sector from xdvdfs output"
}
python (Join-Path $repoRoot 'scripts\add_iso9660_overlay.py') $isoFull @extentArgs
if ($LASTEXITCODE -ne 0) {
    throw "ISO9660 overlay failed"
}

$hashes = [ordered]@{}
foreach ($file in @('default.xbe', 'linuxboot.cfg', 'devkrnl', 'devinit', 'devuan.ext2')) {
    $hashes[$file] = (Get-FileHash -LiteralPath (Join-Path $outFull $file) -Algorithm SHA256).Hash
}
$manifest = [ordered]@{
    output_iso = $isoFull
    staging_dir = $outFull
    format = 'XDVDFS with minimal ISO9660 overlay'
    purpose = 'Xbox game-disc style Xromwell launch plus Cromwell ISO9660 payload test'
    files = $hashes
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outFull 'manifest.json') -Encoding ASCII

Get-Item -LiteralPath $isoFull, (Join-Path $outFull 'default.xbe'), (Join-Path $outFull 'linuxboot.cfg'), (Join-Path $outFull 'manifest.json')
