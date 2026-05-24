$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$xemu = Join-Path $repoRoot 'tools\xemu\xemu.exe'
$config = Join-Path $repoRoot 'run\xemu.toml'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'
$kernel = Join-Path $repoRoot 'upstream\tinycore-17-x86\vmlinuz'
$initrd = Join-Path $repoRoot 'upstream\tinycore-17-x86\core.gz'

foreach ($path in @($xemu, $config, $mcpx, $bios, $kernel, $initrd)) {
    if (-not (Test-Path $path)) {
        throw "Required file was not found: $path"
    }
}

$append = 'quiet'

& $xemu `
    -config_path $config `
    -bios $bios `
    -machine "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=hdtv,kernel=$kernel,initrd=$initrd,append=$append" `
    -display none `
    -S `
    @args
