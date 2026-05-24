param(
    [string]$OutputIso = "artifacts\cromwell-tinycore11-stage6-xfbdev-desktop-noxpad.iso",
    [string]$KernelPath = "artifacts\kernels\xbox-linux-5.8.1-noxpad-bzImage"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$kernel = Join-Path $repoRoot $KernelPath
$coreDir = Join-Path $repoRoot 'downloads\tinycore\11.x\x86'
$core = Join-Path $coreDir 'core.gz'
$coreMd5 = Join-Path $coreDir 'core.gz.md5.txt'
$coreUrl = 'https://distro.ibiblio.org/tinycorelinux/11.x/x86/release/distribution_files/core.gz'
$coreMd5Url = 'https://distro.ibiblio.org/tinycorelinux/11.x/x86/release/distribution_files/core.gz.md5.txt'
$expectedCoreMd5 = '0fd08c73e84b26aabbd0d12006d64855'
$tczDir = Join-Path $coreDir 'tcz'

if (-not (Test-Path -LiteralPath $kernel)) {
    throw "Missing kernel artifact: $kernel. Build or restore it first."
}

New-Item -ItemType Directory -Force -Path $coreDir | Out-Null

if (-not (Test-Path -LiteralPath $core)) {
    Invoke-WebRequest -Uri $coreUrl -OutFile $core -UseBasicParsing
}

if (-not (Test-Path -LiteralPath $coreMd5)) {
    Invoke-WebRequest -Uri $coreMd5Url -OutFile $coreMd5 -UseBasicParsing
}

$actualCoreMd5 = (Get-FileHash $core -Algorithm MD5).Hash.ToLowerInvariant()
if ($actualCoreMd5 -ne $expectedCoreMd5) {
    throw "Tiny Core 11 core.gz MD5 mismatch. Expected $expectedCoreMd5, got $actualCoreMd5."
}

python (Join-Path $repoRoot 'scripts\download_tinycore_tcz.py') `
    --base-url 'https://distro.ibiblio.org/tinycorelinux/11.x/x86/tcz' `
    --out-dir $tczDir `
    Xorg-fonts.tcz Xfbdev.tcz flwm_topside.tcz aterm.tcz wbar.tcz

python (Join-Path $repoRoot 'scripts\make_busybox_initramfs.py')

$env:CROMWELL_ISO_MODE = 'tinycore-stage6-xfbdev-desktop-noxpad'
$env:CROMWELL_ISO_OUT = $OutputIso
$env:CROMWELL_KERNEL = $KernelPath
$env:TINYCORE_VERSION = '11.x'
try {
    python (Join-Path $repoRoot 'scripts\make_cromwell_iso.py')
}
finally {
    Remove-Item Env:CROMWELL_ISO_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:CROMWELL_ISO_OUT -ErrorAction SilentlyContinue
    Remove-Item Env:CROMWELL_KERNEL -ErrorAction SilentlyContinue
    Remove-Item Env:TINYCORE_VERSION -ErrorAction SilentlyContinue
}

Get-Item -LiteralPath (Join-Path $repoRoot $OutputIso)
