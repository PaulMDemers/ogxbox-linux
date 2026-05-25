param(
    [string]$RawHdd = "run\hdd\xbox_hdd_hddboot.raw",
    [string]$KernelPath = "artifacts\kernels\xbox-linux-6.18.33-bzImage",
    [string]$InitrdPath = "artifacts\initramfs\xbox-busybox-console.cpio",
    [switch]$NoInitrd,
    [string]$Append = "init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7",
    [string]$Title = "Xbox HDD",
    [string]$PayloadPath,
    [string]$PayloadName = "linuxroot.ext2",
    [switch]$AppendPayloadInfo
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$rawHddFull = Join-Path $repoRoot $RawHdd
$kernelFull = Join-Path $repoRoot $KernelPath
$initrdFull = Join-Path $repoRoot $InitrdPath
$payloadFull = if ($PayloadPath) { Join-Path $repoRoot $PayloadPath } else { $null }

foreach ($path in @($rawHddFull, $kernelFull)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $path"
    }
}

$argsForPython = @(
    (Join-Path $repoRoot 'scripts\fatx_stage_boot.py'),
    $rawHddFull,
    '--kernel', $kernelFull,
    '--append', $Append,
    '--title', $Title
)

if (-not $NoInitrd) {
    if (-not (Test-Path -LiteralPath $initrdFull)) {
        throw "Missing required file: $initrdFull"
    }
    $argsForPython += @('--initrd', $initrdFull)
}

if ($PayloadPath) {
    if (-not (Test-Path -LiteralPath $payloadFull)) {
        throw "Missing required payload file: $payloadFull"
    }
    $argsForPython += @('--payload', $payloadFull, '--payload-name', $PayloadName)
    if ($AppendPayloadInfo) {
        $argsForPython += '--append-payload-info'
    }
}

python @argsForPython
