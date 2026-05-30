param(
    [string]$OutDir = "build\xbox-linux-devuan-desktop-full-live-game-disc",
    [string]$OutputIso = "artifacts\xbox-linux-devuan-desktop-full-live-game-disc.iso",
    [string]$PayloadPath = "artifacts\hdd\xbox-devuan-daedalus-i386-desktop-full.squashfs",
    [switch]$RebuildPayload,
    [switch]$NoIso9660Overlay
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$squashBuilder = Join-Path $repoRoot 'scripts\build_devuan_daedalus_i386_desktop_full_squashfs.ps1'
$discBuilder = Join-Path $repoRoot 'scripts\build_devuan_daedalus_i386_game_disc.ps1'

if ($RebuildPayload -or -not (Test-Path -LiteralPath (Join-Path $repoRoot $PayloadPath))) {
    & $squashBuilder -SquashfsPath $PayloadPath -RebuildRoot:$RebuildPayload
    if ($LASTEXITCODE -ne 0) {
        throw "Devuan full desktop squashfs build failed"
    }
}

& $discBuilder `
    -OutDir $OutDir `
    -OutputIso $OutputIso `
    -PayloadPath $PayloadPath `
    -PayloadDiscName "devuan.squashfs" `
    -RootFsType "squashfs" `
    -Title "Xbox Linux Devuan Full Desktop Live Game Disc" `
    -NoIso9660Overlay:$NoIso9660Overlay
