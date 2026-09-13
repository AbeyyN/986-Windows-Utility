$ErrorActionPreference = 'Stop'
$clsid = '{5FCCE720-D806-4B6A-A5F1-F060344FC88D}'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$reg = Join-Path $root 'storage\registration\Register-StorageView.ps1'
$dll = Join-Path $root 'storage\bin\986StorageShell.dll'
$classRoot = 'HKCU:\Software\Classes\CLSID\' + $clsid
$nsRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\' + $clsid
$cacheDir = Join-Path $env:LOCALAPPDATA 'AbeyyTechXy\986-Windows-Utility\storage-cache'
$cache = Join-Path $cacheDir 'drive-C.json'
$backup = Join-Path $env:TEMP ('986-drive-C-' + [guid]::NewGuid().ToString('N') + '.json')
$cacheExisted = Test-Path $cache
if ($cacheExisted) { Copy-Item -LiteralPath $cache -Destination $backup -Force }

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class W986RealButton {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr data);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wp, IntPtr lp);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hWnd, uint flags);
}
'@

function Find-986Controls {
    $script:view = [IntPtr]::Zero
    $script:button = [IntPtr]::Zero
    $child = [W986RealButton+EnumProc]{
        param([IntPtr]$h,[IntPtr]$l)
        $class = New-Object Text.StringBuilder 128
        [W986RealButton]::GetClassName($h,$class,$class.Capacity) | Out-Null
        if ($class.ToString() -eq '986StorageViewWindow') { $script:view = $h }
        if ($class.ToString() -eq 'Button') {
            $text = New-Object Text.StringBuilder 128
            [W986RealButton]::GetWindowText($h,$text,$text.Capacity) | Out-Null
            if ($text.ToString() -eq 'Scan / Refresh') { $script:button = $h }
        }
        return $true
    }
    $top = [W986RealButton+EnumProc]{
        param([IntPtr]$h,[IntPtr]$l)
        [W986RealButton]::EnumChildWindows($h,$child,[IntPtr]::Zero) | Out-Null
        return $true
    }
    [W986RealButton]::EnumWindows($top,[IntPtr]::Zero) | Out-Null
    [pscustomobject]@{ View=$script:view; Button=$script:button }
}

try {
    if ((Test-Path $classRoot) -or (Test-Path $nsRoot)) {
        $owner = $null
        try { $owner = (Get-ItemProperty -LiteralPath $classRoot -Name '986Owner' -ErrorAction Stop).'986Owner' } catch {}
        if ($owner -ne 'AbeyyTechXy/986-Windows-Utility') { throw 'Foreign or unknown Storage registration exists.' }
        & $reg -Action Remove | Out-Null
    }
    if (-not (Test-Path $dll)) { throw 'Built Storage shell DLL missing.' }
    if (Test-Path $cache) { Remove-Item -LiteralPath $cache -Force }
    & $reg -Action Install -DllPath $dll | Out-Null
    Start-Process explorer.exe -ArgumentList ('shell:::' + $clsid)
    Start-Sleep -Seconds 5

    $controls = Find-986Controls
    Write-Output ('VIEW_HANDLE=' + $controls.View)
    Write-Output ('BUTTON_HANDLE=' + $controls.Button)
    if ($controls.View -eq [IntPtr]::Zero) { throw '986 Storage view not created.' }
    if ($controls.Button -eq [IntPtr]::Zero) { throw 'Real Scan / Refresh button not found.' }

    $sw = [Diagnostics.Stopwatch]::StartNew()
    [W986RealButton]::SendMessage($controls.Button,0x00F5,[IntPtr]::Zero,[IntPtr]::Zero) | Out-Null
    Write-Output 'BM_CLICK_SENT=True'
    $spawnDeadline = (Get-Date).AddSeconds(8)
    $scanner = $null
    while ((Get-Date) -lt $spawnDeadline -and -not $scanner) {
        Start-Sleep -Milliseconds 250
        $scanner = Get-Process 986StorageScanner -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    Write-Output ('SCANNER_SPAWNED=' + [bool]$scanner)
    if (-not $scanner) { throw 'Real button did not launch scanner.' }
    Write-Output ('SCANNER_PID=' + $scanner.Id)
    Write-Output ('SCANNER_PRIORITY=' + $scanner.PriorityClass)

    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline -and -not (Test-Path $cache)) { Start-Sleep -Seconds 1 }
    $sw.Stop()
    if (-not (Test-Path $cache)) { throw 'Storage scan cache missing after 120 seconds.' }
    $json = Get-Content -LiteralPath $cache -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Output ('SCAN_SECONDS=' + [Math]::Round($sw.Elapsed.TotalSeconds,2))
    Write-Output ('SCAN_FILES=' + $json.Files)
    Write-Output ('SCAN_BYTES=' + $json.ScannedBytes)
    Write-Output ('SCAN_SKIPPED=' + $json.SkippedDirectories)
    if ([int64]$json.Files -lt 800000 -or [int64]$json.ScannedBytes -lt 400000000000) { throw 'Storage scan coverage unexpectedly low.' }

    Start-Sleep -Seconds 2
    $after = Find-986Controls
    Write-Output ('VIEW_ALIVE_AFTER_SCAN=' + ($after.View -ne [IntPtr]::Zero))
    Write-Output ('BUTTON_ALIVE_AFTER_SCAN=' + ($after.Button -ne [IntPtr]::Zero))
    if ($after.View -eq [IntPtr]::Zero -or $after.Button -eq [IntPtr]::Zero) { throw 'Storage view/button did not survive scan.' }

    $topWindow = [W986RealButton]::GetAncestor($after.View,2)
    if ($topWindow -ne [IntPtr]::Zero) { [W986RealButton]::SendMessage($topWindow,0x0010,[IntPtr]::Zero,[IntPtr]::Zero) | Out-Null }
    Start-Sleep -Seconds 2
    & $reg -Action Remove | Out-Null
    if ((Test-Path $classRoot) -or (Test-Path $nsRoot)) { throw 'Storage unregister did not restore clean registry state.' }
    Write-Output 'STORAGE_REAL_BUTTON_MACHINE_GATE_PASS'
}
finally {
    try {
        if ((Test-Path $classRoot) -or (Test-Path $nsRoot)) { & $reg -Action Remove -ErrorAction SilentlyContinue | Out-Null }
    } catch {}
    if ($cacheExisted -and (Test-Path $backup)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        Copy-Item -LiteralPath $backup -Destination $cache -Force
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    } elseif (-not $cacheExisted -and (Test-Path $cache)) {
        Remove-Item -LiteralPath $cache -Force -ErrorAction SilentlyContinue
    }
}
