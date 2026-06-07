param(
    [string]$Rev = "2026-06-06",
    [string]$OutRoot = "artifacts\rev-2026-06-06"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outFull = Join-Path $repoRoot $OutRoot
$isoOut = Join-Path $outFull 'isos'
$gameOut = Join-Path $outFull 'game-isos'
$xbeOut = Join-Path $outFull 'xbes'
$buildRoot = Join-Path $repoRoot (Join-Path 'build' "release-rev-$Rev")
$xdvdfs = Join-Path $repoRoot 'tools\xdvdfs\xdvdfs.exe'
$xbe = Join-Path $repoRoot 'artifacts\softmod\xromwell-dvd-boot\default.xbe'

foreach ($path in @($xdvdfs, $xbe)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required artifact: $path"
    }
}

New-Item -ItemType Directory -Force -Path $isoOut, $gameOut, $xbeOut, $buildRoot | Out-Null

$artifacts = New-Object System.Collections.Generic.List[object]

function Resolve-RepoPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $repoRoot $Path
}

function Add-Artifact([string]$Kind, [string]$Config, [string]$Path, [string]$Kernel, [string]$Notes) {
    $full = Resolve-RepoPath $Path
    $hash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    $item = Get-Item -LiteralPath $full
    $artifacts.Add([ordered]@{
        kind = $Kind
        config = $Config
        path = $item.FullName
        bytes = $item.Length
        sha256 = $hash
        kernel = $Kernel
        notes = $Notes
    }) | Out-Null
}

function Copy-Required([string]$Source, [string]$Destination) {
    $sourceFull = Resolve-RepoPath $Source
    if (-not (Test-Path -LiteralPath $sourceFull)) {
        throw "Missing required file: $sourceFull"
    }
    Copy-Item -Force -LiteralPath $sourceFull -Destination $Destination
}

function New-GameDisc(
    [string]$Name,
    [string]$Title,
    [string]$KernelPath,
    [string]$KernelName,
    [string]$InitrdPath,
    [string]$InitrdName,
    [string]$Append,
    [array]$ExtraFiles,
    [string]$KernelLabel,
    [string]$BootDir = '',
    [int64]$MinimumBytes = 0
) {
    $stage = Join-Path $buildRoot "game-$Name"
    $iso = Join-Path $gameOut "$Name.iso"
    Remove-Item -Recurse -Force -LiteralPath $stage -ErrorAction SilentlyContinue
    Remove-Item -Force -LiteralPath $iso -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $stage | Out-Null

    Copy-Item -Force -LiteralPath $xbe -Destination (Join-Path $stage 'default.xbe')

    $bootPrefix = ''
    $bootStage = $stage
    if ($BootDir) {
        $bootPrefix = $BootDir.Trim('/').Trim('\').Replace('\', '/')
        $bootStage = Join-Path $stage ($bootPrefix.Replace('/', [IO.Path]::DirectorySeparatorChar))
        New-Item -ItemType Directory -Force -Path $bootStage | Out-Null
    }

    Copy-Required $KernelPath (Join-Path $bootStage $KernelName)
    Copy-Required $InitrdPath (Join-Path $bootStage $InitrdName)
    foreach ($extra in $ExtraFiles) {
        Copy-Required $extra.source (Join-Path $stage $extra.name)
    }

    if ($MinimumBytes -gt 0) {
        $payloadBytes = (Get-ChildItem -LiteralPath $stage -Recurse -File | Measure-Object -Property Length -Sum).Sum
        if ($payloadBytes -lt $MinimumBytes) {
            $padBytes = $MinimumBytes - $payloadBytes
            $padPath = Join-Path $bootStage 'pad.bin'
            $fs = [IO.File]::Create($padPath)
            try {
                if ($padBytes -gt 0) {
                    $fs.SetLength($padBytes)
                }
            } finally {
                $fs.Dispose()
            }
        }
    }

    $kernelConfigPath = if ($bootPrefix) { "$bootPrefix/$KernelName" } else { $KernelName }
    $initrdConfigPath = if ($bootPrefix) { "$bootPrefix/$InitrdName" } else { $InitrdName }

    @"
title $Title
kernel $kernelConfigPath
initrd $initrdConfigPath
append $Append
"@ | Set-Content -LiteralPath (Join-Path $stage 'linuxboot.cfg') -Encoding ASCII

    $stageFiles = @{}
    $stagePrefix = ([IO.Path]::GetFullPath($stage).TrimEnd('\') + '\')
    Get-ChildItem -LiteralPath $stage -Recurse -File | ForEach-Object {
        $fullName = [IO.Path]::GetFullPath($_.FullName)
        $relative = $fullName.Substring($stagePrefix.Length).Replace('\', '/')
        $stageFiles[$_.FullName.ToLowerInvariant()] = [ordered]@{
            relative = $relative
            size = $_.Length
        }
    }

    $packOutput = & $xdvdfs pack $stage $iso 2>&1
    $packOutput | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "xdvdfs pack failed for $Name"
    }

    $extentArgs = @()
    foreach ($line in $packOutput) {
        if ($line -match 'Added file: "(.+)" at sector ([0-9]+)') {
            $hostPath = $Matches[1]
            while ($hostPath.Contains('\\')) {
                $hostPath = $hostPath.Replace('\\', '\')
            }
            if ($hostPath.StartsWith('\\?\')) {
                $hostPath = $hostPath.Substring(4)
            }
            if ($hostPath.StartsWith('\?\')) {
                $hostPath = $hostPath.Substring(3)
            }
            $hostPath = [IO.Path]::GetFullPath($hostPath).ToLowerInvariant()
            if (-not $stageFiles.ContainsKey($hostPath)) {
                continue
            }
            $fileInfo = $stageFiles[$hostPath]
            $sector = [int]$Matches[2]
            $extentArgs += @('--extent', "$($fileInfo.relative)=${sector}:$($fileInfo.size)")
        }
    }
    if (($extentArgs -join ' ') -notmatch 'linuxboot\.cfg') {
        throw "Could not derive linuxboot.cfg sector for $Name"
    }

    python (Join-Path $repoRoot 'scripts\add_iso9660_overlay.py') $iso @extentArgs
    if ($LASTEXITCODE -ne 0) {
        throw "ISO9660 overlay failed for $Name"
    }

    @"
$Title
$('=' * $Title.Length)

This is an Xbox XDVDFS game-style ISO with a minimal ISO9660 overlay for
Xromwell's Linux CD loader.

Root files:
  default.xbe
  linuxboot.cfg
  $kernelConfigPath
  $initrdConfigPath
$($ExtraFiles | ForEach-Object { "  $($_.name)" } | Out-String)
Append:
  $Append
"@ | Set-Content -LiteralPath (Join-Path $stage 'README.txt') -Encoding ASCII

    Add-Artifact 'game-iso' $Name $iso $KernelLabel 'XDVDFS game-disc style ISO with minimal ISO9660 overlay'
}

function New-XbePackage(
    [string]$Name,
    [string]$Title,
    [string]$KernelPath,
    [string]$KernelName,
    [string]$InitrdPath,
    [string]$InitrdName,
    [string]$Append,
    [array]$PayloadFiles,
    [string]$KernelLabel,
    [string]$Notes
) {
    $pkg = Join-Path $xbeOut $Name
    $zip = "$pkg.zip"
    $eRoot = Join-Path $pkg 'E-root'
    Remove-Item -Recurse -Force -LiteralPath $pkg -ErrorAction SilentlyContinue
    Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $pkg, $eRoot | Out-Null

    Copy-Item -Force -LiteralPath $xbe -Destination (Join-Path $pkg 'default.xbe')
    Copy-Required $KernelPath (Join-Path $eRoot $KernelName)
    Copy-Required $InitrdPath (Join-Path $eRoot $InitrdName)
    foreach ($payload in $PayloadFiles) {
        Copy-Required $payload.source (Join-Path $eRoot $payload.name)
    }

    @"
title $Title
kernel $KernelName
initrd $InitrdName
append $Append
"@ | Set-Content -LiteralPath (Join-Path $eRoot 'linuxboot.cfg') -Encoding ASCII

    $payloadText = if ($PayloadFiles.Count -gt 0) {
        ($PayloadFiles | ForEach-Object { "  E:\$($_.name)" }) -join "`r`n"
    } else {
        "  (none; this package expects the matching disc/ISO payload when noted)"
    }

    @"
$Title
$('=' * $Title.Length)

Copy this folder as a dashboard app, for example:

  E:\Apps\$Name\

Then copy E-root contents to E:\ root:

  E:\linuxboot.cfg
  E:\$KernelName
  E:\$InitrdName
$payloadText

Append:
  $Append

Notes:
  $Notes
"@ | Set-Content -LiteralPath (Join-Path $pkg 'README.txt') -Encoding ASCII

    Compress-Archive -Path (Join-Path $pkg '*') -DestinationPath $zip
    Add-Artifact 'xbe-zip' $Name $zip $KernelLabel $Notes
}

function New-CromwellIso([string]$Name, [string]$Mode, [string]$KernelPath, [string]$InitrdPath, [string]$PayloadPath, [string]$Append, [string]$KernelLabel) {
    $out = Join-Path $isoOut "$Name.iso"
    $env:CROMWELL_ISO_MODE = $Mode
    $env:CROMWELL_ISO_OUT = $out
    $env:CROMWELL_KERNEL = $KernelPath
    if ($InitrdPath) { $env:CROMWELL_INITRAMFS = $InitrdPath }
    if ($PayloadPath) { $env:CROMWELL_PAYLOAD = $PayloadPath }
    if ($Append) { $env:CROMWELL_APPEND = $Append }
    if ($Mode -like 'tinycore*') { $env:TINYCORE_VERSION = '11.x' }
    try {
        python (Join-Path $repoRoot 'scripts\make_cromwell_iso.py')
    }
    finally {
        Remove-Item Env:CROMWELL_ISO_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:CROMWELL_ISO_OUT -ErrorAction SilentlyContinue
        Remove-Item Env:CROMWELL_KERNEL -ErrorAction SilentlyContinue
        Remove-Item Env:CROMWELL_INITRAMFS -ErrorAction SilentlyContinue
        Remove-Item Env:CROMWELL_PAYLOAD -ErrorAction SilentlyContinue
        Remove-Item Env:CROMWELL_APPEND -ErrorAction SilentlyContinue
        Remove-Item Env:TINYCORE_VERSION -ErrorAction SilentlyContinue
    }
    Add-Artifact 'cromwell-iso' $Name $out $KernelLabel 'Plain ISO9660 Cromwell boot ISO'
}

python (Join-Path $repoRoot 'scripts\download_tinycore_tcz.py') `
    --base-url 'https://distro.ibiblio.org/tinycorelinux/11.x/x86/tcz' `
    --out-dir (Join-Path $repoRoot 'downloads\tinycore\11.x\x86\tcz') `
    Xorg-fonts.tcz Xfbdev.tcz flwm_topside.tcz aterm.tcz wbar.tcz
if ($LASTEXITCODE -ne 0) {
    throw "Tiny Core extension download/verify failed"
}

python (Join-Path $repoRoot 'scripts\make_busybox_initramfs.py')
if ($LASTEXITCODE -ne 0) {
    throw "BusyBox/Tiny Core initramfs rebuild failed"
}

$tcAppend = 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7'
$devTermAppendIso = 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_source=iso xbox_payload_file=/devuan.ext2 xbox_root_init=/xbox-init xbox_x_mouse=0'
$devLiveAppendIso = 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_source=iso xbox_payload_file=/devuan.squashfs xbox_root_fstype=squashfs xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_terminal_light=1 xbox_diag=off xbox_fluxbox_lite=1 xbox_fatx_loop_readahead_kb=2048 xbox_loop_readahead_kb=2048'
$devTermAppendFatx = 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/devuan.ext2 xbox_root_init=/xbox-init xbox_x_mouse=0'
$devLiveAppendFatx = 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/devuan.squashfs xbox_root_fstype=squashfs xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_terminal_light=1 xbox_diag=off xbox_fluxbox_lite=1 xbox_fatx_loop_readahead_kb=2048 xbox_loop_readahead_kb=2048'

New-CromwellIso 'tinycore11-desktop-5.8.1' 'tinycore-stage6-xfbdev-desktop-noxpad' 'artifacts\kernels\xbox-linux-5.8.1-noxpad-bzImage' '' '' 'console=tty0 ignore_loglevel loglevel=7' '5.8.1-noxpad'
New-CromwellIso 'tinycore11-desktop-6.18.33' 'tinycore-stage6-xfbdev-desktop-noxpad' 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' '' '' 'console=tty0 ignore_loglevel loglevel=7' '6.18.33-fatx-tinycore'
New-CromwellIso 'devuan-daedalus-terminal-5.8.1' 'devuan-daedalus-i386-terminal' 'artifacts\kernels\xbox-linux-5.8.1-rd-gzip-bzImage' 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' 'artifacts\hdd\xbox-devuan-daedalus-i386.ext2' '' '5.8.1-rd-gzip'
New-CromwellIso 'devuan-daedalus-terminal-6.18.33' 'devuan-daedalus-i386-terminal' 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' 'artifacts\hdd\xbox-devuan-daedalus-i386.ext2' '' '6.18.33-fatx-tinycore'

New-GameDisc 'tinycore11-desktop-5.8.1-game' 'Tiny Core 11 Desktop 5.8.1 Game Disc' 'artifacts\kernels\xbox-linux-5.8.1-noxpad-bzImage' 'vmlinuz' 'artifacts\initramfs\xbox-tinycore-hdd-stage6-xfbdev-desktop.cpio' 'initramf' $tcAppend @() '5.8.1-noxpad' 'boot' 268435456
New-GameDisc 'tinycore11-desktop-6.18.33-game' 'Tiny Core 11 Desktop 6.18.33 Game Disc' 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' 'vmlinuz' 'artifacts\initramfs\xbox-tinycore-hdd-stage6-xfbdev-desktop.cpio' 'initramf' $tcAppend @() '6.18.33-fatx-tinycore' 'boot' 268435456
New-GameDisc 'devuan-daedalus-terminal-5.8.1-game' 'Devuan Daedalus Terminal 5.8.1 Game Disc' 'artifacts\kernels\xbox-linux-5.8.1-rd-gzip-bzImage' 'devkrnl' 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' 'devinit' $devTermAppendIso @(@{ source = 'artifacts\hdd\xbox-devuan-daedalus-i386.ext2'; name = 'devuan.ext2' }) '5.8.1-rd-gzip'
New-GameDisc 'devuan-daedalus-terminal-6.18.33-game' 'Devuan Daedalus Terminal 6.18.33 Game Disc' 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' 'devkrnl' 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' 'devinit' $devTermAppendIso @(@{ source = 'artifacts\hdd\xbox-devuan-daedalus-i386.ext2'; name = 'devuan.ext2' }) '6.18.33-fatx-tinycore'
New-GameDisc 'devuan-daedalus-desktop-live-5.8.1-game' 'Devuan Daedalus Live Desktop 5.8.1 Game Disc' 'artifacts\kernels\xbox-linux-5.8.1-rd-gzip-bzImage' 'devkrnl' 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' 'devinit' $devLiveAppendIso @(@{ source = 'artifacts\hdd\xbox-devuan-daedalus-i386-desktop-full.squashfs'; name = 'devuan.squashfs' }) '5.8.1-rd-gzip'
New-GameDisc 'devuan-daedalus-desktop-live-6.18.33-game' 'Devuan Daedalus Live Desktop 6.18.33 Game Disc' 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' 'devkrnl' 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' 'devinit' $devLiveAppendIso @(@{ source = 'artifacts\hdd\xbox-devuan-daedalus-i386-desktop-full.squashfs'; name = 'devuan.squashfs' }) '6.18.33-fatx-tinycore'

New-XbePackage 'tinycore11-desktop-5.8.1-xbe' 'Tiny Core 11 Desktop 5.8.1 XBE Package' 'artifacts\kernels\xbox-linux-5.8.1-noxpad-bzImage' 'vmlinuz' 'artifacts\initramfs\xbox-tinycore-hdd-stage6-xfbdev-desktop.cpio' 'initramf' $tcAppend @() '5.8.1-noxpad' 'Self-contained Tiny Core initramfs; no E: payload required.'
New-XbePackage 'tinycore11-desktop-6.18.33-xbe' 'Tiny Core 11 Desktop 6.18.33 XBE Package' 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' 'vmlinuz' 'artifacts\initramfs\xbox-tinycore-hdd-stage6-xfbdev-desktop.cpio' 'initramf' $tcAppend @() '6.18.33-fatx-tinycore' 'Self-contained Tiny Core initramfs; no E: payload required.'
New-XbePackage 'devuan-daedalus-terminal-5.8.1-xbe-disc-assisted' 'Devuan Daedalus Terminal 5.8.1 XBE Disc-Assisted Package' 'artifacts\kernels\xbox-linux-5.8.1-rd-gzip-bzImage' 'devkrnl' 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' 'devinit' $devTermAppendIso @() '5.8.1-rd-gzip' '5.8 has no FATX payload-file mount path here; keep the matching Devuan ISO/game disc inserted for the payload.'
New-XbePackage 'devuan-daedalus-terminal-6.18.33-xbe' 'Devuan Daedalus Terminal 6.18.33 XBE Package' 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' 'devkrnl' 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' 'devinit' $devTermAppendFatx @(@{ source = 'artifacts\hdd\xbox-devuan-daedalus-i386.ext2'; name = 'devuan.ext2' }) '6.18.33-fatx-tinycore' 'Copies the Devuan ext2 payload to E: and mounts it through the 6.18 FATX file path.'
New-XbePackage 'devuan-daedalus-desktop-live-5.8.1-xbe-disc-assisted' 'Devuan Daedalus Live Desktop 5.8.1 XBE Disc-Assisted Package' 'artifacts\kernels\xbox-linux-5.8.1-rd-gzip-bzImage' 'devkrnl' 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' 'devinit' $devLiveAppendIso @() '5.8.1-rd-gzip' '5.8 has no FATX payload-file mount path here; keep the matching live desktop ISO/game disc inserted for the squashfs payload.'
New-XbePackage 'devuan-daedalus-desktop-live-6.18.33-xbe' 'Devuan Daedalus Live Desktop 6.18.33 XBE Package' 'artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage' 'devkrnl' 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' 'devinit' $devLiveAppendFatx @(@{ source = 'artifacts\hdd\xbox-devuan-daedalus-i386-desktop-full.squashfs'; name = 'devuan.squashfs' }) '6.18.33-fatx-tinycore' 'Copies the Devuan live squashfs payload to E: and mounts it through the 6.18 FATX file path.'

$manifest = [ordered]@{
    rev = $Rev
    created_at = (Get-Date).ToString("s")
    root = $outFull
    notes = @(
        "Game ISOs are XDVDFS with a minimal ISO9660 overlay for Xromwell.",
        "Tiny Core game ISOs keep default.xbe and linuxboot.cfg at the disc root, place heavy boot files under boot/, and pad the image to improve real-drive recognition.",
        "Tiny Core XBE packages are self-contained initramfs packages.",
        "Devuan 5.8 XBE packages are disc-assisted because this 5.8 line does not include the 6.18 FATX payload-file mount path.",
        "Devuan 6.18 XBE packages include E-root payload files for FATX file-backed boot."
    )
    artifacts = $artifacts
}
$manifestPath = Join-Path $outFull 'manifest.json'
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding ASCII

$lines = @()
$lines += "# Xbox Linux release rev $Rev"
$lines += ""
$lines += "Root: ``$outFull``"
$lines += ""
$lines += "| Kind | Config | Kernel | Bytes | SHA256 | Path |"
$lines += "|---|---|---|---:|---|---|"
foreach ($artifact in $artifacts) {
    $lines += "| $($artifact.kind) | $($artifact.config) | $($artifact.kernel) | $($artifact.bytes) | $($artifact.sha256) | ``$($artifact.path)`` |"
}
$lines += ""
$lines += "See ``manifest.json`` for notes and machine-readable artifact metadata."
$lines | Set-Content -LiteralPath (Join-Path $outFull 'README.md') -Encoding ASCII

Get-Item -LiteralPath $manifestPath, (Join-Path $outFull 'README.md')
$artifacts | ForEach-Object {
    [pscustomobject]@{
        Kind = $_.kind
        Config = $_.config
        Kernel = $_.kernel
        Bytes = $_.bytes
        Sha256 = $_.sha256
        Path = $_.path
    }
} | Format-Table -AutoSize
