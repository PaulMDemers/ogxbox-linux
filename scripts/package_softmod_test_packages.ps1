param(
    [string]$OutRoot = "artifacts\softmod"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'

& $packager `
    -OutDir (Join-Path $OutRoot 'xromwell-hddfatx-busybox-smoke') `
    -KernelPath 'artifacts\kernels\xbox-linux-6.18.33-fatx-bzImage' `
    -InitrdPath 'artifacts\initramfs\xbox-busybox-console.cpio' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7' `
    -PackageTitle 'Xromwell FATX BusyBox Smoke Test' `
    -DashboardFolder 'XromwellBusyBoxSmoke'

& $packager `
    -OutDir (Join-Path $OutRoot 'xromwell-hddfatx-tinycore-fatx') `
    -KernelPath 'artifacts\kernels\xbox-linux-6.18.33-fatx-bzImage' `
    -InitrdPath 'artifacts\initramfs\xbox-tinycore-hdd-ext2-stage7-xfbdev-desktop.cpio' `
    -PayloadPath 'artifacts\hdd\xbox-tinycore-payload.ext2' `
    -PayloadName 'linuxroot.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7' `
    -PackageTitle 'Xromwell FATX Tiny Core Desktop Test' `
    -DashboardFolder 'XromwellTinyCoreFatx'

& $packager `
    -OutDir (Join-Path $OutRoot 'xromwell-hddfatx-tinycore-lean') `
    -KernelPath 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' `
    -InitrdPath 'artifacts\initramfs\xbox-tinycore-hdd-ext2-stage7-xfbdev-desktop.cpio' `
    -PayloadPath 'artifacts\hdd\xbox-tinycore-payload.ext2' `
    -PayloadName 'linuxroot.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7' `
    -PackageTitle 'Xromwell FATX Tiny Core Lean Kernel Test' `
    -DashboardFolder 'XromwellTinyCoreLean'
