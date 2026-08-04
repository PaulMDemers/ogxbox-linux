[CmdletBinding()]
param(
    [string]$SourceRoot = 'artifacts\devuan-5.8.1-squashfs-block-ab',
    [string]$SourceVariant = 'block128k',
    [string]$OutRoot = 'artifacts\devuan-5.8.1-readahead-ab',
    [ValidateSet(128, 512, 1024, 2048, 4096)]
    [int[]]$ReadAheadKb = @(128, 512, 1024, 2048)
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
$sourceFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $SourceRoot))
$outFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
$sourceManifestPath = Join-Path $sourceFull 'candidate-manifest.json'
$sourceManifest = Get-Content -LiteralPath $sourceManifestPath -Raw | ConvertFrom-Json
$sourceProperty = $sourceManifest.variants.psobject.Properties | Where-Object Name -eq $SourceVariant
if (-not $sourceProperty) {
    throw "Source variant was not found: $SourceVariant"
}
$source = $sourceProperty.Value
$sourceDir = Join-Path $sourceFull $source.directory

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

function Get-FileHashMap([string]$Root) {
    $files = [ordered]@{}
    Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative = (Get-RelativePath -BasePath $Root -TargetPath $_.FullName).Replace('\', '/')
        $files[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
    $files
}

$artifactsPrefix = $artifactsRoot.TrimEnd('\') + '\'
if (-not $outFull.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Output must be a child of ${artifactsRoot}: $outFull"
}
if ($outFull -eq $sourceFull) {
    throw 'Read-ahead output cannot replace its source candidate.'
}
foreach ($property in $source.files.psobject.Properties) {
    Assert-FileHash (Join-Path $sourceDir ($property.Name.Replace('/', '\'))) $property.Value
}

if (Test-Path -LiteralPath $outFull) {
    $resolvedOut = [System.IO.Path]::GetFullPath($outFull)
    if (-not $resolvedOut.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove output outside artifacts: $resolvedOut"
    }
    Remove-Item -LiteralPath $resolvedOut -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outFull | Out-Null

$variants = [ordered]@{}
foreach ($readAhead in $ReadAheadKb) {
    $label = "ra${readAhead}k"
    $directoryName = "devuan-daedalus-desktop-live-5.8.1-selftest-$label"
    $directory = Join-Path $outFull $directoryName
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    Copy-Item -Path (Join-Path $sourceDir '*') -Destination $directory -Recurse -Force

    $cfgPath = Join-Path $directory 'E-root\linuxboot.cfg'
    $cfg = Get-Content -LiteralPath $cfgPath -Raw
    $cfg = $cfg -replace 'xbox_fatx_loop_readahead_kb=\d+', "xbox_fatx_loop_readahead_kb=$readAhead"
    $cfg = $cfg -replace 'xbox_loop_readahead_kb=\d+', "xbox_loop_readahead_kb=$readAhead"
    if ($cfg -notmatch "xbox_fatx_loop_readahead_kb=$readAhead" -or
        $cfg -notmatch "xbox_loop_readahead_kb=$readAhead") {
        throw "Failed to set read-ahead in $cfgPath"
    }
    Set-Content -LiteralPath $cfgPath -Value $cfg -Encoding ASCII -NoNewline

    $variants[$label] = [ordered]@{
        blockSize = 131072
        readAheadKb = $readAhead
        directory = $directoryName
        files = Get-FileHashMap $directory
    }
}

$manifest = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Config-only Devuan 5.8.1 FATX/SquashFS loop read-ahead A/B'
    source = [ordered]@{
        manifest = 'artifacts/devuan-5.8.1-squashfs-block-ab/candidate-manifest.json'
        variant = $SourceVariant
        directory = $source.directory
        payloadSha256 = $source.files.'E-root/devuan.squashfs'
    }
    invariants = @(
        'All source files are hash-verified before copying',
        'Every variant has the same XBE, kernel, initramfs, and SquashFS payload',
        'Only xbox_fatx_loop_readahead_kb and xbox_loop_readahead_kb change',
        'Both loop devices receive the same value in a given variant'
    )
    variants = $variants
}
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outFull 'candidate-manifest.json') -Encoding ASCII

@"
# Devuan 5.8.1 Read-Ahead A/B

These benchmark-only packages use the same gzip/128 KiB self-test payload.
Only the stage1 FATX backing-loop and SquashFS root-loop read-ahead values
change: $($ReadAheadKb -join ', ') KiB. Each directory is a complete boot set.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'README.md') -Encoding ASCII

$variants.GetEnumerator() | ForEach-Object {
    [pscustomobject]@{
        variant = $_.Key
        readAheadKb = $_.Value.readAheadKb
        directory = Join-Path $outFull $_.Value.directory
        payloadSha256 = $_.Value.files.'E-root/devuan.squashfs'
        configSha256 = $_.Value.files.'E-root/linuxboot.cfg'
    }
}
