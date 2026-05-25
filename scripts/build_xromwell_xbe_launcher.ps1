param(
    [string]$CromwellPath = "sources\cromwell-xboxdev",
    [string]$OutDir = "build\xromwell-modern-disc",
    [string]$OutIso = "artifacts\xromwell-modern-initrd32.iso"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$cromwell = Join-Path $repoRoot $CromwellPath
$xbe = Join-Path $cromwell 'xbe\xromwell.xbe'
$outDirFull = Join-Path $repoRoot $OutDir
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
wsl --cd $cromwellWsl bash -lc 'make all'

if (-not (Test-Path -LiteralPath $xbe)) {
    throw "Cromwell build did not produce: $xbe"
}

New-Item -ItemType Directory -Force -Path $outDirFull | Out-Null
Copy-Item -Force -LiteralPath $xbe -Destination (Join-Path $outDirFull 'default.xbe')
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outIsoFull) | Out-Null
& $xdvdfs pack $outDirFull $outIsoFull

Get-Item -LiteralPath (Join-Path $outDirFull 'default.xbe'), $outIsoFull
