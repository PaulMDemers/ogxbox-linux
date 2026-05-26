param(
    [string]$KernelPath = "artifacts\kernels\xbox-linux-6.18.33-fatx-rw-existing-bzImage",
    [string]$InitrdPath = "artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio",
    [string]$PayloadPath = "artifacts\hdd\xbox-debian-bookworm-i386.ext2"
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $repoRoot 'scripts\stage_hdd_fatx_linuxboot.ps1') `
    -KernelPath $KernelPath `
    -KernelName 'debkrnl' `
    -InitrdPath $InitrdPath `
    -InitrdName 'debinit' `
    -PayloadPath $PayloadPath `
    -PayloadName 'debian.ext2' `
    -Title 'Debian Bookworm rw persistence smoke' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/debian.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_fatx_mode=rw xbox_root_mode=rw xbox_persist_smoke=1'
