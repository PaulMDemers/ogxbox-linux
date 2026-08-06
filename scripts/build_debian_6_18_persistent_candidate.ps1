[CmdletBinding()]
param(
    [string]$OutRoot = 'artifacts\debian-6.18.33-persistent-shell-candidate',
    [string]$WslDistro = 'Ubuntu-24.04',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outFull = if ([System.IO.Path]::IsPathRooted($OutRoot)) {
    [System.IO.Path]::GetFullPath($OutRoot)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
}
$packageId = 'xromwell-hddfatx-debian-bookworm-6.18.33-persistent-shell'
$packageDir = Join-Path $outFull $packageId
$packageZip = Join-Path $outFull "$packageId.zip"
$sourceDir = Join-Path $repoRoot 'build\debian-6.18.33-persistent-shell-sources'
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'

$baselineZip = Join-Path $repoRoot 'artifacts\debian-6.18.33-rw-candidate\xromwell-hddfatx-debian-bookworm-6.18.33-rw-shell.zip'
$baselineZipHash = '494E1798C2686A9DD774717B5C62D4971189816DD4DEC2DB69B4AF41605DD738'
$xbeHash = 'C78475E8713EC694F484C40209966805E9F9CD267E7C2EE6A3B9217E40FE0CD2'
$kernelHash = '0AC26C6FB52F89503DE2E7ADAD65DC856A12A06B13D51F9AC430B7CE9AB40546'
$initrdHash = '7CADFFDE0B78BA6C263DAD34B69862642A622A9491AD69B9CCFA1B40C0CF6CCB'
$payloadHash = '4F7AA468A0D63D18D2EE855C650CBE9E839457CD020282C9FBFAAF3C10969A7B'

$xbe = Join-Path $sourceDir 'default.xbe'
$kernel = Join-Path $sourceDir 'pskrnl'
$initrd = Join-Path $sourceDir 'psinit'
$payload = Join-Path $sourceDir 'psdebian.ext2'
$initOverlay = Join-Path $repoRoot 'rootfs-overlays\debian-persistent\xbox-persistent-init'
$shutdownOverlay = Join-Path $repoRoot 'rootfs-overlays\debian-persistent\usr\local\bin\xbox-persistent-shutdown'
$statusOverlay = Join-Path $repoRoot 'rootfs-overlays\debian-persistent\root\xbox-shutdown-status.txt'
$append = 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/psdebian.ext2 xbox_root_init=/xbox-persistent-init xbox_fatx_mode=rw xbox_root_mode=rw xbox_diag=off'

function Assert-PathBelowRepo {
    param([string]$Path, [string]$Description)
    $repoPrefix = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/') + '\'
    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description must stay below the repository root: $full"
    }
}

function Assert-Hash {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required file was not found: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) { throw "SHA-256 mismatch for $Path. Expected $Expected, got $actual" }
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
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = (& wsl -d $WslDistro -u root -- @Arguments 2>&1) -join "`n"
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldPreference
    }
    if ($exitCode -ne 0) { throw "$Description failed (exit $exitCode).`n$output" }
    $output
}

function Inject-File {
    param([string]$Source, [string]$Target, [string]$Mode)
    $payloadWsl = ConvertTo-WslPath $payload
    $sourceWsl = ConvertTo-WslPath $Source
    Invoke-WslTool @('/usr/sbin/debugfs', '-w', '-R', "rm $Target", $payloadWsl) "Removing old $Target" | Out-Null
    Invoke-WslTool @('/usr/sbin/debugfs', '-w', '-R', "write $sourceWsl $Target", $payloadWsl) "Injecting $Target" | Out-Null
    if ($Mode) {
        Invoke-WslTool @('/usr/sbin/debugfs', '-w', '-R', "set_inode_field $Target mode $Mode", $payloadWsl) "Setting mode on $Target" | Out-Null
    }
}

Assert-PathBelowRepo $outFull 'Candidate output directory'
Assert-PathBelowRepo $sourceDir 'Candidate source directory'
Assert-Hash $baselineZip $baselineZipHash
foreach ($overlay in @($initOverlay, $shutdownOverlay, $statusOverlay)) {
    if (-not (Test-Path -LiteralPath $overlay -PathType Leaf)) { throw "Required overlay was not found: $overlay" }
}
if (Test-Path -LiteralPath $outFull) {
    if (-not $Force) { throw "Output already exists: $outFull. Re-run with -Force to replace it." }
    Remove-Item -Recurse -Force -LiteralPath $outFull
}
Remove-Item -Recurse -Force -LiteralPath $sourceDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $outFull, $sourceDir | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($baselineZip)
try {
    $entries = @{
        'default.xbe' = $xbe
        'E-root/rwkrnl' = $kernel
        'E-root/rwinit' = $initrd
        'E-root/rwdebian.ext2' = $payload
    }
    foreach ($entryName in $entries.Keys) {
        $entry = $archive.Entries | Where-Object { $_.FullName.Replace('\', '/') -eq $entryName } | Select-Object -First 1
        if (-not $entry) { throw "The hardware-passed baseline is missing $entryName" }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $entries[$entryName], $true)
    }
} finally {
    $archive.Dispose()
}
Assert-Hash $xbe $xbeHash
Assert-Hash $kernel $kernelHash
Assert-Hash $initrd $initrdHash
Assert-Hash $payload $payloadHash

Inject-File -Source $initOverlay -Target '/xbox-persistent-init' -Mode '0100755'
Inject-File -Source $shutdownOverlay -Target '/usr/local/bin/xbox-persistent-shutdown' -Mode '0100755'
Inject-File -Source $statusOverlay -Target '/root/xbox-shutdown-status.txt' -Mode '0100644'

$payloadWsl = ConvertTo-WslPath $payload
$fsck = Invoke-WslTool @('/usr/sbin/e2fsck', '-fn', $payloadWsl) 'Validating the persistent payload'
if ($fsck -match 'filesystem still has errors|UNEXPECTED INCONSISTENCY|WARNING') {
    throw "Persistent payload failed read-only fsck.`n$fsck"
}

& $packager `
    -OutDir (Get-RelativePath -BasePath $repoRoot -TargetPath $packageDir) `
    -XbePath (Get-RelativePath -BasePath $repoRoot -TargetPath $xbe) `
    -KernelPath (Get-RelativePath -BasePath $repoRoot -TargetPath $kernel) `
    -KernelName 'pskrnl' `
    -InitrdPath (Get-RelativePath -BasePath $repoRoot -TargetPath $initrd) `
    -InitrdName 'psinit' `
    -PayloadPath (Get-RelativePath -BasePath $repoRoot -TargetPath $payload) `
    -PayloadName 'psdebian.ext2' `
    -Append $append `
    -PackageTitle 'Debian Bookworm Linux 6.18.33 Persistent Shell Candidate' `
    -DashboardFolder 'XboxLinuxDebian618PersistentShell' `
    -NoZip | Out-Null

@"
EXPERIMENTAL PERSISTENT DEBIAN SHELL
====================================

This package is derived byte-for-byte from the hardware-passed Debian 6.18.33
FATX existing-file write baseline, then given separate init and shutdown helpers.

Always run `xbox-persistent-shutdown` before powering off or resetting. A failed
read-only remount deliberately leaves the Xbox running with an error message.

The complete isolated E: set is:
  E:\linuxboot.cfg
  E:\pskrnl
  E:\psinit
  E:\psdebian.ext2

Never mix these files with the protected rw* safety package or another E-root.
The FATX driver still cannot create, delete, rename, extend, or allocate files.
"@ | Set-Content -LiteralPath (Join-Path $packageDir 'PERSISTENCE-WARNING.txt') -Encoding ASCII

@"
# Exact install set

Copy `default.xbe` and `E-root` from this one package only. Changes made inside
the Debian root persist in `psdebian.ext2` after a clean shutdown.

At the shell, write files normally under `/root`. Finish every session with:

    xbox-persistent-shutdown

Wait for Linux to power the console off. Do not interrupt a read-only remount.
"@ | Set-Content -LiteralPath (Join-Path $packageDir 'INSTALL-SET.md') -Encoding ASCII

Compress-Archive -Path (Join-Path $packageDir '*') -DestinationPath $packageZip -CompressionLevel Optimal
$manifest = [ordered]@{
    schemaVersion = 1
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Interactive persistent Debian 6.18.33 shell using existing-file-only FATX writes'
    hardwareState = 'requires-xemu-gate-and-real-hardware-validation'
    package = [ordered]@{
        id = $packageId
        directory = $packageId
        zip = "$packageId.zip"
        zipSha256 = (Get-FileHash -LiteralPath $packageZip -Algorithm SHA256).Hash
        files = Get-TreeHashes $packageDir
    }
    boot = [ordered]@{ kernel = 'pskrnl'; initrd = 'psinit'; payload = 'psdebian.ext2'; append = $append }
    sourceLocks = [ordered]@{
        hardwarePassedZip = [ordered]@{ path = 'artifacts/debian-6.18.33-rw-candidate/xromwell-hddfatx-debian-bookworm-6.18.33-rw-shell.zip'; sha256 = $baselineZipHash }
        xromwell = [ordered]@{ sha256 = $xbeHash }
        kernel = [ordered]@{ sha256 = $kernelHash; sourceCommit = '829b71ab17ed' }
        stage1 = [ordered]@{ sha256 = $initrdHash }
        payloadBase = [ordered]@{ sha256 = $payloadHash }
        persistentInit = [ordered]@{ path = 'rootfs-overlays/debian-persistent/xbox-persistent-init'; sha256 = (Get-FileHash $initOverlay -Algorithm SHA256).Hash }
        shutdownHelper = [ordered]@{ path = 'rootfs-overlays/debian-persistent/usr/local/bin/xbox-persistent-shutdown'; sha256 = (Get-FileHash $shutdownOverlay -Algorithm SHA256).Hash }
        shutdownStatus = [ordered]@{ path = 'rootfs-overlays/debian-persistent/root/xbox-shutdown-status.txt'; sha256 = (Get-FileHash $statusOverlay -Algorithm SHA256).Hash }
        payloadCandidate = [ordered]@{ generatedPath = 'build/debian-6.18.33-persistent-shell-sources/psdebian.ext2'; sha256 = (Get-FileHash $payload -Algorithm SHA256).Hash }
    }
}
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $outFull 'manifest.json') -Encoding ASCII

Get-ChildItem -LiteralPath $outFull -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object Name | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash, $_.Name
} | Set-Content -LiteralPath (Join-Path $outFull 'SHA256SUMS.txt') -Encoding ASCII

Get-ChildItem -LiteralPath $outFull | Select-Object Name, Length, LastWriteTime
