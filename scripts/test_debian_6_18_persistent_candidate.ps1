[CmdletBinding()]
param(
    [string]$CandidateRoot = 'artifacts\debian-6.18.33-persistent-shell-candidate',
    [string]$OutputRoot = 'run\debian-persistent-safety-gate',
    [ValidateRange(60, 600)]
    [int]$TimeoutSeconds = 240,
    [ValidateRange(15, 180)]
    [int]$ShellSettleSeconds = 75,
    [ValidateRange(2, 30)]
    [int]$PollSeconds = 5,
    [ValidateRange(1, 2)]
    [int]$BootCount = 2,
    [string]$WslDistro = 'Ubuntu-24.04',
    [switch]$KeepDisk
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$candidateFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $CandidateRoot))
$manifestPath = Join-Path $candidateFull 'manifest.json'
$baseHdd = Join-Path $repoRoot 'Xbox-Emulator-Files\hdd\xbox_hdd.qcow2'
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$capture = Join-Path $repoRoot 'tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe'
$classifier = Join-Path $repoRoot 'scripts\classify_xemu_boot_frame.py'
$converter = Join-Path $repoRoot 'scripts\qcow2_to_raw_sparse.py'
$stager = Join-Path $repoRoot 'scripts\fatx_stage_boot.py'
$extractor = Join-Path $repoRoot 'scripts\extract_fatx_root_file.py'
$sendKeys = Join-Path $repoRoot 'scripts\send_xemu_shell_probe.ps1'
$xdvdfs = Join-Path $repoRoot 'tools\xdvdfs\xdvdfs.exe'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$eeprom = Join-Path $repoRoot 'run\eeprom.bin'
$userMarker = 'XBOX_PERSISTENT_USER_V1'
$shutdownMarker = 'XBOX_SHUTDOWN_STATUS=SAFE____'

function Assert-Hash {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required file was not found: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) { throw "SHA-256 mismatch for $Path. Expected $Expected, got $actual" }
}

function ConvertTo-WslPath {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full -notmatch '^([A-Za-z]):\\(.*)$') { throw "Cannot convert path to WSL form: $full" }
    '/mnt/{0}/{1}' -f $Matches[1].ToLowerInvariant(), $Matches[2].Replace('\', '/')
}

function Invoke-WslTool {
    param([string[]]$Arguments)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = (& wsl -d $WslDistro -u root -- @Arguments 2>&1) -join "`n"
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldPreference
    }
    [pscustomobject]@{ Output = $output; ExitCode = $exitCode }
}

function Write-XemuConfig {
    param([string]$Path, [string]$Hdd, [string]$Dvd)
    @"
[general]
show_welcome = false

[sys.files]
bootrom_path = '$mcpx'
flashrom_path = '$bios'
eeprom_path = '$eeprom'
hdd_path = '$Hdd'
dvd_path = '$Dvd'

[input.bindings]
port1 = 'keyboard'
port1_driver = 'usb-xbox-gamepad'
"@ | Set-Content -LiteralPath $Path -Encoding ASCII
}

function Save-Frame {
    param([System.Diagnostics.Process]$Process, [string]$BootDir, [int]$Elapsed)
    & $capture --pid $Process.Id --out-dir $BootDir --prefix ("frame-{0:d3}s" -f $Elapsed) --rect frame | Out-Null
    if ($LASTEXITCODE -ne 0) { return $null }
    $png = Get-ChildItem -LiteralPath $BootDir -Filter '*.png' | Sort-Object LastWriteTime | Select-Object -Last 1
    if (-not $png) { return $null }
    $analysis = & python $classifier $png.FullName | ConvertFrom-Json
    [pscustomobject]@{ elapsedSeconds = $Elapsed; image = $png.Name; analysis = $analysis }
}

function Invoke-PersistentBoot {
    param([int]$BootNumber, [string]$Config, [string]$BootDir)
    New-Item -ItemType Directory -Force -Path $BootDir | Out-Null
    $started = Get-Date
    $firstLinux = $null
    $commandSent = $null
    $process = $null
    $selfPoweredOff = $false
    $frames = [System.Collections.Generic.List[object]]::new()
    try {
        $process = Start-Process -FilePath $xemu -ArgumentList @(
            '-config_path', $Config, '-bios', $bios,
            '-machine', "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite",
            '-device', 'usb-kbd'
        ) -PassThru
        while (((Get-Date) - $started).TotalSeconds -lt $TimeoutSeconds) {
            Start-Sleep -Seconds $PollSeconds
            $process.Refresh()
            if ($process.HasExited) {
                if ($null -eq $commandSent) { throw "xemu exited before the shutdown command during boot $BootNumber." }
                $selfPoweredOff = $true
                break
            }
            $elapsed = [int][Math]::Round(((Get-Date) - $started).TotalSeconds)
            $frame = Save-Frame -Process $process -BootDir $BootDir -Elapsed $elapsed
            if ($frame) {
                $frames.Add($frame)
                if ($frame.analysis.stage -in @('linux-text', 'desktop-x') -and $null -eq $firstLinux) {
                    $firstLinux = $elapsed
                }
            }
            if ($null -ne $firstLinux -and $null -eq $commandSent -and ($elapsed - $firstLinux) -ge $ShellSettleSeconds) {
                $command = if ($BootNumber -eq 1) {
                    "echo $userMarker>/root/xbox-persistent-user.txt; xbox-persistent-shutdown"
                } else {
                    'cat /root/xbox-persistent-user.txt; xbox-persistent-shutdown'
                }
                & $sendKeys -ProcessId $process.Id -Commands @($command) | ConvertTo-Json -Depth 4 |
                    Set-Content -LiteralPath (Join-Path $BootDir 'shell-command.json') -Encoding ASCII
                $commandSent = $elapsed
            }
        }
        if ($null -eq $firstLinux) { throw "Boot $BootNumber did not reach Linux within $TimeoutSeconds seconds." }
        if ($null -eq $commandSent) { throw "Boot $BootNumber did not reach the shell command window." }
        if (-not $selfPoweredOff) { throw "Linux did not power xemu off during boot $BootNumber." }
    } finally {
        if ($process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $process.WaitForExit(10000) | Out-Null
        }
        $frames | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $BootDir 'frames.json') -Encoding ASCII
    }
    [ordered]@{
        boot = $BootNumber
        firstLinuxSeconds = $firstLinux
        commandSentSeconds = $commandSent
        elapsedSeconds = [int][Math]::Round(((Get-Date) - $started).TotalSeconds)
        selfPoweredOff = $selfPoweredOff
        frameCount = $frames.Count
        lastFrame = if ($frames.Count) { $frames[$frames.Count - 1].image } else { $null }
        lastStage = if ($frames.Count) { $frames[$frames.Count - 1].analysis.stage } else { $null }
    }
}

function Get-DebugfsFile {
    param([string]$Image, [string]$Path)
    $result = Invoke-WslTool @('/usr/sbin/debugfs', '-R', "cat $Path", $Image)
    if ($result.ExitCode -ne 0) { throw "debugfs could not read $Path.`n$($result.Output)" }
    ($result.Output -split "`r?`n" | Where-Object { $_ -notmatch '^debugfs ' }) -join "`n"
}

function Test-ExtractedPayload {
    param([int]$BootNumber, [string]$Image, [string]$OutputDir)
    $extracted = Join-Path $OutputDir "psdebian-after-boot-$BootNumber.ext2"
    $extractOutput = (& python $extractor $Image 'psdebian.ext2' $extracted --partition E 2>&1) -join "`n"
    $extractOutput | Set-Content -LiteralPath (Join-Path $OutputDir "extract-after-boot-$BootNumber.txt") -Encoding ASCII
    if ($LASTEXITCODE -ne 0) { throw "FATX extraction failed after boot $BootNumber.`n$extractOutput" }
    $wslPath = ConvertTo-WslPath $extracted

    $fsck = Invoke-WslTool @('/usr/sbin/e2fsck', '-fn', $wslPath)
    $fsck.Output | Set-Content -LiteralPath (Join-Path $OutputDir "e2fsck-after-boot-$BootNumber.txt") -Encoding ASCII
    if ($fsck.ExitCode -ne 0 -or $fsck.Output -match 'filesystem still has errors|UNEXPECTED INCONSISTENCY|WARNING') {
        throw "e2fsck failed after boot $BootNumber (exit $($fsck.ExitCode))."
    }

    $userFile = (Get-DebugfsFile -Image $wslPath -Path '/root/xbox-persistent-user.txt').Trim()
    if ($userFile -ne $userMarker) { throw "Persistent user marker mismatch after boot ${BootNumber}: $userFile" }
    $shutdownFile = (Get-DebugfsFile -Image $wslPath -Path '/root/xbox-shutdown-status.txt').Trim()
    if ($shutdownFile -ne $shutdownMarker) { throw "Shutdown marker mismatch after boot ${BootNumber}: $shutdownFile" }

    $super = Invoke-WslTool @('/usr/sbin/dumpe2fs', '-h', $wslPath)
    $super.Output | Set-Content -LiteralPath (Join-Path $OutputDir "dumpe2fs-after-boot-$BootNumber.txt") -Encoding ASCII
    if ($super.ExitCode -ne 0) { throw "dumpe2fs failed after boot $BootNumber." }
    $match = [regex]::Match($super.Output, '(?m)^Mount count:\s+(\d+)\s*$')
    if (-not $match.Success) { throw "Could not read mount count after boot $BootNumber." }

    [ordered]@{
        boot = $BootNumber
        extractedPayload = $extracted
        extractedSha256 = (Get-FileHash -LiteralPath $extracted -Algorithm SHA256).Hash
        mountCount = [int]$match.Groups[1].Value
        userMarker = $userFile
        shutdownStatus = $shutdownFile
        fsckExitCode = $fsck.ExitCode
    }
}

foreach ($required in @($manifestPath, $baseHdd, $xemu, $capture, $classifier, $converter, $stager, $extractor, $sendKeys, $xdvdfs, $bios, $mcpx, $eeprom)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required file was not found: $required" }
}
if (Get-Process xemu -ErrorAction SilentlyContinue) { throw 'xemu is already running. Close it before starting the persistent safety gate.' }

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$packageDir = Join-Path $candidateFull $manifest.package.directory
$packageZip = Join-Path $candidateFull $manifest.package.zip
Assert-Hash $packageZip $manifest.package.zipSha256
foreach ($property in $manifest.package.files.psobject.Properties) {
    Assert-Hash (Join-Path $packageDir $property.Name.Replace('/', '\')) $property.Value
}

$session = Join-Path (Join-Path $repoRoot $OutputRoot) ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
$bootSource = Join-Path $session 'loader-source'
$rawHdd = Join-Path $session 'xbox-persistent-gate.raw'
$loaderIso = Join-Path $session 'xromwell-persistent-loader.iso'
$layout = Join-Path $session 'fatx-layout.json'
$config = Join-Path $session 'xemu.toml'
New-Item -ItemType Directory -Force -Path $session, $bootSource | Out-Null
Copy-Item -LiteralPath (Join-Path $packageDir 'default.xbe') -Destination (Join-Path $bootSource 'default.xbe')
& $xdvdfs pack $bootSource $loaderIso | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $loaderIso -PathType Leaf)) { throw 'Failed to build the Xromwell loader ISO.' }

$passed = $false
try {
    & python $converter $baseHdd $rawHdd --force
    if ($LASTEXITCODE -ne 0) { throw 'qcow2 conversion failed.' }
    $eRoot = Join-Path $packageDir 'E-root'
    & python $stager $rawHdd --partition E --clean-known-boot `
        --kernel (Join-Path $eRoot $manifest.boot.kernel) --kernel-name $manifest.boot.kernel `
        --initrd (Join-Path $eRoot $manifest.boot.initrd) --initrd-name $manifest.boot.initrd `
        --payload (Join-Path $eRoot $manifest.boot.payload) --payload-name $manifest.boot.payload `
        --append $manifest.boot.append --title 'Debian 6.18 persistent shell gate' `
        --boot-layout contiguous --payload-layout contiguous --stage-order payload-first --manifest $layout
    if ($LASTEXITCODE -ne 0) { throw 'FATX staging failed.' }
    $layoutData = Get-Content -LiteralPath $layout -Raw | ConvertFrom-Json
    foreach ($file in $layoutData.files) {
        if ($file.contiguous -ne $true) { throw "Staged FATX file is fragmented: $($file.name)" }
        if ($file.sha256 -ne $file.readback_sha256) { throw "FATX readback failed: $($file.name)" }
    }
    Write-XemuConfig $config $rawHdd $loaderIso

    $boots = [System.Collections.Generic.List[object]]::new()
    $checks = [System.Collections.Generic.List[object]]::new()
    foreach ($bootNumber in 1..$BootCount) {
        Write-Host "Starting persistent Debian boot $bootNumber of $BootCount..."
        $boots.Add([pscustomobject](Invoke-PersistentBoot -BootNumber $bootNumber -Config $config -BootDir (Join-Path $session "boot-$bootNumber")))
        $checks.Add([pscustomobject](Test-ExtractedPayload -BootNumber $bootNumber -Image $rawHdd -OutputDir $session))
        Write-Host ("Boot {0}: Linux={1}s, self-poweroff, mount count={2}, fsck clean" -f $bootNumber, $boots[$boots.Count - 1].firstLinuxSeconds, $checks[$checks.Count - 1].mountCount)
    }
    if ($BootCount -eq 2 -and $checks[1].mountCount -le $checks[0].mountCount) {
        throw "Mount count did not increase ($($checks[0].mountCount) -> $($checks[1].mountCount))."
    }
    [ordered]@{
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        outcome = 'passed'
        candidateManifest = $manifestPath
        loaderIsoSha256 = (Get-FileHash -LiteralPath $loaderIso -Algorithm SHA256).Hash
        layoutManifest = $layout
        boots = $boots
        payloadChecks = $checks
        automatedCriteria = @(
            "Linux reached and powered xemu off on all $BootCount requested boot(s)",
            'The same FATX disk was reused without restaging',
            'User marker and SAFE shutdown marker persisted after each boot',
            'e2fsck -fn returned clean after each Linux-controlled poweroff',
            'Ext2 mount count increased on the second boot when two boots were requested'
        )
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $session 'summary.json') -Encoding ASCII
    $passed = $true
} catch {
    [ordered]@{ generatedUtc = [DateTime]::UtcNow.ToString('o'); outcome = 'failed'; error = $_.Exception.Message; diskRetained = $rawHdd } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $session 'summary.json') -Encoding ASCII
    throw
} finally {
    Get-Process xemu -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    if ($passed -and -not $KeepDisk) {
        if (Test-Path -LiteralPath $rawHdd -PathType Leaf) { [System.IO.File]::Delete($rawHdd) }
        Get-ChildItem -LiteralPath $session -Filter 'psdebian-after-boot-*.ext2' -File -ErrorAction SilentlyContinue |
            ForEach-Object { [System.IO.File]::Delete($_.FullName) }
    }
}

Write-Host "Persistent Debian safety gate passed. Results: $session"
if ($KeepDisk) { Write-Host "Disposable raw HDD retained: $rawHdd" }
