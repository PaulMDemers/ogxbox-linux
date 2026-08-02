[CmdletBinding()]
param(
    [ValidateSet('terminal', 'desktop', 'all')]
    [string]$Variant = 'all',
    [ValidateRange(1, 20)]
    [int]$Runs = 3,
    [ValidateRange(30, 900)]
    [int]$TimeoutSeconds = 180,
    [ValidateRange(2, 60)]
    [int]$PollSeconds = 5,
    [string]$OutputRoot = 'run\boot-reliability',
    [switch]$RebuildImages
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$artifactRoot = Join-Path $repoRoot 'artifacts\devuan-5.8.1-nondisc'
$manifestPath = Join-Path $artifactRoot 'manifest.json'
$baseHdd = Join-Path $repoRoot 'Xbox-Emulator-Files\hdd\xbox_hdd.qcow2'
$xemu = Join-Path $repoRoot 'tools\xemu-v0.8.135-nvnet\xemu.exe'
$capture = Join-Path $repoRoot 'tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe'
$classifier = Join-Path $repoRoot 'scripts\classify_xemu_boot_frame.py'
$converter = Join-Path $repoRoot 'scripts\qcow2_to_raw_sparse.py'
$stager = Join-Path $repoRoot 'scripts\fatx_stage_boot.py'
$bios = Join-Path $repoRoot 'Xbox-Emulator-Files\bios\Complex_4627.bin'
$mcpx = Join-Path $repoRoot 'Xbox-Emulator-Files\mcpx\mcpx_1.0.bin'
$eeprom = Join-Path $repoRoot 'run\eeprom.bin'
$loaderIso = Join-Path $repoRoot 'artifacts\xromwell-sector512-baseline.iso'
$terminalReference = Join-Path $repoRoot 'tests\fixtures\devuan58-terminal-proof.png'

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

function Resolve-Package {
    param([string]$Name, [pscustomobject]$Manifest)
    $entry = $Manifest.packages | Where-Object name -eq $Name | Select-Object -First 1
    if (-not $entry) { throw "Package is missing from protected manifest: $Name" }
    $directory = Join-Path $artifactRoot $entry.directory
    Assert-FileHash (Join-Path $artifactRoot $entry.zip) $entry.zipSha256
    foreach ($property in $entry.files.psobject.Properties) {
        Assert-FileHash (Join-Path $directory ($property.Name.Replace('/', '\'))) $property.Value
    }
    [pscustomobject]@{ Entry = $entry; Directory = $directory }
}

function Prepare-Hdd {
    param([string]$Name, [pscustomobject]$Package)
    $hddDir = Join-Path $repoRoot 'run\hdd'
    New-Item -ItemType Directory -Force -Path $hddDir | Out-Null
    $raw = Join-Path $hddDir "devuan58-$Name-coldboot.raw"
    $layout = Join-Path $hddDir "devuan58-$Name-coldboot-layout.json"
    if ($RebuildImages -or -not (Test-Path -LiteralPath $raw) -or -not (Test-Path -LiteralPath $layout)) {
        $converterOutput = & python $converter $baseHdd $raw --force
        if ($LASTEXITCODE -ne 0) { throw "qcow2 conversion failed for $Name" }
        if ($converterOutput) { Write-Host ($converterOutput -join "`n") }
        $eRoot = Join-Path $Package.Directory 'E-root'
        $cfg = Get-Content -LiteralPath (Join-Path $eRoot 'linuxboot.cfg') -Raw
        $appendLine = ($cfg -split "`r?`n" | Where-Object { $_ -like 'append *' } | Select-Object -First 1)
        if (-not $appendLine) { throw "linuxboot.cfg has no append line: $eRoot" }
        $append = $appendLine.Substring('append '.Length)
        $kernelName = 'devkrnl'
        $initrdName = 'devinit'
        $payloadName = $Package.Entry.payload
        $stagerOutput = & python $stager $raw --partition E --clean-known-boot `
            --kernel (Join-Path $eRoot $kernelName) --kernel-name $kernelName `
            --initrd (Join-Path $eRoot $initrdName) --initrd-name $initrdName `
            --payload (Join-Path $eRoot $payloadName) --payload-name $payloadName `
            --append $append --manifest $layout
        if ($LASTEXITCODE -ne 0) { throw "FATX staging failed for $Name" }
        if ($stagerOutput) { Write-Host ($stagerOutput -join "`n") }
    }
    $layoutData = Get-Content -LiteralPath $layout -Raw | ConvertFrom-Json
    foreach ($file in $layoutData.files) {
        if ($file.contiguous -ne $true) { throw "Staged FATX file is fragmented: $($file.name)" }
    }
    return $raw
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

foreach ($required in @($manifestPath, $baseHdd, $xemu, $capture, $classifier, $converter, $stager, $bios, $mcpx, $eeprom, $loaderIso, $terminalReference)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required file was not found: $required" }
}
if (Get-Process xemu -ErrorAction SilentlyContinue) {
    throw 'xemu is already running. Close it before starting cold-boot measurements.'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$selected = if ($Variant -eq 'all') { @('terminal', 'desktop') } else { @($Variant) }
$packageNames = @{
    terminal = 'devuan-daedalus-terminal-5.8.1-xbe'
    desktop = 'devuan-daedalus-desktop-live-5.8.1-xbe'
}
$session = Join-Path (Join-Path $repoRoot $OutputRoot) ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $session | Out-Null
$results = [System.Collections.Generic.List[object]]::new()

foreach ($name in $selected) {
    $package = Resolve-Package $packageNames[$name] $manifest
    $hdd = Prepare-Hdd $name $package
    for ($run = 1; $run -le $Runs; $run++) {
        $runDir = Join-Path $session ("{0}-run-{1:d2}" -f $name, $run)
        New-Item -ItemType Directory -Force -Path $runDir | Out-Null
        $config = Join-Path $runDir 'xemu.toml'
        Write-XemuConfig $config $hdd
        $started = Get-Date
        $process = $null
        $frames = [System.Collections.Generic.List[object]]::new()
        $outcome = 'timed-out'
        $firstLinux = $null
        $firstX = $null
        $ready = $null
        $maxRepeated = 0
        $repeated = 0
        $previousFingerprint = $null
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
                $classifierArgs = @($classifier, $png.FullName)
                if ($name -eq 'terminal') { $classifierArgs += @('--reference', $terminalReference) }
                $analysis = (& python @classifierArgs | ConvertFrom-Json)
                $frames.Add([pscustomobject]@{ elapsedSeconds = $elapsed; image = $png.Name; analysis = $analysis })
                if ($analysis.stage -eq 'linux-text' -and $null -eq $firstLinux) { $firstLinux = $elapsed }
                if ($analysis.stage -eq 'desktop-x' -and $null -eq $firstX) { $firstX = $elapsed }
                if ($analysis.fingerprint -eq $previousFingerprint) { $repeated++ } else { $repeated = 0 }
                if ($repeated -gt $maxRepeated) { $maxRepeated = $repeated }
                $previousFingerprint = $analysis.fingerprint

                if ($name -eq 'desktop' -and $analysis.stage -eq 'desktop-x' -and $analysis.centerDarkRatio -ge 0.66) {
                    $ready = $elapsed; $outcome = 'passed'; break
                }
                if ($name -eq 'terminal' -and $analysis.stage -eq 'linux-text' -and
                    $analysis.centerDarkRatio -ge 0.78 -and $analysis.edgeRatio -le 0.09 -and
                    $repeated -ge 1 -and
                    $analysis.referenceDistance -le 0.04) {
                    $ready = $elapsed; $outcome = 'passed'; break
                }
            }
            $process.Refresh()
            if ($process.HasExited -and $outcome -ne 'passed') { $outcome = 'xemu-exited' }
            elseif ($outcome -ne 'passed' -and $frames.Count -gt 0 -and $frames[-1].analysis.stage -eq 'xromwell' -and $maxRepeated -ge 3) {
                $outcome = 'stalled-xromwell'
            }
            elseif ($outcome -ne 'passed' -and $frames.Count -gt 0 -and $frames[-1].analysis.stage -eq 'xbox-error') {
                $outcome = 'xbox-error'
            }
        }
        finally {
            if ($process -and -not $process.HasExited) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                $process.WaitForExit(10000) | Out-Null
            }
        }
        $result = [ordered]@{
            variant = $name; run = $run; outcome = $outcome
            elapsedSeconds = [int][Math]::Round(((Get-Date) - $started).TotalSeconds)
            firstLinuxSeconds = $firstLinux; firstXSeconds = $firstX; readySeconds = $ready
            repeatedFingerprintPolls = $maxRepeated
            frameCount = $frames.Count; package = $PackageNames[$name]
            packageZipSha256 = $package.Entry.zipSha256
        }
        $frames | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runDir 'frames.json') -Encoding ASCII
        $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDir 'result.json') -Encoding ASCII
        $results.Add([pscustomobject]$result)
        Write-Host ("{0} run {1}: {2} (ready={3}s)" -f $name, $run, $outcome, $ready)
    }
}

$summary = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    protectedManifest = $manifestPath
    runsRequestedPerVariant = $Runs
    timeoutSeconds = $TimeoutSeconds
    pollSeconds = $PollSeconds
    results = $results
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $session 'summary.json') -Encoding ASCII
$results | Export-Csv -LiteralPath (Join-Path $session 'summary.csv') -NoTypeInformation
Write-Host "Results: $session"
$results | Format-Table variant, run, outcome, firstLinuxSeconds, firstXSeconds, readySeconds, frameCount -AutoSize
