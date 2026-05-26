param(
    [string]$CromwellPath = "sources\cromwell-xboxdev",
    [string]$OutRom = "artifacts\cromwell-hddfatx-autoboot-hdtv480p_1024.bin",
    [string]$OutXbeDir = "build\xromwell-hddfatx-autoboot-hdtv480p-disc",
    [string]$OutIso = "artifacts\xromwell-hddfatx-autoboot-hdtv480p.iso"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$builder = Join-Path $repoRoot 'scripts\build_cromwell_hdd_fatx_autoboot.ps1'

& $builder `
    -CromwellPath $CromwellPath `
    -OutRom $OutRom `
    -OutXbeDir $OutXbeDir `
    -OutIso $OutIso `
    -ExtraCromCflags '-DXBOX_LINUX_AUTOBOOT_FATX -DFATX_PROGRESS -DXBOX_FORCE_AV_HDTV_480P'

