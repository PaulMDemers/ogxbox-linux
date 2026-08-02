$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu-xromwell-xboxdev.toml' `
    -BiosPath 'Xbox-Emulator-Files\bios\Complex_4627.bin' `
    -RequiredPath 'artifacts\xromwell-xboxdev.iso' `
    -OmitMachineArgument `
    -XemuArgument ([string[]]$args)
