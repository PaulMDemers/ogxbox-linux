[CmdletBinding()]
param(
    [string]$OutRoot = 'artifacts\devuan-5.8.1-desktop-candidate',
    [string]$WslScratchRoot = '/home/paul/ogxbox/distro-build/devuan-daedalus-i386-desktop-candidate-build',
    [switch]$BaselineOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$protectedRoot = Join-Path $repoRoot 'artifacts\devuan-5.8.1-nondisc'
$protectedManifestPath = Join-Path $protectedRoot 'manifest.json'
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
$packageName = 'devuan-daedalus-desktop-live-5.8.1-xbe'
$candidateName = 'devuan-daedalus-desktop-live-5.8.1-candidate'
$outFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
$candidateDir = Join-Path $outFull $candidateName
$candidateSquashfs = Join-Path $candidateDir 'E-root\devuan.squashfs'
$fixScript = Join-Path $repoRoot 'scripts\apply_devuan_desktop_candidate_fixes.sh'

function Assert-FileHash {
    param([string]$Path, [string]$Expected)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Protected input was not found: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) {
        throw "Protected input changed: $Path. Expected $Expected, got $actual"
    }
}

function Get-RelativePath {
    param([string]$BasePath, [string]$TargetPath)

    $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'
    $targetFull = [System.IO.Path]::GetFullPath($TargetPath)
    $baseUri = New-Object System.Uri($baseFull)
    $targetUri = New-Object System.Uri($targetFull)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

function Convert-ToWslPath([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -lt 3 -or $full[1] -ne ':') {
        throw "Only drive-qualified Windows paths are supported: $Path"
    }
    $drive = $full[0].ToString().ToLowerInvariant()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

if (-not (Test-Path -LiteralPath $protectedManifestPath -PathType Leaf)) {
    throw "Protected manifest was not found: $protectedManifestPath"
}

$artifactsPrefix = $artifactsRoot.TrimEnd('\') + '\'
if (-not $outFull.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Candidate output must be a child of ${artifactsRoot}: $outFull"
}
if ($outFull -eq [System.IO.Path]::GetFullPath($protectedRoot)) {
    throw "Candidate output cannot replace the protected baseline: $outFull"
}

$protectedManifest = Get-Content -LiteralPath $protectedManifestPath -Raw | ConvertFrom-Json
$package = $protectedManifest.packages | Where-Object name -eq $packageName | Select-Object -First 1
if (-not $package) {
    throw "Protected desktop package is missing from manifest: $packageName"
}

$protectedPackageDir = Join-Path $protectedRoot $package.directory
Assert-FileHash (Join-Path $protectedRoot $package.zip) $package.zipSha256
foreach ($property in $package.files.psobject.Properties) {
    $source = Join-Path $protectedPackageDir ($property.Name.Replace('/', '\'))
    Assert-FileHash $source $property.Value
}

Remove-Item -LiteralPath $outFull -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $candidateDir | Out-Null
Copy-Item -Path (Join-Path $protectedPackageDir '*') -Destination $candidateDir -Recurse -Force

foreach ($property in $package.files.psobject.Properties) {
    $candidateFile = Join-Path $candidateDir ($property.Name.Replace('/', '\'))
    if ((Get-FileHash -LiteralPath $candidateFile -Algorithm SHA256).Hash -ne $property.Value) {
        throw "Candidate copy differs from protected input: $($property.Name)"
    }
}

$changes = @()
if (-not $BaselineOnly) {
    if (-not (Test-Path -LiteralPath $fixScript -PathType Leaf)) {
        throw "Candidate fix script was not found: $fixScript"
    }
    & wsl.exe -u root -e sh `
        (Convert-ToWslPath $fixScript) `
        (Convert-ToWslPath $candidateSquashfs) `
        $WslScratchRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'Devuan desktop candidate squashfs update failed'
    }
    $changes += 'Run distro applications without the Tiny Core /usr/local library override'
}

$candidateFiles = [ordered]@{}
Get-ChildItem -LiteralPath $candidateDir -Recurse -File | Sort-Object FullName | ForEach-Object {
    $relative = (Get-RelativePath -BasePath $candidateDir -TargetPath $_.FullName).Replace('\', '/')
    $candidateFiles[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
}

$candidateZip = Join-Path $outFull "$candidateName.zip"
Compress-Archive -Path (Join-Path $candidateDir '*') -DestinationPath $candidateZip -CompressionLevel Optimal

$candidateManifest = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Isolated desktop-development candidate derived from the hardware-validated Devuan 5.8.1 baseline'
    protectedSource = [ordered]@{
        manifest = 'artifacts/devuan-5.8.1-nondisc/manifest.json'
        package = $packageName
        zipSha256 = $package.zipSha256
    }
    candidate = [ordered]@{
        directory = $candidateName
        zip = [System.IO.Path]::GetFileName($candidateZip)
        zipSha256 = (Get-FileHash -LiteralPath $candidateZip -Algorithm SHA256).Hash
        payload = $package.payload
        files = $candidateFiles
        changes = $changes
    }
}
$candidateManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outFull 'candidate-manifest.json') -Encoding ASCII

@"
# Devuan 5.8.1 Desktop Candidate

This directory is isolated from the hardware-validated desktop package. Every
protected source file under `artifacts/devuan-5.8.1-nondisc` was hash-checked
before copying, and the protected package was not modified.

Candidate-only changes:
  $($changes -join "`r`n  ")

Use this candidate as the starting point for desktop and performance experiments.
Do not copy experimental files back into the protected baseline.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'README.md') -Encoding ASCII

Get-ChildItem -LiteralPath $outFull | Select-Object Name, Length, LastWriteTime
