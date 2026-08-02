$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'
$serialLog = Join-Path $repoRoot 'run\guest-serial.log'

if ($env:XBOX_XEMU_DRY_RUN -ne '1') {
    Remove-Item -LiteralPath $serialLog -Force -ErrorAction SilentlyContinue
}

$xemuArguments = @('-serial', "file:$serialLog") + [string[]]$args

& $launcher `
    -ConfigPath 'run\xemu.toml' `
    -BiosPath 'Xbox-Emulator-Files\bios\Complex_4627.bin' `
    -XemuPath 'tools\xemu\xemu.exe' `
    -Avpack 'hdtv' `
    -KernelPath 'artifacts\kernels\xbox-linux-5.8.1-serial-bzImage' `
    -InitrdPath 'artifacts\initramfs\xbox-smoke-core.gz' `
    -KernelAppend 'console=ttyS0,,115200n8' `
    -XemuArgument ([string[]]$xemuArguments)
