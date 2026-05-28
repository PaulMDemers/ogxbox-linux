param(
    [string]$Suite = "daedalus",
    [string]$Arch = "i386",
    [string]$Mirror = "https://pkgmaster.devuan.org/merged",
    [string]$WslBuildRoot = "/home/paul/ogxbox/distro-build/devuan-daedalus-i386-desktop-plus-root",
    [string]$ImagePath = "artifacts\hdd\xbox-devuan-daedalus-i386-desktop-plus.ext2",
    [int]$ImageSizeMiB = 640,
    [switch]$ForceBootstrap
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$builder = Join-Path $repoRoot 'scripts\build_devuan_daedalus_i386_payload.ps1'

& $builder `
    -Suite $Suite `
    -Arch $Arch `
    -Mirror $Mirror `
    -WslBuildRoot $WslBuildRoot `
    -ImagePath $ImagePath `
    -ImageSizeMiB $ImageSizeMiB `
    -DesktopPlus `
    -ForceBootstrap:$ForceBootstrap
