param(
    [string]$OutDir = "build\xbox-linux-devuan-fluxlite-game-disc-modern-diagnostic",
    [string]$OutputIso = "artifacts\xbox-linux-devuan-fluxlite-game-disc-modern-diagnostic.iso",
    [string]$KernelPath = "artifacts\kernels\xbox-linux-6.18.33-fatx-tinycore-bzImage"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$builder = Join-Path $repoRoot 'scripts\build_devuan_daedalus_i386_game_disc.ps1'

& $builder -OutDir $OutDir -OutputIso $OutputIso -KernelPath $KernelPath
