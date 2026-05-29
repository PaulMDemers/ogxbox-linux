param(
    [string]$OutRoot = "artifacts\softmod"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot 'xromwell-hddfatx-devuan-daedalus-i386-sector512-baseline'
$baselineRoot = 'artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386\E-root'

& $packager `
    -OutDir $outDir `
    -XbePath 'artifacts\audit\xromwell-3fa5e65-sector512-altname-devuan-daedalus-i386\default.xbe' `
    -KernelPath (Join-Path $baselineRoot 'devkrnl') `
    -KernelName 'devkrnl' `
    -InitrdPath (Join-Path $baselineRoot 'devinit') `
    -InitrdName 'devinit' `
    -PayloadPath (Join-Path $baselineRoot 'devuan.ext2') `
    -PayloadName 'devuan.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/devuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0' `
    -PackageTitle 'Xromwell FATX Devuan Daedalus i386 Sector512 Baseline' `
    -DashboardFolder 'XromwellDevuanSector512Baseline' `
    -NoZip | Out-Null

$outFull = Join-Path $repoRoot $outDir

$hashes = [ordered]@{
    'default.xbe' = (Get-FileHash -LiteralPath (Join-Path $outFull 'default.xbe') -Algorithm SHA256).Hash
    'E-root\devkrnl' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\devkrnl') -Algorithm SHA256).Hash
    'E-root\devinit' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\devinit') -Algorithm SHA256).Hash
    'E-root\devuan.ext2' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\devuan.ext2') -Algorithm SHA256).Hash
    'E-root\linuxboot.cfg' = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\linuxboot.cfg') -Algorithm SHA256).Hash
}

@"
DEVUAN SECTOR512 BASELINE
=========================

Purpose:
  This is the rollback baseline after the later Xromwell payload/IDE timing
  experiments failed to improve real hardware behavior.

What this package uses:
  - The 3fa5e65 sector512 XBE that booted 4 out of 5 hardware attempts.
  - The release Devuan desktop payload bytes.
  - The release root filenames:
      E:\linuxboot.cfg
      E:\devkrnl
      E:\devinit
      E:\devuan.ext2

What this package intentionally does not use:
  - payload-progress-readsectors
  - payload-settle-readsectors
  - idephase-payload-readsectors
  - idephase-readsectors-filesector
  - ata-readsectors-filesector

Copy rule:
  Delete the previous four root files from E:\, then copy this package's
  E-root\ files to E:\ in this order:

    devkrnl
    devinit
    devuan.ext2
    linuxboot.cfg

  Copy this dashboard folder to:

    E:\Apps\XromwellDevuanSector512Baseline\

Hashes:
  default.xbe:       $($hashes['default.xbe'])
  E-root\devkrnl:   $($hashes['E-root\devkrnl'])
  E-root\devinit:   $($hashes['E-root\devinit'])
  E-root\devuan.ext2:   $($hashes['E-root\devuan.ext2'])
  E-root\linuxboot.cfg: $($hashes['E-root\linuxboot.cfg'])
"@ | Set-Content -LiteralPath (Join-Path $outFull 'SECTOR512-BASELINE.txt') -Encoding ASCII

$zip = "$outFull.zip"
Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip

Get-Item -LiteralPath $outFull, $zip
