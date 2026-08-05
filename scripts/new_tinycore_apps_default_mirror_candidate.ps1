[CmdletBinding()]
param(
    [string]$SourceRoot = 'artifacts\tinycore-6.18.33-nondisc',
    [string]$OutRoot = 'artifacts\tinycore-apps-default-mirror-candidate',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
$sourceFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $SourceRoot))
$outFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
$sourceZipName = 'tinycore11-desktop-6.18.33-hotset-release-xbe.zip'
$sourceZipSha256 = 'F75DC44CBA6CDD994E146C6E684AFE0EB149DFF75E48BA5A0CC8CA965A5FDAF1'
$sourceZip = Join-Path $sourceFull $sourceZipName
$candidateName = 'tinycore11-desktop-6.18.33-apps-default-mirror-xbe'
$candidateDir = Join-Path $outFull $candidateName
$candidateZip = Join-Path $outFull "$candidateName.zip"
$initramfsBuild = Join-Path $repoRoot 'build\tinycore-apps-default-mirror-initramfs'
$newInitramfs = Join-Path $initramfsBuild 'xbox-tinycore-hdd-ext2-stage7-xfbdev-desktop.cpio'
$expectedMirror = 'http://repo.tinycorelinux.net/'
$markerPath = '/tmp/tce/firstrun'

function Get-RelativePath {
    param([string]$BasePath, [string]$TargetPath)
    $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'
    $targetFull = [System.IO.Path]::GetFullPath($TargetPath)
    $baseUri = [System.Uri]::new($baseFull)
    $targetUri = [System.Uri]::new($targetFull)
    [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

function Assert-FileHash {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file was not found: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) {
        throw "SHA256 mismatch for $Path. Expected $Expected, got $actual"
    }
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
foreach ($path in @($sourceFull, $outFull)) {
    if (-not $path.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Candidate paths must be children of ${artifactsRoot}: $path"
    }
}
Assert-FileHash -Path $sourceZip -Expected $sourceZipSha256

if (Test-Path -LiteralPath $outFull) {
    if (-not $Force) {
        throw "Candidate output already exists. Use -Force to rebuild only this directory: $outFull"
    }
    Remove-Item -LiteralPath $outFull -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outFull | Out-Null
Expand-Archive -LiteralPath $sourceZip -DestinationPath $candidateDir

& python (Join-Path $repoRoot 'scripts\make_busybox_initramfs.py') --out-dir $initramfsBuild
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $newInitramfs -PathType Leaf)) {
    throw 'Building the Apps-default-mirror initramfs failed.'
}
$initramfsText = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($newInitramfs))
foreach ($requiredText in @('xbox_apps_skip_mirror=1', 'mkdir -p /tmp/tce/optional', ': > /tmp/tce/firstrun', 'XBOX_APPS_DEFAULT_MIRROR_OK')) {
    if (-not $initramfsText.Contains($requiredText)) {
        throw "Generated initramfs is missing Apps bypass logic: $requiredText"
    }
}
Copy-Item -LiteralPath $newInitramfs -Destination (Join-Path $candidateDir 'E-root\initramf') -Force

$cfgPath = Join-Path $candidateDir 'E-root\linuxboot.cfg'
$cfgLines = [System.IO.File]::ReadAllLines($cfgPath)
$appendIndexes = @()
for ($i = 0; $i -lt $cfgLines.Count; $i++) {
    if ($cfgLines[$i].StartsWith('append ', [System.StringComparison]::Ordinal)) {
        $appendIndexes += $i
    }
}
if ($appendIndexes.Count -ne 1) {
    throw "Expected exactly one append line in $cfgPath; found $($appendIndexes.Count)."
}
$appendIndex = $appendIndexes[0]
if ($cfgLines[$appendIndex] -notmatch '(?:^| )xbox_apps_skip_mirror=1(?: |$)') {
    $cfgLines[$appendIndex] += ' xbox_apps_skip_mirror=1'
}
[System.IO.File]::WriteAllLines($cfgPath, $cfgLines, [System.Text.Encoding]::ASCII)

$cfg = [System.IO.File]::ReadAllText($cfgPath)
if ($cfg -notmatch '(?:^| )xbox_apps_skip_mirror=1(?: |\r?$)') {
    throw 'The candidate boot flag was not added to linuxboot.cfg.'
}
Assert-FileHash -Path $sourceZip -Expected $sourceZipSha256

@"
Tiny Core Apps Default-Mirror Candidate
=======================================

This isolated candidate is derived from the exact hardware-validated Tiny Core
6.18.33 release ZIP. It adds one boot-gated behavior: create Tiny Core's normal
$markerPath marker before the desktop starts. It also creates the standard
/tmp/tce/optional directory that Apps uses when resolving that marker. This
skips the first-run offer to benchmark mirrors.

The repository remains unchanged:

    $expectedMirror

Install this candidate exactly like the promoted release. Keep all candidate
files together and do not mix them with another package. The promoted release
remains the rollback package. This candidate is emulator-validated and still
requires one real-hardware Apps launch before promotion.
"@ | Set-Content -LiteralPath (Join-Path $candidateDir 'README-APPS-CANDIDATE.txt') -Encoding ASCII

$files = Get-FileHashMap $candidateDir
Compress-Archive -Path (Join-Path $candidateDir '*') -DestinationPath $candidateZip -CompressionLevel Optimal
$manifest = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Tiny Core Apps first-run mirror benchmark bypass candidate'
    protectedSource = [ordered]@{
        root = $SourceRoot.Replace('\', '/')
        zip = $sourceZipName
        zipSha256 = $sourceZipSha256
    }
    candidate = [ordered]@{
        directory = $candidateName
        zip = [System.IO.Path]::GetFileName($candidateZip)
        zipSha256 = (Get-FileHash -LiteralPath $candidateZip -Algorithm SHA256).Hash
        diskReadAheadKb = 1024
        fatxLoopReadAheadKb = 1024
        rootLoopReadAheadKb = 1024
        xHotset = $true
        xHotsetRelease = $true
        remoteDiagnostics = $true
        terminalFont = '9x15'
        appsSkipMirror = $true
        appsOptionalDirectory = '/tmp/tce/optional'
        appsFirstRunMarker = $markerPath
        configuredMirror = $expectedMirror
        files = $files
    }
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outFull 'candidate-manifest.json') -Encoding ASCII

[pscustomobject]@{
    directory = $candidateDir
    zip = $candidateZip
    zipBytes = (Get-Item -LiteralPath $candidateZip).Length
    zipSha256 = $manifest.candidate.zipSha256
    initramfsSha256 = $files.'E-root/initramf'
    payloadSha256 = $files.'E-root/linuxroot.ext2'
    protectedSourceSha256 = $sourceZipSha256
}
