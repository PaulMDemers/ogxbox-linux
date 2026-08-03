[CmdletBinding()]
param(
    [string]$SourceRoot = 'artifacts\devuan-5.8.1-desktop-candidate',
    [string]$OutRoot = 'artifacts\devuan-5.8.1-desktop-hot-order',
    [string]$WslScratchRoot = '/home/paul/ogxbox/distro-build/devuan-5.8.1-hot-order-root'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
$sourceFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $SourceRoot))
$outFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
$sourceManifestPath = Join-Path $sourceFull 'candidate-manifest.json'
$sourceManifest = Get-Content -LiteralPath $sourceManifestPath -Raw | ConvertFrom-Json
$sourceDir = Join-Path $sourceFull $sourceManifest.candidate.directory
$helper = Join-Path $repoRoot 'scripts\build_devuan_5_8_hot_order_squashfs.sh'
$controlName = 'devuan-daedalus-desktop-live-5.8.1-control-repack'
$hotName = 'devuan-daedalus-desktop-live-5.8.1-hot-order'
$controlDir = Join-Path $outFull $controlName
$hotDir = Join-Path $outFull $hotName
$sortFile = Join-Path $outFull 'hot-files.sort'
$sortReport = Join-Path $outFull 'hot-files-report.txt'

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
    throw 'Hot-order output cannot replace the audited desktop candidate.'
}

Assert-FileHash (Join-Path $sourceFull $sourceManifest.candidate.zip) $sourceManifest.candidate.zipSha256
foreach ($property in $sourceManifest.candidate.files.psobject.Properties) {
    Assert-FileHash (Join-Path $sourceDir ($property.Name.Replace('/', '\'))) $property.Value
}

Remove-Item -LiteralPath $outFull -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $controlDir, $hotDir | Out-Null
Copy-Item -Path (Join-Path $sourceDir '*') -Destination $controlDir -Recurse -Force
Copy-Item -Path (Join-Path $sourceDir '*') -Destination $hotDir -Recurse -Force

$sourceSquashfs = Join-Path $sourceDir 'E-root\devuan.squashfs'
$controlSquashfs = Join-Path $controlDir 'E-root\devuan.squashfs'
$hotSquashfs = Join-Path $hotDir 'E-root\devuan.squashfs'
& wsl.exe -u root -e bash `
    (Convert-ToWslPath $helper) `
    (Convert-ToWslPath $sourceSquashfs) `
    (Convert-ToWslPath $controlSquashfs) `
    (Convert-ToWslPath $hotSquashfs) `
    $WslScratchRoot `
    (Convert-ToWslPath $sortFile) `
    (Convert-ToWslPath $sortReport)
if ($LASTEXITCODE -ne 0) {
    throw 'Matched control/hot-order SquashFS build failed.'
}

$variants = [ordered]@{}
foreach ($variant in @(
    [pscustomobject]@{ Name = 'control'; DirectoryName = $controlName; Directory = $controlDir },
    [pscustomobject]@{ Name = 'hotOrder'; DirectoryName = $hotName; Directory = $hotDir }
)) {
    $zip = Join-Path $outFull "$($variant.DirectoryName).zip"
    Compress-Archive -Path (Join-Path $variant.Directory '*') -DestinationPath $zip -CompressionLevel Optimal
    $files = Get-FileHashMap $variant.Directory
    $variants[$variant.Name] = [ordered]@{
        directory = $variant.DirectoryName
        zip = [System.IO.Path]::GetFileName($zip)
        zipSha256 = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
        files = $files
    }
}

$manifest = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Matched SquashFS physical-order A/B derived from the audited Devuan 5.8.1 desktop candidate'
    source = [ordered]@{
        manifest = 'artifacts/devuan-5.8.1-desktop-candidate/candidate-manifest.json'
        directory = $sourceManifest.candidate.directory
        zipSha256 = $sourceManifest.candidate.zipSha256
        payloadSha256 = $sourceManifest.candidate.files.'E-root/devuan.squashfs'
    }
    build = [ordered]@{
        commonFlags = '-noappend -comp gzip -b 131072 -mkfs-time 0'
        controlChange = 'Fresh repack with no sort file'
        hotOrderChange = 'Same repack with dependency-derived hot-files.sort'
        sortFile = 'hot-files.sort'
        sortFileSha256 = (Get-FileHash -LiteralPath $sortFile -Algorithm SHA256).Hash
        sortEntries = (Get-Content -LiteralPath $sortFile).Count
    }
    variants = $variants
}
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outFull 'candidate-manifest.json') -Encoding ASCII

@"
# Devuan 5.8.1 SquashFS Hot-Order A/B

Both packages are self-contained and derived from the same audited desktop
candidate. Their kernel, initramfs, XBE, and linuxboot.cfg are unchanged. Both
SquashFS files were freshly repacked with identical gzip/128 KiB settings and a
fixed filesystem timestamp. Only the hot-order variant uses hot-files.sort.

The control package measures repack variance. Promote the hot-order package only
if repeated cold boots beat both the control repack and the audited candidate.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'README.md') -Encoding ASCII

[pscustomobject]@{
    controlDirectory = $controlDir
    controlPayloadSha256 = $variants.control.files.'E-root/devuan.squashfs'
    hotOrderDirectory = $hotDir
    hotOrderPayloadSha256 = $variants.hotOrder.files.'E-root/devuan.squashfs'
    sortEntries = $manifest.build.sortEntries
    manifest = Join-Path $outFull 'candidate-manifest.json'
}
