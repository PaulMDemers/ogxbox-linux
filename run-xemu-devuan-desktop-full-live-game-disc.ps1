$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'
$eeprom = Join-Path $repoRoot 'run\eeprom.bin'
$hdd = Join-Path $repoRoot 'Xbox-Emulator-Files\hdd\xbox_hdd.qcow2'
$dvd = Join-Path $repoRoot 'artifacts\xbox-linux-devuan-desktop-full-live-game-disc.iso'

foreach ($path in @($xemu, $mcpx, $bios, $eeprom, $hdd, $dvd)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file was not found: $path"
    }
}

$config = Join-Path $env:TEMP ("xemu-devuan-live-" + [System.Guid]::NewGuid().ToString("N") + ".toml")
@"
[general]
show_welcome = false

[input.bindings]
port1_driver = 'usb-xbox-gamepad'
port1 = 'keyboard'

[sys.files]
bootrom_path = '$mcpx'
flashrom_path = '$bios'
eeprom_path = '$eeprom'
hdd_path = '$hdd'
dvd_path = '$dvd'
"@ | Set-Content -LiteralPath $config -Encoding ASCII

try {
    & $xemu `
        -config_path $config `
        -bios $bios `
        -machine "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite" `
        @args
} finally {
    Remove-Item -LiteralPath $config -Force -ErrorAction SilentlyContinue
}
