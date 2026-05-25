$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$config = Join-Path $repoRoot 'run\xemu-cromwell-hdd-fatx-busybox-6.18.33.toml'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$bios = Join-Path $repoRoot 'artifacts\cromwell-hddfatx-autoboot-modernhdr-initrd32_1024.bin'
$hdd = Join-Path $repoRoot 'run\hdd\xbox_hdd_hddboot.raw'

foreach ($path in @($xemu, $config, $mcpx, $bios, $hdd)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file was not found: $path"
    }
}

& $xemu `
    -config_path $config `
    -bios $bios `
    -machine "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite" `
    @args
