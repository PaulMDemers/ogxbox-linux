$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu_temporary_media.ps1'

& $launcher `
    -BiosPath 'Xbox-Emulator-Files\bios\Complex_4627.bin' `
    -HddPath 'Xbox-Emulator-Files\hdd\xbox_hdd.qcow2' `
    -DvdPath 'artifacts\xbox-linux-devuan-desktop-full-live-game-disc.iso' `
    -ConfigPrefix 'xemu-devuan-live' `
    -InputBindings 'keyboard-gamepad' `
    -XemuArgument ([string[]]$args)
