$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'
$xemuArguments = @('-display', 'none', '-S') + [string[]]$args

& $launcher `
    -ConfigPath 'run\xemu.toml' `
    -BiosPath 'Xbox-Emulator-Files\bios\Complex_4627.bin' `
    -XemuPath 'tools\xemu\xemu.exe' `
    -Avpack 'hdtv' `
    -KernelPath 'upstream\tinycore-17-x86\vmlinuz' `
    -InitrdPath 'upstream\tinycore-17-x86\core.gz' `
    -KernelAppend 'quiet' `
    -XemuArgument ([string[]]$xemuArguments)
