[CmdletBinding()]
param(
    [ValidateRange(1, 10)]
    [int]$Runs = 3,
    [ValidateRange(1, 10)]
    [int]$RequiredPasses = 3,
    [ValidateRange(120, 600)]
    [int]$TimeoutSeconds = 300,
    [ValidateRange(5, 30)]
    [int]$PollSeconds = 10,
    [string]$CandidateRoot = 'artifacts\tinycore-hdd-ra128-candidate',
    [string]$OutputRoot = 'run\tinycore-hdd-ra128',
    [ValidateSet('cromwell-rom', 'xromwell-xbe')]
    [string]$BootTransport = 'cromwell-rom',
    [ValidateSet('payload-first', 'boot-first')]
    [string]$StageOrder = 'payload-first'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$candidateFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $CandidateRoot))
$manifestPath = Join-Path $candidateFull 'candidate-manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$packageDir = Join-Path $candidateFull $manifest.candidate.directory
$eRoot = Join-Path $packageDir 'E-root'
$baseHdd = Join-Path $repoRoot 'Xbox-Emulator-Files\hdd\xbox_hdd.qcow2'
$rawHdd = Join-Path $repoRoot 'run\hdd\tinycore-hdd-candidate.raw'
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$capture = Join-Path $repoRoot 'tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe'
$classifier = Join-Path $repoRoot 'scripts\classify_xemu_boot_frame.py'
$converter = Join-Path $repoRoot 'scripts\qcow2_to_raw_sparse.py'
$stager = Join-Path $repoRoot 'scripts\fatx_stage_boot.py'
$complexBios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'
$cromwellBios = Join-Path $repoRoot 'artifacts\cromwell-hddfatx-autoboot-modernhdr-initrd32_1024.bin'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$eeprom = Join-Path $repoRoot 'run\eeprom.bin'
$loaderIso = Join-Path $repoRoot 'artifacts\xromwell-sector512-baseline.iso'
$placeholderIso = Join-Path $repoRoot 'artifacts\xromwell-modern-initrd32.iso'
$bootBios = if ($BootTransport -eq 'cromwell-rom') { $cromwellBios } else { $complexBios }
$dvdPath = if ($BootTransport -eq 'cromwell-rom') { $placeholderIso } else { $loaderIso }

function Assert-FileHash {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required file was not found: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) { throw "SHA-256 mismatch for $Path. Expected $Expected, got $actual" }
}

function Write-XemuConfig {
    param([string]$Path, [string]$Hdd)
    @"
[general]
show_welcome = false

[sys.files]
bootrom_path = '$mcpx'
flashrom_path = '$bootBios'
eeprom_path = '$eeprom'
hdd_path = '$Hdd'
dvd_path = '$dvdPath'

[input.bindings]
port1 = 'keyboard'
port1_driver = 'usb-xbox-gamepad'
"@ | Set-Content -LiteralPath $Path -Encoding ASCII
}

foreach ($required in @($manifestPath, $baseHdd, $xemu, $capture, $classifier, $converter, $stager, $bootBios, $mcpx, $eeprom, $dvdPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required file was not found: $required" }
}
if (Get-Process xemu -ErrorAction SilentlyContinue) { throw 'xemu is already running. Close it before testing.' }
if ($RequiredPasses -gt $Runs) { throw "RequiredPasses ($RequiredPasses) cannot exceed Runs ($Runs)." }
foreach ($property in $manifest.candidate.files.psobject.Properties) {
    Assert-FileHash (Join-Path $packageDir ($property.Name.Replace('/', '\'))) $property.Value
}
$cfg = Get-Content -LiteralPath (Join-Path $eRoot 'linuxboot.cfg') -Raw
$cfgLines = $cfg -split "`r?`n"
$appendLines = @($cfgLines | Where-Object { $_ -like 'append *' })
if ($appendLines.Count -ne 1) { throw "Expected exactly one append line in $eRoot, found $($appendLines.Count)" }
$appendLine = $appendLines[0]
if (-not $appendLine) { throw "linuxboot.cfg has no append line: $eRoot" }
$append = $appendLine.Substring('append '.Length)
$stageTitle = if ($null -eq $manifest.candidate.fatxLoopReadAheadKb) {
    'Tiny Core HDD Protected Control'
} else {
    "Tiny Core HDD RA$($manifest.candidate.fatxLoopReadAheadKb)"
}
if ($null -ne $manifest.candidate.fatxLoopReadAheadKb) {
    $expectedArgs = @(
        "xbox_disk_readahead_kb=$($manifest.candidate.diskReadAheadKb)",
        "xbox_fatx_loop_readahead_kb=$($manifest.candidate.fatxLoopReadAheadKb)",
        "xbox_loop_readahead_kb=$($manifest.candidate.rootLoopReadAheadKb)"
    )
    foreach ($expectedArg in $expectedArgs) {
        if ($append -notmatch "(?:^| )$([regex]::Escape($expectedArg))(?: |$)") {
            throw "Candidate append line is missing ${expectedArg}: $appendLine"
        }
    }
}
if ($manifest.candidate.appsSkipMirror -eq $true -and
    $append -notmatch '(?:^| )xbox_apps_skip_mirror=1(?: |$)') {
    throw "Apps-default-mirror candidate is missing xbox_apps_skip_mirror=1: $appendLine"
}

$session = Join-Path (Join-Path $repoRoot $OutputRoot) ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $session, (Split-Path -Parent $rawHdd) | Out-Null
$results = [System.Collections.Generic.List[object]]::new()
$passedRuns = 0

for ($run = 1; $run -le $Runs; $run++) {
    $runDir = Join-Path $session ("run-{0:d2}" -f $run)
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null
    $layout = Join-Path $runDir 'fatx-layout.json'
    $config = Join-Path $runDir 'xemu.toml'
    & python $converter $baseHdd $rawHdd --force
    if ($LASTEXITCODE -ne 0) { throw "qcow2 conversion failed for run $run" }
    & python $stager $rawHdd --partition E --clean-known-boot `
        --kernel (Join-Path $eRoot 'vmlinuz') --kernel-name vmlinuz `
        --initrd (Join-Path $eRoot 'initramf') --initrd-name initramf `
        --payload (Join-Path $eRoot 'linuxroot.ext2') --payload-name linuxroot.ext2 `
        --append $append --title $stageTitle --boot-layout contiguous --payload-layout contiguous `
        --stage-order $StageOrder --manifest $layout
    if ($LASTEXITCODE -ne 0) { throw "FATX staging failed for run $run" }
    $layoutData = Get-Content -LiteralPath $layout -Raw | ConvertFrom-Json
    foreach ($file in $layoutData.files) {
        if ($file.contiguous -ne $true) { throw "Staged FATX file is fragmented: $($file.name)" }
        if ($file.sha256 -ne $file.readback_sha256) { throw "FATX readback failed: $($file.name)" }
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
    $lastStage = $null
    try {
        $process = Start-Process -FilePath $xemu -ArgumentList @(
            '-config_path', $config, '-bios', $bootBios,
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
            if ($analysis.stage -eq 'desktop-x' -and $null -eq $firstX) { $firstX = $elapsed }
            if ($analysis.fingerprint -eq $previousFingerprint) { $repeatedFingerprintPolls++ } else { $repeatedFingerprintPolls = 0 }
            $previousFingerprint = $analysis.fingerprint
            $tinyCoreDesktop = $null -ne $firstLinux -and $analysis.stage -eq 'xromwell' -and `
                $analysis.blueRatio -ge 0.75 -and $analysis.darkRatio -le 0.75 -and `
                $analysis.lightRatio -ge 0.02 -and $analysis.edgeRatio -le 0.06
            if ($tinyCoreDesktop -and $null -eq $firstX) { $firstX = $elapsed }
            if (($analysis.stage -eq 'desktop-x' -and $analysis.centerDarkRatio -ge 0.45) -or $tinyCoreDesktop) {
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
        run = $run
        outcome = $outcome
        elapsedSeconds = [int][Math]::Round(((Get-Date) - $started).TotalSeconds)
        firstLinuxSeconds = $firstLinux
        firstXSeconds = $firstX
        proofVisibleSeconds = $proofVisible
        frameCount = $frames.Count
        lastStage = $lastStage
        initramfsSha256 = $manifest.candidate.files.'E-root/initramf'
        payloadSha256 = $manifest.candidate.files.'E-root/linuxroot.ext2'
        bootTransport = $BootTransport
        stageOrder = $StageOrder
    }
    $frames | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runDir 'frames.json') -Encoding ASCII
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDir 'result.json') -Encoding ASCII
    $results.Add([pscustomobject]$result)
    if ($outcome -eq 'passed') { $passedRuns++ }
    Write-Host ("run {0}: {1} (Linux={2}s X={3}s proof={4}s)" -f $run, $outcome, $firstLinux, $firstX, $proofVisible)
}

[ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    candidateManifest = $manifestPath
    runsRequested = $Runs
    requiredPasses = $RequiredPasses
    bootTransport = $BootTransport
    stageOrder = $StageOrder
    passes = $passedRuns
    results = $results
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $session 'summary.json') -Encoding ASCII
$results | Export-Csv -LiteralPath (Join-Path $session 'summary.csv') -NoTypeInformation
$results | Format-Table run, outcome, firstLinuxSeconds, firstXSeconds, proofVisibleSeconds, frameCount -AutoSize
Write-Host "Results: $session"
if ($passedRuns -lt $RequiredPasses) { throw "Candidate passed $passedRuns/$Runs boots; $RequiredPasses required." }
