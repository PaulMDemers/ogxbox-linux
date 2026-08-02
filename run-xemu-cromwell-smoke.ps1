$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu-cromwell.toml' `
    -BiosPath 'sources\cromwell-2.40\cromwell_1024.bin' `
    -XemuPath 'tools\xemu\xemu.exe' `
    -RequiredPath 'artifacts\cromwell-smoke.iso' `
    -XemuArgument ([string[]]$args)
