param(
    [int]$ProcessId = 0,
    [string[]]$Commands = @(
        'echo CODEX_OK',
        'uname -a',
        'cat /proc/cmdline'
    )
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;

public class XemuSendKeysNative {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@

if ($ProcessId -ne 0) {
    $proc = Get-Process -Id $ProcessId -ErrorAction Stop
} else {
    $proc = Get-Process -Name xemu -ErrorAction Stop |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Sort-Object StartTime -Descending |
        Select-Object -First 1
}

if (-not $proc -or $proc.MainWindowHandle -eq 0) {
    throw 'No xemu process with a main window handle was found.'
}

function ConvertTo-SendKeysLiteral([string]$Text) {
    $builder = [System.Text.StringBuilder]::new()
    foreach ($char in $Text.ToCharArray()) {
        switch ($char) {
            '+' { [void]$builder.Append('{+}') }
            '^' { [void]$builder.Append('{^}') }
            '%' { [void]$builder.Append('{%}') }
            '~' { [void]$builder.Append('{~}') }
            '(' { [void]$builder.Append('{(}') }
            ')' { [void]$builder.Append('{)}') }
            '[' { [void]$builder.Append('{[}') }
            ']' { [void]$builder.Append('{]}') }
            '{' { [void]$builder.Append('{{}') }
            '}' { [void]$builder.Append('{}}') }
            default { [void]$builder.Append($char) }
        }
    }
    $builder.ToString()
}

[XemuSendKeysNative]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 750

foreach ($command in $Commands) {
    [System.Windows.Forms.SendKeys]::SendWait((ConvertTo-SendKeysLiteral $command) + '{ENTER}')
    Start-Sleep -Seconds 1
}

[pscustomobject]@{
    pid = $proc.Id
    hwnd = "0x{0:X}" -f $proc.MainWindowHandle.ToInt64()
    commands = $Commands
}
