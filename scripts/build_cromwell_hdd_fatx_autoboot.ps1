param(
    [string]$CromwellPath = "sources\cromwell-xboxdev",
    [string]$OutRom = "artifacts\cromwell-hddfatx-autoboot-modernhdr-initrd32_1024.bin",
    [string]$OutXbeDir = "build\xromwell-hddfatx-autoboot-disc",
    [string]$OutIso = "artifacts\xromwell-hddfatx-autoboot-initrd32.iso",
    [string]$ExtraCromCflags = "-DXBOX_LINUX_AUTOBOOT_FATX -DFATX_PROGRESS",
    [switch]$NoClean
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$cromwell = Join-Path $repoRoot $CromwellPath
$outRomFull = Join-Path $repoRoot $OutRom
$outXbeDirFull = Join-Path $repoRoot $OutXbeDir
$outIsoFull = Join-Path $repoRoot $OutIso
$xdvdfs = Join-Path $repoRoot 'tools\xdvdfs\xdvdfs.exe'

foreach ($path in @($cromwell, $xdvdfs)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required path was not found: $path"
    }
}

$cromwellWsl = (Resolve-Path -LiteralPath $cromwell).Path -replace '\\', '/'
if ($cromwellWsl -match '^([A-Za-z]):/(.*)$') {
    $drive = $Matches[1].ToLowerInvariant()
    $cromwellWsl = "/mnt/$drive/$($Matches[2])"
}

if (-not $NoClean) {
    wsl --cd $cromwellWsl bash -lc 'make clean'
}

$makeCommand = "make all EXTRA_CROM_CFLAGS='$ExtraCromCflags'"
wsl --cd $cromwellWsl bash -lc $makeCommand

$rom = Join-Path $cromwell 'image\cromwell_1024.bin'
$xbe = Join-Path $cromwell 'xbe\xromwell.xbe'
foreach ($path in @($rom, $xbe)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Cromwell build did not produce: $path"
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outRomFull) | Out-Null
Copy-Item -Force -LiteralPath $rom -Destination $outRomFull

New-Item -ItemType Directory -Force -Path $outXbeDirFull | Out-Null
Copy-Item -Force -LiteralPath $xbe -Destination (Join-Path $outXbeDirFull 'default.xbe')

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outIsoFull) | Out-Null
& $xdvdfs pack $outXbeDirFull $outIsoFull

Get-Item -LiteralPath $outRomFull, (Join-Path $outXbeDirFull 'default.xbe'), $outIsoFull
