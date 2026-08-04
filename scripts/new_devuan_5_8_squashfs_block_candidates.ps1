[CmdletBinding()]
param(
    [string]$SourceRoot = 'artifacts\devuan-5.8.1-desktop-candidate',
    [string]$OutRoot = 'artifacts\devuan-5.8.1-squashfs-block-ab',
    [ValidateSet(65536, 131072, 262144, 1048576)]
    [int[]]$BlockSizes = @(131072, 262144, 1048576),
    [ValidateSet('gzip', 'zstd', 'xz')]
    [string]$Compression = 'gzip',
    [string]$WslScratchRoot = '/home/paul/ogxbox/distro-build/devuan-5.8.1-block-ab-root'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
$sourceFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $SourceRoot))
$outFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
$sourceManifestPath = Join-Path $sourceFull 'candidate-manifest.json'
$sourceManifest = Get-Content -LiteralPath $sourceManifestPath -Raw | ConvertFrom-Json
$sourceDir = Join-Path $sourceFull $sourceManifest.candidate.directory
$helper = Join-Path $repoRoot 'scripts\build_devuan_5_8_squashfs_block_candidates.sh'
$buildOutput = Join-Path $outFull 'squashfs'

function Convert-ToWslPath([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -lt 3 -or $full[1] -ne ':') {
        throw "Only drive-qualified Windows paths are supported: $Path"
    }
    $drive = $full[0].ToString().ToLowerInvariant()
    $rest = $full.Substring(2).Replace('\', '/')
    "/mnt/$drive$rest"
}

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
    throw 'Block-size output cannot replace the audited desktop candidate.'
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
New-Item -ItemType Directory -Force -Path $outFull, $buildOutput | Out-Null

$sourceSquashfs = Join-Path $sourceDir 'E-root\devuan.squashfs'
$helperArgs = @(
    (Convert-ToWslPath $helper),
    (Convert-ToWslPath $sourceSquashfs),
    (Convert-ToWslPath $buildOutput),
    $WslScratchRoot,
    $Compression
) + @($BlockSizes | ForEach-Object { $_.ToString() })
& wsl.exe -u root -e bash @helperArgs
if ($LASTEXITCODE -ne 0) {
    throw 'SquashFS block-size candidate build failed.'
}

$variants = [ordered]@{}
foreach ($blockSize in $BlockSizes) {
    $label = switch ($blockSize) {
        65536 { 'block64k' }
        131072 { 'block128k' }
        262144 { 'block256k' }
        1048576 { 'block1m' }
    }
    $variantLabel = if ($Compression -eq 'gzip') { $label } else { "$Compression-$label" }
    $directoryName = "devuan-daedalus-desktop-live-5.8.1-selftest-$variantLabel"
    $directory = Join-Path $outFull $directoryName
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    Copy-Item -Path (Join-Path $sourceDir '*') -Destination $directory -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $buildOutput "devuan-$Compression-block-$blockSize.squashfs") `
        -Destination (Join-Path $directory 'E-root\devuan.squashfs') -Force

    $cfgPath = Join-Path $directory 'E-root\linuxboot.cfg'
    $cfg = Get-Content -LiteralPath $cfgPath -Raw
    if ($cfg -match '(?m)^append .*\bxbox_storage_selftest=') {
        throw "Source configuration already selects storage self-test mode: $cfgPath"
    }
    $cfg = $cfg -replace '(?m)^(append .*)$', '$1 xbox_storage_selftest=1'
    Set-Content -LiteralPath $cfgPath -Value $cfg -Encoding ASCII -NoNewline

    $files = Get-FileHashMap $directory
    $variants[$variantLabel] = [ordered]@{
        blockSize = $blockSize
        directory = $directoryName
        files = $files
        compression = $Compression
        superblockReport = "squashfs/devuan-$Compression-block-$blockSize.superblock.txt"
    }
}

$manifest = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Input-free Devuan 5.8.1 SquashFS block-size storage benchmark'
    source = [ordered]@{
        manifest = 'artifacts/devuan-5.8.1-desktop-candidate/candidate-manifest.json'
        directory = $sourceManifest.candidate.directory
        zipSha256 = $sourceManifest.candidate.zipSha256
        payloadSha256 = $sourceManifest.candidate.files.'E-root/devuan.squashfs'
    }
    invariants = @(
        'Protected source package is hash-verified and never modified',
        'All variants use the same patched uncompressed filesystem tree',
        "Every variant in this candidate uses $Compression compression",
        'XBE, kernel, and initramfs are byte-identical across variants',
        'xbox_storage_selftest=1 runs before early helpers and X startup'
    )
    benchmark = [ordered]@{
        rawReadOffsetsMiB = @(0, 64, 128, 192, 256)
        rawReadSizeMiB = 1
        closureBinaries = @('Xfbdev', 'xterm', 'fluxbox', 'dillo', 'mtpaint', 'xfe')
        completionMarker = 'XBOX_STORAGE_SELFTEST_OK'
        completionDisplay = 'green console held indefinitely'
    }
    build = [ordered]@{
        compression = $Compression
        blockSizes = $BlockSizes
        commonFlags = "-noappend -comp $Compression -mkfs-time 0"
    }
    variants = $variants
}
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outFull 'candidate-manifest.json') -Encoding ASCII

@"
# Devuan 5.8.1 SquashFS Block-Size A/B

These are benchmark-only, self-contained HDD/XBE packages derived from the
audited Devuan 5.8.1 desktop candidate. They boot into an input-free storage
self-test before early helpers and X, display millisecond timings on a green
console, and hold that screen for full-window capture.

Within one generated candidate, only the SquashFS block size differs. The
selected compression is $Compression. Do not promote these packages as desktop
builds; use a measured winner to build a normal desktop candidate and then
repeat cold-boot testing.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'README.md') -Encoding ASCII

$variants.GetEnumerator() | ForEach-Object {
    [pscustomobject]@{
        variant = $_.Key
        blockSize = $_.Value.blockSize
        directory = Join-Path $outFull $_.Value.directory
        payloadSha256 = $_.Value.files.'E-root/devuan.squashfs'
    }
}
