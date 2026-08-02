[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BiosPath,

    [Parameter(Mandatory)]
    [string]$HddPath,

    [Parameter(Mandatory)]
    [string]$DvdPath,

    [string]$EepromPath = 'run\eeprom.bin',
    [string]$McpxPath = 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin',
    [string]$XemuPath = 'tools\xemu-v0.8.135-nvnet\xemu.exe',
    [string]$ConfigPrefix = 'xemu-media',

    [ValidateSet('none', 'keyboard-gamepad')]
    [string]$InputBindings = 'none',

    [string[]]$Device = @(),
    [string[]]$XemuArgument = @(),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$launcher = Join-Path $repoRoot 'scripts\invoke_xemu.ps1'

function Resolve-WorkspacePath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
}

$resolvedMcpx = Resolve-WorkspacePath $McpxPath
$resolvedBios = Resolve-WorkspacePath $BiosPath
$resolvedEeprom = Resolve-WorkspacePath $EepromPath
$resolvedHdd = Resolve-WorkspacePath $HddPath
$resolvedDvd = Resolve-WorkspacePath $DvdPath

if ($InputBindings -eq 'keyboard-gamepad') {
    $configText = @"
[general]
show_welcome = false

[input.bindings]
port1_driver = 'usb-xbox-gamepad'
port1 = 'keyboard'

[sys.files]
bootrom_path = '$resolvedMcpx'
flashrom_path = '$resolvedBios'
eeprom_path = '$resolvedEeprom'
hdd_path = '$resolvedHdd'
dvd_path = '$resolvedDvd'
"@
} else {
    $configText = @"
[general]
show_welcome = false

[sys.files]
bootrom_path = '$resolvedMcpx'
flashrom_path = '$resolvedBios'
eeprom_path = '$resolvedEeprom'
hdd_path = '$resolvedHdd'
dvd_path = '$resolvedDvd'
"@
}

if ($env:XBOX_XEMU_DRY_RUN -eq '1') {
    $DryRun = $true
}

$config = Join-Path $env:TEMP (
    "$ConfigPrefix-" + [System.Guid]::NewGuid().ToString('N') + '.toml'
)
Set-Content -LiteralPath $config -Encoding ASCII -Value $configText

try {
    $invokeParameters = @{
        ConfigPath = $config
        BiosPath = $resolvedBios
        McpxPath = $resolvedMcpx
        XemuPath = $XemuPath
        Device = [string[]]$Device
        RequiredPath = [string[]]@($resolvedEeprom, $resolvedHdd, $resolvedDvd)
        XemuArgument = [string[]]$XemuArgument
        DryRun = $DryRun
    }

    if ($DryRun) {
        $result = & $launcher @invokeParameters
        [pscustomobject]@{
            XemuPath = $result.XemuPath
            Arguments = [string[]]$result.Arguments
            RequiredPaths = [string[]]$result.RequiredPaths
            ConfigPath = $config
            ConfigText = $configText
        }
        return
    }

    & $launcher @invokeParameters
} finally {
    Remove-Item -LiteralPath $config -Force -ErrorAction SilentlyContinue
}
