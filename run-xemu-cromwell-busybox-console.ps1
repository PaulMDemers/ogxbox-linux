$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu-cromwell-busybox-console.toml' `
    -BiosPath 'artifacts\cromwell-fast-atapi_1024.bin' `
    -RequiredPath 'artifacts\cromwell-busybox-console.iso' `
    -XemuArgument ([string[]]$args)
