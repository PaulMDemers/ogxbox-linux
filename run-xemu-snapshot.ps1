$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$xemu = Join-Path $repoRoot 'tools\xemu\xemu.exe'
$config = Join-Path $repoRoot 'run\xemu.toml'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'

if (-not (Test-Path $xemu)) {
    throw "xemu.exe was not found at $xemu"
}

if (-not (Test-Path $config)) {
    throw "xemu config was not found at $config"
}

if (-not (Test-Path $bios)) {
    throw "Xbox BIOS was not found at $bios"
}

& $xemu -config_path $config -bios $bios -snapshot @args
