[CmdletBinding()]
param(
    [string]$OutRoot = 'artifacts\tinycore-hdd-ui-first-candidates',
    [ValidateRange(128, 4096)]
    [int]$DiskReadAheadKb = 1024
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$builder = Join-Path $repoRoot 'scripts\new_tinycore_hdd_ra128_candidate.ps1'
$outFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts')).TrimEnd('\') + '\'

if (-not $outFull.StartsWith($artifactsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Candidate output must be a child of ${artifactsRoot}: $outFull"
}

New-Item -ItemType Directory -Force -Path $outFull | Out-Null
$variants = @(
    [ordered]@{ name = 'ra128'; readAheadKb = 128 },
    [ordered]@{ name = 'ra1024'; readAheadKb = 1024 }
)
$built = [System.Collections.Generic.List[object]]::new()

foreach ($variant in $variants) {
    $variantRoot = Join-Path $outFull $variant.name
    & $builder -OutRoot $variantRoot -ReadAheadKb $variant.readAheadKb -DiskReadAheadKb $DiskReadAheadKb
    if ($LASTEXITCODE -ne 0) {
        throw "Tiny Core UI-first $($variant.name) candidate build failed"
    }

    $manifestPath = Join-Path $variantRoot 'candidate-manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $built.Add([ordered]@{
        name = $variant.name
        readAheadKb = $variant.readAheadKb
        manifest = (Resolve-Path -LiteralPath $manifestPath).Path.Substring($repoRoot.Length + 1).Replace('\', '/')
        directory = $manifest.candidate.directory
        zip = $manifest.candidate.zip
        zipSha256 = $manifest.candidate.zipSha256
        initramfsSha256 = $manifest.candidate.files.'E-root/initramf'
    })
}

$index = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Matched Tiny Core UI-first candidates for real-hardware desktop startup comparison'
    invariant = [ordered]@{
        protectedSource = 'artifacts/softmod/xromwell-hddfatx-tinycore-lean.zip'
        protectedSourceSha256 = '17327756ED0CB274145CFDD974D119BEF19DB0F7588509726BB8C6BBFD4DE866'
        diskReadAheadKb = $DiskReadAheadKb
        desktopStartup = 'FLWM, proof terminal, and wbar launch before asynchronous wallpaper loading'
        timingLog = '/tmp/xbox-desktop-timing.txt'
    }
    variants = $built
}
$indexPath = Join-Path $outFull 'candidate-index.json'
$index | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $indexPath -Encoding ASCII

[pscustomobject]@{
    root = $outFull
    index = $indexPath
    variants = $built.Count
}
