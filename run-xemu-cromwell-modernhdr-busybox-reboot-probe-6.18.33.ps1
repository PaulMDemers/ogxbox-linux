$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu-cromwell-modernhdr-busybox-reboot-probe-6.18.33.toml' `
    -BiosPath 'artifacts\cromwell-autocd-modernhdr_1024.bin' `
    -XemuArgument ([string[]]$args)
