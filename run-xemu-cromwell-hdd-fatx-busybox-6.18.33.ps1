$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

& $launcher `
    -ConfigPath 'run\xemu-cromwell-hdd-fatx-busybox-6.18.33.toml' `
    -BiosPath 'artifacts\cromwell-hddfatx-autoboot-modernhdr-initrd32_1024.bin' `
    -RequiredPath 'run\hdd\xbox_hdd_hddboot.raw' `
    -XemuArgument ([string[]]$args)
