param(
    [string]$BaseImage = "Xbox-Emulator-Files\hdd\xbox_hdd.qcow2",
    [string]$OutDir = "run\hdd\fatx-layout-tests",
    [string]$KernelPath = "artifacts\softmod\xromwell-hddfatx-devuan-loader-3fa5e65-sector512\E-root\devkrnl",
    [string]$InitrdPath = "artifacts\softmod\xromwell-hddfatx-devuan-loader-3fa5e65-sector512\E-root\devinit",
    [string]$PayloadPath = "artifacts\softmod\xromwell-hddfatx-devuan-loader-3fa5e65-sector512\E-root\devuan.ext2",
    [string]$TinyKernelPath = "",
    [string]$TinyInitrdPath = "artifacts\initramfs\xbox-tiny-init.cpio",
    [ValidateSet('tiny','contig','fragmented')]
    [string[]]$Layout = @('tiny','contig','fragmented'),
    [switch]$NoPayload,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$baseFull = Join-Path $repoRoot $BaseImage
$outFull = Join-Path $repoRoot $OutDir
$kernelFull = Join-Path $repoRoot $KernelPath
$initrdFull = Join-Path $repoRoot $InitrdPath
$payloadFull = Join-Path $repoRoot $PayloadPath
$tinyKernelFull = if ($TinyKernelPath) { Join-Path $repoRoot $TinyKernelPath } else { $kernelFull }
$tinyInitrdFull = Join-Path $repoRoot $TinyInitrdPath
$stageScript = Join-Path $repoRoot 'scripts\fatx_stage_boot.py'
$qcowScript = Join-Path $repoRoot 'scripts\qcow2_to_raw_sparse.py'

foreach ($path in @($baseFull, $kernelFull, $initrdFull, $stageScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $path"
    }
}
if (-not $NoPayload -and -not (Test-Path -LiteralPath $payloadFull)) {
    throw "Missing required payload file: $payloadFull"
}
if (-not (Test-Path -LiteralPath $tinyKernelFull)) {
    throw "Missing required tiny kernel file: $tinyKernelFull"
}
if (-not (Test-Path -LiteralPath $tinyInitrdFull)) {
    throw "Missing required tiny initrd file: $tinyInitrdFull"
}

New-Item -ItemType Directory -Force $outFull | Out-Null

$driveRoot = [System.IO.Path]::GetPathRoot($outFull)
$driveName = $driveRoot.TrimEnd('\').TrimEnd(':')
$driveInfo = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
if ($driveInfo) {
    $estimatedBytes = [int64]9GB * $Layout.Count
    if ($driveInfo.Free -lt $estimatedBytes) {
        throw "Not enough free space for $($Layout.Count) raw image(s). Need roughly $([math]::Round($estimatedBytes / 1GB, 1)) GB, have $([math]::Round($driveInfo.Free / 1GB, 1)) GB. Use -Layout to generate one image at a time."
    }
}

function New-BaseRawCopy {
    param(
        [string]$Destination
    )

    if ((Test-Path -LiteralPath $Destination) -and -not $Force) {
        throw "Refusing to overwrite $Destination; pass -Force"
    }

    if ($baseFull.ToLowerInvariant().EndsWith('.qcow2')) {
        python $qcowScript $baseFull $Destination --force
    } else {
        Copy-Item -LiteralPath $baseFull -Destination $Destination -Force
    }
}

function Stage-Layout {
    param(
        [string]$Name,
        [string]$BootLayout,
        [string]$ImagePath,
        [string]$ManifestPath,
        [string]$Kernel,
        [string]$KernelName,
        [string]$Initrd,
        [string]$InitrdName,
        [string]$Append,
        [string]$Title,
        [string]$Payload,
        [string]$PayloadName
    )

    New-BaseRawCopy -Destination $ImagePath

    $argsForPython = @(
        $stageScript,
        $ImagePath,
        '--kernel', $Kernel,
        '--kernel-name', $KernelName,
        '--initrd', $Initrd,
        '--initrd-name', $InitrdName,
        '--append', $Append,
        '--title', $Title,
        '--boot-layout', $BootLayout,
        '--manifest', $ManifestPath,
        '--clean-known-boot'
    )

    if ($Payload) {
        $argsForPython += @(
            '--payload', $Payload,
            '--payload-name', $PayloadName,
            '--payload-layout', 'contiguous'
        )
    }

    python @argsForPython
}

$devuanAppend = 'init=/init rootfs_file=/devuan.ext2 rootfs_name=devuan.ext2 quiet'
$tinyAppend = 'init=/init console=tty0'

$layouts = @(
    @{
        Name = 'tiny'
        BootLayout = 'contiguous'
        Kernel = $tinyKernelFull
        KernelName = 'devkrnl'
        Initrd = $tinyInitrdFull
        InitrdName = 'devinit'
        Append = $tinyAppend
        Title = 'FATX tiny contiguous smoke'
        Payload = ''
        PayloadName = ''
    },
    @{
        Name = 'contig'
        BootLayout = 'contiguous'
        Kernel = $kernelFull
        KernelName = 'devkrnl'
        Initrd = $initrdFull
        InitrdName = 'devinit'
        Append = $devuanAppend
        Title = 'FATX Devuan contiguous'
        Payload = if ($NoPayload) { '' } else { $payloadFull }
        PayloadName = 'devuan.ext2'
    },
    @{
        Name = 'fragmented'
        BootLayout = 'fragmented'
        Kernel = $kernelFull
        KernelName = 'devkrnl'
        Initrd = $initrdFull
        InitrdName = 'devinit'
        Append = $devuanAppend
        Title = 'FATX Devuan fragmented'
        Payload = if ($NoPayload) { '' } else { $payloadFull }
        PayloadName = 'devuan.ext2'
    }
)

$summary = @()
foreach ($layoutSpec in ($layouts | Where-Object { $Layout -contains $_.Name })) {
    $imagePath = Join-Path $outFull ("xbox_hdd_layout_{0}.raw" -f $layoutSpec.Name)
    $manifestPath = Join-Path $outFull ("xbox_hdd_layout_{0}.manifest.json" -f $layoutSpec.Name)
    Stage-Layout `
        -Name $layoutSpec.Name `
        -BootLayout $layoutSpec.BootLayout `
        -ImagePath $imagePath `
        -ManifestPath $manifestPath `
        -Kernel $layoutSpec.Kernel `
        -KernelName $layoutSpec.KernelName `
        -Initrd $layoutSpec.Initrd `
        -InitrdName $layoutSpec.InitrdName `
        -Append $layoutSpec.Append `
        -Title $layoutSpec.Title `
        -Payload $layoutSpec.Payload `
        -PayloadName $layoutSpec.PayloadName

    $summary += [pscustomobject]@{
        name = $layoutSpec.Name
        image = $imagePath
        manifest = $manifestPath
        boot_layout = $layoutSpec.BootLayout
    }
}

$summaryPath = Join-Path $outFull 'summary.json'
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host ""
Write-Host "Generated FATX layout test images:"
$summary | Format-Table -AutoSize
Write-Host "Summary: $summaryPath"
