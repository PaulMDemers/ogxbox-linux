$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu-xromwell-linux-smoke.toml' `
    -BiosPath 'Xbox-Emulator-Files\bios\Complex_4627.bin' `
    -RequiredPath 'artifacts\xromwell-linux-smoke.iso' `
    -OmitMachineArgument `
    -XemuArgument ([string[]]$args)
