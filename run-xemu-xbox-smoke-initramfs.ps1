$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu.toml' `
    -BiosPath 'Xbox-Emulator-Files\bios\Complex_4627.bin' `
    -XemuPath 'tools\xemu\xemu.exe' `
    -Avpack 'hdtv' `
    -KernelPath 'artifacts\kernels\xbox-linux-5.8.1-bzImage' `
    -InitrdPath 'artifacts\initramfs\xbox-smoke-core.gz' `
    -KernelAppend 'debug' `
    -XemuArgument ([string[]]$args)
