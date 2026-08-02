$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu-cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33-usbkbd-tablet.toml' `
    -BiosPath 'artifacts\cromwell-autocd_1024.bin' `
    -Device ([string[]]@('usb-kbd', 'usb-tablet')) `
    -XemuArgument ([string[]]$args)
