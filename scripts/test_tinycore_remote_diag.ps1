[CmdletBinding()]
param(
    [string]$CandidateRoot = 'artifacts\tinycore-hdd-x-hotset-remote-candidate',
    [string]$OutputRoot = 'run\tinycore-hdd-x-hotset-remote-ssh',
    [ValidateRange(1024, 65535)]
    [int]$HostPort = 2222,
    [ValidateRange(30, 180)]
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$capture = Join-Path $repoRoot 'tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe'
$rawHdd = Join-Path $repoRoot 'run\hdd\tinycore-hdd-candidate.raw'
$bootBios = Join-Path $repoRoot 'artifacts\cromwell-hddfatx-autoboot-modernhdr-initrd32_1024.bin'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$eeprom = Join-Path $repoRoot 'run\eeprom.bin'
$dvdPath = Join-Path $repoRoot 'artifacts\xromwell-modern-initrd32.iso'
$sshKeyscan = (Get-Command ssh-keyscan.exe -ErrorAction Stop).Source
$session = Join-Path (Join-Path $repoRoot $OutputRoot) ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
$config = Join-Path $session 'xemu-ssh.toml'
$keyscanOut = Join-Path $session 'ssh-keyscan.txt'
$keyscanErr = Join-Path $session 'ssh-keyscan.err.txt'

foreach ($required in @($xemu, $capture, $bootBios, $mcpx, $eeprom, $dvdPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required file was not found: $required" }
}
if (Get-Process xemu -ErrorAction SilentlyContinue) { throw 'xemu is already running. Close it before testing.' }
if (Get-NetTCPConnection -State Listen -LocalPort $HostPort -ErrorAction SilentlyContinue) {
    throw "Host port $HostPort is already in use."
}

& (Join-Path $repoRoot 'scripts\test_tinycore_hdd_candidate.ps1') `
    -CandidateRoot $CandidateRoot -OutputRoot (Join-Path $OutputRoot 'desktop-gate') `
    -Runs 1 -RequiredPasses 1 -PollSeconds 5
if ($LASTEXITCODE -ne 0) { throw 'The prerequisite Tiny Core desktop gate failed.' }
if (-not (Test-Path -LiteralPath $rawHdd -PathType Leaf)) { throw "Staged raw HDD was not found: $rawHdd" }

New-Item -ItemType Directory -Force -Path $session | Out-Null
@"
[general]
show_welcome = false

[sys.files]
bootrom_path = '$mcpx'
flashrom_path = '$bootBios'
eeprom_path = '$eeprom'
hdd_path = '$rawHdd'
dvd_path = '$dvdPath'

[input.bindings]
port1 = 'keyboard'
port1_driver = 'usb-xbox-gamepad'

[net]
enable = true
backend = 'nat'

[[net.nat.forward_ports]]
host = $HostPort
guest = 22
protocol = 'tcp'
"@ | Set-Content -LiteralPath $config -Encoding ASCII

$process = $null
try {
    $process = Start-Process -FilePath $xemu -ArgumentList @(
        '-config_path', $config, '-bios', $bootBios,
        '-machine', "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite", '-snapshot'
    ) -PassThru
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $reachable = $false
    while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
        Remove-Item -LiteralPath $keyscanOut, $keyscanErr -Force -ErrorAction SilentlyContinue
        $scan = Start-Process -FilePath $sshKeyscan -ArgumentList @(
            '-T', '3', '-p', "$HostPort", '127.0.0.1'
        ) -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $keyscanOut -RedirectStandardError $keyscanErr
        if ($scan.ExitCode -eq 0 -and (Test-Path -LiteralPath $keyscanOut) -and (Get-Item -LiteralPath $keyscanOut).Length -gt 0) {
            $reachable = $true
            break
        }
    }
    if (-not $reachable) {
        throw "Dropbear did not answer on 127.0.0.1:$HostPort within $TimeoutSeconds seconds."
    }
    & $capture --pid $process.Id --out-dir $session --prefix 'ssh-reachable' --rect frame | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Capturing the complete xemu window failed.' }
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        $process.WaitForExit(10000) | Out-Null
    }
}

[pscustomobject]@{
    result = 'passed'
    endpoint = "127.0.0.1:$HostPort"
    keyscan = $keyscanOut
    screenshot = (Get-ChildItem -LiteralPath $session -Filter 'ssh-reachable*.png' | Select-Object -First 1).FullName
    session = $session
}
