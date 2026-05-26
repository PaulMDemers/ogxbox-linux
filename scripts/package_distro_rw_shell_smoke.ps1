param(
    [string]$OutRoot = "artifacts\softmod"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot 'xromwell-hddfatx-debian-bookworm-rw-shell-smoke'
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
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/debian.ext2 xbox_root_init=/xbox-init xbox_fatx_mode=rw xbox_root_mode=rw xbox_persist_smoke=1 xbox_sync_ro_smoke=1' `
    -PackageTitle 'Xromwell FATX Debian Bookworm i386 RW Shell Smoke' `
    -DashboardFolder 'XromwellDebianBookwormRwShell' `
    -NoZip

@"
EXPERIMENTAL RW FATX / DEBIAN SHELL-ONLY SMOKE
==============================================

This is the lowest-moving-parts rw package for real-hardware storage testing.
It intentionally does not start the X desktop.

It mounts:

  E:\debian.ext2

through FATX read-write, mounts the ext2 root image read-write, writes:

  /root/xbox-persist-smoke.txt
  /root/xbox-normal-use.txt

then runs:

  xbox-sync-ro

Expected successful console markers:

  XBOX_PERSIST_MARKER_WRITTEN
  XBOX_NORMAL_USE_FILE_WRITTEN
  XBOX_ROOT_REMOUNT_RO_OK

On the next boot of the same package, expected markers:

  XBOX_PERSIST_MARKER_PRESENT
  XBOX_NORMAL_USE_FILE_PRESENT
  XBOX_ROOT_REMOUNT_RO_OK

Real hardware guidance:

  - back up E:\debian.ext2 before testing
  - keep the normal read-only package as fallback
  - do not FTP this over the normal rw desktop package unless you intend to
  - this is still experimental; it is a storage smoke, not a daily-use package
"@ | Set-Content -LiteralPath (Join-Path $outFull 'RW-SHELL-SMOKE-WARNING.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
