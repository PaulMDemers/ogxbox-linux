param(
    [string]$OutRoot = "artifacts\softmod"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$outDir = Join-Path $OutRoot 'xromwell-hddfatx-devuan-daedalus-i386-rw-shell-smoke'
$outFull = Join-Path $repoRoot $outDir
$zip = "$outFull.zip"

& $packager `
    -OutDir $outDir `
    -XbePath 'artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386\default.xbe' `
    -KernelPath 'artifacts\kernels\xbox-linux-6.18.33-fatx-rw-existing-bzImage' `
    -KernelName 'devkrnl' `
    -InitrdPath 'artifacts\initramfs\xbox-distro-hdd-ext2-stage1.cpio' `
    -InitrdName 'devinit' `
    -PayloadPath 'artifacts\hdd\xbox-devuan-daedalus-i386.ext2' `
    -PayloadName 'devuan.ext2' `
    -Append 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/devuan.ext2 xbox_root_init=/xbox-init xbox_fatx_mode=rw xbox_root_mode=rw xbox_persist_smoke=1 xbox_sync_ro_smoke=1 xbox_no_early_helpers=1' `
    -PackageTitle 'Xromwell FATX Devuan Daedalus i386 RW Shell Smoke' `
    -DashboardFolder 'XromwellDevuanRwShellSmoke' `
    -NoZip

@"
EXPERIMENTAL RW FATX / DEVUAN SHELL-ONLY SMOKE
==============================================

This package is separate from the normal Devuan desktop release baseline. It
intentionally does not start X. It exists only to validate persistence with the
fewest moving parts.

Current status:

  - xemu writes the marker and normal-use file
  - xemu second boot finds both files without restaging
  - extracted devuan.ext2 passes e2fsck -fn after the hard stop
  - XBOX_ROOT_REMOUNT_RO_OK is not reached yet

Do not use this on real hardware as a disk-safe smoke until the remount-ro
marker is fixed. It is an emulator/debug package for now.

It mounts:

  E:\devuan.ext2

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

  - do not run this on hardware yet unless deliberately debugging rw behavior
  - back up E:\devuan.ext2 before testing
  - keep the restored read-only Devuan desktop package as fallback
  - copy only files from this package's own E-root\ folder
  - do not mix this package with xkrnl/xinit diagnostic packages
  - this is experimental storage smoke, not a daily-use package
"@ | Set-Content -LiteralPath (Join-Path $outFull 'RW-SHELL-SMOKE-WARNING.txt') -Encoding ASCII

@"
NOT READY FOR NORMAL REAL-HARDWARE TESTING
==========================================

This package currently persists files in xemu and the extracted ext2 image
passes fsck after a hard stop, but it does not yet print
XBOX_ROOT_REMOUNT_RO_OK. Keep it as an emulator/debug package until the
remount-read-only path is fixed.

Copy this package only when deliberately debugging the rw storage smoke.

1. Copy this dashboard folder to:
   E:\Apps\XromwellDevuanRwShellSmoke\

2. Back up the current Devuan root image:
   E:\devuan.ext2

3. Delete old global Linux boot files from E:\ if present:
   E:\linuxboot.cfg
   E:\devkrnl
   E:\devinit
   E:\devuan.ext2
   E:\xkrnl
   E:\xinit
   E:\xdevuan.ext2

4. Copy every file from this package's E-root\ folder to E:\:
   E:\linuxboot.cfg
   E:\devkrnl
   E:\devinit
   E:\devuan.ext2

5. Launch:
   E:\Apps\XromwellDevuanRwShellSmoke\default.xbe

6. Wait for:
   XBOX_ROOT_REMOUNT_RO_OK

7. Reboot the same package without recopying E-root\. The second boot should
   report the persistence marker and normal-use file as present.
"@ | Set-Content -LiteralPath (Join-Path $outFull 'COPY-ORDER.txt') -Encoding ASCII

Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
Get-Item -LiteralPath $outFull, $zip
