param(
    [string]$OutputIso = "artifacts\cromwell-devuan-daedalus-i386-complete.iso",
    [string]$KernelPath = "artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage",
    [string]$InitrdPath = "artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio",
    [string]$PayloadPath = "artifacts\hdd\xbox-devuan-daedalus-i386-complete.ext2"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

foreach ($path in @($KernelPath, $InitrdPath, $PayloadPath)) {
    $full = Join-Path $repoRoot $path
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Missing required artifact: $full"
    }
}

$env:CROMWELL_ISO_MODE = 'devuan-daedalus-i386-complete'
$env:CROMWELL_ISO_OUT = $OutputIso
$env:CROMWELL_KERNEL = $KernelPath
$env:CROMWELL_INITRAMFS = $InitrdPath
$env:CROMWELL_PAYLOAD = $PayloadPath
try {
    python (Join-Path $repoRoot 'scripts\make_cromwell_iso.py')
}
finally {
    Remove-Item Env:CROMWELL_ISO_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:CROMWELL_ISO_OUT -ErrorAction SilentlyContinue
    Remove-Item Env:CROMWELL_KERNEL -ErrorAction SilentlyContinue
    Remove-Item Env:CROMWELL_INITRAMFS -ErrorAction SilentlyContinue
    Remove-Item Env:CROMWELL_PAYLOAD -ErrorAction SilentlyContinue
}

Get-Item -LiteralPath (Join-Path $repoRoot $OutputIso)
