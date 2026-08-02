$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'
$debugLog = Join-Path $repoRoot 'run\guest-debugcon.log'

if ($env:XBOX_XEMU_DRY_RUN -ne '1') {
    Remove-Item -LiteralPath $debugLog -Force -ErrorAction SilentlyContinue
}

$xemuArguments = @(
    '-chardev', "file,id=debugcon,path=$debugLog",
    '-device', 'isa-debugcon,iobase=0xe9,chardev=debugcon'
) + [string[]]$args

& $launcher `
    -ConfigPath 'run\xemu.toml' `
    -BiosPath 'Xbox-Emulator-Files\bios\Complex_4627.bin' `
    -XemuPath 'tools\xemu\xemu.exe' `
    -Avpack 'hdtv' `
    -KernelPath 'artifacts\kernels\xbox-linux-5.8.1-bzImage' `
    -InitrdPath 'artifacts\initramfs\xbox-smoke-core.gz' `
    -KernelAppend 'debug' `
    -XemuArgument ([string[]]$xemuArguments)
