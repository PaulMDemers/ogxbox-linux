param(
    [string]$OutDir = "artifacts\softmod\xromwell-hddfatx-autoboot",
    [string]$XbePath = "build\xromwell-hddfatx-autoboot-disc\default.xbe",
    [string]$KernelPath = "artifacts\kernels\xbox-linux-6.18.33-bzImage",
    [string]$InitrdPath = "artifacts\initramfs\xbox-busybox-console.cpio",
    [string]$Append = "init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7",
    [string]$PayloadPath,
    [string]$PayloadName = "linuxroot.ext2",
    [string]$PackageTitle = "Xromwell FATX HDD Autoboot Test Package",
    [string]$DashboardFolder = "",
    [switch]$NoZip
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outFull = Join-Path $repoRoot $OutDir
$eRoot = Join-Path $outFull 'E-root'
$outLeaf = Split-Path -Leaf $outFull
$dashboardLeaf = if ($DashboardFolder) { $DashboardFolder } else { $outLeaf }
$xbeFull = Join-Path $repoRoot $XbePath
$kernelFull = Join-Path $repoRoot $KernelPath
$initrdFull = Join-Path $repoRoot $InitrdPath
$payloadFull = if ($PayloadPath) { Join-Path $repoRoot $PayloadPath } else { $null }

foreach ($path in @($xbeFull, $kernelFull, $initrdFull)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file was not found: $path"
    }
}
if ($PayloadPath -and -not (Test-Path -LiteralPath $payloadFull)) {
    throw "Required payload file was not found: $payloadFull"
}

Remove-Item -Recurse -Force -LiteralPath $outFull -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $outFull, $eRoot | Out-Null

Copy-Item -Force -LiteralPath $xbeFull -Destination (Join-Path $outFull 'default.xbe')
Copy-Item -Force -LiteralPath $kernelFull -Destination (Join-Path $eRoot 'vmlinuz')
Copy-Item -Force -LiteralPath $initrdFull -Destination (Join-Path $eRoot 'initramf')
if ($PayloadPath) {
    Copy-Item -Force -LiteralPath $payloadFull -Destination (Join-Path $eRoot $PayloadName)
}

@"
title Xbox HDD
kernel vmlinuz
initrd initramf
append $Append
"@ | Set-Content -LiteralPath (Join-Path $eRoot 'linuxboot.cfg') -Encoding ASCII

$requiredFiles = @(
    '    E:\linuxboot.cfg',
    '    E:\vmlinuz',
    '    E:\initramf'
)
$expected = @(
    '  Launching default.xbe should start Xromwell, read E:\linuxboot.cfg,',
    '  and load E:\vmlinuz and E:\initramf from FATX.'
)
if ($PayloadPath) {
    $requiredFiles += "    E:\$PayloadName"
    $expected += @(
        "  With E:\$PayloadName present, Linux mounts E: as FATX and",
        '  loop-mounts the Tiny Core payload by filename.'
    )
} else {
    $expected += '  This package should stop at the BusyBox proof shell.'
}

$payloadLine = if ($PayloadPath) { $PayloadPath } else { '(none)' }

@"
$PackageTitle
$('=' * $PackageTitle.Length)

This is an experimental Original Xbox Linux boot package for softmod testing.

Dashboard app folder:
  Copy this package folder to a dashboard apps location such as:
    E:\Apps\$dashboardLeaf\

  The app entry point is:
    E:\Apps\$dashboardLeaf\default.xbe

Required E: root payload files:
  Copy the contents of E-root\ to the Xbox E:\ root:
$($requiredFiles -join "`r`n")

Expected result:
$($expected -join "`r`n")

Current payload:
  Kernel:  $KernelPath
  Initrd:  $InitrdPath
  Payload: $payloadLine
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
