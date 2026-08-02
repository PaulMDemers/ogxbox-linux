$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu_temporary_media.ps1'

& $launcher `
    -BiosPath 'artifacts\cromwell-autocd_1024.bin' `
    -HddPath 'Xbox-Emulator-Files\hdd\xbox_hdd.qcow2' `
    -DvdPath 'artifacts\xbox-linux-devuan-desktop-full-live-game-disc.iso' `
    -ConfigPrefix 'xemu-devuan-live-autocd' `
    -Device ([string[]]@('usb-kbd', 'usb-tablet')) `
    -XemuArgument ([string[]]$args)
