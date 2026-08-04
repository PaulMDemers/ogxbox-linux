[CmdletBinding()]
param(
    [ValidateRange(1, 5)]
    [int]$Runs = 1,
    [ValidateRange(120, 900)]
    [int]$TimeoutSeconds = 420,
    [ValidateRange(5, 30)]
    [int]$PollSeconds = 10,
    [string[]]$Variants = @(),
    [string]$CandidateRoot = 'artifacts\devuan-5.8.1-squashfs-block-ab',
    [string]$OutputRoot = 'run\devuan58-squashfs-block-ab'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$candidateFull = Join-Path $repoRoot $CandidateRoot
$manifestPath = Join-Path $candidateFull 'candidate-manifest.json'
$baseHdd = Join-Path $repoRoot 'Xbox-Emulator-Files\hdd\xbox_hdd.qcow2'
$rawHdd = Join-Path $repoRoot 'run\hdd\devuan58-squashfs-block-ab.raw'
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

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$session = Join-Path (Join-Path $repoRoot $OutputRoot) ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $session, (Split-Path -Parent $rawHdd) | Out-Null
$results = [System.Collections.Generic.List[object]]::new()
$variantProperties = @($manifest.variants.psobject.Properties)
if ($Variants.Count -gt 0) {
    $unknown = @($Variants | Where-Object { $_ -notin $variantProperties.Name })
    if ($unknown.Count -gt 0) {
        throw "Unknown variants: $($unknown -join ', ')"
    }
    $variantProperties = @($variantProperties | Where-Object Name -in $Variants)
}

foreach ($variantProperty in $variantProperties) {
    $variantName = $variantProperty.Name
    $variant = $variantProperty.Value
    $packageDir = Join-Path $candidateFull $variant.directory
    foreach ($property in $variant.files.psobject.Properties) {
        Assert-FileHash (Join-Path $packageDir ($property.Name.Replace('/', '\'))) $property.Value
    }
    $eRoot = Join-Path $packageDir 'E-root'
    $cfg = Get-Content -LiteralPath (Join-Path $eRoot 'linuxboot.cfg') -Raw
    $appendLine = $cfg -split "`r?`n" | Where-Object { $_ -like 'append *' } | Select-Object -First 1
    if (-not $appendLine) { throw "linuxboot.cfg has no append line: $eRoot" }
    if ($appendLine -notmatch '\bxbox_storage_selftest=1\b') {
        throw "Self-test flag is missing from $eRoot"
    }
    $append = $appendLine.Substring('append '.Length)

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
            if ($file.sha256 -ne $file.readback_sha256) { throw "FATX readback failed: $($file.name)" }
        }
        Write-XemuConfig $config $rawHdd

        $started = Get-Date
        $process = $null
        $frames = [System.Collections.Generic.List[object]]::new()
        $outcome = 'timed-out'
        $firstLinux = $null
        $benchmarkComplete = $null
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
                if ($analysis.stage -eq 'linux-text' -and $null -eq $firstLinux) {
                    $firstLinux = $elapsed
                }
                $greenSummary = $analysis.stage -in @('xbox-splash', 'xbox-error') -and `
                    $analysis.greenRatio -ge 0.06
                if ($null -ne $firstLinux -and $greenSummary) {
                    $benchmarkComplete = $elapsed
                    $outcome = 'passed'
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
            blockSize = $variant.blockSize
            readAheadKb = if ($variant.psobject.Properties.Name -contains 'readAheadKb') { $variant.readAheadKb } else { $null }
            run = $run
            outcome = $outcome
            elapsedSeconds = [int][Math]::Round(((Get-Date) - $started).TotalSeconds)
            firstLinuxSeconds = $firstLinux
            benchmarkCompleteSeconds = $benchmarkComplete
            frameCount = $frames.Count
            payloadSha256 = $variant.files.'E-root/devuan.squashfs'
            finalFrame = if ($frames.Count) { $frames[$frames.Count - 1].image } else { $null }
        }
        $frames | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runDir 'frames.json') -Encoding ASCII
        $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDir 'result.json') -Encoding ASCII
        $results.Add([pscustomobject]$result)
        Write-Host ("{0} run {1}: {2} (linux={3}s benchmark={4}s)" -f `
            $variantName, $run, $outcome, $firstLinux, $benchmarkComplete)
    }
}

[ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    candidateManifest = $manifestPath
    runsPerVariant = $Runs
    selectedVariants = @($variantProperties.Name)
    timeoutSeconds = $TimeoutSeconds
    pollSeconds = $PollSeconds
    results = $results
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $session 'summary.json') -Encoding ASCII
$results | Export-Csv -LiteralPath (Join-Path $session 'summary.csv') -NoTypeInformation
Write-Host "Results: $session"
$results | Format-Table variant, blockSize, readAheadKb, run, outcome, firstLinuxSeconds, benchmarkCompleteSeconds -AutoSize
