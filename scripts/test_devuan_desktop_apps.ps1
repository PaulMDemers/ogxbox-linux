param(
    [string]$WslBuildRoot = "/home/paul/ogxbox/distro-build/devuan-daedalus-i386-desktop-full-root",
    [string]$ReportPath = "artifacts\reports\devuan-desktop-app-smoke.txt"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$reportFull = Join-Path $repoRoot $ReportPath
$scriptFull = Join-Path $repoRoot 'scripts\test_devuan_desktop_apps.sh'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFull) | Out-Null

function Convert-ToWslPath([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -lt 3 -or $full[1] -ne ':') {
        throw "Only drive-qualified Windows paths are supported: $Path"
    }
    $drive = $full[0].ToString().ToLowerInvariant()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

$scriptWsl = Convert-ToWslPath $scriptFull
$reportWsl = Convert-ToWslPath $reportFull

& wsl.exe -u root -e sh $scriptWsl $WslBuildRoot $reportWsl
if ($LASTEXITCODE -ne 0) {
    throw "Devuan desktop app smoke failed; see $reportFull"
}

Get-Item -LiteralPath $reportFull
