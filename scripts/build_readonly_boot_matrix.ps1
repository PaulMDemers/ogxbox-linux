[CmdletBinding()]
param(
    [string]$OutRoot = 'artifacts\readonly-boot-matrix',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutRoot))
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$launcherArchive = Join-Path $repoRoot 'artifacts\softmod\xromwell-hddfatx-devuan-loader-3fa5e65-sector512.zip'
$launcherHash = '81B3A6850627A8BEC6FA0D92BB4652400DB3EC863072EAA7351BB159DED0BAFD'
$launcherBuild = Join-Path $repoRoot 'build\readonly-matrix-xromwell-3fa5e65-sector512'
$launcher = Join-Path $launcherBuild 'default.xbe'
$launcher618Hash = 'C78475E8713EC694F484C40209966805E9F9CD267E7C2EE6A3B9217E40FE0CD2'
$launcher618Build = Join-Path $repoRoot 'build\readonly-matrix-xromwell-4dcc618'
$launcher618 = Join-Path $launcher618Build 'default.xbe'
$initrd618 = Join-Path $launcher618Build 'xbox-distro-hdd-ext2-stage1-6.18.33.cpio'
$loader618Iso = Join-Path $outFull 'xromwell-4dcc618-loader.iso'
$xdvdfs = Join-Path $repoRoot 'tools\xdvdfs\xdvdfs.exe'

$sources = [ordered]@{
    kernel58 = [ordered]@{
        path = 'artifacts\kernels\xbox-linux-5.8.1-fatx-rd-gzip-bzImage'
        sha256 = '6F5C27B134144EDEB8F7138242FFFAD50571B3F76733374D0A4A4E3D5BE3B577'
    }
    config58 = [ordered]@{
        path = 'artifacts\kernels\xbox-linux-5.8.1-fatx-rd-gzip.config'
        sha256 = 'E0E714A373C58017005CABABA6489280737BDF4E74BF6DF9FA3C0A4C8D5D8627'
    }
    kernel618 = [ordered]@{
        path = 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage'
        sha256 = 'D3C812196908F8F2CA96C7863184C59C39982E27A2DD1ED6DFF125D5DA9FCAFE'
    }
    config618 = [ordered]@{
        path = 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore.config'
        sha256 = '6B895CCB8923F09FBA2B17BF1436F8676B2808BCCC326515C626C336C37BA205'
    }
    initrd58 = [ordered]@{
        path = 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio'
        sha256 = 'EC6633C838976C8EF1C6B6678164F16B5689066EFF6A9E58E6752E3900F9B23E'
    }
    devuan618Baseline = [ordered]@{
        path = 'artifacts\softmod\xromwell-hddfatx-devuan-daedalus-i386.zip'
        sha256 = 'D1B5024AB4A5910F035A1A632209EAC2CDAC4D40621B35DEB6BC2F308B17F383'
    }
    debian = [ordered]@{
        path = 'artifacts\hdd\xbox-debian-bookworm-i386.ext2'
        sha256 = 'D9ED5D6BE065592E6553C574DF8D61A20DA72A9B29E53B2D940E56279CEDE6A2'
    }
    devuan58 = [ordered]@{
        path = 'artifacts\devuan-5.8.1-nondisc\devuan-daedalus-desktop-live-5.8.1-xbe.zip'
        sha256 = 'CB01ED5C384E7B2E6B0A16C74D7C2FFECE609A50D95C6577C1A926A2279CE7D6'
    }
    tinycore618 = [ordered]@{
        path = 'artifacts\tinycore-6.18.33-nondisc\tinycore11-desktop-6.18.33-apps-default-mirror-xbe.zip'
        sha256 = 'B914A6B513009CE84422EE881996B09F96F75196F65D3F3FB39B0B272478F6F0'
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

function Get-PackageHashes {
    param([string]$Directory)
    $hashes = [ordered]@{}
    Get-ChildItem -LiteralPath $Directory -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative = (Get-RelativePath -BasePath $Directory -TargetPath $_.FullName).Replace('\', '/')
        $hashes[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
    $hashes
}

function Expand-ProtectedPackage {
    param(
        [string]$Id,
        [string]$ZipPath,
        [string]$ZipHash,
        [string]$Distro,
        [string]$Release,
        [string]$KernelVersion,
        [string]$KernelName,
        [string]$InitrdName,
        [string]$PayloadName,
        [string]$ProofProfile,
        [string]$HardwareState
    )
    Assert-Hash $ZipPath $ZipHash
    $directory = Join-Path $outFull $Id
    $zipDestination = Join-Path $outFull "$Id.zip"
    Copy-Item -LiteralPath $ZipPath -Destination $zipDestination
    Expand-Archive -LiteralPath $zipDestination -DestinationPath $directory
    $cfgPath = Join-Path $directory 'E-root\linuxboot.cfg'
    $appendLine = Get-Content -LiteralPath $cfgPath | Where-Object { $_ -like 'append *' } | Select-Object -First 1
    if (-not $appendLine) { throw "No append line was found in $cfgPath" }
    [ordered]@{
        id = $Id
        distro = $Distro
        release = $Release
        kernelVersion = $KernelVersion
        sourceKind = 'protected-copy'
        hardwareState = $HardwareState
        proofProfile = $ProofProfile
        directory = $Id
        zip = "$Id.zip"
        zipSha256 = $ZipHash
        xromwellSha256 = (Get-FileHash -LiteralPath (Join-Path $directory 'default.xbe') -Algorithm SHA256).Hash
        xemuLoader = if ((Get-FileHash -LiteralPath (Join-Path $directory 'default.xbe') -Algorithm SHA256).Hash -eq $launcherHash) { 'sector512' } else { '4dcc618' }
        boot = [ordered]@{
            kernel = $KernelName
            initrd = $InitrdName
            payload = $PayloadName
            append = $appendLine.Substring('append '.Length)
        }
        files = Get-PackageHashes $directory
    }
}

function New-MatrixPackage {
    param(
        [string]$Id,
        [string]$Title,
        [string]$DashboardFolder,
        [string]$Distro,
        [string]$Release,
        [string]$KernelVersion,
        [string]$KernelPath,
        [string]$KernelName,
        [string]$XbePath,
        [string]$XbeHash,
        [string]$InitrdPath,
        [string]$InitrdName,
        [string]$PayloadPath,
        [string]$PayloadName,
        [string]$Append
    )
    $directory = Join-Path $outFull $Id
    & $packager `
        -OutDir (Get-RelativePath -BasePath $repoRoot -TargetPath $directory) `
        -XbePath (Get-RelativePath -BasePath $repoRoot -TargetPath $XbePath) `
        -KernelPath (Get-RelativePath -BasePath $repoRoot -TargetPath $KernelPath) `
        -KernelName $KernelName `
        -InitrdPath (Get-RelativePath -BasePath $repoRoot -TargetPath $InitrdPath) `
        -InitrdName $InitrdName `
        -PayloadPath (Get-RelativePath -BasePath $repoRoot -TargetPath $PayloadPath) `
        -PayloadName $PayloadName `
        -Append $Append `
        -PackageTitle $Title `
        -DashboardFolder $DashboardFolder `
        -NoZip | Out-Null

    $zip = Join-Path $outFull "$Id.zip"
    Compress-Archive -Path (Join-Path $directory '*') -DestinationPath $zip -CompressionLevel Optimal
    [ordered]@{
        id = $Id
        distro = $Distro
        release = $Release
        kernelVersion = $KernelVersion
        sourceKind = 'matrix-build'
        hardwareState = 'pending'
        proofProfile = 'desktop-x'
        directory = $Id
        zip = "$Id.zip"
        zipSha256 = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
        xromwellSha256 = $XbeHash
        xemuLoader = if ($XbeHash -eq $launcherHash) { 'sector512' } else { '4dcc618' }
        boot = [ordered]@{
            kernel = $KernelName
            initrd = $InitrdName
            payload = $PayloadName
            append = $Append
        }
        files = Get-PackageHashes $directory
    }
}

foreach ($source in $sources.Values) {
    Assert-Hash (Join-Path $repoRoot $source.path) $source.sha256
}
Assert-Hash $launcherArchive '49AD5B70653A3E23BB3DEF4FA2D33C4EE366787BAC99A45DD5D10AF30806F30B'
if (-not (Select-String -LiteralPath (Join-Path $repoRoot $sources.config58.path) -Pattern '^CONFIG_FATX_FS=y$' -Quiet)) {
    throw 'The Linux 5.8.1 matrix kernel does not have built-in FATX support.'
}
if (-not (Select-String -LiteralPath (Join-Path $repoRoot $sources.config618.path) -Pattern '^CONFIG_FATX_FS=y$' -Quiet)) {
    throw 'The Linux 6.18.33 matrix kernel does not have built-in FATX support.'
}

if (-not (Test-Path -LiteralPath $xdvdfs -PathType Leaf)) {
    throw "Required tool was not found: $xdvdfs"
}
if (Test-Path -LiteralPath $outFull) {
    if (-not $Force) { throw "Output already exists: $outFull. Re-run with -Force to replace it." }
    Remove-Item -Recurse -Force -LiteralPath $outFull
}
New-Item -ItemType Directory -Force -Path $outFull, $launcherBuild, $launcher618Build | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($launcherArchive)
try {
    $entry = $archive.Entries | Where-Object Name -eq 'default.xbe' | Select-Object -First 1
    if (-not $entry) { throw "default.xbe is missing from $launcherArchive" }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $launcher, $true)
}
finally {
    $archive.Dispose()
}
Assert-Hash $launcher $launcherHash

$baseline618Archive = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $repoRoot $sources.devuan618Baseline.path))
try {
    $xbeEntry = $baseline618Archive.Entries | Where-Object { $_.FullName -eq 'default.xbe' } | Select-Object -First 1
    $initrdEntry = $baseline618Archive.Entries | Where-Object { $_.FullName -eq 'E-root\devinit' } | Select-Object -First 1
    if (-not $xbeEntry -or -not $initrdEntry) {
        throw 'The protected 6.18 Devuan baseline is missing default.xbe or E-root\devinit.'
    }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($xbeEntry, $launcher618, $true)
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($initrdEntry, $initrd618, $true)
}
finally {
    $baseline618Archive.Dispose()
}
Assert-Hash $launcher618 $launcher618Hash
Assert-Hash $initrd618 '7CADFFDE0B78BA6C263DAD34B69862642A622A9491AD69B9CCFA1B40C0CF6CCB'
& $xdvdfs pack $launcher618Build $loader618Iso | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $loader618Iso -PathType Leaf)) {
    throw 'Failed to build the Xromwell 4dcc618 xemu loader ISO.'
}

$kernel58 = Join-Path $repoRoot $sources.kernel58.path
$kernel618 = Join-Path $repoRoot $sources.kernel618.path
$initrd58 = Join-Path $repoRoot $sources.initrd58.path
$debianPayload = Join-Path $repoRoot $sources.debian.path
$debianAppend = 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/{0} xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0'

$packages = @()
$packages += New-MatrixPackage `
    -Id 'debian-bookworm-desktop-5.8.1-xbe' `
    -Title 'Debian Bookworm Desktop Linux 5.8.1 FATX HDD' `
    -DashboardFolder 'XboxLinuxDebian58Desktop' `
    -Distro 'Debian' -Release 'Bookworm i386' -KernelVersion '5.8.1' `
    -KernelPath $kernel58 -KernelName 'db58krnl' -XbePath $launcher -XbeHash $launcherHash `
    -InitrdPath $initrd58 -InitrdName 'db58init' `
    -PayloadPath $debianPayload -PayloadName 'db58root.ext2' `
    -Append ($debianAppend -f 'db58root.ext2')
$packages += New-MatrixPackage `
    -Id 'debian-bookworm-desktop-6.18.33-xbe' `
    -Title 'Debian Bookworm Desktop Linux 6.18.33 FATX HDD' `
    -DashboardFolder 'XboxLinuxDebian618Desktop' `
    -Distro 'Debian' -Release 'Bookworm i386' -KernelVersion '6.18.33' `
    -KernelPath $kernel618 -KernelName 'db6krnl' -XbePath $launcher618 -XbeHash $launcher618Hash `
    -InitrdPath $initrd618 -InitrdName 'db6init' `
    -PayloadPath $debianPayload -PayloadName 'db6root.ext2' `
    -Append ($debianAppend -f 'db6root.ext2')
$packages += Expand-ProtectedPackage `
    -Id 'devuan-daedalus-desktop-5.8.1-xbe' `
    -ZipPath (Join-Path $repoRoot $sources.devuan58.path) -ZipHash $sources.devuan58.sha256 `
    -Distro 'Devuan' -Release 'Daedalus i386' -KernelVersion '5.8.1' `
    -KernelName 'devkrnl' -InitrdName 'devinit' -PayloadName 'devuan.squashfs' `
    -ProofProfile 'desktop-x' -HardwareState 'passed'
$packages += Expand-ProtectedPackage `
    -Id 'devuan-daedalus-desktop-6.18.33-xbe' `
    -ZipPath (Join-Path $repoRoot $sources.devuan618Baseline.path) -ZipHash $sources.devuan618Baseline.sha256 `
    -Distro 'Devuan' -Release 'Daedalus i386' -KernelVersion '6.18.33' `
    -KernelName 'devkrnl' -InitrdName 'devinit' -PayloadName 'devuan.ext2' `
    -ProofProfile 'desktop-x' -HardwareState 'passed'
$packages += Expand-ProtectedPackage `
    -Id 'tinycore11-desktop-6.18.33-xbe' `
    -ZipPath (Join-Path $repoRoot $sources.tinycore618.path) -ZipHash $sources.tinycore618.sha256 `
    -Distro 'Tiny Core' -Release '11.x x86' -KernelVersion '6.18.33' `
    -KernelName 'vmlinuz' -InitrdName 'initramf' -PayloadName 'linuxroot.ext2' `
    -ProofProfile 'tinycore-desktop' -HardwareState 'passed'

$manifest = [ordered]@{
    schemaVersion = 1
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Read-only FATX non-disc Original Xbox Linux desktop boot matrix'
    transport = 'Dashboard XBE plus FATX E-root'
    fatxMode = 'read-only'
    xromwell = [ordered]@{
        linux58 = [ordered]@{
            lineage = '3fa5e65-sector512'
            sha256 = $launcherHash
            sourceArchive = (Get-RelativePath -BasePath $repoRoot -TargetPath $launcherArchive).Replace('\', '/')
        }
        linux618 = [ordered]@{
            lineage = '4dcc618'
            sha256 = $launcher618Hash
            sourceArchive = $sources.devuan618Baseline.path.Replace('\', '/')
        }
    }
    xemuLoaders = [ordered]@{
        sector512 = [ordered]@{
            path = 'artifacts/xromwell-sector512-baseline.iso'
            sha256 = '537A5A7AC8F4C0C3D80586A8989C40E49EFB562A5A6B4C8B54079F93C5DF1D61'
        }
        '4dcc618' = [ordered]@{
            path = 'xromwell-4dcc618-loader.iso'
            sha256 = (Get-FileHash -LiteralPath $loader618Iso -Algorithm SHA256).Hash
        }
    }
    sourceLocks = $sources
    packages = $packages
}
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $outFull 'manifest.json') -Encoding ASCII

@"
# Read-only Xbox Linux Boot Matrix

This directory reconciles the supported non-disc desktop boot combinations:

- Debian Bookworm i386 on Linux 5.8.1 and 6.18.33
- Devuan Daedalus i386 on Linux 5.8.1 and 6.18.33
- Tiny Core 11.x on Linux 6.18.33

Every package directory and ZIP is self-contained. Copy `default.xbe` as the
dashboard application and copy only that package's complete `E-root` contents
to the root of E:. Never mix E-root files between matrix cells.

The Devuan 5.8.1, Devuan 6.18.33, and Tiny Core 6.18.33 ZIPs are exact copies
of protected hardware-passed baselines. Linux 5.8.1 uses the pinned
3fa5e65-sector512 Xromwell lineage. Linux 6.18.33 uses the 4dcc618 Xromwell and
stage-one bytes from the documented snappy Devuan baseline; sector512 does not
pass the 6.18 initramfs metadata correctly. Devuan 6.18.33 intentionally keeps
the baseline ext2 payload because replacing it with the later SquashFS payload
causes reproducible FATX-backed loop I/O errors under Linux 6.18.33.

This matrix is deliberately read-only. FATX write support is a separate
milestone and is not enabled by any package here.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'README.md') -Encoding ASCII

$sumLines = Get-ChildItem -LiteralPath $outFull -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object Name | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash, $_.Name
}
$sumLines | Set-Content -LiteralPath (Join-Path $outFull 'SHA256SUMS.txt') -Encoding ASCII
Get-ChildItem -LiteralPath $outFull | Select-Object Name, Length, LastWriteTime
