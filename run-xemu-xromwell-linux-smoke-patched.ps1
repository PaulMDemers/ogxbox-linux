$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$config = Join-Path $repoRoot 'run\xemu-xromwell-linux-smoke.toml'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'
$iso = Join-Path $repoRoot 'artifacts\xromwell-linux-smoke.iso'

foreach ($path in @($xemu, $config, $mcpx, $bios, $iso)) {
    if (-not (Test-Path $path)) {
        throw "Required file was not found: $path"
    }
}

& $xemu `
    -config_path $config `
    -bios $bios `
    @args
