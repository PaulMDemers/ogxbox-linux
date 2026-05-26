param(
    [string]$OutRoot = "artifacts\softmod"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'

& $packager `
    -OutDir (Join-Path $OutRoot 'xromwell-hddfatx-devuan-daedalus-i386') `
    -KernelPath 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' `
    -KernelName 'devkrnl' `
    -InitrdPath 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' `
    -InitrdName 'devinit' `
    -PayloadPath 'artifacts\hdd\xbox-devuan-daedalus-i386.ext2' `
    -PayloadName 'devuan.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/devuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0' `
    -PackageTitle 'Xromwell FATX Devuan Daedalus i386 X Desktop Test' `
    -DashboardFolder 'XromwellDevuanDaedalus'

