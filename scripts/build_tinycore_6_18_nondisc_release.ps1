[CmdletBinding()]
param(
    [string]$SourceRoot = 'artifacts\tinycore-apps-default-mirror-candidate',
    [string]$RollbackSourceRoot = 'artifacts\tinycore-hdd-x-hotset-memory-candidate',
    [string]$OutRoot = 'artifacts\tinycore-6.18.33-nondisc',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
$sourceFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $SourceRoot))
$rollbackSourceFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $RollbackSourceRoot))
$outFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
$releaseName = 'tinycore11-desktop-6.18.33-apps-default-mirror-xbe'
$sourceZipName = 'tinycore11-desktop-6.18.33-apps-default-mirror-xbe.zip'
$sourceZipSha256 = 'B914A6B513009CE84422EE881996B09F96F75196F65D3F3FB39B0B272478F6F0'
$rollbackSourceZipName = 'xromwell-hddfatx-tinycore-lean-xhotset-release-remote-ra1024k-candidate.zip'
$rollbackZipName = 'tinycore11-desktop-6.18.33-pre-apps-rollback-xbe.zip'
$rollbackZipSha256 = 'F75DC44CBA6CDD994E146C6E684AFE0EB149DFF75E48BA5A0CC8CA965A5FDAF1'
$sourceZip = Join-Path $sourceFull $sourceZipName
$rollbackSourceZip = Join-Path $rollbackSourceFull $rollbackSourceZipName
$sourceManifestPath = Join-Path $sourceFull 'candidate-manifest.json'
$releaseDir = Join-Path $outFull $releaseName
$releaseZip = Join-Path $outFull "$releaseName.zip"
$rollbackZip = Join-Path $outFull $rollbackZipName

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

$artifactsPrefix = $artifactsRoot.TrimEnd('\') + '\'
if (-not $sourceFull.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "SourceRoot must be under ${artifactsRoot}: $sourceFull"
}
if (-not $rollbackSourceFull.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "RollbackSourceRoot must be under ${artifactsRoot}: $rollbackSourceFull"
}
if (-not $outFull.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutRoot must be under ${artifactsRoot}: $outFull"
}
if (-not (Test-Path -LiteralPath $sourceManifestPath -PathType Leaf)) {
    throw "Candidate manifest was not found: $sourceManifestPath"
}
Assert-FileHash -Path $sourceZip -Expected $sourceZipSha256
Assert-FileHash -Path $rollbackSourceZip -Expected $rollbackZipSha256

$sourceManifest = Get-Content -LiteralPath $sourceManifestPath -Raw | ConvertFrom-Json
if ($sourceManifest.candidate.zipSha256 -ne $sourceZipSha256) {
    throw "Candidate manifest does not identify the hardware-tested ZIP: $sourceManifestPath"
}
if ($sourceManifest.candidate.xHotsetRelease -ne $true -or
    $sourceManifest.candidate.remoteDiagnostics -ne $true -or
    $sourceManifest.candidate.terminalFont -ne '9x15' -or
    $sourceManifest.candidate.appsSkipMirror -ne $true -or
    $sourceManifest.candidate.appsOptionalDirectory -ne '/tmp/tce/optional' -or
    $sourceManifest.candidate.appsFirstRunMarker -ne '/tmp/tce/firstrun' -or
    $sourceManifest.candidate.configuredMirror -ne 'http://repo.tinycorelinux.net/') {
    throw 'Candidate manifest is missing the hardware-tested hotset, diagnostics, terminal, or Apps settings.'
}

if (Test-Path -LiteralPath $outFull) {
    if (-not $Force) {
        throw "Release output already exists. Use -Force to rebuild only this output directory: $outFull"
    }
    Remove-Item -LiteralPath $outFull -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outFull | Out-Null

# The promoted release ZIP is a byte-for-byte copy of the hardware-tested ZIP.
Copy-Item -LiteralPath $sourceZip -Destination $releaseZip
Assert-FileHash -Path $releaseZip -Expected $sourceZipSha256
Copy-Item -LiteralPath $rollbackSourceZip -Destination $rollbackZip
Assert-FileHash -Path $rollbackZip -Expected $rollbackZipSha256
Expand-Archive -LiteralPath $releaseZip -DestinationPath $releaseDir

foreach ($property in $sourceManifest.candidate.files.PSObject.Properties) {
    $path = Join-Path $releaseDir ($property.Name.Replace('/', '\'))
    Assert-FileHash -Path $path -Expected $property.Value
}

$compatManifest = $sourceManifest | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$compatManifest.protectedSource.root = $OutRoot.Replace('\', '/')
$compatManifest.protectedSource.zip = $rollbackZipName
$compatManifest.protectedSource.zipSha256 = $rollbackZipSha256
$compatManifest.candidate.directory = $releaseName
$compatManifest.candidate.zip = [System.IO.Path]::GetFileName($releaseZip)
$compatManifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outFull 'candidate-manifest.json') -Encoding ASCII

$payloadFiles = [ordered]@{}
Get-ChildItem -LiteralPath $releaseDir -Recurse -File | Sort-Object FullName | ForEach-Object {
    $relative = (Get-RelativePath -BasePath $releaseDir -TargetPath $_.FullName).Replace('\', '/')
    $payloadFiles[$relative] = [ordered]@{
        bytes = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
}

$gitCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to identify the coordinator Git commit.' }
$releaseManifest = [ordered]@{
    releaseId = 'tinycore11-desktop-6.18.33-nondisc-apps-default-mirror'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    coordinatorCommit = $gitCommit
    hardwareValidated = $true
    source = [ordered]@{
        candidateRoot = $SourceRoot.Replace('\', '/')
        zip = $sourceZipName
        zipSha256 = $sourceZipSha256
    }
    package = [ordered]@{
        directory = $releaseName
        zip = [System.IO.Path]::GetFileName($releaseZip)
        zipBytes = (Get-Item -LiteralPath $releaseZip).Length
        zipSha256 = (Get-FileHash -LiteralPath $releaseZip -Algorithm SHA256).Hash
        kernel = '6.18.33'
        transport = 'dashboard XBE plus E-root FATX files'
        opticalDiscRequired = $false
        fatxWriteEnabled = $false
        dhcp = $true
        apps = [ordered]@{
            fastestMirrorPromptSkipped = $true
            optionalDirectory = '/tmp/tce/optional'
            firstRunMarker = '/tmp/tce/firstrun'
            configuredMirror = 'http://repo.tinycorelinux.net/'
        }
        ssh = [ordered]@{
            service = 'Dropbear tcp/22'
            user = 'tc'
            password = 'tcuser'
            rootLogin = $false
        }
        files = $payloadFiles
    }
    rollback = [ordered]@{
        zip = $rollbackZipName
        zipBytes = (Get-Item -LiteralPath $rollbackZip).Length
        zipSha256 = $rollbackZipSha256
        sourceRoot = $RollbackSourceRoot.Replace('\', '/')
        sourceZip = $rollbackSourceZipName
        description = 'Previous hardware-tested hotset release before the Apps mirror bypass.'
    }
    hardwareResult = [ordered]@{
        hotsetPathsRestored = 450
        hotsetRestoreFailures = 0
        memAvailableAfterInteractiveKb = 6260
        xReadySeconds = 26.48
        desktopCompleteSeconds = 27.63
        appsPromptSkipped = $true
        appsOpened = $true
        dhcp = $true
        ssh = $true
    }
    knownIssue = $null
}
$releaseManifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outFull 'release-manifest.json') -Encoding ASCII

@"
# Tiny Core 11 Desktop for Original Xbox

This is the hardware-validated, non-disc Tiny Core desktop release using Linux
6.18.33. The primary ZIP is a byte-for-byte copy of the tested Apps
default-mirror package. No DVD or CD payload is required.

## Install

1. Extract $releaseName.zip.
2. FTP the extracted folder to a dashboard application directory, such as
   E:\Apps\TinyCoreLinux\.
3. FTP the four files inside E-root to the root of E:\:
   linuxboot.cfg, vmlinuz, initramf, and linuxroot.ext2.
4. Launch default.xbe from the dashboard.

Keep every file from this package together. Do not mix its kernel, initramfs,
configuration, payload, or XBE with files from another build.

## Rollback

The previous hardware-tested release is retained as:

    $rollbackZipName

It predates the Apps prompt bypass. Use all files from one ZIP or the other;
never mix their boot files.

## Network Login

DHCP starts automatically. SSH listens on tcp/22 after an address is acquired.

    user:     tc
    password: tcuser
    root SSH login: disabled

## Tiny Core Apps

Apps opens with the normal Tiny Core repository already configured. The
resource-heavy fastest-mirror benchmark is intentionally marked complete so it
does not prompt on this 64 MB system.

## Validation

- X hotset release: 450 restored, 0 failed
- Hardware X ready: 26.48 seconds of kernel uptime
- Hardware desktop complete: 27.63 seconds of kernel uptime
- MemAvailable after interactive Apps testing: 6,260 kB
- Apps opened without the mirror question and remained responsive
- DHCP, SSH, SCP, mouse, dock, terminal, and editor passed on hardware
- FATX remains read-only

release-manifest.json records the package contents and validation result.
candidate-manifest.json is retained so the established xemu test harness can
verify and boot the promoted release without special handling.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'README.md') -Encoding ASCII

@(
    "$sourceZipSha256 *$([System.IO.Path]::GetFileName($releaseZip))"
    "$rollbackZipSha256 *$rollbackZipName"
) | Set-Content -LiteralPath (Join-Path $outFull 'SHA256SUMS.txt') -Encoding ASCII

[pscustomobject]@{
    releaseRoot = $outFull
    packageDirectory = $releaseDir
    zip = $releaseZip
    zipBytes = (Get-Item -LiteralPath $releaseZip).Length
    zipSha256 = (Get-FileHash -LiteralPath $releaseZip -Algorithm SHA256).Hash
    rollbackZip = $rollbackZip
    rollbackZipSha256 = (Get-FileHash -LiteralPath $rollbackZip -Algorithm SHA256).Hash
    payloadFiles = $payloadFiles.Count
}
