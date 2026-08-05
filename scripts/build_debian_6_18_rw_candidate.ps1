[CmdletBinding()]
param(
    [string]$OutRoot = 'artifacts\debian-6.18.33-rw-candidate',
    [string]$KernelPath = 'artifacts\kernels\xbox-linux-6.18.33-fatx-rw-existing-bzImage',
    [string]$KernelExpectedHash = '0AC26C6FB52F89503DE2E7ADAD65DC856A12A06B13D51F9AC430B7CE9AB40546',
    [string]$KernelSourceCommit = '829b71ab17ed',
    [string]$WslDistro = 'Ubuntu-24.04',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outFull = if ([System.IO.Path]::IsPathRooted($OutRoot)) {
    [System.IO.Path]::GetFullPath($OutRoot)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
}
$packageId = 'xromwell-hddfatx-debian-bookworm-6.18.33-rw-shell'
$packageDir = Join-Path $outFull $packageId
$packageZip = Join-Path $outFull "$packageId.zip"
$sourceDir = Join-Path $repoRoot 'build\debian-6.18.33-rw-candidate-sources'
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'

$baselineArchive = Join-Path $repoRoot 'artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386.zip'
$baselineArchiveHash = 'D1B5024AB4A5910F035A1A632209EAC2CDAC4D40621B35DEB6BC2F308B17F383'
$xbeHash = 'C78475E8713EC694F484C40209966805E9F9CD267E7C2EE6A3B9217E40FE0CD2'
$initrdHash = '7CADFFDE0B78BA6C263DAD34B69862642A622A9491AD69B9CCFA1B40C0CF6CCB'
$kernel = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $KernelPath))
$kernelHash = $KernelExpectedHash
$kernelConfig = Join-Path $repoRoot 'artifacts\kernels\xbox-linux-6.18.33-fatx-rw-existing.config'
$kernelConfigHash = '6B895CCB8923F09FBA2B17BF1436F8676B2808BCCC326515C626C336C37BA205'
$payload = Join-Path $repoRoot 'artifacts\hdd\xbox-debian-bookworm-i386.ext2'
$payloadHash = 'D9ED5D6BE065592E6553C574DF8D61A20DA72A9B29E53B2D940E56279CEDE6A2'
$payloadCandidate = Join-Path $sourceDir 'rwdebian.ext2'
$syncRoOverlay = Join-Path $repoRoot 'rootfs-overlays\debian\usr\local\bin\xbox-sync-ro'
$initOverlay = Join-Path $repoRoot 'rootfs-overlays\debian\xbox-init'
$remountStatusOverlay = Join-Path $repoRoot 'rootfs-overlays\debian\root\xbox-remount-status.txt'
$xbe = Join-Path $sourceDir 'default.xbe'
$initrd = Join-Path $sourceDir 'rwinit'
$append = 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/rwdebian.ext2 xbox_root_init=/xbox-init xbox_fatx_mode=rw xbox_root_mode=rw xbox_persist_smoke=1 xbox_sync_ro_smoke=1 xbox_no_early_helpers=1'

function Assert-Hash {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required input was not found: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) {
        throw "SHA-256 mismatch for $Path. Expected $Expected, got $actual"
    }
}

function Assert-PathBelowRepo {
    param([string]$Path, [string]$Description)
    $repoPrefix = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if (-not $pathFull.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description must stay below the repository root: $pathFull"
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

function Get-TreeHashes {
    param([string]$Directory)
    $hashes = [ordered]@{}
    Get-ChildItem -LiteralPath $Directory -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative = (Get-RelativePath -BasePath $Directory -TargetPath $_.FullName).Replace('\', '/')
        $hashes[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
    $hashes
}

function ConvertTo-WslPath {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full -notmatch '^([A-Za-z]):\\(.*)$') { throw "Cannot convert path to WSL form: $full" }
    '/mnt/{0}/{1}' -f $Matches[1].ToLowerInvariant(), $Matches[2].Replace('\', '/')
}

function Invoke-WslTool {
    param([string[]]$Arguments, [string]$Description)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = (& wsl -d $WslDistro -u root -- @Arguments 2>&1) -join "`n"
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne 0) { throw "$Description failed (exit $exitCode).`n$output" }
    $output
}

Assert-PathBelowRepo $outFull 'Candidate output directory'
Assert-PathBelowRepo $sourceDir 'Candidate source directory'

foreach ($inputLock in @(
    @($baselineArchive, $baselineArchiveHash),
    @($kernel, $kernelHash),
    @($kernelConfig, $kernelConfigHash),
    @($payload, $payloadHash)
)) {
    Assert-Hash $inputLock[0] $inputLock[1]
}
if (-not (Test-Path -LiteralPath $syncRoOverlay -PathType Leaf)) {
    throw "Required rootfs overlay was not found: $syncRoOverlay"
}
if (-not (Test-Path -LiteralPath $initOverlay -PathType Leaf)) {
    throw "Required rootfs overlay was not found: $initOverlay"
}
if (-not (Test-Path -LiteralPath $remountStatusOverlay -PathType Leaf)) {
    throw "Required rootfs overlay was not found: $remountStatusOverlay"
}
if (-not (Select-String -LiteralPath $kernelConfig -Pattern '^CONFIG_FATX_FS=y$' -Quiet)) {
    throw 'The write candidate kernel does not have built-in FATX support.'
}
if (Test-Path -LiteralPath $outFull) {
    if (-not $Force) { throw "Output already exists: $outFull. Re-run with -Force to replace it." }
    Remove-Item -Recurse -Force -LiteralPath $outFull
}
Remove-Item -Recurse -Force -LiteralPath $sourceDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $outFull, $sourceDir | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($baselineArchive)
try {
    $xbeEntry = $archive.Entries | Where-Object { $_.FullName.Replace('\', '/') -eq 'default.xbe' } | Select-Object -First 1
    $initrdEntry = $archive.Entries | Where-Object { $_.FullName.Replace('\', '/') -eq 'E-root/devinit' } | Select-Object -First 1
    if (-not $xbeEntry -or -not $initrdEntry) {
        throw 'The protected 6.18 baseline is missing default.xbe or E-root/devinit.'
    }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($xbeEntry, $xbe, $true)
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($initrdEntry, $initrd, $true)
}
finally {
    $archive.Dispose()
}
Assert-Hash $xbe $xbeHash
Assert-Hash $initrd $initrdHash

Copy-Item -LiteralPath $payload -Destination $payloadCandidate
$payloadWsl = ConvertTo-WslPath $payloadCandidate
$overlayWsl = ConvertTo-WslPath $syncRoOverlay
$initOverlayWsl = ConvertTo-WslPath $initOverlay
$remountStatusOverlayWsl = ConvertTo-WslPath $remountStatusOverlay
Invoke-WslTool @('/usr/sbin/debugfs', '-w', '-R', 'rm /usr/local/bin/xbox-sync-ro', $payloadWsl) 'Removing the old xbox-sync-ro helper' | Out-Null
Invoke-WslTool @('/usr/sbin/debugfs', '-w', '-R', "write $overlayWsl /usr/local/bin/xbox-sync-ro", $payloadWsl) 'Injecting the updated xbox-sync-ro helper' | Out-Null
Invoke-WslTool @('/usr/sbin/debugfs', '-w', '-R', 'set_inode_field /usr/local/bin/xbox-sync-ro mode 0100755', $payloadWsl) 'Marking xbox-sync-ro executable' | Out-Null
Invoke-WslTool @('/usr/sbin/debugfs', '-w', '-R', 'rm /xbox-init', $payloadWsl) 'Removing the old xbox-init' | Out-Null
Invoke-WslTool @('/usr/sbin/debugfs', '-w', '-R', "write $initOverlayWsl /xbox-init", $payloadWsl) 'Injecting the updated xbox-init' | Out-Null
Invoke-WslTool @('/usr/sbin/debugfs', '-w', '-R', 'set_inode_field /xbox-init mode 0100755', $payloadWsl) 'Marking xbox-init executable' | Out-Null
Invoke-WslTool @('/usr/sbin/debugfs', '-w', '-R', 'rm /root/xbox-remount-status.txt', $payloadWsl) 'Removing the old remount status file' | Out-Null
Invoke-WslTool @('/usr/sbin/debugfs', '-w', '-R', "write $remountStatusOverlayWsl /root/xbox-remount-status.txt", $payloadWsl) 'Injecting the remount status file' | Out-Null
$payloadFsck = Invoke-WslTool @('/usr/sbin/e2fsck', '-fn', $payloadWsl) 'Validating the candidate payload'
if ($payloadFsck -match 'filesystem still has errors|UNEXPECTED INCONSISTENCY|WARNING') {
    throw "Candidate payload failed read-only fsck.`n$payloadFsck"
}

& $packager `
    -OutDir (Get-RelativePath -BasePath $repoRoot -TargetPath $packageDir) `
    -XbePath (Get-RelativePath -BasePath $repoRoot -TargetPath $xbe) `
    -KernelPath (Get-RelativePath -BasePath $repoRoot -TargetPath $kernel) `
    -KernelName 'rwkrnl' `
    -InitrdPath (Get-RelativePath -BasePath $repoRoot -TargetPath $initrd) `
    -InitrdName 'rwinit' `
    -PayloadPath (Get-RelativePath -BasePath $repoRoot -TargetPath $payloadCandidate) `
    -PayloadName 'rwdebian.ext2' `
    -Append $append `
    -PackageTitle 'Debian Bookworm Linux 6.18.33 FATX RW Shell Safety Candidate' `
    -DashboardFolder 'XboxLinuxDebian618RwShell' `
    -NoZip | Out-Null

@"
WARNING: EXPERIMENTAL FATX WRITE CANDIDATE
==========================================

Do not install this package on real hardware until the disposable-xemu
two-boot safety gate passes and the hardware checklist is explicitly updated.

This package uses isolated E: filenames:
  E:\rwkrnl
  E:\rwinit
  E:\rwdebian.ext2

E:\linuxboot.cfg is the only shared filename. Back it up before any eventual
hardware test. Never rename these files to the read-only release names and
never mix this E-root with another package.

The FATX driver can overwrite blocks inside an existing file only. It cannot
create, delete, rename, extend, or allocate FATX files.
"@ | Set-Content -LiteralPath (Join-Path $packageDir 'RW-SAFETY-WARNING.txt') -Encoding ASCII

@"
# Exact install set

This directory is self-contained. The dashboard launches `default.xbe`.
The complete `E-root` set must remain together:

- `linuxboot.cfg`
- `rwkrnl`
- `rwinit`
- `rwdebian.ext2`

The shell-only smoke writes two marker files inside `rwdebian.ext2`, replaces
PID 1 with the sync helper, and stops after requesting a read-only root
remount. It does not start X or launch a proof shell.
"@ | Set-Content -LiteralPath (Join-Path $packageDir 'INSTALL-SET.md') -Encoding ASCII

Compress-Archive -Path (Join-Path $packageDir '*') -DestinationPath $packageZip -CompressionLevel Optimal
$manifest = [ordered]@{
    schemaVersion = 1
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Disposable-xemu Debian 6.18.33 FATX existing-file write safety candidate'
    hardwareState = 'requires-successful-xemu-gate-and-hardware-validation'
    package = [ordered]@{
        id = $packageId
        directory = $packageId
        zip = "$packageId.zip"
        zipSha256 = (Get-FileHash -LiteralPath $packageZip -Algorithm SHA256).Hash
        files = Get-TreeHashes $packageDir
    }
    boot = [ordered]@{
        kernel = 'rwkrnl'
        initrd = 'rwinit'
        payload = 'rwdebian.ext2'
        append = $append
    }
    sourceLocks = [ordered]@{
        baselineArchive = [ordered]@{ path = 'artifacts/softmod/xromwell-hddfatx-devuan-daedalus-i386.zip'; sha256 = $baselineArchiveHash }
        xromwell = [ordered]@{ lineage = '4dcc618'; sha256 = $xbeHash }
        stage1 = [ordered]@{ sourceEntry = 'E-root/devinit'; sha256 = $initrdHash }
        kernel = [ordered]@{ path = $KernelPath.Replace('\', '/'); sha256 = $kernelHash; sourceCommit = $KernelSourceCommit }
        kernelConfig = [ordered]@{ path = 'artifacts/kernels/xbox-linux-6.18.33-fatx-rw-existing.config'; sha256 = $kernelConfigHash }
        payloadBase = [ordered]@{ path = 'artifacts/hdd/xbox-debian-bookworm-i386.ext2'; sha256 = $payloadHash }
        syncRoOverlay = [ordered]@{ path = 'rootfs-overlays/debian/usr/local/bin/xbox-sync-ro'; sha256 = (Get-FileHash -LiteralPath $syncRoOverlay -Algorithm SHA256).Hash }
        initOverlay = [ordered]@{ path = 'rootfs-overlays/debian/xbox-init'; sha256 = (Get-FileHash -LiteralPath $initOverlay -Algorithm SHA256).Hash }
        remountStatusOverlay = [ordered]@{ path = 'rootfs-overlays/debian/root/xbox-remount-status.txt'; sha256 = (Get-FileHash -LiteralPath $remountStatusOverlay -Algorithm SHA256).Hash }
        payloadCandidate = [ordered]@{ generatedPath = 'build/debian-6.18.33-rw-candidate-sources/rwdebian.ext2'; sha256 = (Get-FileHash -LiteralPath $payloadCandidate -Algorithm SHA256).Hash }
    }
}
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $outFull 'manifest.json') -Encoding ASCII

Get-ChildItem -LiteralPath $outFull -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object Name | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash, $_.Name
} | Set-Content -LiteralPath (Join-Path $outFull 'SHA256SUMS.txt') -Encoding ASCII

Get-ChildItem -LiteralPath $outFull | Select-Object Name, Length, LastWriteTime
