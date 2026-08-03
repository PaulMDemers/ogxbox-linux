[CmdletBinding()]
param(
    [ValidateRange(1, 5)]
    [int]$Runs = 1,
    [ValidateRange(1, 3)]
    [int]$RequiredPasses = 1,
    [ValidateRange(120, 600)]
    [int]$TimeoutSeconds = 300,
    [ValidateRange(5, 30)]
    [int]$PollSeconds = 10,
    [string]$CandidateRoot = 'artifacts\devuan-5.8.1-desktop-hot-order',
    [string]$OutputRoot = 'run\devuan58-hot-order-ab'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$candidateFull = Join-Path $repoRoot $CandidateRoot
$manifestPath = Join-Path $candidateFull 'candidate-manifest.json'
$baseHdd = Join-Path $repoRoot 'Xbox-Emulator-Files\hdd\xbox_hdd.qcow2'
$rawHdd = Join-Path $repoRoot 'run\hdd\devuan58-hot-order-ab.raw'
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$capture = Join-Path $repoRoot 'tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe'
$classifier = Join-Path $repoRoot 'scripts\classify_xemu_boot_frame.py'
$converter = Join-Path $repoRoot 'scripts\qcow2_to_raw_sparse.py'
$stager = Join-Path $repoRoot 'scripts\fatx_stage_boot.py'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$eeprom = Join-Path $repoRoot 'run\eeprom.bin'
$loaderIso = Join-Path $repoRoot 'artifacts\xromwell-sector512-baseline.iso'

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
    param([string]$Path, [string]$Hdd)
    @"
[general]
show_welcome = false

[sys.files]
bootrom_path = '$mcpx'
flashrom_path = '$bios'
eeprom_path = '$eeprom'
hdd_path = '$Hdd'
dvd_path = '$loaderIso'

[input.bindings]
port1 = 'keyboard'
port1_driver = 'usb-xbox-gamepad'
"@ | Set-Content -LiteralPath $Path -Encoding ASCII
}

foreach ($required in @(
    $manifestPath, $baseHdd, $xemu, $capture, $classifier, $converter,
    $stager, $bios, $mcpx, $eeprom, $loaderIso
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file was not found: $required"
    }
}
if (Get-Process xemu -ErrorAction SilentlyContinue) {
    throw 'xemu is already running. Close it before starting the A/B.'
}
if ($RequiredPasses -gt $Runs) {
    throw "RequiredPasses ($RequiredPasses) cannot exceed Runs ($Runs)."
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$session = Join-Path (Join-Path $repoRoot $OutputRoot) ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $session, (Split-Path -Parent $rawHdd) | Out-Null
$results = [System.Collections.Generic.List[object]]::new()

foreach ($variantName in @('control', 'hotOrder')) {
    $variant = $manifest.variants.$variantName
    $packageDir = Join-Path $candidateFull $variant.directory
    foreach ($property in $variant.files.psobject.Properties) {
        Assert-FileHash (Join-Path $packageDir ($property.Name.Replace('/', '\'))) $property.Value
    }
    $eRoot = Join-Path $packageDir 'E-root'
    $cfg = Get-Content -LiteralPath (Join-Path $eRoot 'linuxboot.cfg') -Raw
    $appendLine = $cfg -split "`r?`n" | Where-Object { $_ -like 'append *' } | Select-Object -First 1
    if (-not $appendLine) { throw "linuxboot.cfg has no append line: $eRoot" }
    $append = $appendLine.Substring('append '.Length)
    $passedRuns = 0

    for ($run = 1; $run -le $Runs; $run++) {
        $runDir = Join-Path $session ("{0}-run-{1:d2}" -f $variantName, $run)
        New-Item -ItemType Directory -Force -Path $runDir | Out-Null
        $layout = Join-Path $runDir 'fatx-layout.json'
        $config = Join-Path $runDir 'xemu.toml'

        & python $converter $baseHdd $rawHdd --force
        if ($LASTEXITCODE -ne 0) { throw "qcow2 conversion failed for $variantName run $run" }
        & python $stager $rawHdd --partition E --clean-known-boot `
            --kernel (Join-Path $eRoot 'devkrnl') --kernel-name devkrnl `
            --initrd (Join-Path $eRoot 'devinit') --initrd-name devinit `
            --payload (Join-Path $eRoot 'devuan.squashfs') --payload-name devuan.squashfs `
            --append $append --title 'Xbox HDD' `
            --boot-layout contiguous --payload-layout contiguous --stage-order boot-first --manifest $layout
        if ($LASTEXITCODE -ne 0) { throw "FATX staging failed for $variantName run $run" }
        $layoutData = Get-Content -LiteralPath $layout -Raw | ConvertFrom-Json
        foreach ($file in $layoutData.files) {
            if ($file.contiguous -ne $true) { throw "Staged FATX file is fragmented: $($file.name)" }
        }
        Write-XemuConfig $config $rawHdd

        $started = Get-Date
        $process = $null
        $frames = [System.Collections.Generic.List[object]]::new()
        $outcome = 'timed-out'
        $firstLinux = $null
        $firstX = $null
        $proofVisible = $null
        $previousFingerprint = $null
        $repeatedFingerprintPolls = 0
        $maxRepeatedFingerprintPolls = 0
        $lastStage = $null
        try {
            $process = Start-Process -FilePath $xemu -ArgumentList @(
                '-config_path', $config, '-bios', $bios,
                '-machine', "xbox,bootrom=$mcpx,kernel-irqchip=off,avpack=composite",
                '-snapshot'
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
                if ($analysis.stage -eq 'desktop-x' -and $null -eq $firstX) { $firstX = $elapsed }
                if ($analysis.fingerprint -eq $previousFingerprint) {
                    $repeatedFingerprintPolls++
                }
                else {
                    $repeatedFingerprintPolls = 0
                }
                if ($repeatedFingerprintPolls -gt $maxRepeatedFingerprintPolls) {
                    $maxRepeatedFingerprintPolls = $repeatedFingerprintPolls
                }
                $previousFingerprint = $analysis.fingerprint
                if ($analysis.stage -eq 'desktop-x' -and $analysis.centerDarkRatio -ge 0.66) {
                    $proofVisible = $elapsed
                    $outcome = 'passed'
                    break
                }
                if ($analysis.stage -eq 'xromwell' -and $repeatedFingerprintPolls -ge 5) {
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

        $result = [ordered]@{
            variant = $variantName
            run = $run
            outcome = $outcome
            elapsedSeconds = [int][Math]::Round(((Get-Date) - $started).TotalSeconds)
            firstLinuxSeconds = $firstLinux
            firstXSeconds = $firstX
            proofVisibleSeconds = $proofVisible
            frameCount = $frames.Count
            lastStage = $lastStage
            repeatedFingerprintPolls = $maxRepeatedFingerprintPolls
            payloadSha256 = $variant.files.'E-root/devuan.squashfs'
        }
        $frames | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runDir 'frames.json') -Encoding ASCII
        $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDir 'result.json') -Encoding ASCII
        $results.Add([pscustomobject]$result)
        Write-Host ("{0} run {1}: {2} (firstX={3}s proofVisible={4}s)" -f `
            $variantName, $run, $outcome, $firstX, $proofVisible)
        if ($outcome -eq 'passed') {
            $passedRuns++
            if ($passedRuns -ge $RequiredPasses) { break }
        }
    }

    if ($passedRuns -lt $RequiredPasses) {
        Write-Warning ("{0} produced {1}/{2} required successful boots in {3} attempts." -f `
            $variantName, $passedRuns, $RequiredPasses, $Runs)
    }
}

[ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    candidateManifest = $manifestPath
    runsRequestedPerVariant = $Runs
    requiredPassesPerVariant = $RequiredPasses
    timeoutSeconds = $TimeoutSeconds
    pollSeconds = $PollSeconds
    results = $results
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $session 'summary.json') -Encoding ASCII
$results | Export-Csv -LiteralPath (Join-Path $session 'summary.csv') -NoTypeInformation
Write-Host "Results: $session"
$results | Format-Table variant, run, outcome, firstLinuxSeconds, firstXSeconds, proofVisibleSeconds, frameCount -AutoSize
