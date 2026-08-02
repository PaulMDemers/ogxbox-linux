$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu-cromwell-fast-atapi.toml' `
    -BiosPath 'artifacts\cromwell-fast-atapi_1024.bin' `
    -RequiredPath 'artifacts\cromwell-smoke.iso' `
    -XemuArgument ([string[]]$args)
