param(
    [string]$OutDir = "artifacts\release",
    [string[]]$ArtifactPaths = @(
        "artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33.iso",
        "artifacts\cromwell-devuan-daedalus-i386-terminal.iso",
        "artifacts\cromwell-devuan-daedalus-i386-desktop.iso",
        "artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip",
        "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-terminal.zip",
        "artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline.zip"
    )
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outFull = Join-Path $repoRoot $OutDir
New-Item -ItemType Directory -Force -Path $outFull | Out-Null

$entries = foreach ($rel in $ArtifactPaths) {
    $full = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) {
        Write-Warning "Skipping missing artifact: $rel"
        continue
    }
    $item = Get-Item -LiteralPath $full
    $hash = Get-FileHash -LiteralPath $full -Algorithm SHA256
    [pscustomobject]@{
        path = $rel.Replace('\', '/')
        bytes = $item.Length
        sha256 = $hash.Hash.ToLowerInvariant()
        last_write_utc = $item.LastWriteTimeUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
}

$manifestPath = Join-Path $outFull 'manifest.json'
$sumsPath = Join-Path $outFull 'SHA256SUMS.txt'

$entries | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $manifestPath -Encoding ASCII
$sumLines = $entries | ForEach-Object { "$($_.sha256)  $($_.path)" }
$sumLines | Set-Content -LiteralPath $sumsPath -Encoding ASCII

Get-Item -LiteralPath $manifestPath, $sumsPath
