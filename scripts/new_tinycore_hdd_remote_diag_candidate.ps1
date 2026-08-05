[CmdletBinding()]
param(
    [string]$OutRoot = 'artifacts\tinycore-hdd-x-hotset-remote-candidate',
    [string]$BuildRoot = 'build\tinycore-hdd-x-hotset-remote',
    [ValidateRange(64, 4096)]
    [int]$ReadAheadKb = 1024,
    [ValidateRange(128, 4096)]
    [int]$DiskReadAheadKb = 1024
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$baseRoot = Join-Path $repoRoot 'artifacts\hdd\tinycore-ext2-root'
$downloadRoot = Join-Path $repoRoot 'downloads\tinycore\11.x\x86\dropbear-closure'
$buildFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $BuildRoot))
$inputRoot = Join-Path $buildFull 'input'
$payloadRoot = Join-Path $buildFull 'payload-root'
$payloadPath = Join-Path $buildFull 'linuxroot.ext2'
$baseImage = Join-Path $repoRoot 'artifacts\hdd\xbox-tinycore-payload.ext2'
$expectedBaseImageSha256 = 'CFBBC4ED822FFBA297954C80FA94B1878C5CBB07BE7FA8F7B855E3B55E3E4691'

if ((Get-FileHash -LiteralPath $baseImage -Algorithm SHA256).Hash -ne $expectedBaseImageSha256) {
    throw 'The protected Tiny Core payload image changed; refusing to derive a candidate.'
}
foreach ($required in @($baseRoot, (Join-Path $baseRoot 'core.gz'), (Join-Path $baseRoot 'tcz\desktop-load-order.txt'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Required Tiny Core input was not found: $required" }
}

& python (Join-Path $repoRoot 'scripts\download_tinycore_tcz.py') `
    --base-url 'https://distro.ibiblio.org/tinycorelinux/11.x/x86/tcz' `
    --out-dir $downloadRoot dropbear
if ($LASTEXITCODE -ne 0) { throw 'Downloading the Tiny Core 11 Dropbear extension failed.' }
$dropbearTcz = Join-Path $downloadRoot 'dropbear.tcz'
if (-not (Test-Path -LiteralPath $dropbearTcz -PathType Leaf)) { throw "Dropbear extension was not found: $dropbearTcz" }

if (Test-Path -LiteralPath $buildFull) {
    $buildPrefix = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'build')).TrimEnd('\') + '\'
    if (-not $buildFull.StartsWith($buildPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove build output outside the build directory: $buildFull"
    }
    Remove-Item -LiteralPath $buildFull -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $inputRoot | Out-Null
Copy-Item -Path (Join-Path $baseRoot '*') -Destination $inputRoot -Recurse -Force
Copy-Item -LiteralPath $dropbearTcz -Destination (Join-Path $inputRoot 'tcz\dropbear.tcz') -Force
$orderPath = Join-Path $inputRoot 'tcz\desktop-load-order.txt'
$order = @([System.IO.File]::ReadAllLines($orderPath) | Where-Object { $_ -and $_ -ne 'dropbear.tcz' })
$order += 'dropbear.tcz'
[System.IO.File]::WriteAllLines($orderPath, $order, [System.Text.Encoding]::ASCII)

& (Join-Path $repoRoot 'scripts\stage_hdd_ext2_tinycore_payload.ps1') `
    -TinyCoreRoot $inputRoot -PayloadRoot $payloadRoot -ImagePath $payloadPath -ImageSizeMiB 128
if ($LASTEXITCODE -ne 0) { throw 'Building the Dropbear-enabled Tiny Core payload failed.' }

& (Join-Path $repoRoot 'scripts\new_tinycore_hdd_ra128_candidate.ps1') `
    -OutRoot $OutRoot -ReadAheadKb $ReadAheadKb -DiskReadAheadKb $DiskReadAheadKb `
    -XHotset -RemoteDiagnostics -TerminalFont 9x15 -PayloadPath $payloadPath
if ($LASTEXITCODE -ne 0) { throw 'Packaging the Tiny Core remote-diagnostics candidate failed.' }
