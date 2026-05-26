param(
    [string]$OutRoot = "artifacts\softmod"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot 'xromwell-hddfatx-debian-bookworm-rw-smoke'
$outFull = Join-Path $repoRoot $outDir
$zip = "$outFull.zip"

& $packager `
    -OutDir $outDir `
    -KernelPath 'artifacts\kernels\xbox-linux-6.18.33-fatx-rw-existing-bzImage' `
    -KernelName 'debkrnl' `
    -InitrdPath 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' `
    -InitrdName 'debinit' `
    -PayloadPath 'artifacts\hdd\xbox-debian-bookworm-i386.ext2' `
    -PayloadName 'debian.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/debian.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0 xbox_fatx_mode=rw xbox_root_mode=rw xbox_persist_smoke=1' `
    -PackageTitle 'Xromwell FATX Debian Bookworm i386 RW Persistence Smoke' `
    -DashboardFolder 'XromwellDebianBookwormRwSmoke' `
    -NoZip

@"
EXPERIMENTAL RW FATX / DEBIAN PERSISTENCE SMOKE
================================================

This package is intentionally separate from the normal read-only Debian
package.  It uses the experimental FATX existing-file write kernel and mounts:

  E:\debian.ext2

through FATX read-write, then mounts the ext2 root image read-write.

What this test writes:

  /root/xbox-persist-smoke.txt

inside the Debian ext2 root image.

What the FATX kernel supports today:

  - overwriting bytes inside an existing FATX file

What it does NOT support today:

  - creating FATX files
  - deleting FATX files
  - renaming FATX files
  - extending FATX files
  - allocating or freeing FATX clusters

Status:

  - xemu two-boot persistence smoke: PASS
  - real hardware: NOT YET VALIDATED

Real hardware guidance:

  - keep the normal read-only Debian zip as the known-good fallback
  - back up E:\debian.ext2 before testing this package
  - do not replace the default Debian package with this one yet
  - treat this as an opt-in write smoke only
"@ | Set-Content -LiteralPath (Join-Path $outFull 'RW-SMOKE-WARNING.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
