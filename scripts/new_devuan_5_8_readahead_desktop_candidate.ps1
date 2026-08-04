[CmdletBinding()]
param(
    [string]$SourceRoot = 'artifacts\devuan-5.8.1-desktop-candidate',
    [string]$OutRoot = 'artifacts\devuan-5.8.1-desktop-ra128-candidate',
    [ValidateRange(64, 4096)]
    [int]$ReadAheadKb = 128
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
$sourceFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $SourceRoot))
$outFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
$sourceManifestPath = Join-Path $sourceFull 'candidate-manifest.json'
$sourceManifest = Get-Content -LiteralPath $sourceManifestPath -Raw | ConvertFrom-Json
$sourceDir = Join-Path $sourceFull $sourceManifest.candidate.directory
$candidateName = "devuan-daedalus-desktop-live-5.8.1-ra${ReadAheadKb}k-candidate"
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
    throw "Candidate output must be a child of ${artifactsRoot}: $outFull"
}
if ($outFull -eq $sourceFull) {
    throw 'Read-ahead candidate cannot replace the audited desktop candidate.'
}

Assert-FileHash (Join-Path $sourceFull $sourceManifest.candidate.zip) $sourceManifest.candidate.zipSha256
foreach ($property in $sourceManifest.candidate.files.psobject.Properties) {
    Assert-FileHash (Join-Path $sourceDir ($property.Name.Replace('/', '\'))) $property.Value
}

if (Test-Path -LiteralPath $outFull) {
    $resolvedOut = [System.IO.Path]::GetFullPath($outFull)
    if (-not $resolvedOut.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove output outside artifacts: $resolvedOut"
    }
    Remove-Item -LiteralPath $resolvedOut -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $candidateDir | Out-Null
Copy-Item -Path (Join-Path $sourceDir '*') -Destination $candidateDir -Recurse -Force

$cfg = Get-Content -LiteralPath $candidateCfg -Raw
$originalCfg = $cfg
$cfg = $cfg -replace 'xbox_fatx_loop_readahead_kb=\d+', "xbox_fatx_loop_readahead_kb=$ReadAheadKb"
$cfg = $cfg -replace 'xbox_loop_readahead_kb=\d+', "xbox_loop_readahead_kb=$ReadAheadKb"
if ($cfg -notmatch "xbox_fatx_loop_readahead_kb=$ReadAheadKb" -or
    $cfg -notmatch "xbox_loop_readahead_kb=$ReadAheadKb") {
    throw "Failed to set both read-ahead values in $candidateCfg"
}
if ($cfg -eq $originalCfg) {
    throw "Source configuration already uses ${ReadAheadKb} KiB read-ahead: $candidateCfg"
}
Set-Content -LiteralPath $candidateCfg -Value $cfg -Encoding ASCII -NoNewline

$candidateFiles = [ordered]@{}
Get-ChildItem -LiteralPath $candidateDir -Recurse -File | Sort-Object FullName | ForEach-Object {
    $relative = (Get-RelativePath -BasePath $candidateDir -TargetPath $_.FullName).Replace('\', '/')
    $candidateFiles[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
}

foreach ($property in $sourceManifest.candidate.files.psobject.Properties) {
    if ($property.Name -eq 'E-root/linuxboot.cfg') { continue }
    if ($candidateFiles[$property.Name] -ne $property.Value) {
        throw "Unexpected candidate change outside linuxboot.cfg: $($property.Name)"
    }
}

$candidateZip = Join-Path $outFull "$candidateName.zip"
Compress-Archive -Path (Join-Path $candidateDir '*') -DestinationPath $candidateZip -CompressionLevel Optimal
$manifest = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Config-only 128 KiB loop read-ahead candidate derived from the audited Devuan 5.8.1 desktop candidate'
    source = [ordered]@{
        manifest = 'artifacts/devuan-5.8.1-desktop-candidate/candidate-manifest.json'
        directory = $sourceManifest.candidate.directory
        zipSha256 = $sourceManifest.candidate.zipSha256
        payloadSha256 = $sourceManifest.candidate.files.'E-root/devuan.squashfs'
        configSha256 = $sourceManifest.candidate.files.'E-root/linuxboot.cfg'
    }
    candidate = [ordered]@{
        directory = $candidateName
        zip = [System.IO.Path]::GetFileName($candidateZip)
        zipSha256 = (Get-FileHash -LiteralPath $candidateZip -Algorithm SHA256).Hash
        payload = $sourceManifest.candidate.payload
        readAheadKb = $ReadAheadKb
        files = $candidateFiles
        changes = @(
            "Set xbox_fatx_loop_readahead_kb=$ReadAheadKb",
            "Set xbox_loop_readahead_kb=$ReadAheadKb"
        )
    }
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outFull 'candidate-manifest.json') -Encoding ASCII

@"
# Devuan 5.8.1 128 KiB Read-Ahead Candidate

This complete desktop package is derived from the audited normal desktop
candidate. The XBE, kernel, initramfs, and SquashFS payload are byte-identical.
Only the two loop read-ahead values in linuxboot.cfg change to ${ReadAheadKb} KiB.
It does not contain the benchmark self-test or its boot flag.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'README.md') -Encoding ASCII

[pscustomobject]@{
    directory = $candidateDir
    zip = $candidateZip
    zipSha256 = $manifest.candidate.zipSha256
    payloadSha256 = $manifest.source.payloadSha256
    configSha256 = $candidateFiles.'E-root/linuxboot.cfg'
}
