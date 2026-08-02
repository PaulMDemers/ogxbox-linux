$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$mcpxRelative = 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$defaultXemu = 'tools\xemu-v0.8.135-nvnet\xemu.exe'

function New-LauncherCase {
    param(
        [Parameter(Mandatory)]
        [string]$Launcher,

        [Parameter(Mandatory)]
        [string]$Config,

        [Parameter(Mandatory)]
        [string]$Bios,

        [string[]]$Devices = @(),
        [string[]]$RequiredPaths = @(),
        [string]$XemuPath = $defaultXemu,
        [switch]$OmitMachineArgument
    )

    [pscustomobject]@{
        Launcher = $Launcher
        Config = $Config
        Bios = $Bios
        Devices = [string[]]$Devices
        RequiredPaths = [string[]]$RequiredPaths
        XemuPath = $XemuPath
        OmitMachineArgument = [bool]$OmitMachineArgument
    }
}

$cases = @(
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-modernhdr-busybox-reboot-probe-6.18.33.ps1' `
        -Config 'run\xemu-cromwell-modernhdr-busybox-reboot-probe-6.18.33.toml' `
        -Bios 'artifacts\cromwell-autocd-modernhdr_1024.bin'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-modernhdr-initrd16-busybox-console-6.18.33.ps1' `
        -Config 'run\xemu-cromwell-modernhdr-initrd16-busybox-console-6.18.33.toml' `
        -Bios 'artifacts\cromwell-autocd-modernhdr-initrd16_1024.bin'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-modernhdr-initrd16-busybox-reboot-probe-6.18.33.ps1' `
        -Config 'run\xemu-cromwell-modernhdr-initrd16-busybox-reboot-probe-6.18.33.toml' `
        -Bios 'artifacts\cromwell-autocd-modernhdr-initrd16_1024.bin'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-modernhdr-initrd16-tinycore11-stage6-xfbdev-desktop-6.18.33.ps1' `
        -Config 'run\xemu-cromwell-modernhdr-initrd16-tinycore11-stage6-xfbdev-desktop-6.18.33.toml' `
        -Bios 'artifacts\cromwell-autocd-modernhdr-initrd16_1024.bin' `
        -Devices @('usb-kbd', 'usb-tablet')
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-modernhdr-initrd16-tinycore11-stage6-xfbdev-desktop-6.18.33-noinput.ps1' `
        -Config 'run\xemu-cromwell-modernhdr-initrd16-tinycore11-stage6-xfbdev-desktop-6.18.33.toml' `
        -Bios 'artifacts\cromwell-autocd-modernhdr-initrd16_1024.bin'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-modernhdr-initrd32-busybox-console-6.18.33.ps1' `
        -Config 'run\xemu-cromwell-modernhdr-initrd32-busybox-console-6.18.33.toml' `
        -Bios 'artifacts\cromwell-autocd-modernhdr-initrd32_1024.bin'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-modernhdr-initrd32-tinycore11-stage6-xfbdev-desktop-6.18.33.ps1' `
        -Config 'run\xemu-cromwell-modernhdr-initrd32-tinycore11-stage6-xfbdev-desktop-6.18.33.toml' `
        -Bios 'artifacts\cromwell-autocd-modernhdr-initrd32_1024.bin' `
        -Devices @('usb-kbd', 'usb-tablet')

    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-busybox-reboot-probe-6.18.33.ps1' `
        -Config 'run\xemu-cromwell-busybox-reboot-probe-6.18.33.toml' `
        -Bios 'artifacts\cromwell-autocd_1024.bin'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-busybox-reboot-probe-6.18.33-compressed-o0.ps1' `
        -Config 'run\xemu-cromwell-busybox-reboot-probe-6.18.33-compressed-o0.toml' `
        -Bios 'artifacts\cromwell-autocd_1024.bin'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-busybox-console-noxpad-usbkbd.ps1' `
        -Config 'run\xemu-cromwell-busybox-console-noxpad-usbkbd.toml' `
        -Bios 'artifacts\cromwell-autocd_1024.bin' `
        -Devices 'usb-kbd'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-busybox-stage2-noxpad-usbkbd.ps1' `
        -Config 'run\xemu-cromwell-busybox-stage2-noxpad-usbkbd.toml' `
        -Bios 'artifacts\cromwell-autocd_1024.bin' `
        -Devices 'usb-kbd'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-tinycore-stage3-noxpad-usbkbd.ps1' `
        -Config 'run\xemu-cromwell-tinycore-stage3-noxpad-usbkbd.toml' `
        -Bios 'artifacts\cromwell-autocd_1024.bin' `
        -Devices 'usb-kbd'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-tinycore-stage4-noxpad-usbkbd.ps1' `
        -Config 'run\xemu-cromwell-tinycore-stage4-noxpad-usbkbd.toml' `
        -Bios 'artifacts\cromwell-autocd_1024.bin' `
        -Devices 'usb-kbd'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33-usbkbd-tablet.ps1' `
        -Config 'run\xemu-cromwell-tinycore11-stage6-xfbdev-desktop-6.18.33-usbkbd-tablet.toml' `
        -Bios 'artifacts\cromwell-autocd_1024.bin' `
        -Devices @('usb-kbd', 'usb-tablet')
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-tinycore11-stage6-xfbdev-desktop-noxpad-usbkbd-tablet.ps1' `
        -Config 'run\xemu-cromwell-tinycore11-stage6-xfbdev-desktop-noxpad-usbkbd-tablet.toml' `
        -Bios 'artifacts\cromwell-autocd_1024.bin' `
        -Devices @('usb-kbd', 'usb-tablet')
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-tinycore-stage5-desktop-probe-noxpad-usbkbd-tablet.ps1' `
        -Config 'run\xemu-cromwell-tinycore-stage5-desktop-probe-noxpad-usbkbd-tablet.toml' `
        -Bios 'artifacts\cromwell-autocd_1024.bin' `
        -Devices @('usb-kbd', 'usb-tablet')
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-tinycore-stage6-xfbdev-desktop-noxpad-usbkbd-tablet.ps1' `
        -Config 'run\xemu-cromwell-tinycore-stage6-xfbdev-desktop-noxpad-usbkbd-tablet.toml' `
        -Bios 'artifacts\cromwell-autocd_1024.bin' `
        -Devices @('usb-kbd', 'usb-tablet')

    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-busybox-console.ps1' `
        -Config 'run\xemu-cromwell-busybox-console.toml' `
        -Bios 'artifacts\cromwell-fast-atapi_1024.bin' `
        -RequiredPaths 'artifacts\cromwell-busybox-console.iso'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-busybox-init.ps1' `
        -Config 'run\xemu-cromwell-busybox-init.toml' `
        -Bios 'artifacts\cromwell-fast-atapi_1024.bin' `
        -RequiredPaths 'artifacts\cromwell-busybox-init.iso'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-fast-atapi.ps1' `
        -Config 'run\xemu-cromwell-fast-atapi.toml' `
        -Bios 'artifacts\cromwell-fast-atapi_1024.bin' `
        -RequiredPaths 'artifacts\cromwell-smoke.iso'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-fast-serial.ps1' `
        -Config 'run\xemu-cromwell-fast-serial.toml' `
        -Bios 'artifacts\cromwell-fast-atapi_1024.bin' `
        -RequiredPaths 'artifacts\cromwell-serial-smoke.iso'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-tiny-init.ps1' `
        -Config 'run\xemu-cromwell-tiny-init.toml' `
        -Bios 'artifacts\cromwell-fast-atapi_1024.bin' `
        -RequiredPaths 'artifacts\cromwell-tiny-init.iso'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-tiny-read-patched.ps1' `
        -Config 'run\xemu-cromwell-tiny-read.toml' `
        -Bios 'downloads\cromwell-xboxdev\build-20250529-86f5473\cromwell_1024.bin' `
        -RequiredPaths 'artifacts\cromwell-tiny-read.iso'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-xboxdev-patched.ps1' `
        -Config 'run\xemu-cromwell-xboxdev.toml' `
        -Bios 'downloads\cromwell-xboxdev\build-20250529-86f5473\cromwell_1024.bin' `
        -RequiredPaths 'artifacts\cromwell-smoke.iso'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-xboxdev-smoke.ps1' `
        -Config 'run\xemu-cromwell-xboxdev.toml' `
        -Bios 'downloads\cromwell-xboxdev\build-20250529-86f5473\cromwell_1024.bin' `
        -RequiredPaths 'artifacts\cromwell-smoke.iso' `
        -XemuPath 'tools\xemu\xemu.exe'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-smoke.ps1' `
        -Config 'run\xemu-cromwell.toml' `
        -Bios 'sources\cromwell-2.40\cromwell_1024.bin' `
        -RequiredPaths 'artifacts\cromwell-smoke.iso' `
        -XemuPath 'tools\xemu\xemu.exe'
    New-LauncherCase `
        -Launcher 'run-xemu-cromwell-hdd-fatx-busybox-6.18.33.ps1' `
        -Config 'run\xemu-cromwell-hdd-fatx-busybox-6.18.33.toml' `
        -Bios 'artifacts\cromwell-hddfatx-autoboot-modernhdr-initrd32_1024.bin' `
        -RequiredPaths 'run\hdd\xbox_hdd_hddboot.raw'

    New-LauncherCase `
        -Launcher 'run-xemu-xromwell-linux-smoke-patched.ps1' `
        -Config 'run\xemu-xromwell-linux-smoke.toml' `
        -Bios 'Xbox-Emulator-Files\bios\Complex_4627.bin' `
        -RequiredPaths 'artifacts\xromwell-linux-smoke.iso' `
        -OmitMachineArgument
    New-LauncherCase `
        -Launcher 'run-xemu-xromwell-modern-initrd32.ps1' `
        -Config 'run\xemu-xromwell-modern-initrd32.toml' `
        -Bios 'Xbox-Emulator-Files\bios\Complex_4627.bin' `
        -RequiredPaths 'artifacts\xromwell-modern-initrd32.iso' `
        -OmitMachineArgument
    New-LauncherCase `
        -Launcher 'run-xemu-xromwell-xboxdev.ps1' `
        -Config 'run\xemu-xromwell-xboxdev.toml' `
        -Bios 'Xbox-Emulator-Files\bios\Complex_4627.bin' `
        -RequiredPaths 'artifacts\xromwell-xboxdev.iso' `
        -XemuPath 'tools\xemu\xemu.exe' `
        -OmitMachineArgument
    New-LauncherCase `
        -Launcher 'run-xemu-xromwell-xboxdev-patched.ps1' `
        -Config 'run\xemu-xromwell-xboxdev.toml' `
        -Bios 'Xbox-Emulator-Files\bios\Complex_4627.bin' `
        -RequiredPaths 'artifacts\xromwell-xboxdev.iso' `
        -OmitMachineArgument
)

$oldDryRun = $env:XBOX_XEMU_DRY_RUN
$oldSkipPathValidation = $env:XBOX_XEMU_SKIP_PATH_VALIDATION
$env:XBOX_XEMU_DRY_RUN = '1'
$env:XBOX_XEMU_SKIP_PATH_VALIDATION = '1'

try {
    foreach ($case in $cases) {
        $launcher = Join-Path $repoRoot $case.Launcher
        $result = & $launcher
        $expectedXemu = Join-Path $repoRoot $case.XemuPath
        $expectedArguments = @(
            '-config_path', (Join-Path $repoRoot $case.Config),
            '-bios', (Join-Path $repoRoot $case.Bios)
        )

        if (-not $case.OmitMachineArgument) {
            $expectedArguments += @(
                '-machine',
                "xbox,bootrom=$(Join-Path $repoRoot $mcpxRelative),kernel-irqchip=off,avpack=composite"
            )
        }

        foreach ($device in $case.Devices) {
            $expectedArguments += @('-device', $device)
        }

        if ($result.XemuPath -ne $expectedXemu) {
            throw "Xemu path mismatch for $($case.Launcher)"
        }

        if ((ConvertTo-Json @($result.Arguments) -Compress) -ne
            (ConvertTo-Json @($expectedArguments) -Compress)) {
            throw "Argument mismatch for $($case.Launcher)"
        }

        $expectedRequired = @(
            $expectedXemu,
            (Join-Path $repoRoot $case.Config),
            (Join-Path $repoRoot $case.Bios),
            (Join-Path $repoRoot $mcpxRelative)
        )
        $expectedRequired += @($case.RequiredPaths | ForEach-Object {
            Join-Path $repoRoot $_
        })

        if ((ConvertTo-Json @($result.RequiredPaths) -Compress) -ne
            (ConvertTo-Json @($expectedRequired) -Compress)) {
            throw "Required path mismatch for $($case.Launcher)"
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
    $env:XBOX_XEMU_SKIP_PATH_VALIDATION = $oldSkipPathValidation
}

Write-Output "Xemu launcher wrapper smoke: PASS ($($cases.Count) wrappers)"
