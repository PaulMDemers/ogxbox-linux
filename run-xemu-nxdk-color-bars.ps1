$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$xemu = Join-Path $repoRoot 'tools\xemu\xemu.exe'
$config = Join-Path $repoRoot 'run\xemu-nxdk-color-bars.toml'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'

foreach ($path in @($xemu, $config, $bios)) {
    if (-not (Test-Path $path)) {
        throw "Required file was not found: $path"
    }
}

& $xemu -config_path $config -bios $bios @args
