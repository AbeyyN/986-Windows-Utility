$ErrorActionPreference = 'Stop'
$work = Join-Path $env:TEMP '986-v07-rc1-validation'
$app = Get-ChildItem -LiteralPath $work -Filter '986-Windows-Utility.ps1' -File -Recurse | Select-Object -First 1
if (-not $app) { throw 'RC validation payload missing' }
$root = $app.Directory.FullName
$manager = Join-Path $root 'display\ResolutionManager.ps1'
. $manager

$stateDir = Join-Path $env:TEMP '986-v07-resolution-state'
if (Test-Path $stateDir) { Remove-Item -LiteralPath $stateDir -Recurse -Force }
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null

$displays = @(Get-986NativeDisplays)
$display = $displays | Where-Object { $_.Primary } | Select-Object -First 1
if (-not $display) { $display = $displays | Select-Object -First 1 }
if (-not $display) { throw 'No physical display detected' }

Write-Output ('ORIGINAL|' + $display.DeviceName + '|' + $display.Width + '|' + $display.Height + '|' + $display.RefreshRate + '|' + $display.BitsPerPixel + '|' + $display.Description)

$candidates = @(
    [pscustomobject]@{W=1920;H=1200;Hz=60},
    [pscustomobject]@{W=1920;H=1080;Hz=60},
    [pscustomobject]@{W=1680;H=1050;Hz=60},
    [pscustomobject]@{W=1600;H=1000;Hz=60},
    [pscustomobject]@{W=1600;H=900;Hz=60},
    [pscustomobject]@{W=1366;H=768;Hz=60},
    [pscustomobject]@{W=1280;H=800;Hz=60}
)
$chosen = $null
foreach ($c in $candidates) {
    if ($c.W -eq $display.Width -and $c.H -eq $display.Height -and $c.Hz -eq $display.RefreshRate) { continue }
    $t = Test-986DriverResolution -DeviceName $display.DeviceName -Width $c.W -Height $c.H -RefreshRate $c.Hz
    Write-Output ('CDS_TEST|' + $c.W + '|' + $c.H + '|' + $c.Hz + '|' + $t.Supported + '|' + $t.Status)
    if ($t.Supported) { $chosen = $c; break }
}
if (-not $chosen) { throw 'No different safe driver-supported resolution candidate found' }
Write-Output ('CHOSEN|' + $chosen.W + '|' + $chosen.H + '|' + $chosen.Hz)

function Get-Current986Display {
    $items = @(Get-986NativeDisplays)
    return ($items | Where-Object { $_.DeviceName -eq $display.DeviceName } | Select-Object -First 1)
}

function Assert-Mode([int]$w,[int]$h,[int]$hz,[string]$phase) {
    $cur = Get-Current986Display
    if (-not $cur) { throw "Display disappeared during $phase" }
    Write-Output ($phase + '|' + $cur.Width + '|' + $cur.Height + '|' + $cur.RefreshRate)
    if ($cur.Width -ne $w -or $cur.Height -ne $h -or $cur.RefreshRate -ne $hz) {
        throw "Mode verification failed during $phase"
    }
}

$persisted = $false
try {
    Write-Output '---15S TIMEOUT/REVERT TRIAL---'
    $trial = Invoke-986ResolutionTrial -Display $display -Width $chosen.W -Height $chosen.H -RefreshRate $chosen.Hz -StateDir $stateDir -Seconds 15
    Write-Output ('TRIAL_STATUS=' + $trial.Status)
    if ($trial.Status -ne 'REVERTED' -or $trial.Kept) { throw '15-second timeout trial did not revert' }
    Assert-Mode -w $display.Width -h $display.Height -hz $display.RefreshRate -phase 'AFTER_TIMEOUT_REVERT'
    Start-Sleep -Seconds 7
    Assert-Mode -w $display.Width -h $display.Height -hz $display.RefreshRate -phase 'AFTER_FALLBACK_WINDOW'

    Write-Output '---15S KEEP TRIAL---'
    $clicker = @"
Start-Sleep -Seconds 3
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
`$root = [Windows.Automation.AutomationElement]::RootElement
`$title = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty,'986 Custom Resolution - Keep this mode?')
`$win = `$root.FindFirst([Windows.Automation.TreeScope]::Children, `$title)
if (-not `$win) { exit 11 }
`$name = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty,'Keep')
`$btn = `$win.FindFirst([Windows.Automation.TreeScope]::Descendants, `$name)
if (-not `$btn) { exit 12 }
`$pattern = `$btn.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern)
`$pattern.Invoke()
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($clicker))
    $clickProc = Start-Process powershell.exe -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)
    $keep = Invoke-986ResolutionTrial -Display $display -Width $chosen.W -Height $chosen.H -RefreshRate $chosen.Hz -StateDir $stateDir -Seconds 15
    $clickProc.WaitForExit()
    Write-Output ('KEEP_CLICKER_EXIT=' + $clickProc.ExitCode)
    Write-Output ('KEEP_STATUS=' + $keep.Status)
    if ($clickProc.ExitCode -ne 0) { throw 'UI Automation failed to invoke Keep' }
    if ($keep.Status -ne 'KEPT' -or -not $keep.Kept) { throw 'Keep trial was not persisted' }
    $persisted = $true
    Assert-Mode -w $chosen.W -h $chosen.H -hz $chosen.Hz -phase 'AFTER_KEEP'

    Start-Sleep -Seconds 22
    Assert-Mode -w $chosen.W -h $chosen.H -hz $chosen.Hz -phase 'AFTER_KEEP_FALLBACK_WINDOW'

    Write-Output '---UNDO---'
    if (-not (Undo-986Resolution -DeviceName $display.DeviceName -StateDir $stateDir)) { throw 'Undo returned false' }
    $persisted = $false
    Start-Sleep -Seconds 2
    Assert-Mode -w $display.Width -h $display.Height -hz $display.RefreshRate -phase 'AFTER_UNDO'
    $statePath = Get-986ResolutionStatePath -StateDir $stateDir
    if (Test-Path $statePath) { throw 'Resolution snapshot remained after exact Undo' }
    Write-Output 'DISPLAY_REAL_MACHINE_GATE_PASS'
}
finally {
    try {
        $cur = Get-Current986Display
        if ($cur -and ($cur.Width -ne $display.Width -or $cur.Height -ne $display.Height -or $cur.RefreshRate -ne $display.RefreshRate)) {
            $op = if ($persisted) { 'apply-persist' } else { 'apply-temp' }
            Invoke-986ResolutionHelper -Arguments @($op,$display.DeviceName,[string]$display.Width,[string]$display.Height,[string]$display.RefreshRate) | Out-Null
            Start-Sleep -Seconds 2
        }
    } catch {}
    Remove-Item -LiteralPath $stateDir -Recurse -Force -ErrorAction SilentlyContinue
}
