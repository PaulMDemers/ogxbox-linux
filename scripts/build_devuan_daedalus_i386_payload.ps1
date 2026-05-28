param(
    [string]$Suite = "daedalus",
    [string]$Arch = "i386",
    [string]$Mirror = "https://pkgmaster.devuan.org/merged",
    [string]$WslBuildRoot = "/home/paul/ogxbox/distro-build/devuan-daedalus-i386-root",
    [string]$ImagePath = "artifacts\hdd\xbox-devuan-daedalus-i386.ext2",
    [int]$ImageSizeMiB = 384,
    [switch]$Desktop,
    [switch]$DesktopPlus,
    [switch]$CompleteDesktop,
    [switch]$ForceBootstrap
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$imageFull = Join-Path $repoRoot $ImagePath
$scriptFull = Join-Path $repoRoot 'scripts\build_devuan_daedalus_i386_payload.sh'

function Convert-ToWslPath([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -lt 3 -or $full[1] -ne ':') {
        throw "Only drive-qualified Windows paths are supported: $Path"
    }
    $drive = $full[0].ToString().ToLowerInvariant()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

$imageWsl = Convert-ToWslPath $imageFull
$scriptWsl = Convert-ToWslPath $scriptFull
$force = if ($ForceBootstrap) { "1" } else { "0" }
$desktopFlag = if ($Desktop -or $DesktopPlus -or $CompleteDesktop) { "1" } else { "0" }
$completeFlag = if ($CompleteDesktop) { "1" } else { "0" }
$desktopPlusFlag = if ($DesktopPlus) { "1" } else { "0" }
if (($Desktop -or $DesktopPlus -or $CompleteDesktop) -and $ImageSizeMiB -lt 384) {
    $ImageSizeMiB = 384
}
if ($DesktopPlus -and $ImageSizeMiB -lt 640) {
    $ImageSizeMiB = 640
}
if ($CompleteDesktop -and $ImageSizeMiB -lt 768) {
    $ImageSizeMiB = 768
}

& wsl.exe -u root -e bash $scriptWsl $WslBuildRoot $imageWsl $Suite $Arch $Mirror $ImageSizeMiB $force $desktopFlag $completeFlag $desktopPlusFlag
if ($LASTEXITCODE -ne 0) {
    throw "Devuan payload build failed"
}

Get-Item -LiteralPath $imageFull
