[CmdletBinding()]
param(
    [int]$ProcessId = 0,
    [string]$OutRoot = 'run\devuan58-storage-profile',
    [ValidateRange(5, 180)]
    [int]$RawWaitSeconds = 20,
    [ValidateRange(30, 600)]
    [int]$ClosureWaitSeconds = 120,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$sender = Join-Path $repoRoot 'scripts\send_xemu_shell_probe.ps1'
$capture = Join-Path $repoRoot 'tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe'
$session = Join-Path (Join-Path $repoRoot $OutRoot) ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $session | Out-Null

if (-not $DryRun -and $ProcessId -eq 0) {
    $process = Get-Process -Name xemu -ErrorAction Stop |
        Where-Object MainWindowHandle -ne 0 |
        Sort-Object StartTime -Descending |
        Select-Object -First 1
    $ProcessId = $process.Id
}

$percent = "p=`$(printf '\045')"
$plus = "q=`$(printf '\053')"
$rawCommand = "$percent; $plus; for s in 0 64 128 192 256; do sync; echo 3 >/proc/sys/vm/drop_caches; a=`$(date `${q}`${p}s`${p}N); dd if=/dev/loop1 of=/dev/null bs=1M skip=`$s count=1 2>/dev/null; b=`$(date `${q}`${p}s`${p}N); echo RAW_`${s}M=`$(((b-a)/1000000)); done >/tmp/xbox-storage-raw.txt; cat /tmp/xbox-storage-raw.txt"
$closureCommand = "$percent; $plus; for x in dillo mtpaint xfe; do sync; echo 3 >/proc/sys/vm/drop_caches; a=`$(date `${q}`${p}s`${p}N); b=`$(command -v `$x); cat `$b >/dev/null; ldd `$b | sed -n 's/.*=> \(\/[^ ]*\).*/\1/p' | xargs cat >/dev/null; z=`$(date `${q}`${p}s`${p}N); echo PRELOAD_`${x}=`$(((z-a)/1000000)); done >/tmp/xbox-storage-closure.txt 2>&1; cat /tmp/xbox-storage-closure.txt"

if ($DryRun) {
    [pscustomobject]@{
        PerformanceCommand = 'xbox-perf >/tmp/xbox-perf.txt 2>&1; tail -25 /tmp/xbox-perf.txt'
        RawReadCommand = $rawCommand
        ClosureCommand = $closureCommand
    }
    return
}

& $sender -ProcessId $ProcessId -Commands @('xbox-perf >/tmp/xbox-perf.txt 2>&1; tail -25 /tmp/xbox-perf.txt') | Out-Null
Start-Sleep -Seconds 5
& $capture --pid $ProcessId --out-dir $session --prefix 'read-ahead-and-memory' --rect frame | Out-Null

& $sender -ProcessId $ProcessId -Commands @($rawCommand) | Out-Null
Start-Sleep -Seconds $RawWaitSeconds
& $capture --pid $ProcessId --out-dir $session --prefix 'raw-loop1-read-times' --rect frame | Out-Null

& $sender -ProcessId $ProcessId -Commands @($closureCommand) | Out-Null
Start-Sleep -Seconds $ClosureWaitSeconds
& $capture --pid $ProcessId --out-dir $session --prefix 'application-closure-times' --rect frame | Out-Null

[ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    xemuProcessId = $ProcessId
    rawOffsetsMiB = @(0, 64, 128, 192, 256)
    rawReadMiB = 1
    closureApplications = @('dillo', 'mtpaint', 'xfe')
    screenshots = @(Get-ChildItem -LiteralPath $session -Filter '*.png' | Sort-Object Name | ForEach-Object Name)
    note = 'All screenshots capture the full existing xemu window frame.'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $session 'profile-manifest.json') -Encoding ASCII

Write-Host "Storage profile: $session"
