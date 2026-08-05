[CmdletBinding()]
param(
    [string]$CandidateRoot = 'artifacts\tinycore-hdd-x-hotset-remote-candidate',
    [string]$OutputRoot = 'run\tinycore-hdd-x-hotset-remote-ssh',
    [ValidateRange(1024, 65535)]
    [int]$HostPort = 2222,
    [ValidateRange(30, 180)]
    [int]$TimeoutSeconds = 120,
    [switch]$ApplicationSmoke,
    [switch]$AppsDefaultMirrorSmoke,
    [string]$LoginUser = 'tc',
    [string]$LoginPassword = 'tcuser'
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
$ssh = (Get-Command ssh.exe -ErrorAction Stop).Source
$session = Join-Path (Join-Path $repoRoot $OutputRoot) ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
$config = Join-Path $session 'xemu-ssh.toml'
$keyscanOut = Join-Path $session 'ssh-keyscan.txt'
$keyscanErr = Join-Path $session 'ssh-keyscan.err.txt'
$appSmokeOut = Join-Path $session 'ssh-app-smoke.txt'
$globalKnownHosts = Join-Path $session 'ssh-global-known-hosts.txt'

foreach ($required in @($xemu, $capture, $bootBios, $mcpx, $eeprom, $dvdPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required file was not found: $required" }
}
if (Get-Process xemu -ErrorAction SilentlyContinue) { throw 'xemu is already running. Close it before testing.' }
if (Get-NetTCPConnection -State Listen -LocalPort $HostPort -ErrorAction SilentlyContinue) {
    throw "Host port $HostPort is already in use."
}
if (($ApplicationSmoke -or $AppsDefaultMirrorSmoke) -and $LoginPassword -match '[\r\n&|<>^]') {
    throw 'LoginPassword contains characters that cannot be written safely to the temporary askpass helper.'
}

& (Join-Path $repoRoot 'scripts\test_tinycore_hdd_candidate.ps1') `
    -CandidateRoot $CandidateRoot -OutputRoot (Join-Path $OutputRoot 'desktop-gate') `
    -Runs 1 -RequiredPasses 1 -PollSeconds 5
if ($LASTEXITCODE -ne 0) { throw 'The prerequisite Tiny Core desktop gate failed.' }
if (-not (Test-Path -LiteralPath $rawHdd -PathType Leaf)) { throw "Staged raw HDD was not found: $rawHdd" }

New-Item -ItemType Directory -Force -Path $session | Out-Null
'' | Set-Content -LiteralPath $globalKnownHosts -Encoding ASCII
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

    if ($ApplicationSmoke -or $AppsDefaultMirrorSmoke) {
        $askpass = Join-Path $session 'askpass.cmd'
        $oldAskpass = $env:SSH_ASKPASS
        $oldAskpassRequire = $env:SSH_ASKPASS_REQUIRE
        $oldDisplay = $env:DISPLAY
        try {
            @(
                '@echo off'
                "echo $LoginPassword"
            ) | Set-Content -LiteralPath $askpass -Encoding ASCII
            $env:SSH_ASKPASS = $askpass
            $env:SSH_ASKPASS_REQUIRE = 'force'
            $env:DISPLAY = 'codex-askpass'

            if ($AppsDefaultMirrorSmoke) {
                $remoteCommand = 'echo XBOX_PASSWORD_SSH_OK; export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin; export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib; tcedir=$(readlink /etc/sysconfig/tcedir); echo XBOX_APPS_TCEDIR=$tcedir; test -d "$tcedir/optional" && echo XBOX_APPS_OPTIONAL_DIR_OK; test -f "$tcedir/firstrun" && echo XBOX_APPS_FIRSTRUN_MARKER_OK; test "$(cat /opt/tcemirror)" = "http://repo.tinycorelinux.net/" && echo XBOX_APPS_DEFAULT_MIRROR_OK; cat /tmp/xbox-apps-default-mirror.txt 2>&1; rm -f /tmp/firstrun; killall aterm 2>/dev/null || true; sleep 1; before=$(grep -l apps /proc/[0-9]*/comm 2>/dev/null | wc -l); sudo env DISPLAY=:0 XAUTHORITY=/home/tc/.Xauthority HOME=/root USER=root PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib apps </dev/null >/tmp/xbox-apps-smoke.log 2>&1 & sleep 5; appcomm=$(grep -l apps /proc/[0-9]*/comm 2>/dev/null | head -1); echo XBOX_APPS_COMM_FILE=$appcomm; apppid=${appcomm#/proc/}; apppid=${apppid%/comm}; after=$(grep -l apps /proc/[0-9]*/comm 2>/dev/null | wc -l); echo XBOX_APPS_COUNT_${before}_${after}; if test $after -gt $before; then echo XBOX_APPS_LAUNCH_OK; fi; appcwd=$(sudo readlink /proc/$apppid/cwd 2>/dev/null); echo XBOX_APPS_CWD=$appcwd; case "$appcwd" in "$tcedir/optional") echo XBOX_APPS_CWD_OK ;; esac; if [ ! -f /tmp/firstrun ]; then echo XBOX_APPS_NO_FALLBACK_MARKER_OK; fi; if ! pidof mirrorpicker >/dev/null 2>&1; then echo XBOX_APPS_NO_MIRRORPICKER_OK; fi; test "$(cat /opt/tcemirror)" = "http://repo.tinycorelinux.net/" && echo XBOX_APPS_MIRROR_UNCHANGED_OK; echo XBOX_APPS_FIRSTRUN_FILES; find /tmp -name firstrun -type f 2>/dev/null; echo XBOX_APPS_LOG; cat /tmp/xbox-apps-smoke.log 2>&1'
            } else {
                $remoteCommand = 'echo XBOX_PASSWORD_SSH_OK; export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin; export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib; echo XBOX_ATERM=$(command -v aterm); ls -l /tmp/.X11-unix /home/tc/.Xauthority 2>&1; before=$(grep -l aterm /proc/[0-9]*/comm 2>/dev/null | wc -l); sudo env DISPLAY=:0 XAUTHORITY=/home/tc/.Xauthority HOME=/root USER=root PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib aterm -fn 9x15 -fg white -bg black -geometry 66x26+8+8 -e sleep 8 </dev/null >/tmp/xbox-release-aterm.log 2>&1 & sleep 3; after=$(grep -l aterm /proc/[0-9]*/comm 2>/dev/null | wc -l); echo XBOX_ATERM_COUNT_${before}_${after}; if test $after -gt $before; then echo XBOX_RELEASE_APP_OK; fi; echo XBOX_ATERM_LOG; cat /tmp/xbox-release-aterm.log 2>&1'
            }
            $sshArgs = @(
                '-n',
                '-p', "$HostPort",
                '-o', 'StrictHostKeyChecking=yes',
                '-o', "UserKnownHostsFile=$keyscanOut",
                '-o', "GlobalKnownHostsFile=$globalKnownHosts",
                '-o', 'PreferredAuthentications=password',
                '-o', 'PubkeyAuthentication=no',
                '-o', 'NumberOfPasswordPrompts=1',
                '-o', 'LogLevel=ERROR',
                '-o', 'ConnectTimeout=10',
                '-o', 'ServerAliveInterval=5',
                '-o', 'ServerAliveCountMax=3',
                "${LoginUser}@127.0.0.1",
                $remoteCommand
            )
            $savedErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $sshOutput = & $ssh @sshArgs 2>&1
                $sshExitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $savedErrorActionPreference
            }
            $sshOutput | Set-Content -LiteralPath $appSmokeOut -Encoding ASCII
            if ($sshExitCode -ne 0) {
                throw "SSH application smoke exited with code $sshExitCode. See $appSmokeOut"
            }
            $sshText = $sshOutput -join "`n"
            if ($sshText -notmatch 'XBOX_PASSWORD_SSH_OK') {
                throw "Password login marker was missing. See $appSmokeOut"
            }
            if ($AppsDefaultMirrorSmoke) {
                foreach ($marker in @(
                    'XBOX_APPS_FIRSTRUN_MARKER_OK',
                    'XBOX_APPS_OPTIONAL_DIR_OK',
                    'XBOX_APPS_DEFAULT_MIRROR_OK',
                    'XBOX_APPS_LAUNCH_OK',
                    'XBOX_APPS_CWD_OK',
                    'XBOX_APPS_NO_FALLBACK_MARKER_OK',
                    'XBOX_APPS_NO_MIRRORPICKER_OK',
                    'XBOX_APPS_MIRROR_UNCHANGED_OK'
                )) {
                    if ($sshText -notmatch [regex]::Escape($marker)) {
                        throw "Apps smoke marker $marker was missing. See $appSmokeOut"
                    }
                }
            } elseif ($sshText -notmatch 'XBOX_RELEASE_APP_OK') {
                throw "Aterm launch marker was missing. See $appSmokeOut"
            }
            & $capture --pid $process.Id --out-dir $session --prefix 'application-smoke' --rect frame | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Capturing the application smoke window failed.' }
        }
        finally {
            $env:SSH_ASKPASS = $oldAskpass
            $env:SSH_ASKPASS_REQUIRE = $oldAskpassRequire
            $env:DISPLAY = $oldDisplay
            Remove-Item -LiteralPath $askpass -Force -ErrorAction SilentlyContinue
        }
    }
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
    passwordLogin = [bool]($ApplicationSmoke -or $AppsDefaultMirrorSmoke)
    applicationSmoke = [bool]$ApplicationSmoke
    appsDefaultMirrorSmoke = [bool]$AppsDefaultMirrorSmoke
    applicationSmokeOutput = if ($ApplicationSmoke -or $AppsDefaultMirrorSmoke) { $appSmokeOut } else { $null }
    screenshot = (Get-ChildItem -LiteralPath $session -Filter 'ssh-reachable*.png' | Select-Object -First 1).FullName
    applicationScreenshot = if ($ApplicationSmoke -or $AppsDefaultMirrorSmoke) { (Get-ChildItem -LiteralPath $session -Filter 'application-smoke*.png' | Select-Object -First 1).FullName } else { $null }
    session = $session
}
