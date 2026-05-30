param(
    [string]$WslBuildRoot = "/home/paul/ogxbox/distro-build/devuan-daedalus-i386-desktop-full-root",
    [string]$SquashfsPath = "artifacts\hdd\xbox-devuan-daedalus-i386-desktop-full.squashfs",
    [string]$Compression = "gzip",
    [string]$BlockSize = "128K",
    [switch]$RebuildRoot,
    [switch]$ForceBootstrap
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$squashFull = Join-Path $repoRoot $SquashfsPath

function Convert-ToWslPath([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -lt 3 -or $full[1] -ne ':') {
        throw "Only drive-qualified Windows paths are supported: $Path"
    }
    $drive = $full[0].ToString().ToLowerInvariant()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

if ($RebuildRoot) {
    & (Join-Path $repoRoot 'scripts\build_devuan_daedalus_i386_desktop_full_payload.ps1') `
        -WslBuildRoot $WslBuildRoot `
        -ForceBootstrap:$ForceBootstrap
    if ($LASTEXITCODE -ne 0) {
        throw "Devuan full desktop root rebuild failed"
    }
}

$rootCheck = & wsl.exe -u root -e test -d $WslBuildRoot
if ($LASTEXITCODE -ne 0) {
    throw "Missing WSL build root: $WslBuildRoot. Re-run with -RebuildRoot."
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $squashFull) | Out-Null
if (Test-Path -LiteralPath $squashFull) {
    Remove-Item -LiteralPath $squashFull -Force
}

$squashWsl = Convert-ToWslPath $squashFull
$mksquashfs = & wsl.exe -u root -e bash -lc 'command -v mksquashfs'
if ($LASTEXITCODE -ne 0 -or -not $mksquashfs) {
    throw "mksquashfs is not available in WSL"
}

& wsl.exe -u root -e mksquashfs $WslBuildRoot $squashWsl -noappend -comp $Compression -b $BlockSize -no-xattrs -no-progress
if ($LASTEXITCODE -ne 0) {
    throw "mksquashfs failed"
}

Get-Item -LiteralPath $squashFull
