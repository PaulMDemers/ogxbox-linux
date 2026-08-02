param(
    [string]$OutRoot = "artifacts\devuan-5.8.1-nondisc"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$launcherArchive = Join-Path $repoRoot 'artifacts\softmod\xromwell-hddfatx-devuan-loader-3fa5e65-sector512.zip'
$launcherHash = '81B3A6850627A8BEC6FA0D92BB4652400DB3EC863072EAA7351BB159DED0BAFD'
$kernel = Join-Path $repoRoot 'artifacts\kernels\xbox-linux-5.8.1-fatx-rd-gzip-bzImage'
$kernelConfig = Join-Path $repoRoot 'artifacts\kernels\xbox-linux-5.8.1-fatx-rd-gzip.config'
$initrd = Join-Path $repoRoot 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio'
$terminalPayload = Join-Path $repoRoot 'artifacts\hdd\xbox-devuan-daedalus-i386.ext2'
$desktopPayload = Join-Path $repoRoot 'artifacts\hdd\xbox-devuan-daedalus-i386-desktop-full.squashfs'
$outFull = Join-Path $repoRoot $OutRoot
$buildDir = Join-Path $repoRoot 'build\pinned-xromwell-3fa5e65-sector512'
$launcher = Join-Path $buildDir 'default.xbe'

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'
    $targetFull = [System.IO.Path]::GetFullPath($TargetPath)
    $baseUri = New-Object System.Uri($baseFull)
    $targetUri = New-Object System.Uri($targetFull)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

foreach ($path in @($packager, $launcherArchive, $kernel, $kernelConfig, $initrd, $terminalPayload, $desktopPayload)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required input was not found: $path"
    }
}

if (-not (Select-String -LiteralPath $kernelConfig -Pattern '^CONFIG_FATX_FS=y$' -Quiet)) {
    throw "The selected 5.8.1 kernel config does not have built-in FATX support: $kernelConfig"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$archive = [System.IO.Compression.ZipFile]::OpenRead($launcherArchive)
try {
    $entry = $archive.Entries | Where-Object { $_.Name -eq 'default.xbe' } | Select-Object -First 1
    if (-not $entry) {
        throw "The pinned launcher archive does not contain default.xbe: $launcherArchive"
    }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $launcher, $true)
}
finally {
    $archive.Dispose()
}

$actualLauncherHash = (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash
if ($actualLauncherHash -ne $launcherHash) {
    throw "Pinned Xromwell launcher hash mismatch. Expected $launcherHash, got $actualLauncherHash"
}

Remove-Item -Recurse -Force -LiteralPath $outFull -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $outFull | Out-Null

$packages = @(
    [ordered]@{
        Name = 'devuan-daedalus-terminal-5.8.1-xbe'
        Title = 'Devuan Daedalus Terminal 5.8.1 FATX HDD'
        DashboardFolder = 'XboxLinuxDevuan58Terminal'
        PayloadPath = $terminalPayload
        PayloadName = 'devuan.ext2'
        Append = 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/devuan.ext2 xbox_root_init=/xbox-init xbox_x_mouse=0'
    },
    [ordered]@{
        Name = 'devuan-daedalus-desktop-live-5.8.1-xbe'
        Title = 'Devuan Daedalus Desktop Live 5.8.1 FATX HDD'
        DashboardFolder = 'XboxLinuxDevuan58Desktop'
        PayloadPath = $desktopPayload
        PayloadName = 'devuan.squashfs'
        Append = 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/devuan.squashfs xbox_root_fstype=squashfs xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_terminal_light=1 xbox_diag=off xbox_fluxbox_lite=1 xbox_fatx_loop_readahead_kb=2048 xbox_loop_readahead_kb=2048'
    }
)

$manifestPackages = @()
foreach ($package in $packages) {
    $packageDir = Join-Path $outFull $package.Name
    $packageRelative = Get-RelativePath -BasePath $repoRoot -TargetPath $packageDir

    & $packager `
        -OutDir $packageRelative `
        -XbePath (Get-RelativePath -BasePath $repoRoot -TargetPath $launcher) `
        -KernelPath (Get-RelativePath -BasePath $repoRoot -TargetPath $kernel) `
        -KernelName 'devkrnl' `
        -InitrdPath (Get-RelativePath -BasePath $repoRoot -TargetPath $initrd) `
        -InitrdName 'devinit' `
        -PayloadPath (Get-RelativePath -BasePath $repoRoot -TargetPath $package.PayloadPath) `
        -PayloadName $package.PayloadName `
        -Append $package.Append `
        -PackageTitle $package.Title `
        -DashboardFolder $package.DashboardFolder `
        -NoZip | Out-Null

    @"
NON-DISC DEVUAN 5.8.1 PACKAGE
==============================

This package boots entirely from the Xbox hard disk. It does not require a
Linux payload disc after default.xbe starts.

The kernel is the proven Xbox Linux 5.8.1 configuration with one functional
addition: the read-only FATX filesystem driver is built in. Linux can therefore
mount E: and loop-mount $($package.PayloadName) after Xromwell loads the kernel
and stage-one initramfs.

Install:
  1. Copy this whole folder to E:\Apps\$($package.DashboardFolder)\.
  2. Copy every file inside E-root\ to the root of E:\.
  3. Launch default.xbe from the dashboard.

Pinned Xromwell launcher SHA-256:
  $launcherHash

Hardware status:
  The launcher lineage and original 5.8.1 distro payloads were previously
  hardware-tested. This new 5.8.1 FATX kernel build still requires a fresh
  real-Xbox boot test before release designation.
"@ | Set-Content -LiteralPath (Join-Path $packageDir 'NONDISC-5.8.1.txt') -Encoding ASCII

    $packageHashes = [ordered]@{}
    Get-ChildItem -LiteralPath $packageDir -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative = (Get-RelativePath -BasePath $packageDir -TargetPath $_.FullName).Replace('\', '/')
        $packageHashes[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }

    $zip = "$packageDir.zip"
    Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $packageDir '*') -DestinationPath $zip -CompressionLevel Optimal

    $manifestPackages += [ordered]@{
        name = $package.Name
        directory = (Get-RelativePath -BasePath $outFull -TargetPath $packageDir).Replace('\', '/')
        zip = [System.IO.Path]::GetFileName($zip)
        zipSha256 = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
        payload = $package.PayloadName
        files = $packageHashes
    }
}

$manifest = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Non-disc-assisted Devuan Daedalus i386 packages for Original Xbox'
    kernel = [ordered]@{
        version = '5.8.1'
        path = (Get-RelativePath -BasePath $repoRoot -TargetPath $kernel).Replace('\', '/')
        sha256 = (Get-FileHash -LiteralPath $kernel -Algorithm SHA256).Hash
        configPath = (Get-RelativePath -BasePath $repoRoot -TargetPath $kernelConfig).Replace('\', '/')
        configSha256 = (Get-FileHash -LiteralPath $kernelConfig -Algorithm SHA256).Hash
        fatx = 'built-in, read-only'
    }
    xromwell = [ordered]@{
        lineage = '3fa5e65-sector512'
        sha256 = $launcherHash
        sourceArchive = (Get-RelativePath -BasePath $repoRoot -TargetPath $launcherArchive).Replace('\', '/')
    }
    packages = $manifestPackages
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outFull 'manifest.json') -Encoding ASCII

@"
# Devuan 5.8.1 Non-Disc Packages

These packages boot the existing Devuan Daedalus terminal and desktop payloads
from FATX E:. A disc is not needed after installation.

- `devuan-daedalus-terminal-5.8.1-xbe.zip`: terminal-focused Devuan system.
- `devuan-daedalus-desktop-live-5.8.1-xbe.zip`: live Fluxbox desktop system.

Each ZIP is self-contained: `default.xbe` is the dashboard launcher and its
`E-root` directory contains the complete matching kernel, initramfs, payload,
and `linuxboot.cfg`. Do not mix files between the two package folders.

The Xromwell binary is pinned to the hardware-tested 3fa5e65 sector512 lineage.
The kernel uses the previous working 5.8.1 config plus built-in read-only FATX.
Fresh real-hardware validation of the FATX-enabled 5.8.1 kernel is still needed.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'README.md') -Encoding ASCII

$sumLines = Get-ChildItem -LiteralPath $outFull -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | Sort-Object Name | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash, $_.Name
}
$sumLines | Set-Content -LiteralPath (Join-Path $outFull 'SHA256SUMS.txt') -Encoding ASCII

Get-ChildItem -LiteralPath $outFull | Select-Object Name, Length, LastWriteTime
