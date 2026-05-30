param(
    [string]$OutDir = "build\xbox-linux-devuan-desktop-full-game-disc",
    [string]$OutputIso = "artifacts\xbox-linux-devuan-desktop-full-game-disc.iso",
    [string]$PayloadPath = "artifacts\hdd\xbox-devuan-daedalus-i386-desktop-full.ext2"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$builder = Join-Path $repoRoot 'scripts\build_devuan_daedalus_i386_game_disc.ps1'

& $builder `
    -OutDir $OutDir `
    -OutputIso $OutputIso `
    -PayloadPath $PayloadPath `
    -Title "Xbox Linux Devuan Full Desktop Game Disc"
