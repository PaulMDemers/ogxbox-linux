param(
    [string]$TinyCoreRoot = "downloads\tinycore\11.x\x86",
    [string]$PayloadRoot = "artifacts\hdd\tinycore-ext2-root",
    [string]$ImagePath = "artifacts\hdd\xbox-tinycore-payload.ext2",
    [int]$ImageSizeMiB = 128
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tinyCoreFull = if ([System.IO.Path]::IsPathRooted($TinyCoreRoot)) { $TinyCoreRoot } else { Join-Path $repoRoot $TinyCoreRoot }
$payloadRootFull = if ([System.IO.Path]::IsPathRooted($PayloadRoot)) { $PayloadRoot } else { Join-Path $repoRoot $PayloadRoot }
$imageFull = if ([System.IO.Path]::IsPathRooted($ImagePath)) { $ImagePath } else { Join-Path $repoRoot $ImagePath }
$tczSource = Join-Path $tinyCoreFull 'tcz'
$orderSource = Join-Path $tczSource 'desktop-load-order.txt'

foreach ($path in @($tinyCoreFull, (Join-Path $tinyCoreFull 'core.gz'), $tczSource, $orderSource)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file or directory: $path"
    }
}

function Convert-ToWslPath([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -lt 3 -or $full[1] -ne ':') {
        throw "Only drive-qualified Windows paths are supported: $Path"
    }
    $drive = $full[0].ToString().ToLowerInvariant()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

function Quote-Sh([string]$Value) {
    return "'" + $Value.Replace("'", "'\''") + "'"
}

Remove-Item -LiteralPath $payloadRootFull -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $payloadRootFull 'tcz') | Out-Null
Copy-Item -LiteralPath (Join-Path $tinyCoreFull 'core.gz') -Destination (Join-Path $payloadRootFull 'core.gz') -Force
Copy-Item -LiteralPath $orderSource -Destination (Join-Path $payloadRootFull 'tcz\desktop-load-order.txt') -Force

Get-Content -LiteralPath $orderSource | ForEach-Object {
    $name = $_.Trim()
    if ($name.Length -eq 0) {
        return
    }
    $source = Join-Path $tczSource $name
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing Tiny Core extension listed in desktop-load-order.txt: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $payloadRootFull "tcz\$name") -Force
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $imageFull) | Out-Null
$payloadRootWsl = Convert-ToWslPath $payloadRootFull
$imageWsl = Convert-ToWslPath $imageFull
$mkfsCmd = "/usr/sbin/mke2fs -q -t ext2 -F -d $(Quote-Sh $payloadRootWsl) $(Quote-Sh $imageWsl) ${ImageSizeMiB}M"
& wsl.exe sh -lc $mkfsCmd
if ($LASTEXITCODE -ne 0) {
    throw "mke2fs failed"
}

$imageInfo = Get-Item -LiteralPath $imageFull

Write-Host "payload_root=$payloadRootFull"
Write-Host "payload_image=$imageFull"
Write-Host "payload_size=$($imageInfo.Length)"
Write-Host "next_step=powershell -ExecutionPolicy Bypass -File .\scripts\stage_hdd_fatx_linuxboot.ps1 -PayloadPath $ImagePath -AppendPayloadInfo"
