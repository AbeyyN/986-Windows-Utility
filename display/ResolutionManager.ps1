Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Test-986ResolutionRequest {
    param(
        [Parameter(Mandatory=$true)][int]$Width,
        [Parameter(Mandatory=$true)][int]$Height,
        [Parameter(Mandatory=$true)][int]$RefreshRate
    )
    if ($Width -lt 640 -or $Width -gt 16384) { return $false }
    if ($Height -lt 480 -or $Height -gt 16384) { return $false }
    if ($RefreshRate -lt 24 -or $RefreshRate -gt 1000) { return $false }
    return $true
}

function Get-986ResolutionProvider {
    param([string]$AdapterName,[string]$AdapterCompatibility)
    $text = (($AdapterName + ' ' + $AdapterCompatibility).Trim()).ToLowerInvariant()
    if ($text -match 'amd|advanced micro devices|radeon') { return 'AMD-ADLX' }
    if ($text -match 'nvidia|geforce|quadro') { return 'NVIDIA-NVAPI' }
    if ($text -match 'intel|iris|uhd') { return 'Intel-IGCL' }
    return 'Windows-Driver'
}

function Get-986DisplayAdapters {
    $items = @()
    try {
        foreach ($gpu in @(Get-CimInstance Win32_VideoController -ErrorAction Stop)) {
            $provider = Get-986ResolutionProvider -AdapterName ([string]$gpu.Name) -AdapterCompatibility ([string]$gpu.AdapterCompatibility)
            $items += [pscustomobject]@{
                Name = [string]$gpu.Name
                Vendor = [string]$gpu.AdapterCompatibility
                DriverVersion = [string]$gpu.DriverVersion
                CurrentWidth = [int]$gpu.CurrentHorizontalResolution
                CurrentHeight = [int]$gpu.CurrentVerticalResolution
                CurrentRefreshRate = [int]$gpu.CurrentRefreshRate
                Provider = $provider
            }
        }
    } catch { }
    return @($items)
}

function Get-986ResolutionHelperPath {
    $path = Join-Path $PSScriptRoot '986ResolutionHelper.exe'
    if (Test-Path $path) { return $path }
    return $null
}

function Invoke-986ResolutionHelper {
    param([Parameter(Mandatory=$true)][string[]]$Arguments)
    $helper = Get-986ResolutionHelperPath
    if (-not $helper) { throw '986ResolutionHelper.exe is not installed.' }
    $output = @(& $helper @Arguments 2>&1)
    $code = $LASTEXITCODE
    [pscustomobject]@{ ExitCode=$code; Output=@($output | ForEach-Object { [string]$_ }) }
}

function Get-986NativeDisplays {
    $helper = Get-986ResolutionHelperPath
    if (-not $helper) { return @() }
    $result = Invoke-986ResolutionHelper -Arguments @('probe')
    $items = @()
    foreach ($line in $result.Output) {
        if ($line -notlike 'DEVICE|*') { continue }
        $p = $line -split '\|', 9
        if ($p.Count -lt 8) { continue }
        $items += [pscustomobject]@{
            DeviceName=$p[1]; Width=[int]$p[2]; Height=[int]$p[3]
            RefreshRate=[int]$p[4]; BitsPerPixel=[int]$p[5]
            Primary=($p[6] -eq '1'); Description=$p[7]
        }
    }
    return @($items)
}

function Get-986ResolutionCapability {
    param([Parameter(Mandatory=$true)]$Adapter)
    $provider = [string]$Adapter.Provider
    $helperReady = [bool](Get-986ResolutionHelperPath)
    [pscustomobject]@{
        Provider = $provider
        ExistingModesSupported = $helperReady
        TrueCustomCandidate = $helperReady
        TrueCustomReady = $helperReady
        Status = if ($helperReady) { 'DRIVER_TRIAL_READY' } else { 'HELPER_REQUIRED' }
        VendorFallback = $provider -in @('AMD-ADLX','NVIDIA-NVAPI','Intel-IGCL')
        Safety = 'TEST_CONFIRM_AUTO_REVERT'
    }
}

function New-986ResolutionPlan {
    param(
        [Parameter(Mandatory=$true)]$Adapter,
        [Parameter(Mandatory=$true)][int]$Width,
        [Parameter(Mandatory=$true)][int]$Height,
        [Parameter(Mandatory=$true)][int]$RefreshRate,
        [switch]$ExistingMode
    )
    if (-not (Test-986ResolutionRequest -Width $Width -Height $Height -RefreshRate $RefreshRate)) {
        throw 'Resolution request is outside 986 safety bounds.'
    }
    $cap = Get-986ResolutionCapability -Adapter $Adapter
    [pscustomobject]@{
        Width=$Width; Height=$Height; RefreshRate=$RefreshRate
        Provider=$cap.Provider
        ModeKind=if ($ExistingMode) { 'Existing' } else { 'CustomDriverTrial' }
        CanApply=[bool]$cap.TrueCustomReady
        RequiresTrial=$true
        RequiresConfirmation=$true
        AutoRevertRequired=$true
        Reason=if ($cap.TrueCustomReady) { 'Driver mode is tested with CDS_TEST before temporary apply.' } else { 'Resolution helper is not installed.' }
    }
}

function Test-986DriverResolution {
    param([string]$DeviceName,[int]$Width,[int]$Height,[int]$RefreshRate)
    if (-not (Test-986ResolutionRequest -Width $Width -Height $Height -RefreshRate $RefreshRate)) {
        return [pscustomobject]@{ Supported=$false; Status='OUT_OF_BOUNDS'; Raw=@() }
    }
    $r = Invoke-986ResolutionHelper -Arguments @('test',$DeviceName,[string]$Width,[string]$Height,[string]$RefreshRate)
    $status = ($r.Output | Where-Object { $_ -like 'RESULT|*' } | Select-Object -Last 1)
    [pscustomobject]@{ Supported=($r.ExitCode -eq 0); Status=[string]$status; Raw=$r.Output }
}

function Get-986ResolutionStatePath {
    param([string]$StateDir)
    if (-not $StateDir) { $StateDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'state' }
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    Join-Path $StateDir 'resolution-state.json'
}

function Save-986ResolutionOriginal {
    param([Parameter(Mandatory=$true)]$Display,[string]$StateDir)
    $path = Get-986ResolutionStatePath -StateDir $StateDir
    $state = @{}
    if (Test-Path $path) {
        try {
            $obj = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $obj.PSObject.Properties) { $state[$p.Name] = $p.Value }
        } catch { }
    }
    if (-not $state.ContainsKey([string]$Display.DeviceName)) {
        $state[[string]$Display.DeviceName] = [pscustomobject]@{
            DeviceName=[string]$Display.DeviceName; Width=[int]$Display.Width; Height=[int]$Display.Height
            RefreshRate=[int]$Display.RefreshRate; BitsPerPixel=[int]$Display.BitsPerPixel
            Captured=(Get-Date).ToString('o')
        }
        $state | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
    }
    $path
}

function Start-986FallbackReverter {
    param([Parameter(Mandatory=$true)]$Display,[Parameter(Mandatory=$true)][string]$TokenPath,[int]$Seconds=20)
    $helper = Get-986ResolutionHelperPath
    $device = [string]$Display.DeviceName
    $script = @"
Start-Sleep -Seconds $Seconds
if (-not (Test-Path '$($TokenPath.Replace("'","''"))')) {
    & '$($helper.Replace("'","''"))' apply-temp '$($device.Replace("'","''"))' $($Display.Width) $($Display.Height) $($Display.RefreshRate) | Out-Null
}
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) | Out-Null
}

function Start-986TrialTokenCleanup {
    param([Parameter(Mandatory=$true)][string]$TokenPath,[int]$Seconds=35)
    $script = @"
Start-Sleep -Seconds $Seconds
Remove-Item -LiteralPath '$($TokenPath.Replace("'","''"))' -Force -ErrorAction SilentlyContinue
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) | Out-Null
}

function Invoke-986ResolutionTrial {
    param(
        [Parameter(Mandatory=$true)]$Display,[int]$Width,[int]$Height,[int]$RefreshRate,
        [string]$StateDir,[int]$Seconds=15
    )
    $test = Test-986DriverResolution -DeviceName $Display.DeviceName -Width $Width -Height $Height -RefreshRate $RefreshRate
    if (-not $test.Supported) { return [pscustomobject]@{ Kept=$false; Status='UNSUPPORTED'; Detail=$test.Status } }
    Save-986ResolutionOriginal -Display $Display -StateDir $StateDir | Out-Null
    $token = Join-Path $env:TEMP ('986-resolution-' + [guid]::NewGuid().ToString('N') + '.keep')
    Start-986FallbackReverter -Display $Display -TokenPath $token -Seconds ($Seconds + 5)
    $apply = Invoke-986ResolutionHelper -Arguments @('apply-temp',$Display.DeviceName,[string]$Width,[string]$Height,[string]$RefreshRate)
    if ($apply.ExitCode -ne 0) { return [pscustomobject]@{ Kept=$false; Status='APPLY_FAILED'; Detail=$apply.Output } }

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName PresentationCore
    $brush = New-Object Windows.Media.BrushConverter
    $window = New-Object Windows.Window
    $window.Title = '986 Custom Resolution - Keep this mode?'
    $window.Width = 470; $window.Height = 220; $window.WindowStartupLocation = 'CenterScreen'; $window.Topmost = $true
    $window.Background = $brush.ConvertFromString('#050505'); $window.Foreground = $brush.ConvertFromString('#F5F1EE')
    $grid = New-Object Windows.Controls.Grid
    $text = New-Object Windows.Controls.TextBlock; $text.Margin='22'; $text.FontSize=18; $text.TextWrapping='Wrap'; $text.Foreground=$brush.ConvertFromString('#F5F1EE')
    $keep = New-Object Windows.Controls.Button; $keep.Content='Keep'; $keep.Width=120; $keep.Height=36; $keep.HorizontalAlignment='Left'; $keep.Margin='55,125,0,0'; $keep.Background=$brush.ConvertFromString('#C85A00'); $keep.Foreground=$brush.ConvertFromString('#F5F1EE'); $keep.BorderBrush=$brush.ConvertFromString('#FF8A00')
    $revert = New-Object Windows.Controls.Button; $revert.Content='Revert'; $revert.Width=120; $revert.Height=36; $revert.HorizontalAlignment='Right'; $revert.Margin='0,125,55,0'; $revert.Background=$brush.ConvertFromString('#7A414B'); $revert.Foreground=$brush.ConvertFromString('#F5F1EE'); $revert.BorderBrush=$brush.ConvertFromString('#B76E79')
    $grid.Children.Add($text) | Out-Null; $grid.Children.Add($keep) | Out-Null; $grid.Children.Add($revert) | Out-Null; $window.Content=$grid
    $trialState = [pscustomobject]@{ Choice='timeout'; Remaining=[int]$Seconds }
    $timer = New-Object Windows.Threading.DispatcherTimer; $timer.Interval=[TimeSpan]::FromSeconds(1)
    $update = { $text.Text = "Testing $Width x $Height @ $RefreshRate Hz.`nKeep this mode? Auto-revert in $($trialState.Remaining) seconds." }
    & $update
    $timer.Add_Tick({
        $trialState.Remaining = [int]$trialState.Remaining - 1
        & $update
        if ($trialState.Remaining -le 0) { $timer.Stop(); $window.Close() }
    })
    $keep.Add_Click({ $trialState.Choice='keep'; $timer.Stop(); $window.Close() })
    $revert.Add_Click({ $trialState.Choice='revert'; $timer.Stop(); $window.Close() })
    $timer.Start(); $window.ShowDialog() | Out-Null

    if ($trialState.Choice -eq 'keep') {
        New-Item -ItemType File -Path $token -Force | Out-Null
        $persist = Invoke-986ResolutionHelper -Arguments @('apply-persist',$Display.DeviceName,[string]$Width,[string]$Height,[string]$RefreshRate)
        Start-986TrialTokenCleanup -TokenPath $token -Seconds ($Seconds + 20)
        return [pscustomobject]@{ Kept=($persist.ExitCode -eq 0); Status=if($persist.ExitCode -eq 0){'KEPT'}else{'PERSIST_FAILED'}; Detail=$persist.Output }
    }
    New-Item -ItemType File -Path $token -Force | Out-Null
    Invoke-986ResolutionHelper -Arguments @('apply-temp',$Display.DeviceName,[string]$Display.Width,[string]$Display.Height,[string]$Display.RefreshRate) | Out-Null
    Start-986TrialTokenCleanup -TokenPath $token -Seconds ($Seconds + 20)
    [pscustomobject]@{ Kept=$false; Status='REVERTED'; Detail=@() }
}

function Undo-986Resolution {
    param([string]$DeviceName,[string]$StateDir)
    $path = Get-986ResolutionStatePath -StateDir $StateDir
    if (-not (Test-Path $path)) { throw 'No 986 resolution snapshot exists.' }
    $obj = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $entry = $obj.PSObject.Properties[$DeviceName]
    if (-not $entry) { throw "No 986 resolution snapshot exists for $DeviceName." }
    $s = $entry.Value
    $r = Invoke-986ResolutionHelper -Arguments @('apply-persist',[string]$s.DeviceName,[string]$s.Width,[string]$s.Height,[string]$s.RefreshRate)
    if ($r.ExitCode -ne 0) { throw ('Resolution Undo failed: ' + ($r.Output -join ' ')) }
    $remaining = @{}
    foreach ($p in $obj.PSObject.Properties) { if ($p.Name -ne $DeviceName) { $remaining[$p.Name]=$p.Value } }
    if ($remaining.Count) { $remaining | ConvertTo-Json -Depth 5 | Set-Content $path -Encoding UTF8 } else { Remove-Item $path -Force }
    $true
}
