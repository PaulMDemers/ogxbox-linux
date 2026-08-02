param(
    [string]$RawHdd = 'run\hdd\xbox_hdd_hddboot.raw',
    [string]$Dvd = 'artifacts\xromwell-hddfatx-autoboot-initrd32.iso'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$config = Join-Path $repoRoot 'run\xemu-xromwell-hddfatx-autoboot.toml'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'
$hdd = Join-Path $repoRoot $RawHdd
$dvd = Join-Path $repoRoot $Dvd
$eeprom = Join-Path $repoRoot 'run\eeprom.bin'

foreach ($path in @($xemu, $mcpx, $bios, $hdd, $dvd, $eeprom)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file was not found: $path"
    }
}

$configText = @"
[general]
show_welcome = false

[sys.files]
bootrom_path = '$mcpx'
flashrom_path = '$bios'
eeprom_path = '$eeprom'
hdd_path = '$hdd'
dvd_path = '$dvd'

[input.bindings]
port1 = 'keyboard'
port1_driver = 'usb-xbox-gamepad'
"@

Set-Content -LiteralPath $config -Encoding ASCII -Value $configText

& $xemu `
    -config_path $config `
    -bios $bios `
    -machine "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite" `
    @args
