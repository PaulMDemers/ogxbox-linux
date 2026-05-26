param(
    [string]$OutRoot = "artifacts\softmod"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'

& $packager `
    -OutDir (Join-Path $OutRoot 'xromwell-hddfatx-debian-bookworm-i386') `
    -KernelPath 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' `
    -KernelName 'debkrnl' `
    -InitrdPath 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' `
    -InitrdName 'debinit' `
    -PayloadPath 'artifacts\hdd\xbox-debian-bookworm-i386.ext2' `
    -PayloadName 'debian.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/debian.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0' `
    -PackageTitle 'Xromwell FATX Debian Bookworm i386 X Desktop Test' `
    -DashboardFolder 'XromwellDebianBookworm'
