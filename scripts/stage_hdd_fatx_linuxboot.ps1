param(
    [string]$RawHdd = "run\hdd\xbox_hdd_hddboot.raw",
    [string]$KernelPath = "artifacts\kernels\xbox-linux-6.18.33-bzImage",
    [string]$InitrdPath = "artifacts\initramfs\xbox-busybox-console.cpio",
    [switch]$NoInitrd,
    [string]$Append = "init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7",
    [string]$Title = "Xbox HDD"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$rawHddFull = Join-Path $repoRoot $RawHdd
$kernelFull = Join-Path $repoRoot $KernelPath
$initrdFull = Join-Path $repoRoot $InitrdPath

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

python @argsForPython
