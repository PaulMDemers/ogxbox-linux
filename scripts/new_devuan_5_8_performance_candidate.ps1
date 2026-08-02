[CmdletBinding()]
param(
    [string]$SourceRoot = 'artifacts\devuan-5.8.1-desktop-candidate',
    [string]$OutRoot = 'artifacts\devuan-5.8.1-desktop-performance-candidate'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
$sourceFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $SourceRoot))
$outFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
$sourceManifestPath = Join-Path $sourceFull 'candidate-manifest.json'
$sourceManifest = Get-Content -LiteralPath $sourceManifestPath -Raw | ConvertFrom-Json
$sourceDir = Join-Path $sourceFull $sourceManifest.candidate.directory
$candidateName = 'devuan-daedalus-desktop-live-5.8.1-preload-candidate'
$candidateDir = Join-Path $outFull $candidateName
$candidateCfg = Join-Path $candidateDir 'E-root\linuxboot.cfg'

function Assert-FileHash {
    param([string]$Path, [string]$Expected)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required source file was not found: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) {
        throw "Source file changed: $Path. Expected $Expected, got $actual"
    }
}

function Get-RelativePath {
    param([string]$BasePath, [string]$TargetPath)

    $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'
    $targetFull = [System.IO.Path]::GetFullPath($TargetPath)
    $baseUri = [System.Uri]::new($baseFull)
    $targetUri = [System.Uri]::new($targetFull)
    [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

$artifactsPrefix = $artifactsRoot.TrimEnd('\') + '\'
if (-not $outFull.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Performance output must be a child of ${artifactsRoot}: $outFull"
}
if ($outFull -eq $sourceFull) {
    throw 'Performance output cannot replace the audited desktop candidate.'
}

Assert-FileHash (Join-Path $sourceFull $sourceManifest.candidate.zip) $sourceManifest.candidate.zipSha256
foreach ($property in $sourceManifest.candidate.files.psobject.Properties) {
    Assert-FileHash (Join-Path $sourceDir ($property.Name.Replace('/', '\'))) $property.Value
}

Remove-Item -LiteralPath $outFull -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $candidateDir | Out-Null
Copy-Item -Path (Join-Path $sourceDir '*') -Destination $candidateDir -Recurse -Force

$cfg = Get-Content -LiteralPath $candidateCfg -Raw
if ($cfg -match '(?m)^append .*\bxbox_preload_fluxbox=') {
    throw "Source configuration already selects a Fluxbox preload mode: $candidateCfg"
}
$cfg = $cfg -replace '(?m)^(append .*)$', '$1 xbox_preload_fluxbox=1'
if ($cfg -notmatch '(?m)^append .*\bxbox_preload_fluxbox=1\b') {
    throw "Failed to enable Fluxbox preload in $candidateCfg"
}
Set-Content -LiteralPath $candidateCfg -Value $cfg -Encoding ASCII -NoNewline

$candidateFiles = [ordered]@{}
Get-ChildItem -LiteralPath $candidateDir -Recurse -File | Sort-Object FullName | ForEach-Object {
    $relative = (Get-RelativePath -BasePath $candidateDir -TargetPath $_.FullName).Replace('\', '/')
    $candidateFiles[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
}

$candidateZip = Join-Path $outFull "$candidateName.zip"
Compress-Archive -Path (Join-Path $candidateDir '*') -DestinationPath $candidateZip -CompressionLevel Optimal

$manifest = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Config-only Fluxbox preload experiment derived from the audited Devuan 5.8.1 desktop candidate'
    source = [ordered]@{
        manifest = 'artifacts/devuan-5.8.1-desktop-candidate/candidate-manifest.json'
        directory = $sourceManifest.candidate.directory
        zipSha256 = $sourceManifest.candidate.zipSha256
        payloadSha256 = $sourceManifest.candidate.files.'E-root/devuan.squashfs'
    }
    candidate = [ordered]@{
        directory = $candidateName
        zip = [System.IO.Path]::GetFileName($candidateZip)
        zipSha256 = (Get-FileHash -LiteralPath $candidateZip -Algorithm SHA256).Hash
        payload = $sourceManifest.candidate.payload
        files = $candidateFiles
        changes = @('Enable the existing xbox_preload_fluxbox=1 startup path')
    }
    measuredResult = [ordered]@{
        status = 'rejected'
        baselineShellSeconds = 115
        baselineSettledSeconds = 209
        preloadShellSeconds = 178
        preloadSettledSeconds = 252
        reason = 'Preloading moved cold reads ahead of the shell and increased settled desktop time by 43 seconds in xemu.'
    }
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outFull 'candidate-manifest.json') -Encoding ASCII

@"
# Devuan 5.8.1 Fluxbox Preload Candidate

This is a rejected config-only performance experiment retained as a reproducible
negative result. The kernel, initramfs, XBE, and SquashFS payload are
byte-identical to the audited desktop candidate. Only the linuxboot.cfg append
line adds xbox_preload_fluxbox=1.

In xemu it moved the first usable shell from 115 to 178 seconds and moved the
settled desktop from 209 to 252 seconds. Do not promote or hardware-test this
package; use it only to reproduce the preload result.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'README.md') -Encoding ASCII

[pscustomobject]@{
    directory = $candidateDir
    zip = $candidateZip
    zipSha256 = $manifest.candidate.zipSha256
    payloadSha256 = $manifest.source.payloadSha256
    configSha256 = $candidateFiles.'E-root/linuxboot.cfg'
}
