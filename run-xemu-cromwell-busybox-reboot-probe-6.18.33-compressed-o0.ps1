$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu-cromwell-busybox-reboot-probe-6.18.33-compressed-o0.toml' `
    -BiosPath 'artifacts\cromwell-autocd_1024.bin' `
    -XemuArgument ([string[]]$args)
