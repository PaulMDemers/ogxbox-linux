[CmdletBinding()]
param(
    [string]$SquashfsPath = 'artifacts\devuan-5.8.1-desktop-candidate\devuan-daedalus-desktop-live-5.8.1-candidate\E-root\devuan.squashfs',
    [string]$ReportPath = 'artifacts\reports\devuan-5.8.1-desktop-candidate-audit.txt',
    [string]$WslScratchRoot = '/tmp/ogxbox-devuan-5.8.1-desktop-audit'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$squashfsFull = Join-Path $repoRoot $SquashfsPath
$reportFull = Join-Path $repoRoot $ReportPath
$auditFull = Join-Path $repoRoot 'scripts\audit_devuan_desktop_payload.sh'
$smokeFull = Join-Path $repoRoot 'scripts\test_devuan_desktop_apps.sh'

function Convert-ToWslPath([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -lt 3 -or $full[1] -ne ':') {
        throw "Only drive-qualified Windows paths are supported: $Path"
    }
    $drive = $full[0].ToString().ToLowerInvariant()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

foreach ($path in @($squashfsFull, $auditFull, $smokeFull)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file was not found: $path"
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFull) | Out-Null
$squashfsHash = (Get-FileHash -LiteralPath $squashfsFull -Algorithm SHA256).Hash

& wsl.exe -u root -e sh `
    (Convert-ToWslPath $auditFull) `
    (Convert-ToWslPath $squashfsFull) `
    $WslScratchRoot `
    (Convert-ToWslPath $reportFull) `
    (Convert-ToWslPath $smokeFull)
if ($LASTEXITCODE -ne 0) {
    throw "Exact Devuan desktop payload audit failed; see $reportFull"
}

@("", "squashfs-sha256=$squashfsHash") | Add-Content -LiteralPath $reportFull -Encoding ASCII
Get-Item -LiteralPath $reportFull | Select-Object FullName, Length, LastWriteTime
