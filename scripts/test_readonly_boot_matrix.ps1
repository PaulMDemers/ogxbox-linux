[CmdletBinding()]
param(
    [string[]]$Cell = @('all'),
    [ValidateRange(1, 10)]
    [int]$Runs = 1,
    [ValidateRange(1, 10)]
    [int]$RequiredPasses = 1,
    [ValidateRange(60, 900)]
    [int]$TimeoutSeconds = 300,
    [ValidateRange(5, 30)]
    [int]$PollSeconds = 10,
    [switch]$KeepDisk,
    [string]$MatrixRoot = 'artifacts\readonly-boot-matrix',
    [string]$OutputRoot = 'run\readonly-boot-matrix'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$matrixFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $MatrixRoot))
$manifestPath = Join-Path $matrixFull 'manifest.json'
$baseHdd = Join-Path $repoRoot 'Xbox-Emulator-Files\hdd\xbox_hdd.qcow2'
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$capture = Join-Path $repoRoot 'tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe'
$classifier = Join-Path $repoRoot 'scripts\classify_xemu_boot_frame.py'
$converter = Join-Path $repoRoot 'scripts\qcow2_to_raw_sparse.py'
$stager = Join-Path $repoRoot 'scripts\fatx_stage_boot.py'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$eeprom = Join-Path $repoRoot 'run\eeprom.bin'

function Assert-FileHash {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file was not found: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) {
        throw "SHA-256 mismatch for $Path. Expected $Expected, got $actual"
    }
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

foreach ($required in @($manifestPath, $baseHdd, $xemu, $capture, $classifier, $converter, $stager, $bios, $mcpx, $eeprom)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file was not found: $required"
    }
}
if ($RequiredPasses -gt $Runs) {
    throw "RequiredPasses ($RequiredPasses) cannot exceed Runs ($Runs)."
}
if (Get-Process xemu -ErrorAction SilentlyContinue) {
    throw 'xemu is already running. Close it before testing the boot matrix.'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$allIds = @($manifest.packages | ForEach-Object id)
$requested = if ($Cell -contains 'all') { $allIds } else { @($Cell) }
foreach ($id in $requested) {
    if ($id -notin $allIds) {
        throw "Unknown matrix cell '$id'. Available cells: $($allIds -join ', ')"
    }
}

$session = Join-Path (Join-Path $repoRoot $OutputRoot) ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
$hddDir = Join-Path $session 'hdd'
New-Item -ItemType Directory -Force -Path $session, $hddDir | Out-Null
$results = [System.Collections.Generic.List[object]]::new()
$failedCells = [System.Collections.Generic.List[string]]::new()

foreach ($id in $requested) {
    $package = $manifest.packages | Where-Object id -eq $id | Select-Object -First 1
    $packageDir = Join-Path $matrixFull $package.directory
    $eRoot = Join-Path $packageDir 'E-root'
    $loaderEntry = $manifest.xemuLoaders.psobject.Properties[$package.xemuLoader].Value
    if (-not $loaderEntry) { throw "No xemu loader is defined for $id ($($package.xemuLoader))." }
    $loaderIso = if ($loaderEntry.path -like 'artifacts/*') {
        Join-Path $repoRoot $loaderEntry.path.Replace('/', '\')
    } else {
        Join-Path $matrixFull $loaderEntry.path.Replace('/', '\')
    }
    Assert-FileHash $loaderIso $loaderEntry.sha256
    Assert-FileHash (Join-Path $matrixFull $package.zip) $package.zipSha256
    foreach ($property in $package.files.psobject.Properties) {
        Assert-FileHash (Join-Path $packageDir ($property.Name.Replace('/', '\'))) $property.Value
    }
    $cfg = Get-Content -LiteralPath (Join-Path $eRoot 'linuxboot.cfg') -Raw
    $appendLines = @($cfg -split "`r?`n" | Where-Object { $_ -like 'append *' })
    if ($appendLines.Count -ne 1) {
        throw "Expected one append line for $id, found $($appendLines.Count)."
    }
    $append = $appendLines[0].Substring('append '.Length)
    if ($append -ne $package.boot.append) {
        throw "Manifest append line differs from package linuxboot.cfg for $id."
    }

    $cellPasses = 0
    for ($run = 1; $run -le $Runs; $run++) {
        $runDir = Join-Path $session ("{0}-run-{1:d2}" -f $id, $run)
        New-Item -ItemType Directory -Force -Path $runDir | Out-Null
        $rawHdd = Join-Path $hddDir ("{0}-run-{1:d2}.raw" -f $id, $run)
        $layout = Join-Path $runDir 'fatx-layout.json'
        $config = Join-Path $runDir 'xemu.toml'

        & python $converter $baseHdd $rawHdd --force
        if ($LASTEXITCODE -ne 0) { throw "qcow2 conversion failed for $id run $run" }
        & python $stager $rawHdd --partition E --clean-known-boot `
            --kernel (Join-Path $eRoot $package.boot.kernel) --kernel-name $package.boot.kernel `
            --initrd (Join-Path $eRoot $package.boot.initrd) --initrd-name $package.boot.initrd `
            --payload (Join-Path $eRoot $package.boot.payload) --payload-name $package.boot.payload `
            --append $append --title "$($package.distro) $($package.kernelVersion)" `
            --boot-layout contiguous --payload-layout contiguous --stage-order payload-first --manifest $layout
        if ($LASTEXITCODE -ne 0) { throw "FATX staging failed for $id run $run" }
        $layoutData = Get-Content -LiteralPath $layout -Raw | ConvertFrom-Json
        foreach ($file in $layoutData.files) {
            if ($file.contiguous -ne $true) { throw "Staged FATX file is fragmented: $($file.name)" }
            if ($file.sha256 -ne $file.readback_sha256) { throw "FATX readback failed: $($file.name)" }
        }
        Write-XemuConfig $config $rawHdd $loaderIso

        $started = Get-Date
        $process = $null
        $frames = [System.Collections.Generic.List[object]]::new()
        $outcome = 'timed-out'
        $firstLinux = $null
        $firstX = $null
        $ready = $null
        $desktopPopulated = $false
        $lastStage = $null
        $previousFingerprint = $null
        $repeatedFingerprintPolls = 0
        try {
            $process = Start-Process -FilePath $xemu -ArgumentList @(
                '-config_path', $config, '-bios', $bios,
                '-machine', "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite", '-snapshot'
            ) -PassThru
            while (-not $process.HasExited -and ((Get-Date) - $started).TotalSeconds -lt $TimeoutSeconds) {
                Start-Sleep -Seconds $PollSeconds
                $elapsed = [int][Math]::Round(((Get-Date) - $started).TotalSeconds)
                & $capture --pid $process.Id --out-dir $runDir --prefix ("frame-{0:d3}s" -f $elapsed) --rect frame | Out-Null
                if ($LASTEXITCODE -ne 0) { continue }
                $png = Get-ChildItem -LiteralPath $runDir -Filter '*.png' | Sort-Object LastWriteTime | Select-Object -Last 1
                if (-not $png) { continue }
                $analysis = & python $classifier $png.FullName | ConvertFrom-Json
                $frames.Add([pscustomobject]@{ elapsedSeconds = $elapsed; image = $png.Name; analysis = $analysis })
                $lastStage = $analysis.stage
                if ($analysis.stage -eq 'linux-text' -and $null -eq $firstLinux) { $firstLinux = $elapsed }
                if ($analysis.stage -eq 'desktop-x' -and $null -eq $firstLinux) { $firstLinux = $elapsed }
                if ($analysis.stage -eq 'desktop-x' -and $null -eq $firstX) { $firstX = $elapsed }
                if ($analysis.fingerprint -eq $previousFingerprint) { $repeatedFingerprintPolls++ } else { $repeatedFingerprintPolls = 0 }
                $previousFingerprint = $analysis.fingerprint

                $tinyCoreDesktop = $null -ne $firstLinux -and $analysis.stage -eq 'xromwell' -and `
                    $analysis.blueRatio -ge 0.75 -and $analysis.darkRatio -le 0.75 -and `
                    $analysis.lightRatio -ge 0.02 -and $analysis.edgeRatio -le 0.06
                if ($tinyCoreDesktop -and $null -eq $firstX) { $firstX = $elapsed }
                $normalDesktop = $analysis.stage -eq 'desktop-x' -and $analysis.centerDarkRatio -ge 0.45
                if ($normalDesktop) { $desktopPopulated = $true }
                if (($package.proofProfile -eq 'tinycore-desktop' -and ($normalDesktop -or $tinyCoreDesktop)) -or
                    ($package.proofProfile -eq 'desktop-x' -and $analysis.stage -eq 'desktop-x')) {
                    $ready = $elapsed
                    $outcome = 'passed'
                    break
                }
                if ($analysis.stage -eq 'xromwell' -and $repeatedFingerprintPolls -ge 5 -and -not $tinyCoreDesktop) {
                    $outcome = 'stalled-xromwell'
                    break
                }
            }
            $process.Refresh()
            if ($process.HasExited -and $outcome -ne 'passed') { $outcome = 'xemu-exited' }
        }
        finally {
            if ($process -and -not $process.HasExited) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                $process.WaitForExit(10000) | Out-Null
            }
        }

        if ($outcome -eq 'passed') { $cellPasses++ }
        $result = [ordered]@{
            cell = $id
            distro = $package.distro
            kernelVersion = $package.kernelVersion
            run = $run
            outcome = $outcome
            elapsedSeconds = [int][Math]::Round(((Get-Date) - $started).TotalSeconds)
            firstLinuxSeconds = $firstLinux
            firstXSeconds = $firstX
            readySeconds = $ready
            frameCount = $frames.Count
            lastStage = $lastStage
            desktopPopulated = $desktopPopulated
            packageZipSha256 = $package.zipSha256
            xemuLoader = $package.xemuLoader
        }
        $frames | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runDir 'frames.json') -Encoding ASCII
        $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDir 'result.json') -Encoding ASCII
        if (-not $KeepDisk -and (Test-Path -LiteralPath $rawHdd -PathType Leaf)) {
            [System.IO.File]::Delete($rawHdd)
        }
        $results.Add([pscustomobject]$result)
        Write-Host ("{0} run {1}: {2} (Linux={3}s X={4}s ready={5}s)" -f $id, $run, $outcome, $firstLinux, $firstX, $ready)
    }
    if ($cellPasses -lt $RequiredPasses) { $failedCells.Add($id) }
}

[ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    matrixManifest = $manifestPath
    runsRequestedPerCell = $Runs
    requiredPassesPerCell = $RequiredPasses
    timeoutSeconds = $TimeoutSeconds
    pollSeconds = $PollSeconds
    failedCells = $failedCells
    results = $results
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $session 'summary.json') -Encoding ASCII
$results | Export-Csv -LiteralPath (Join-Path $session 'summary.csv') -NoTypeInformation
$results | Format-Table cell, run, outcome, firstLinuxSeconds, firstXSeconds, readySeconds, frameCount -AutoSize
Write-Host "Results: $session"
if ($failedCells.Count -gt 0) {
    throw "Boot matrix failed: $($failedCells -join ', ')"
}
