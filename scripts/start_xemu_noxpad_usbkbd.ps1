param(
    [switch]$KillExisting
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$xemu = Join-Path $root 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$config = Join-Path $root 'run\xemu-cromwell-busybox-console-noxpad-usbkbd.toml'
$mcpx = Join-Path $root 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$bios = Join-Path $root 'artifacts\cromwell-autocd_1024.bin'

foreach ($path in @($xemu, $config, $mcpx, $bios)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file was not found: $path"
    }
}

if ($KillExisting) {
    Get-Process -Name xemu -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
}

$args = @(
    '-config_path', $config,
    '-bios', $bios,
    '-machine', "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite",
    '-device', 'usb-kbd'
)

$proc = Start-Process -FilePath $xemu -ArgumentList $args -PassThru

$deadline = (Get-Date).AddSeconds(45)
do {
    $proc.Refresh()
    if ($proc.MainWindowHandle -ne 0) {
        [pscustomobject]@{
            pid = $proc.Id
            hwnd = "0x{0:X}" -f $proc.MainWindowHandle.ToInt64()
            config = $config
        }
        exit 0
    }
    Start-Sleep -Milliseconds 500
} while ((Get-Date) -lt $deadline)

throw "Timed out waiting for xemu window for PID $($proc.Id)."
