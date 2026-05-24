$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$xemu = Join-Path $repoRoot 'tools\xemu\xemu.exe'
$config = Join-Path $repoRoot 'run\xemu.toml'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'
$kernel = Join-Path $repoRoot 'artifacts\kernels\xbox-linux-5.8.1-bzImage'
$initrd = Join-Path $repoRoot 'artifacts\initramfs\xbox-smoke-core.gz'
$debugLog = Join-Path $repoRoot 'run\guest-debugcon.log'

foreach ($path in @($xemu, $config, $mcpx, $bios, $kernel, $initrd)) {
    if (-not (Test-Path $path)) {
        throw "Required file was not found: $path"
    }
}

Remove-Item -Force $debugLog -ErrorAction SilentlyContinue
$append = 'debug'

& $xemu `
    -config_path $config `
    -bios $bios `
    -machine "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=hdtv,kernel=$kernel,initrd=$initrd,append=$append" `
    -chardev "file,id=debugcon,path=$debugLog" `
    -device "isa-debugcon,iobase=0xe9,chardev=debugcon" `
    @args
