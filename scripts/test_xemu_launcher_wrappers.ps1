$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'

$cases = @(
    @{
        Launcher = 'run-xemu-cromwell-modernhdr-busybox-reboot-probe-6.18.33.ps1'
        Config = 'run\xemu-cromwell-modernhdr-busybox-reboot-probe-6.18.33.toml'
        Bios = 'artifacts\cromwell-autocd-modernhdr_1024.bin'
        Devices = @()
    },
    @{
        Launcher = 'run-xemu-cromwell-modernhdr-initrd16-busybox-console-6.18.33.ps1'
        Config = 'run\xemu-cromwell-modernhdr-initrd16-busybox-console-6.18.33.toml'
        Bios = 'artifacts\cromwell-autocd-modernhdr-initrd16_1024.bin'
        Devices = @()
    },
    @{
        Launcher = 'run-xemu-cromwell-modernhdr-initrd16-busybox-reboot-probe-6.18.33.ps1'
        Config = 'run\xemu-cromwell-modernhdr-initrd16-busybox-reboot-probe-6.18.33.toml'
        Bios = 'artifacts\cromwell-autocd-modernhdr-initrd16_1024.bin'
        Devices = @()
    },
    @{
        Launcher = 'run-xemu-cromwell-modernhdr-initrd16-tinycore11-stage6-xfbdev-desktop-6.18.33.ps1'
        Config = 'run\xemu-cromwell-modernhdr-initrd16-tinycore11-stage6-xfbdev-desktop-6.18.33.toml'
        Bios = 'artifacts\cromwell-autocd-modernhdr-initrd16_1024.bin'
        Devices = @('usb-kbd', 'usb-tablet')
    },
    @{
        Launcher = 'run-xemu-cromwell-modernhdr-initrd16-tinycore11-stage6-xfbdev-desktop-6.18.33-noinput.ps1'
        Config = 'run\xemu-cromwell-modernhdr-initrd16-tinycore11-stage6-xfbdev-desktop-6.18.33.toml'
        Bios = 'artifacts\cromwell-autocd-modernhdr-initrd16_1024.bin'
        Devices = @()
    },
    @{
        Launcher = 'run-xemu-cromwell-modernhdr-initrd32-busybox-console-6.18.33.ps1'
        Config = 'run\xemu-cromwell-modernhdr-initrd32-busybox-console-6.18.33.toml'
        Bios = 'artifacts\cromwell-autocd-modernhdr-initrd32_1024.bin'
        Devices = @()
    },
    @{
        Launcher = 'run-xemu-cromwell-modernhdr-initrd32-tinycore11-stage6-xfbdev-desktop-6.18.33.ps1'
        Config = 'run\xemu-cromwell-modernhdr-initrd32-tinycore11-stage6-xfbdev-desktop-6.18.33.toml'
        Bios = 'artifacts\cromwell-autocd-modernhdr-initrd32_1024.bin'
        Devices = @('usb-kbd', 'usb-tablet')
    }
)

$oldDryRun = $env:XBOX_XEMU_DRY_RUN
$env:XBOX_XEMU_DRY_RUN = '1'

try {
    foreach ($case in $cases) {
        $launcher = Join-Path $repoRoot $case.Launcher
        $result = & $launcher
        $expectedArguments = @(
            '-config_path', (Join-Path $repoRoot $case.Config),
            '-bios', (Join-Path $repoRoot $case.Bios),
            '-machine', "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite"
        )

        foreach ($device in $case.Devices) {
            $expectedArguments += @('-device', $device)
        }

        if ((ConvertTo-Json @($result.Arguments) -Compress) -ne
            (ConvertTo-Json @($expectedArguments) -Compress)) {
            throw "Argument mismatch for $($case.Launcher)"
        }
    }

    $forwardResult = & (Join-Path $repoRoot $cases[0].Launcher) '-S' '-display' 'none'
    $forwarded = @($forwardResult.Arguments | Select-Object -Last 3)
    if ((ConvertTo-Json $forwarded -Compress) -ne
        (ConvertTo-Json @('-S', '-display', 'none') -Compress)) {
        throw 'Additional xemu arguments were not forwarded unchanged.'
    }
} finally {
    $env:XBOX_XEMU_DRY_RUN = $oldDryRun
}

Write-Output "Xemu launcher wrapper smoke: PASS ($($cases.Count) wrappers)"
