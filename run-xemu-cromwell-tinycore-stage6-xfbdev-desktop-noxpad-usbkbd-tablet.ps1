$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$config = Join-Path $repoRoot 'run\xemu-cromwell-tinycore-stage6-xfbdev-desktop-noxpad-usbkbd-tablet.toml'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$bios = Join-Path $repoRoot 'artifacts\cromwell-autocd_1024.bin'

foreach ($path in @($xemu, $config, $mcpx, $bios)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file was not found: $path"
    }
}

& $xemu `
    -config_path $config `
    -bios $bios `
    -machine "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite" `
    -device usb-kbd `
    -device usb-tablet `
    @args
