$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$eeprom = Join-Path $repoRoot 'run\eeprom.bin'
$hdd = Join-Path $repoRoot 'Xbox-Emulator-Files\hdd\xbox_hdd.qcow2'
$dvd = Join-Path $repoRoot 'artifacts\xbox-linux-devuan-desktop-full-live-game-disc.iso'

$cases = @(
    [pscustomobject]@{
        Launcher = 'run-xemu-devuan-desktop-full-live-cromwell-autocd.ps1'
        Prefix = 'xemu-devuan-live-autocd-'
        Bios = 'artifacts\cromwell-autocd_1024.bin'
        Devices = @('usb-kbd', 'usb-tablet')
        InputBindings = $false
    },
    [pscustomobject]@{
        Launcher = 'run-xemu-devuan-desktop-full-live-game-disc.ps1'
        Prefix = 'xemu-devuan-live-'
        Bios = 'Xbox-Emulator-Files\bios\Complex_4627.bin'
        Devices = @()
        InputBindings = $true
    }
)

$oldDryRun = $env:XBOX_XEMU_DRY_RUN
$oldSkipPathValidation = $env:XBOX_XEMU_SKIP_PATH_VALIDATION
$env:XBOX_XEMU_DRY_RUN = '1'
Remove-Item Env:XBOX_XEMU_SKIP_PATH_VALIDATION -ErrorAction SilentlyContinue

try {
    foreach ($case in $cases) {
        $before = @(Get-ChildItem -LiteralPath $env:TEMP `
            -Filter "$($case.Prefix)*.toml" -File -ErrorAction SilentlyContinue).FullName
        $result = & (Join-Path $repoRoot $case.Launcher)
        $resolvedBios = Join-Path $repoRoot $case.Bios
        $expectedArguments = @(
            '-config_path', $result.ConfigPath,
            '-bios', $resolvedBios,
            '-machine', "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite"
        )

        foreach ($device in $case.Devices) {
            $expectedArguments += @('-device', $device)
        }

        if ($result.XemuPath -ne $xemu) {
            throw "Xemu path mismatch for $($case.Launcher)"
        }
        if ((ConvertTo-Json @($result.Arguments) -Compress) -ne
            (ConvertTo-Json @($expectedArguments) -Compress)) {
            throw "Argument mismatch for $($case.Launcher)"
        }

        $expectedRequired = @(
            $xemu, $result.ConfigPath, $resolvedBios, $mcpx, $eeprom, $hdd, $dvd
        )
        if ((ConvertTo-Json @($result.RequiredPaths) -Compress) -ne
            (ConvertTo-Json @($expectedRequired) -Compress)) {
            throw "Required path mismatch for $($case.Launcher)"
        }

        $hasInputBindings = $result.ConfigText -match '(?m)^\[input\.bindings\]$'
        if ($hasInputBindings -ne $case.InputBindings) {
            throw "Input binding mismatch for $($case.Launcher)"
        }
        if ($case.InputBindings) {
            $expectedConfig = @"
[general]
show_welcome = false

[input.bindings]
port1_driver = 'usb-xbox-gamepad'
port1 = 'keyboard'

[sys.files]
bootrom_path = '$mcpx'
flashrom_path = '$resolvedBios'
eeprom_path = '$eeprom'
hdd_path = '$hdd'
dvd_path = '$dvd'
"@
        } else {
            $expectedConfig = @"
[general]
show_welcome = false

[sys.files]
bootrom_path = '$mcpx'
flashrom_path = '$resolvedBios'
eeprom_path = '$eeprom'
hdd_path = '$hdd'
dvd_path = '$dvd'
"@
        }
        if ($result.ConfigText -cne $expectedConfig) {
            throw "Generated config mismatch for $($case.Launcher)"
        }
        foreach ($path in @($mcpx, $resolvedBios, $eeprom, $hdd, $dvd)) {
            if ($result.ConfigText -notmatch [regex]::Escape("'$path'")) {
                throw "Generated config omitted $path for $($case.Launcher)"
            }
        }
        if (Test-Path -LiteralPath $result.ConfigPath) {
            throw "Temporary config was not removed: $($result.ConfigPath)"
        }

        $after = @(Get-ChildItem -LiteralPath $env:TEMP `
            -Filter "$($case.Prefix)*.toml" -File -ErrorAction SilentlyContinue).FullName
        if ((ConvertTo-Json @($after) -Compress) -ne
            (ConvertTo-Json @($before) -Compress)) {
            throw "Temporary config inventory changed for $($case.Launcher)"
        }
    }

    $forwardResult = & (Join-Path $repoRoot $cases[0].Launcher) '-S' '-display' 'none'
    $forwarded = @($forwardResult.Arguments | Select-Object -Last 3)
    if ((ConvertTo-Json $forwarded -Compress) -ne
        (ConvertTo-Json @('-S', '-display', 'none') -Compress)) {
        throw 'Temporary-media wrapper arguments were not forwarded unchanged.'
    }

    $failurePrefix = 'xemu-missing-media-smoke-'
    $beforeFailure = @(Get-ChildItem -LiteralPath $env:TEMP `
        -Filter "$failurePrefix*.toml" -File -ErrorAction SilentlyContinue).FullName
    try {
        & (Join-Path $repoRoot 'scripts\invoke_xemu_temporary_media.ps1') `
            -BiosPath $cases[0].Bios `
            -HddPath 'missing\smoke-hdd.qcow2' `
            -DvdPath $dvd `
            -ConfigPrefix $failurePrefix `
            -DryRun
        throw 'Missing-media validation unexpectedly succeeded.'
    } catch {
        if ($_.Exception.Message -eq 'Missing-media validation unexpectedly succeeded.') {
            throw
        }
        if ($_.Exception.Message -notmatch 'Required file was not found:') {
            throw
        }
    }
    $afterFailure = @(Get-ChildItem -LiteralPath $env:TEMP `
        -Filter "$failurePrefix*.toml" -File -ErrorAction SilentlyContinue).FullName
    if ((ConvertTo-Json @($afterFailure) -Compress) -ne
        (ConvertTo-Json @($beforeFailure) -Compress)) {
        throw 'Temporary config remained after dependency validation failed.'
    }
} finally {
    if ($null -eq $oldDryRun) {
        Remove-Item Env:XBOX_XEMU_DRY_RUN -ErrorAction SilentlyContinue
    } else {
        $env:XBOX_XEMU_DRY_RUN = $oldDryRun
    }
    if ($null -eq $oldSkipPathValidation) {
        Remove-Item Env:XBOX_XEMU_SKIP_PATH_VALIDATION -ErrorAction SilentlyContinue
    } else {
        $env:XBOX_XEMU_SKIP_PATH_VALIDATION = $oldSkipPathValidation
    }
}

Write-Output "Dynamic xemu launcher smoke: PASS ($($cases.Count) temporary wrappers)"
