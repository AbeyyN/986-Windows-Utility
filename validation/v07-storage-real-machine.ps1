$ErrorActionPreference = 'Stop'
$clsid = '{5FCCE720-D806-4B6A-A5F1-F060344FC88D}'
$work = Join-Path $env:TEMP '986-v07-rc3-validation'
$app = Get-ChildItem -LiteralPath $work -Filter '986-Windows-Utility.ps1' -File -Recurse | Select-Object -First 1
if (-not $app) { throw 'RC validation payload missing' }
$root = $app.Directory.FullName
$reg = Join-Path $root 'storage\registration\Register-StorageView.ps1'
$dll = Join-Path $root 'storage\bin\986StorageShell.dll'
$classRoot = 'HKCU:\Software\Classes\CLSID\' + $clsid
$nsRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\' + $clsid

Write-Output ('RC_ROOT=' + $root)
$preClass = Test-Path $classRoot
$preNs = Test-Path $nsRoot
Write-Output ('PRE_CLASS=' + $preClass)
Write-Output ('PRE_NAMESPACE=' + $preNs)
if ($preClass -or $preNs) { throw 'Pre-existing 986 Storage registration found; refusing destructive gate' }

$cacheDir = Join-Path $env:LOCALAPPDATA 'AbeyyTechXy\986-Windows-Utility\storage-cache'
$cache = Join-Path $cacheDir 'drive-C.json'
$cacheBackup = Join-Path $env:TEMP '986-drive-C-pretest.json'
$cacheExisted = Test-Path $cache
if ($cacheExisted) { Copy-Item -LiteralPath $cache -Destination $cacheBackup -Force }

try {
    Write-Output '---INSTALL---'
    & $reg -Action Install -DllPath $dll | Format-List | Out-String | Write-Output

    $owner = (Get-ItemProperty -LiteralPath $classRoot -Name '986Owner').'986Owner'
    $nsOwner = (Get-ItemProperty -LiteralPath $nsRoot -Name '986Owner').'986Owner'
    $inproc = (Get-Item -LiteralPath (Join-Path $classRoot 'InprocServer32')).GetValue('')
    Write-Output ('CLASS_OWNER=' + $owner)
    Write-Output ('NS_OWNER=' + $nsOwner)
    Write-Output ('INPROC=' + $inproc)
    if ($owner -ne 'AbeyyTechXy/986-Windows-Utility' -or
        $nsOwner -ne 'AbeyyTechXy/986-Windows-Utility' -or
        [IO.Path]::GetFullPath([string]$inproc) -ne [IO.Path]::GetFullPath($dll)) {
        throw 'Registration verification failed'
    }

    if (Test-Path $cache) { Remove-Item -LiteralPath $cache -Force }

    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class W986Storage {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);
}
'@

    Start-Process explorer.exe -ArgumentList ('shell:::' + $clsid)
    Start-Sleep -Seconds 4

    $shell = New-Object -ComObject Shell.Application
    Write-Output '---SHELL_WINDOWS---'
    foreach ($w in @($shell.Windows())) {
        try { Write-Output ('WINDOW|' + $w.HWND + '|' + $w.LocationName + '|' + $w.LocationURL) } catch {}
    }

    function Find-986StorageView {
        $script:view = [IntPtr]::Zero
        $childCb = [W986Storage+EnumWindowsProc]{
            param([IntPtr]$h, [IntPtr]$l)
            $sb = New-Object Text.StringBuilder 256
            [W986Storage]::GetClassName($h, $sb, $sb.Capacity) | Out-Null
            if ($sb.ToString() -eq '986StorageViewWindow') {
                $script:view = $h
                return $false
            }
            return $true
        }
        $topCb = [W986Storage+EnumWindowsProc]{
            param([IntPtr]$h, [IntPtr]$l)
            [W986Storage]::EnumChildWindows($h, $childCb, [IntPtr]::Zero) | Out-Null
            return ($script:view -eq [IntPtr]::Zero)
        }
        [W986Storage]::EnumWindows($topCb, [IntPtr]::Zero) | Out-Null
        return $script:view
    }

    $view = Find-986StorageView
    Write-Output ('VIEW_HANDLE=' + $view)
    if ($view -eq [IntPtr]::Zero) { throw 'Real 986StorageViewWindow was not created inside Explorer' }

    $rect = New-Object 'W986Storage+RECT'
    if (-not [W986Storage]::GetClientRect($view, [ref]$rect)) { throw 'GetClientRect failed' }
    Write-Output ('VIEW_CLIENT=' + $rect.Right + 'x' + $rect.Bottom)

    $cardTop = 88
    $margin = if ($rect.Right -lt 520) { 14 } else { 28 }
    $left = $margin
    $right = [Math]::Max($left + 180, $rect.Right - $margin)
    $contentWidth = [Math]::Max(1, $right - $left - 36)
    $columns = if ($contentWidth -ge 700) { 4 } elseif ($contentWidth -ge 260) { 2 } else { 1 }
    $rows = [int][Math]::Ceiling(7.0 / $columns)
    $labelY = $cardTop + 82
    $buttonTop = $labelY + ($rows * 25) + 8
    $buttonLeft = [Math]::Max($left + 18, $right - 150)
    $buttonRight = $right - 18
    $x = [int](($buttonLeft + $buttonRight) / 2)
    $y = $buttonTop + 16
    Write-Output ('SCAN_BUTTON_RECT=' + $buttonLeft + ',' + $buttonTop + ',' + $buttonRight + ',' + ($buttonTop + 32))
    if ($x -lt 1 -or $y -lt 1 -or $x -ge $rect.Right -or $y -ge $rect.Bottom) { throw 'Responsive Scan button is outside the real Explorer client area' }
    $lp = [IntPtr](($y -shl 16) -bor ($x -band 0xffff))
    if (-not [W986Storage]::PostMessage($view, 0x0202, [IntPtr]::Zero, $lp)) { throw 'Scan button PostMessage failed' }
    Write-Output ('SCAN_CLICK_POSTED=' + $x + ',' + $y)

    $deadline = (Get-Date).AddSeconds(420)
    while ((Get-Date) -lt $deadline -and -not (Test-Path $cache)) { Start-Sleep -Seconds 2 }
    if (-not (Test-Path $cache)) { throw 'UI-triggered storage scan did not produce cache within 420s' }

    $json = Get-Content -LiteralPath $cache -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Output ('SCAN_ROOT=' + $json.Root)
    Write-Output ('SCAN_FILES=' + $json.Files)
    Write-Output ('SCAN_BYTES=' + $json.ScannedBytes)
    Write-Output ('SCAN_SKIPPED_DIRS=' + $json.SkippedDirectories)
    foreach ($n in @('Apps','Videos','Pictures','Documents','Audio','System','Other')) {
        Write-Output ('CATEGORY_' + $n.ToUpperInvariant() + '=' + $json.Categories.$n)
    }
    if ([int64]$json.Files -le 0 -or [int64]$json.ScannedBytes -le 0) { throw 'Scanner cache is empty' }

    Start-Sleep -Seconds 3
    $view2 = Find-986StorageView
    Write-Output ('VIEW_ALIVE_AFTER_SCAN=' + ($view2 -ne [IntPtr]::Zero))
    if ($view2 -eq [IntPtr]::Zero) { throw 'Explorer custom storage view did not survive scan' }

    $top = [W986Storage]::GetAncestor($view2, 2)
    if ($top -ne [IntPtr]::Zero) { [W986Storage]::PostMessage($top, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null }
    Start-Sleep -Seconds 2

    Write-Output '---REMOVE---'
    & $reg -Action Remove | Format-List | Out-String | Write-Output
    $postClass = Test-Path $classRoot
    $postNs = Test-Path $nsRoot
    Write-Output ('POST_CLASS=' + $postClass)
    Write-Output ('POST_NAMESPACE=' + $postNs)
    if ($postClass -or $postNs) { throw '986 Storage unregister recovery failed' }

    Write-Output 'STORAGE_REAL_MACHINE_GATE_PASS'
}
finally {
    try {
        if ((Test-Path $classRoot) -or (Test-Path $nsRoot)) {
            & $reg -Action Remove -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}
    if ($cacheExisted -and (Test-Path $cacheBackup)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        Copy-Item -LiteralPath $cacheBackup -Destination $cache -Force
        Remove-Item -LiteralPath $cacheBackup -Force -ErrorAction SilentlyContinue
    } elseif (-not $cacheExisted -and (Test-Path $cache)) {
        Remove-Item -LiteralPath $cache -Force -ErrorAction SilentlyContinue
    }
}
