$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$config = Join-Path $repoRoot 'run\xemu-cromwell-tiny-read.toml'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$bios = Join-Path $repoRoot 'downloads\cromwell-xboxdev\build-20250529-86f5473\cromwell_1024.bin'
$iso = Join-Path $repoRoot 'artifacts\cromwell-tiny-read.iso'

foreach ($path in @($xemu, $config, $mcpx, $bios, $iso)) {
    if (-not (Test-Path $path)) {
        throw "Required file was not found: $path"
    }
}

& $xemu `
    -config_path $config `
    -bios $bios `
    -machine "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite" `
    @args
