[CmdletBinding()]
param(
    [string]$ProtectedZip = 'artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip',
    [string]$OutRoot = 'artifacts\tinycore-hdd-ra128-candidate',
    [ValidateRange(64, 4096)]
    [int]$ReadAheadKb = 128,
    [ValidateRange(128, 4096)]
    [int]$DiskReadAheadKb = 1024,
    [switch]$XHotset,
    [switch]$ReleaseXHotset,
    [switch]$RemoteDiagnostics,
    [ValidateSet('fixed', '9x15')]
    [string]$TerminalFont = 'fixed',
    [string]$PayloadPath,
    [switch]$ProtectedControl
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
$protectedZipFull = if ([System.IO.Path]::IsPathRooted($ProtectedZip)) {
    [System.IO.Path]::GetFullPath($ProtectedZip)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $ProtectedZip))
}
$outFull = if ([System.IO.Path]::IsPathRooted($OutRoot)) {
    [System.IO.Path]::GetFullPath($OutRoot)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
}
$initramfsOut = Join-Path $outFull 'initramfs-build'
$candidateName = if ($ProtectedControl) {
    'xromwell-hddfatx-tinycore-lean-protected-control'
} elseif ($RemoteDiagnostics -and $ReleaseXHotset) {
    "xromwell-hddfatx-tinycore-lean-xhotset-release-remote-ra${ReadAheadKb}k-candidate"
} elseif ($RemoteDiagnostics) {
    "xromwell-hddfatx-tinycore-lean-xhotset-remote-ra${ReadAheadKb}k-candidate"
} elseif ($XHotset) {
    "xromwell-hddfatx-tinycore-lean-xhotset-ra${ReadAheadKb}k-candidate"
} else {
    "xromwell-hddfatx-tinycore-lean-ra${ReadAheadKb}k-candidate"
}
$candidateDir = Join-Path $outFull $candidateName
$candidateZip = Join-Path $outFull "$candidateName.zip"
$protectedZipSha256 = '17327756ED0CB274145CFDD974D119BEF19DB0F7588509726BB8C6BBFD4DE866'
$payloadFull = $null
if ($PayloadPath) {
    $payloadFull = if ([System.IO.Path]::IsPathRooted($PayloadPath)) {
        [System.IO.Path]::GetFullPath($PayloadPath)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $PayloadPath))
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
    throw "Candidate output must be a child of ${artifactsRoot}: $outFull"
}
if (-not (Test-Path -LiteralPath $protectedZipFull -PathType Leaf)) {
    throw "Protected Tiny Core package was not found: $protectedZipFull"
}
if ($RemoteDiagnostics -and (-not $XHotset -or -not $payloadFull)) {
    throw 'RemoteDiagnostics requires XHotset and a Dropbear-enabled PayloadPath.'
}
if ($ReleaseXHotset -and -not $XHotset) {
    throw 'ReleaseXHotset requires XHotset.'
}
if ($payloadFull -and -not (Test-Path -LiteralPath $payloadFull -PathType Leaf)) {
    throw "Candidate payload was not found: $payloadFull"
}
if ($payloadFull -and $payloadFull.StartsWith($outFull.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PayloadPath must be outside OutRoot because OutRoot is rebuilt: $payloadFull"
}
$actualProtectedHash = (Get-FileHash -LiteralPath $protectedZipFull -Algorithm SHA256).Hash
if ($actualProtectedHash -ne $protectedZipSha256) {
    throw "Protected Tiny Core package changed. Expected $protectedZipSha256, got $actualProtectedHash"
}

if (Test-Path -LiteralPath $outFull) {
    $resolvedOut = [System.IO.Path]::GetFullPath($outFull)
    if (-not $resolvedOut.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove output outside artifacts: $resolvedOut"
    }
    Remove-Item -LiteralPath $resolvedOut -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outFull | Out-Null
Expand-Archive -LiteralPath $protectedZipFull -DestinationPath $candidateDir
if ($payloadFull) {
    Copy-Item -LiteralPath $payloadFull -Destination (Join-Path $candidateDir 'E-root\linuxroot.ext2') -Force
}

if (-not $ProtectedControl) {
    & python (Join-Path $repoRoot 'scripts\make_busybox_initramfs.py') --out-dir $initramfsOut
    if ($LASTEXITCODE -ne 0) { throw 'Tiny Core candidate initramfs build failed' }
    $newInitrd = Join-Path $initramfsOut 'xbox-tinycore-hdd-ext2-stage7-xfbdev-desktop.cpio'
    if (-not (Test-Path -LiteralPath $newInitrd -PathType Leaf)) { throw "Candidate initramfs was not generated: $newInitrd" }
    Copy-Item -LiteralPath $newInitrd -Destination (Join-Path $candidateDir 'E-root\initramf') -Force

    $cfgPath = Join-Path $candidateDir 'E-root\linuxboot.cfg'
    $cfgLines = [System.IO.File]::ReadAllLines($cfgPath)
    $appendIndex = -1
    for ($i = 0; $i -lt $cfgLines.Count; $i++) {
        if ($cfgLines[$i].StartsWith('append ', [System.StringComparison]::Ordinal)) {
            if ($appendIndex -ge 0) { throw "Multiple append lines found in $cfgPath" }
            $appendIndex = $i
        }
    }
    if ($appendIndex -lt 0) { throw "No append line found in $cfgPath" }
    $cfgLines[$appendIndex] += ' xbox_disk_readahead_kb={0} xbox_fatx_loop_readahead_kb={1} xbox_loop_readahead_kb={1}' -f $DiskReadAheadKb, $ReadAheadKb
    if ($XHotset) {
        $cfgLines[$appendIndex] += ' xbox_x_hotset=1'
    }
    if ($ReleaseXHotset) {
        $cfgLines[$appendIndex] += ' xbox_x_hotset_release=1'
    }
    if ($RemoteDiagnostics) {
        $cfgLines[$appendIndex] += ' xbox_remote_diag=1'
    }
    if ($TerminalFont -ne 'fixed') {
        $cfgLines[$appendIndex] += " xbox_terminal_font=$TerminalFont"
    }
    [System.IO.File]::WriteAllLines($cfgPath, $cfgLines, [System.Text.Encoding]::ASCII)
    $cfg = [System.IO.File]::ReadAllText($cfgPath)
    if ($cfg -notmatch "xbox_disk_readahead_kb=$DiskReadAheadKb" -or
        $cfg -notmatch "xbox_fatx_loop_readahead_kb=$ReadAheadKb" -or
        $cfg -notmatch "xbox_loop_readahead_kb=$ReadAheadKb") {
        throw "Failed to add read-ahead settings to $cfgPath"
    }
    if ($XHotset -and $cfg -notmatch 'xbox_x_hotset=1') {
        throw "Failed to enable the X hotset in $cfgPath"
    }
    if ($ReleaseXHotset -and $cfg -notmatch 'xbox_x_hotset_release=1') {
        throw "Failed to enable X hotset release in $cfgPath"
    }
    if ($RemoteDiagnostics -and $cfg -notmatch 'xbox_remote_diag=1') {
        throw "Failed to enable remote diagnostics in $cfgPath"
    }
    if ($TerminalFont -ne 'fixed' -and $cfg -notmatch "xbox_terminal_font=$TerminalFont") {
        throw "Failed to set the terminal font in $cfgPath"
    }
}

$desktopOrder = if ($XHotset) {
    '  - start FLWM and the proof terminal, load the wallpaper, then launch wbar'
} else {
    '  - start FLWM, the proof terminal, and wbar before loading the wallpaper'
}
$hotsetDetails = if ($XHotset) {
@'
  - materialize the measured Xfbdev/X11 startup hotset into RAM before X starts
  - record hotset timing and memory snapshots under /tmp/xbox-hotset-*
  - start wbar after the wallpaper so its faux-transparent background is valid
'@
} else {
    ''
}
$hotsetReleaseDetails = if ($ReleaseXHotset) {
@'
  - restore the original squashfs links after the desktop has started
  - record reclamation status and memory under /tmp/xbox-hotset-release.txt
'@
} else {
    ''
}
$remoteDetails = if ($RemoteDiagnostics) {
@'
  - add the Tiny Core 11 Dropbear extension to the isolated payload
  - start SSH on tcp/22 after DHCP succeeds, with root login disabled
  - configure the tc/tcuser diagnostic login for this LAN test image
'@
} else {
    ''
}
$candidateTitle = if ($XHotset) {
    "Tiny Core HDD X-Hotset RA${ReadAheadKb} Candidate"
} else {
    "Tiny Core HDD UI-First RA${ReadAheadKb} Candidate"
}

$readmeBody = if ($ProtectedControl) {
@"
Tiny Core HDD Protected Control
===============================

This is an exact extraction of the hash-verified hardware-passed Tiny Core
lean ZIP. It exists only to test the protected boot files through the same
fresh-disk xemu harness as the RA128 candidate.
"@
} else {
@"
$candidateTitle
================================================

This is an isolated candidate derived from the hardware-passed Tiny Core lean
ZIP. Copy default.xbe to a dashboard app folder and copy E-root contents to E:.

Candidate changes:
$desktopOrder
  - record desktop startup milestones in /tmp/xbox-desktop-timing.txt
  - preserve physical-disk read-ahead at ${DiskReadAheadKb} KiB
  - set the FATX loop read-ahead to ${ReadAheadKb} KiB immediately after attach
  - set the ext2 root loop read-ahead to ${ReadAheadKb} KiB immediately after attach
  - make xbox-storage-tune honor the same command-line values
$hotsetDetails
$hotsetReleaseDetails
$remoteDetails
  - use terminal font $TerminalFont

The protected ZIP is hash-verified and is never modified.
"@
}
$readmeBody | Set-Content -LiteralPath (Join-Path $candidateDir 'README-CANDIDATE.txt') -Encoding ASCII

$files = Get-FileHashMap $candidateDir
Compress-Archive -Path (Join-Path $candidateDir '*') -DestinationPath $candidateZip -CompressionLevel Optimal
$manifest = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = if ($ProtectedControl) { 'Unmodified protected Tiny Core HDD/FATX control' } elseif ($RemoteDiagnostics -and $ReleaseXHotset) { "Tiny Core HDD/FATX releasable X-hotset remote-diagnostics ${ReadAheadKb} KiB loop read-ahead candidate" } elseif ($RemoteDiagnostics) { "Tiny Core HDD/FATX X-hotset remote-diagnostics ${ReadAheadKb} KiB loop read-ahead candidate" } elseif ($XHotset) { "Tiny Core HDD/FATX X-hotset ${ReadAheadKb} KiB loop read-ahead candidate" } else { "Tiny Core HDD/FATX UI-first ${ReadAheadKb} KiB loop read-ahead candidate" }
    protectedSource = [ordered]@{
        zip = $ProtectedZip.Replace('\', '/')
        zipSha256 = $protectedZipSha256
    }
    candidate = [ordered]@{
        directory = $candidateName
        zip = [System.IO.Path]::GetFileName($candidateZip)
        zipSha256 = (Get-FileHash -LiteralPath $candidateZip -Algorithm SHA256).Hash
        diskReadAheadKb = if ($ProtectedControl) { $null } else { $DiskReadAheadKb }
        fatxLoopReadAheadKb = if ($ProtectedControl) { $null } else { $ReadAheadKb }
        rootLoopReadAheadKb = if ($ProtectedControl) { $null } else { $ReadAheadKb }
        xHotset = if ($ProtectedControl) { $false } else { [bool]$XHotset }
        xHotsetRelease = if ($ProtectedControl) { $false } else { [bool]$ReleaseXHotset }
        xHotsetExtensions = if ($XHotset) { @('libXau', 'libXdmcp', 'libxcb', 'libX11', 'Xlibs', 'libpng', 'freetype', 'libfontenc', 'libXfont', 'Xfbdev') } else { @() }
        remoteDiagnostics = [bool]$RemoteDiagnostics
        remoteService = if ($RemoteDiagnostics) { 'Dropbear SSH tcp/22; tc login; root disabled' } else { $null }
        terminalFont = $TerminalFont
        replacementPayload = if ($payloadFull) { [ordered]@{ path = $PayloadPath.Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $payloadFull -Algorithm SHA256).Hash } } else { $null }
        protectedControl = [bool]$ProtectedControl
        files = $files
    }
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outFull 'candidate-manifest.json') -Encoding ASCII

[pscustomobject]@{
    directory = $candidateDir
    zip = $candidateZip
    zipSha256 = $manifest.candidate.zipSha256
    kernelSha256 = $files.'E-root/vmlinuz'
    initramfsSha256 = $files.'E-root/initramf'
    payloadSha256 = $files.'E-root/linuxroot.ext2'
}
