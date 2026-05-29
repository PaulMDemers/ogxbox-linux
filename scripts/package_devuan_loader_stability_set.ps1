param(
    [string]$OutRoot = "artifacts\softmod",
    [string]$BaselineRoot = "artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386\E-root"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$packager = Join-Path $repoRoot 'scripts\package_xromwell_hddfatx_softmod.ps1'
$kernelPath = Join-Path $BaselineRoot 'devkrnl'
$initrdPath = Join-Path $BaselineRoot 'devinit'
$payloadPath = Join-Path $BaselineRoot 'devuan.ext2'
$append = 'init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7 xbox_payload_file=/devuan.ext2 xbox_root_init=/xbox-init xbox_desktop=1 xbox_x_mouse=0'

$variants = @(
    [pscustomobject]@{
        Id = 'payload-progress-readsectors'
        Label = 'payload progress ATA READ SECTORS loader'
        Xbe = 'artifacts\audit\xromwell-payload-progress-loader-xbe\default.xbe'
        OutDir = 'xromwell-hddfatx-devuan-loader-payload-progress'
        Dashboard = 'XromwellDevuanLoaderPayloadProgress'
        Notes = 'Follow-up after payload IDE phase trace showed the first /devkrnl sector read completes. This variant suppresses per-sector IDE spam and prints compact progress markers while loading devkrnl and devinit.'
    },
    [pscustomobject]@{
        Id = 'idephase-payload-readsectors'
        Label = 'payload-only ATA READ SECTORS IDE phase trace'
        Xbe = 'artifacts\audit\xromwell-idephase-payload-loader-xbe\default.xbe'
        OutDir = 'xromwell-hddfatx-devuan-loader-idephase-payload'
        Dashboard = 'XromwellDevuanLoaderIdePayload'
        Notes = 'Follow-up to idephase-readsectors-filesector after hardware showed the config/root lookup reads complete. This variant keeps early config loading quiet and enables FATX/IDE phase markers only while loading boot payload files such as devkrnl and devinit.'
    },
    [pscustomobject]@{
        Id = 'idephase-readsectors-filesector'
        Label = 'file-sector loader with ATA READ SECTORS IDE phase trace'
        Xbe = 'artifacts\audit\xromwell-idephase-loader-xbe\default.xbe'
        OutDir = 'xromwell-hddfatx-devuan-loader-idephase-readsectors'
        Dashboard = 'XromwellDevuanLoaderIdePhase'
        Notes = 'Diagnostic follow-up after ata-readsectors-filesector hung during the /devkrnl lookup. Prints compact FATX lookup markers plus IDE command/data phase markers so the last visible line identifies the exact stall phase.'
    },
    [pscustomobject]@{
        Id = 'ata-readsectors-filesector'
        Label = 'cd4bcf1 file-sector loader with ATA READ SECTORS'
        Xbe = 'artifacts\audit\xromwell-ata-readsectors-loader-xbe\default.xbe'
        OutDir = 'xromwell-hddfatx-devuan-loader-ata-readsectors-filesector'
        Dashboard = 'XromwellDevuanLoaderAtaReadSectors'
        Notes = 'File-sector FATX loader that uses ordinary ATA READ SECTORS instead of READ MULTIPLE for HDD reads. This is the first follow-up after 3fa5e65-sector512 booted 4/5 times but once hung before the kernel progress output.'
    },
    [pscustomobject]@{
        Id = '3fa5e65-sector512'
        Label = '3fa5e65 quiet sector512 loader'
        Xbe = 'artifacts\audit\xromwell-3fa5e65-sector512-altname-devuan-daedalus-i386\default.xbe'
        OutDir = 'xromwell-hddfatx-devuan-loader-3fa5e65-sector512'
        Dashboard = 'XromwellDevuanLoaderSector512'
        Notes = 'Older quiet sector-at-a-time loader line. This is the first candidate for repeatable boot stability.'
    },
    [pscustomobject]@{
        Id = '3fa5e65-findsector'
        Label = '3fa5e65 sector512 find-sector trace loader'
        Xbe = 'artifacts\audit\xromwell-3fa5e65-sector512-findsector-devuan-perf1-daedalus-i386\default.xbe'
        OutDir = 'xromwell-hddfatx-devuan-loader-3fa5e65-findsector'
        Dashboard = 'XromwellDevuanLoaderFindSector'
        Notes = 'Diagnostic loader that prints sector-at-a-time directory lookup progress.'
    },
    [pscustomobject]@{
        Id = '3fa5e65-filesector'
        Label = '3fa5e65 sector512 file-sector trace loader'
        Xbe = 'artifacts\audit\xromwell-3fa5e65-sector512-filesector-devuan-perf1-daedalus-i386\default.xbe'
        OutDir = 'xromwell-hddfatx-devuan-loader-3fa5e65-filesector'
        Dashboard = 'XromwellDevuanLoaderFileSector'
        Notes = 'Diagnostic loader that reads boot files sector-at-a-time and prints file read progress.'
    },
    [pscustomobject]@{
        Id = '4dcc618-current'
        Label = 'Current 4dcc618 cached/coalesced loader'
        Xbe = 'artifacts\audit\xromwell-4dcc618-restored-devuan-daedalus-i386\default.xbe'
        OutDir = 'xromwell-hddfatx-devuan-loader-4dcc618-current'
        Dashboard = 'XromwellDevuanLoader4dcc618'
        Notes = 'This is the release-baseline Xromwell loader. Use it to confirm the current nondeterministic failure.'
    }
)

function RepoPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    Join-Path $repoRoot $Path
}

$setDir = Join-Path (Join-Path $repoRoot $OutRoot) 'devuan-loader-stability-set'
Remove-Item -Recurse -Force -LiteralPath $setDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $setDir | Out-Null

$manifest = @()
foreach ($variant in $variants) {
    foreach ($path in @($variant.Xbe, $kernelPath, $initrdPath, $payloadPath)) {
        $full = RepoPath $path
        if (-not (Test-Path -LiteralPath $full)) {
            throw "Required file was not found: $full"
        }
    }

    $outDir = Join-Path $OutRoot $variant.OutDir
    & $packager `
        -OutDir $outDir `
        -XbePath $variant.Xbe `
        -KernelPath $kernelPath `
        -KernelName 'devkrnl' `
        -InitrdPath $initrdPath `
        -InitrdName 'devinit' `
        -PayloadPath $payloadPath `
        -PayloadName 'devuan.ext2' `
        -Append $append `
        -PackageTitle "Devuan Loader Stability - $($variant.Label)" `
        -DashboardFolder $variant.Dashboard `
        -NoZip | Out-Null

    $outFull = Join-Path $repoRoot $outDir
    $xbeHash = (Get-FileHash -LiteralPath (Join-Path $outFull 'default.xbe') -Algorithm SHA256).Hash
    $kernelHash = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\devkrnl') -Algorithm SHA256).Hash
    $initrdHash = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\devinit') -Algorithm SHA256).Hash
    $rootHash = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\devuan.ext2') -Algorithm SHA256).Hash
    $cfgHash = (Get-FileHash -LiteralPath (Join-Path $outFull 'E-root\linuxboot.cfg') -Algorithm SHA256).Hash

@"
DEVUAN LOADER STABILITY VARIANT: $($variant.Id)
================================================

$($variant.Notes)

This package intentionally uses the same baseline Devuan boot payload bytes in
every variant:

  E:\linuxboot.cfg
  E:\devkrnl
  E:\devinit
  E:\devuan.ext2

Test rule:

  1. Delete the previous copies of those four files from E:\.
  2. Copy this package's E-root\ files to E:\ in this order:
       devkrnl
       devinit
       devuan.ext2
       linuxboot.cfg
  3. Copy this dashboard folder to:
       E:\Apps\$($variant.Dashboard)\
  4. Boot this package several times without changing files.
  5. Photograph the last visible Xromwell line if it hangs.

Expected success:

  Xromwell loads /devkrnl and /devinit, then Devuan reaches the desktop.

Hashes:

  XBE SHA256:    $xbeHash
  devkrnl:       $kernelHash
  devinit:       $initrdHash
  devuan.ext2:   $rootHash
  linuxboot.cfg: $cfgHash
"@ | Set-Content -LiteralPath (Join-Path $outFull 'LOADER-STABILITY.txt') -Encoding ASCII

    $zip = "$outFull.zip"
    Remove-Item -Force -LiteralPath $zip -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $outFull '*') -DestinationPath $zip
    $zipHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash

    Copy-Item -Force -LiteralPath $zip -Destination (Join-Path $setDir (Split-Path -Leaf $zip))
    $manifest += [pscustomobject]@{
        id = $variant.Id
        label = $variant.Label
        package = $zip
        dashboard = $variant.Dashboard
        xbe_sha256 = $xbeHash
        zip_sha256 = $zipHash
    }
}

$manifestLines = @(
    '# Devuan Loader Stability Set',
    '',
    'All packages use identical Devuan baseline root payload files:',
    '',
    '```text',
    'E:\linuxboot.cfg',
    'E:\devkrnl',
    'E:\devinit',
    'E:\devuan.ext2',
    '```',
    '',
    'Only `default.xbe` changes between variants. Test one package at a time.',
    'Delete and recopy the four E-root files when switching variants so FATX',
    'placement is controlled as much as FTP allows.',
    '',
    'Recommended hardware order:',
    '',
    '1. `payload-progress-readsectors` - quiet progress markers during devkrnl/devinit file loads.',
    '2. `idephase-payload-readsectors` - quiet until devkrnl/devinit, then prints FATX/IDE phase markers.',
    '3. `idephase-readsectors-filesector` - noisy full phase trace from partition/config lookup.',
    '4. `ata-readsectors-filesector` - first follow-up after sector512 showed a 4/5 boot rate.',
    '5. `3fa5e65-sector512` - current best known loader, but not fully repeatable.',
    '6. `3fa5e65-filesector` - best diagnostic if ATA readsectors still hangs during file reads.',
    '7. `3fa5e65-findsector` - directory lookup diagnostic.',
    '8. `4dcc618-current` - control package for the nondeterministic current-loader behavior.',
    ''
)

foreach ($item in $manifest) {
    $manifestLines += @(
        "## $($item.id)",
        '',
        $item.label,
        '',
        "Package: $($item.package)",
        "Dashboard folder: E:\Apps\$($item.dashboard)\",
        "XBE SHA256: $($item.xbe_sha256)",
        "ZIP SHA256: $($item.zip_sha256)",
        ''
    )
}

$manifestPath = Join-Path $setDir 'README.md'
$manifestLines | Set-Content -LiteralPath $manifestPath -Encoding ASCII

$setZip = "$setDir.zip"
Remove-Item -Force -LiteralPath $setZip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $setDir '*') -DestinationPath $setZip

Get-Item -LiteralPath $setDir, $setZip
