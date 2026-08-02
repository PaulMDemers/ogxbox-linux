$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu-cromwell-tiny-read.toml' `
    -BiosPath 'downloads\cromwell-xboxdev\build-20250529-86f5473\cromwell_1024.bin' `
    -RequiredPath 'artifacts\cromwell-tiny-read.iso' `
    -XemuArgument ([string[]]$args)
