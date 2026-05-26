param(
    [string]$Suite = "daedalus",
    [string]$Arch = "i386",
    [string]$Mirror = "https://pkgmaster.devuan.org/merged",
    [string]$WslBuildRoot = "/home/paul/ogxbox/distro-build/devuan-daedalus-i386-root",
    [string]$ImagePath = "artifacts\hdd\xbox-devuan-daedalus-i386.ext2",
    [int]$ImageSizeMiB = 384,
    [switch]$Desktop,
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
$desktopFlag = if ($Desktop) { "1" } else { "0" }
if ($Desktop -and $ImageSizeMiB -lt 384) {
    $ImageSizeMiB = 384
}

& wsl.exe -u root -e bash $scriptWsl $WslBuildRoot $imageWsl $Suite $Arch $Mirror $ImageSizeMiB $force $desktopFlag
if ($LASTEXITCODE -ne 0) {
    throw "Devuan payload build failed"
}

Get-Item -LiteralPath $imageFull

