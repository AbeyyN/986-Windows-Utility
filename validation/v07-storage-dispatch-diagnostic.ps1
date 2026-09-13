$ErrorActionPreference = 'Stop'

$clsid = '{5FCCE720-D806-4B6A-A5F1-F060344FC88D}'
$work = Join-Path $env:TEMP '986-v07-rc2-validation'
$app = Get-ChildItem -LiteralPath $work -Filter '986-Windows-Utility.ps1' -File -Recurse | Select-Object -First 1
if (-not $app) { throw 'RC2 extracted root missing' }
$root = $app.Directory.FullName
$reg = Join-Path $root 'storage\registration\Register-StorageView.ps1'
$dll = Join-Path $root 'storage\bin\986StorageShell.dll'
$classRoot = 'HKCU:\Software\Classes\CLSID\' + $clsid
$nsRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\' + $clsid
if ((Test-Path $classRoot) -or (Test-Path $nsRoot)) { throw 'Pre-existing test registration' }

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class W986Dispatch {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);
}
'@

function Find-986StorageView {
    $script:view = [IntPtr]::Zero
    $child = [W986Dispatch+EnumWindowsProc]{
        param([IntPtr]$h,[IntPtr]$l)
        $sb = New-Object Text.StringBuilder 256
        [W986Dispatch]::GetClassName($h,$sb,$sb.Capacity) | Out-Null
        if ($sb.ToString() -eq '986StorageViewWindow') {
            $script:view = $h
            return $false
        }
        return $true
    }
    $top = [W986Dispatch+EnumWindowsProc]{
        param([IntPtr]$h,[IntPtr]$l)
        [W986Dispatch]::EnumChildWindows($h,$child,[IntPtr]::Zero) | Out-Null
        return ($script:view -eq [IntPtr]::Zero)
    }
    [W986Dispatch]::EnumWindows($top,[IntPtr]::Zero) | Out-Null
    return $script:view
}

try {
    & $reg -Action Install -DllPath $dll | Out-Null
    Start-Process explorer.exe -ArgumentList ('shell:::' + $clsid)
    Start-Sleep -Seconds 4

    $view = Find-986StorageView
    Write-Output ('VIEW_HANDLE=' + $view)
    if ($view -eq [IntPtr]::Zero) { throw 'Storage view missing' }

    $rect = New-Object 'W986Dispatch+RECT'
    [W986Dispatch]::GetClientRect($view,[ref]$rect) | Out-Null
    Write-Output ('VIEW_CLIENT=' + $rect.Right + 'x' + $rect.Bottom)

    $margin = if ($rect.Right -lt 520) { 14 } else { 28 }
    $left = $margin
    $right = [Math]::Max($left + 180,$rect.Right - $margin)
    $contentWidth = [Math]::Max(1,$right - $left - 36)
    $columns = if ($contentWidth -ge 700) { 4 } elseif ($contentWidth -ge 260) { 2 } else { 1 }
    $rows = [int][Math]::Ceiling(7.0 / $columns)
    $buttonTop = 88 + 82 + ($rows * 25) + 8
    $buttonLeft = [Math]::Max($left + 18,$right - 150)
    $buttonRight = $right - 18
    $x = [int](($buttonLeft + $buttonRight) / 2)
    $y = $buttonTop + 16
    Write-Output ('BUTTON=' + $buttonLeft + ',' + $buttonTop + ',' + $buttonRight + ',' + ($buttonTop + 32))
    Write-Output ('SEND_CLICK=' + $x + ',' + $y)

    $lp = [IntPtr](($y -shl 16) -bor ($x -band 0xffff))
    [W986Dispatch]::SendMessage($view,0x0201,[IntPtr]1,$lp) | Out-Null
    [W986Dispatch]::SendMessage($view,0x0202,[IntPtr]0,$lp) | Out-Null
    Start-Sleep -Seconds 3

    $scanner = @(Get-Process 986StorageScanner -ErrorAction SilentlyContinue)
    Write-Output ('SCANNER_AFTER_SENDMESSAGE=' + $scanner.Count)
    if ($scanner.Count -eq 0) { throw 'Synchronous button dispatch did not launch scanner' }
    foreach ($p in $scanner) {
        Write-Output ('SCANNER_PID=' + $p.Id)
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    Write-Output 'DISPATCH_STARTSCAN_PASS'

    $topWindow = [W986Dispatch]::GetAncestor($view,2)
    if ($topWindow -ne [IntPtr]::Zero) {
        [W986Dispatch]::SendMessage($topWindow,0x0010,[IntPtr]::Zero,[IntPtr]::Zero) | Out-Null
    }
    Start-Sleep -Seconds 1
}
finally {
    try {
        if ((Test-Path $classRoot) -or (Test-Path $nsRoot)) {
            & $reg -Action Remove -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}
}
