[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [Parameter(Mandatory)]
    [string]$BiosPath,

    [string]$McpxPath = 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin',
    [string]$XemuPath = 'tools\xemu-v0.8.135-nvnet\xemu.exe',

    [ValidateSet('composite', 'svideo', 'component', 'vga', 'hdtv')]
    [string]$Avpack = 'composite',

    [string[]]$Device = @(),
    [string[]]$RequiredPath = @(),
    [string[]]$XemuArgument = @(),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

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

$resolvedXemu = Resolve-WorkspacePath $XemuPath
$resolvedConfig = Resolve-WorkspacePath $ConfigPath
$resolvedBios = Resolve-WorkspacePath $BiosPath
$resolvedMcpx = Resolve-WorkspacePath $McpxPath
$resolvedRequired = @($RequiredPath | ForEach-Object { Resolve-WorkspacePath $_ })
$allRequired = @($resolvedXemu, $resolvedConfig, $resolvedBios, $resolvedMcpx) +
    $resolvedRequired

foreach ($path in $allRequired) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file was not found: $path"
    }
}

$launchArguments = [System.Collections.Generic.List[string]]::new()
$launchArguments.Add('-config_path')
$launchArguments.Add($resolvedConfig)
$launchArguments.Add('-bios')
$launchArguments.Add($resolvedBios)
$launchArguments.Add('-machine')
$launchArguments.Add("xbox,bootrom=$resolvedMcpx,kernel-irqchip=off,avpack=$Avpack")

foreach ($deviceName in $Device) {
    $launchArguments.Add('-device')
    $launchArguments.Add($deviceName)
}

foreach ($argument in $XemuArgument) {
    $launchArguments.Add($argument)
}

if ($env:XBOX_XEMU_DRY_RUN -eq '1') {
    $DryRun = $true
}

if ($DryRun) {
    [pscustomobject]@{
        XemuPath = $resolvedXemu
        Arguments = [string[]]$launchArguments
        RequiredPaths = [string[]]$allRequired
    }
    exit 0
}

& $resolvedXemu @launchArguments
