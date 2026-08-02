param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$buildRoot = Join-Path $repoRoot 'build'

$targets = @(
    (Join-Path $buildRoot 'release-rev-2026-06-06'),
    (Join-Path $buildRoot 'release-rev-2026-06-12'),
    (Join-Path $buildRoot 'layout-probe'),
    (Join-Path $buildRoot 'layout-probe-names'),
    (Join-Path $repoRoot 'scripts\__pycache__')
)

if (Test-Path -LiteralPath $buildRoot) {
    $targets += Get-ChildItem -LiteralPath $buildRoot -Force |
        Where-Object { $_.Name -like 'xdvdfs-layout-probe*' } |
        Select-Object -ExpandProperty FullName
}

$targets += Get-ChildItem -LiteralPath $repoRoot -Force -File |
    Where-Object { $_.Name -like '%ln*' } |
    Select-Object -ExpandProperty FullName

$repoFull = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\') + '\'
$existing = @()
foreach ($target in ($targets | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $target)) {
        continue
    }

    $resolved = (Resolve-Path -LiteralPath $target).Path
    if (-not ($resolved + '\').StartsWith($repoFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to touch path outside the workspace: $resolved"
    }

    $item = Get-Item -LiteralPath $resolved -Force
    $bytes = if ($item.PSIsContainer) {
        [int64](Get-ChildItem -LiteralPath $resolved -Recurse -Force -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    } else {
        [int64]$item.Length
    }

    $existing += [pscustomobject]@{
        Path = $resolved
        Bytes = $bytes
        MiB = [math]::Round($bytes / 1MB, 1)
    }
}

$existing | Sort-Object Path | Format-Table -AutoSize
$totalBytes = [int64]($existing | Measure-Object -Property Bytes -Sum).Sum
Write-Output ("Total selected: {0:N1} MiB" -f ($totalBytes / 1MB))

if (-not $Apply) {
    Write-Output 'Dry run only. Pass -Apply to remove these generated paths.'
    exit 0
}

foreach ($entry in $existing) {
    $item = Get-Item -LiteralPath $entry.Path -Force
    if ($item.PSIsContainer) {
        Remove-Item -LiteralPath $entry.Path -Recurse -Force
    } else {
        Remove-Item -LiteralPath $entry.Path -Force
    }
}

Write-Output ("Removed {0:N1} MiB of generated workspace data." -f ($totalBytes / 1MB))
