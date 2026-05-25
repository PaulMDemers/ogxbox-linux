param(
    [string]$RawHdd = "run\hdd\xbox_hdd_hddboot.raw",
    [string]$TinyCoreRoot = "downloads\tinycore\11.x\x86",
    [string]$PayloadRoot = "artifacts\hdd\tinycore-ext2-root",
    [string]$ImagePath = "artifacts\hdd\xbox-tinycore-payload.ext2",
    [UInt64]$PayloadOffset = 8053063680,
    [int]$ImageSizeMiB = 128
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$rawHddFull = Join-Path $repoRoot $RawHdd
$tinyCoreFull = Join-Path $repoRoot $TinyCoreRoot
$payloadRootFull = Join-Path $repoRoot $PayloadRoot
$imageFull = Join-Path $repoRoot $ImagePath
$tczSource = Join-Path $tinyCoreFull 'tcz'
$orderSource = Join-Path $tczSource 'desktop-load-order.txt'

foreach ($path in @($rawHddFull, $tinyCoreFull, (Join-Path $tinyCoreFull 'core.gz'), $tczSource, $orderSource)) {
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
$rawInfo = Get-Item -LiteralPath $rawHddFull
if ($PayloadOffset + [UInt64]$imageInfo.Length -gt [UInt64]$rawInfo.Length) {
    throw "Payload image would extend past raw HDD size"
}

$src = [System.IO.File]::Open($imageFull, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
try {
    $dst = [System.IO.File]::Open($rawHddFull, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try {
        [void]$dst.Seek([Int64]$PayloadOffset, [System.IO.SeekOrigin]::Begin)
        $buffer = New-Object byte[] (4 * 1024 * 1024)
        while (($read = $src.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $dst.Write($buffer, 0, $read)
        }
    }
    finally {
        $dst.Dispose()
    }
}
finally {
    $src.Dispose()
}

Write-Host "payload_root=$payloadRootFull"
Write-Host "payload_image=$imageFull"
Write-Host "payload_offset=$PayloadOffset"
Write-Host "payload_size=$($imageInfo.Length)"
Write-Host "raw_hdd=$rawHddFull"
