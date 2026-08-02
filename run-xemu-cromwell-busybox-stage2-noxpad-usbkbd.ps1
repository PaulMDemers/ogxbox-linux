$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu-cromwell-busybox-stage2-noxpad-usbkbd.toml' `
    -BiosPath 'artifacts\cromwell-autocd_1024.bin' `
    -Device 'usb-kbd' `
    -XemuArgument ([string[]]$args)
