param(
    [string]$KernelPath = "artifacts\kernels\xbox-linux-6.18.33-fatx-rw-existing-bzImage",
    [string]$InitrdPath = "artifacts\initramfs\xbox-fatx-write-smoke.cpio",
    [string]$TestFilePath = "artifacts\fatx-write-smoke\fatxrw.bin",
    [string]$Marker = "FATX_WRITE_EXISTING_OK_20260525"
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testFileFullPath = Join-Path $repoRoot $TestFilePath

New-Item -ItemType Directory -Force (Split-Path -Parent $testFileFullPath) | Out-Null
$initial = [Text.Encoding]::ASCII.GetBytes('FATX_WRITE_INITIAL_' + ('-' * 100))
[IO.File]::WriteAllBytes($testFileFullPath, $initial)

& (Join-Path $repoRoot 'scripts\stage_hdd_fatx_linuxboot.ps1') `
    -KernelPath $KernelPath `
    -KernelName 'vmlinuz' `
    -InitrdPath $InitrdPath `
    -InitrdName 'initramf' `
    -PayloadPath $TestFilePath `
    -PayloadName 'fatxrw.bin' `
    -Title 'FATX rw existing smoke' `
    -Append "init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 fatx_test_file=/fatxrw.bin fatx_test_marker=$Marker"
