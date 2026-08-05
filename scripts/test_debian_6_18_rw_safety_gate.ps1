[CmdletBinding()]
param(
    [string]$CandidateRoot = 'artifacts\debian-6.18.33-rw-candidate',
    [string]$OutputRoot = 'run\debian-rw-safety-gate',
    [ValidateRange(60, 600)]
    [int]$TimeoutSeconds = 240,
    [ValidateRange(20, 180)]
    [int]$SettleSeconds = 75,
    [ValidateRange(3, 30)]
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
$xdvdfs = Join-Path $repoRoot 'tools\xdvdfs\xdvdfs.exe'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$eeprom = Join-Path $repoRoot 'run\eeprom.bin'

function Assert-Hash {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file was not found: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) {
        throw "SHA-256 mismatch for $Path. Expected $Expected, got $actual"
    }
}

function ConvertTo-WslPath {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full -notmatch '^([A-Za-z]):\\(.*)$') { throw "Cannot convert path to WSL form: $full" }
    '/mnt/{0}/{1}' -f $Matches[1].ToLowerInvariant(), $Matches[2].Replace('\', '/')
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

function Invoke-WslTool {
    param([string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = (& wsl -d $WslDistro -u root -- @Arguments 2>&1) -join "`n"
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    [pscustomobject]@{ Output = $output; ExitCode = $exitCode }
}

function Invoke-BootObservation {
    param(
        [int]$BootNumber,
        [string]$Config,
        [string]$BootDir
    )
    New-Item -ItemType Directory -Force -Path $BootDir | Out-Null
    $started = Get-Date
    $firstLinux = $null
    $process = $null
    $frames = [System.Collections.Generic.List[object]]::new()
    try {
        $process = Start-Process -FilePath $xemu -ArgumentList @(
            '-config_path', $Config, '-bios', $bios,
            '-machine', "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite"
        ) -PassThru
        while (-not $process.HasExited -and ((Get-Date) - $started).TotalSeconds -lt $TimeoutSeconds) {
            Start-Sleep -Seconds $PollSeconds
            $elapsed = [int][Math]::Round(((Get-Date) - $started).TotalSeconds)
            & $capture --pid $process.Id --out-dir $BootDir --prefix ("frame-{0:d3}s" -f $elapsed) --rect frame | Out-Null
            if ($LASTEXITCODE -ne 0) { continue }
            $png = Get-ChildItem -LiteralPath $BootDir -Filter '*.png' | Sort-Object LastWriteTime | Select-Object -Last 1
            if (-not $png) { continue }
            $analysis = & python $classifier $png.FullName | ConvertFrom-Json
            $frames.Add([pscustomobject]@{ elapsedSeconds = $elapsed; image = $png.Name; analysis = $analysis })
            if ($analysis.stage -in @('linux-text', 'desktop-x') -and $null -eq $firstLinux) {
                $firstLinux = $elapsed
            }
            if ($null -ne $firstLinux -and ($elapsed - $firstLinux) -ge $SettleSeconds) {
                break
            }
        }
        $process.Refresh()
        if ($process.HasExited) { throw "xemu exited during boot $BootNumber." }
        if ($null -eq $firstLinux) { throw "Boot $BootNumber did not reach Linux within $TimeoutSeconds seconds." }
    }
    finally {
        if ($process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $process.WaitForExit(10000) | Out-Null
        }
        $frames | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $BootDir 'frames.json') -Encoding ASCII
    }
    [ordered]@{
        boot = $BootNumber
        firstLinuxSeconds = $firstLinux
        elapsedSeconds = [int][Math]::Round(((Get-Date) - $started).TotalSeconds)
        frameCount = $frames.Count
        lastFrame = if ($frames.Count) { $frames[$frames.Count - 1].image } else { $null }
        lastStage = if ($frames.Count) { $frames[$frames.Count - 1].analysis.stage } else { $null }
    }
}

function Test-ExtractedPayload {
    param(
        [int]$BootNumber,
        [string]$Image,
        [string]$OutputDir
    )
    $extracted = Join-Path $OutputDir "rwdebian-after-boot-$BootNumber.ext2"
    $extractOutput = (& python $extractor $Image 'rwdebian.ext2' $extracted --partition E 2>&1) -join "`n"
    $extractExit = $LASTEXITCODE
    $extractOutput | Set-Content -LiteralPath (Join-Path $OutputDir "extract-after-boot-$BootNumber.txt") -Encoding ASCII
    if ($extractExit -ne 0) { throw "FATX extraction failed after boot $BootNumber.`n$extractOutput" }
    $wslPath = ConvertTo-WslPath $extracted

    $fsckResult = Invoke-WslTool @('/usr/sbin/e2fsck', '-fn', $wslPath)
    $fsckOutput = $fsckResult.Output
    $fsckExit = $fsckResult.ExitCode
    $fsckOutput | Set-Content -LiteralPath (Join-Path $OutputDir "e2fsck-after-boot-$BootNumber.txt") -Encoding ASCII
    if ($fsckExit -ne 0 -or $fsckOutput -match 'filesystem still has errors|UNEXPECTED INCONSISTENCY|WARNING') {
        throw "e2fsck safety gate failed after boot $BootNumber (exit $fsckExit). See the retained log and disk."
    }

    $persistResult = Invoke-WslTool @('/usr/sbin/debugfs', '-R', 'cat /root/xbox-persist-smoke.txt', $wslPath)
    $persistOutput = $persistResult.Output
    if ($persistResult.ExitCode -ne 0 -or $persistOutput -notmatch 'XBOX_PERSIST_MARKER') {
        throw "Persistence marker is missing after boot $BootNumber.`n$persistOutput"
    }
    $normalResult = Invoke-WslTool @('/usr/sbin/debugfs', '-R', 'cat /root/xbox-normal-use.txt', $wslPath)
    $normalOutput = $normalResult.Output
    if ($normalResult.ExitCode -ne 0 -or $normalOutput -notmatch 'XBOX_NORMAL_USE_FILE') {
        throw "Normal-use marker is missing after boot $BootNumber.`n$normalOutput"
    }
    $remountStatusResult = Invoke-WslTool @('/usr/sbin/debugfs', '-R', 'cat /root/xbox-remount-status.txt', $wslPath)
    if ($remountStatusResult.ExitCode -ne 0 -or $remountStatusResult.Output -notmatch '(?m)^XBOX_REMOUNT_STATUS=OK_____$') {
        throw "Root read-only remount did not complete after boot $BootNumber.`n$($remountStatusResult.Output)"
    }

    $superResult = Invoke-WslTool @('/usr/sbin/dumpe2fs', '-h', $wslPath)
    $superOutput = $superResult.Output
    if ($superResult.ExitCode -ne 0) { throw "dumpe2fs failed after boot $BootNumber.`n$superOutput" }
    $superOutput | Set-Content -LiteralPath (Join-Path $OutputDir "dumpe2fs-after-boot-$BootNumber.txt") -Encoding ASCII
    $mountMatch = [regex]::Match($superOutput, '(?m)^Mount count:\s+(\d+)\s*$')
    if (-not $mountMatch.Success) { throw "Could not read ext2 mount count after boot $BootNumber." }

    [ordered]@{
        boot = $BootNumber
        extractedPayload = $extracted
        extractedSha256 = (Get-FileHash -LiteralPath $extracted -Algorithm SHA256).Hash
        mountCount = [int]$mountMatch.Groups[1].Value
        persistMarker = ($persistOutput -split "`r?`n" | Where-Object { $_ -match 'XBOX_PERSIST_MARKER' } | Select-Object -Last 1)
        normalMarker = ($normalOutput -split "`r?`n" | Where-Object { $_ -match 'XBOX_NORMAL_USE_FILE' } | Select-Object -Last 1)
        remountStatus = ($remountStatusResult.Output -split "`r?`n" | Where-Object { $_ -match '^XBOX_REMOUNT_STATUS=' } | Select-Object -Last 1)
        fsckExitCode = $fsckExit
    }
}

foreach ($required in @($manifestPath, $baseHdd, $xemu, $capture, $classifier, $converter, $stager, $extractor, $xdvdfs, $bios, $mcpx, $eeprom)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required file was not found: $required" }
}
if (Get-Process xemu -ErrorAction SilentlyContinue) {
    throw 'xemu is already running. Close it before starting the write safety gate.'
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$packageDir = Join-Path $candidateFull $manifest.package.directory
$packageZip = Join-Path $candidateFull $manifest.package.zip
Assert-Hash $packageZip $manifest.package.zipSha256
foreach ($property in $manifest.package.files.psobject.Properties) {
    Assert-Hash (Join-Path $packageDir $property.Name.Replace('/', '\')) $property.Value
}

$session = Join-Path (Join-Path $repoRoot $OutputRoot) ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
$bootSource = Join-Path $session 'loader-source'
$rawHdd = Join-Path $session 'xbox-rw-gate.raw'
$loaderIso = Join-Path $session 'xromwell-rw-gate-loader.iso'
$layout = Join-Path $session 'fatx-layout.json'
$config = Join-Path $session 'xemu.toml'
New-Item -ItemType Directory -Force -Path $session, $bootSource | Out-Null
Copy-Item -LiteralPath (Join-Path $packageDir 'default.xbe') -Destination (Join-Path $bootSource 'default.xbe')
& $xdvdfs pack $bootSource $loaderIso | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $loaderIso -PathType Leaf)) {
    throw 'Failed to build the dedicated Xromwell loader ISO.'
}

$passed = $false
try {
    & python $converter $baseHdd $rawHdd --force
    if ($LASTEXITCODE -ne 0) { throw 'qcow2 conversion failed.' }
    $eRoot = Join-Path $packageDir 'E-root'
    & python $stager $rawHdd --partition E --clean-known-boot `
        --kernel (Join-Path $eRoot $manifest.boot.kernel) --kernel-name $manifest.boot.kernel `
        --initrd (Join-Path $eRoot $manifest.boot.initrd) --initrd-name $manifest.boot.initrd `
        --payload (Join-Path $eRoot $manifest.boot.payload) --payload-name $manifest.boot.payload `
        --append $manifest.boot.append --title 'Debian 6.18 RW safety gate' `
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
        Write-Host "Starting disposable-xemu RW boot $bootNumber of $BootCount..."
        $bootResult = Invoke-BootObservation -BootNumber $bootNumber -Config $config -BootDir (Join-Path $session "boot-$bootNumber")
        $checkResult = Test-ExtractedPayload -BootNumber $bootNumber -Image $rawHdd -OutputDir $session
        $boots.Add([pscustomobject]$bootResult)
        $checks.Add([pscustomobject]$checkResult)
        Write-Host ("Boot {0}: Linux={1}s, mount count={2}, fsck clean" -f $bootNumber, $bootResult.firstLinuxSeconds, $checkResult.mountCount)
    }
    if ($BootCount -eq 2 -and $checks[1].mountCount -le $checks[0].mountCount) {
        throw "The second boot did not increase the ext2 mount count ($($checks[0].mountCount) -> $($checks[1].mountCount))."
    }
    $criteria = [System.Collections.Generic.List[string]]::new()
    $criteria.Add("Linux reached on all $BootCount requested boot(s) without restaging")
    $criteria.Add('Persistence markers present and root read-only remount confirmed after each boot')
    if ($BootCount -eq 2) {
        $criteria.Add('Ext2 mount count increased on the second boot')
    }
    $criteria.Add('e2fsck -fn returned clean after each host-side stop')
    [ordered]@{
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        outcome = 'passed'
        candidateManifest = $manifestPath
        loaderIsoSha256 = (Get-FileHash -LiteralPath $loaderIso -Algorithm SHA256).Hash
        layoutManifest = $layout
        boots = $boots
        payloadChecks = $checks
        automatedCriteria = $criteria
        visualCriterion = 'Full-window frames are retained for manual diagnostics; remount success is enforced by filesystem markers.'
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $session 'summary.json') -Encoding ASCII
    $passed = $true
}
catch {
    [ordered]@{
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        outcome = 'failed'
        error = $_.Exception.Message
        diskRetained = $rawHdd
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $session 'summary.json') -Encoding ASCII
    throw
}
finally {
    Get-Process xemu -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    if ($passed -and -not $KeepDisk) {
        if (Test-Path -LiteralPath $rawHdd -PathType Leaf) {
            [System.IO.File]::Delete($rawHdd)
        }
        Get-ChildItem -LiteralPath $session -Filter 'rwdebian-after-boot-*.ext2' -File -ErrorAction SilentlyContinue |
            ForEach-Object { [System.IO.File]::Delete($_.FullName) }
    }
}

Write-Host "RW safety gate passed. Results: $session"
if ($KeepDisk) { Write-Host "Disposable raw HDD retained: $rawHdd" }
