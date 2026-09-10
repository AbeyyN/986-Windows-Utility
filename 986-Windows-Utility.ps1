#Requires -Version 5.1
param([switch]$NoElevation,[switch]$AuditOnly,[switch]$AuditJson,[switch]$DoctorOnly,[switch]$DoctorJson,[switch]$ProfileList)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$AppName = '986 Windows Utility'
$Version = '0.5.0-alpha.1'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$StateDir = Join-Path $Root 'state'
$StateFile = Join-Path $StateDir 'original-state.json'
$LogFile = Join-Path $StateDir '986-windows-utility.log'
New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
$script:LogBox = $null

function Test-IsAdministrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator) -and -not $NoElevation -and -not $AuditOnly -and -not $DoctorOnly -and -not $ProfileList) {
    $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -NoElevation"
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argLine
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName Microsoft.VisualBasic

$Tweaks = @(
    [pscustomobject]@{ Id='show-ext'; Category='Explorer'; Name='Show file extensions'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Value='HideFileExt'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='show-hidden'; Category='Explorer'; Name='Show hidden files'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Value='Hidden'; Type='DWord'; Target=1; Risk='LOW'; Balanced=$false; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='open-thispc'; Category='Explorer'; Name='Open File Explorer to This PC'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Value='LaunchTo'; Type='DWord'; Target=1; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='hide-recent'; Category='Explorer'; Name='Hide recent files in Quick Access'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; Value='ShowRecent'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$false; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='hide-frequent'; Category='Explorer'; Name='Hide frequent folders in Quick Access'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; Value='ShowFrequent'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$false; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='disable-adid'; Category='Privacy'; Name='Disable advertising ID'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Value='Enabled'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='disable-tailored'; Category='Privacy'; Name='Disable tailored experiences'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Value='TailoredExperiencesWithDiagnosticDataEnabled'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='disable-feedback'; Category='Privacy'; Name='Disable Windows feedback prompts'; Path='HKCU:\Software\Microsoft\Siuf\Rules'; Value='NumberOfSIUFInPeriod'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }

    [pscustomobject]@{ Id='disable-tips'; Category='Privacy'; Name='Disable Windows tips and suggestions'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Value='SoftLandingEnabled'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='disable-silentapps'; Category='Privacy'; Name='Disable silent suggested-app installs'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Value='SilentInstalledAppsEnabled'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='disable-pane-suggestions'; Category='Privacy'; Name='Disable Start/System pane suggestions'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Value='SystemPaneSuggestionsEnabled'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='disable-subscribed'; Category='Privacy'; Name='Disable subscribed suggestion content'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Value='SubscribedContent-338389Enabled'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='disable-lock-spotlight'; Category='Privacy'; Name='Disable rotating lock-screen Spotlight'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Value='RotatingLockScreenEnabled'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$false; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='startup-delay'; Category='Performance'; Name='Disable Explorer startup delay'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'; Value='StartupDelayInMSec'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='disable-game-capture'; Category='Gaming'; Name='Disable Xbox/Game DVR capture'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Value='AppCaptureEnabled'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$false; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='taskbar-end-task'; Category='Taskbar'; Name='Enable taskbar End task'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'; Value='TaskbarEndTask'; Type='DWord'; Target=1; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='hide-task-view'; Category='Taskbar'; Name='Hide Task View button'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Value='ShowTaskViewButton'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='hide-widgets'; Category='Taskbar'; Name='Hide Widgets button'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Value='TaskbarDa'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='hide-taskbar-search'; Category='Taskbar'; Name='Hide taskbar Search'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Value='SearchboxTaskbarMode'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='show-clock-seconds'; Category='Taskbar'; Name='Show seconds in system tray clock'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Value='ShowSecondsInSystemClock'; Type='DWord'; Target=1; Risk='LOW'; Balanced=$false; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }

    [pscustomobject]@{ Id='start-more-pins'; Category='Start'; Name='Use more pins in Start'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Value='Start_Layout'; Type='DWord'; Target=1; Risk='LOW'; Balanced=$false; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='disable-start-recommendations'; Category='Start'; Name='Disable Start recommendations'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Value='Start_IrisRecommendations'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$true; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='enable-game-mode'; Category='Gaming'; Name='Enable Game Mode'; Path='HKCU:\Software\Microsoft\GameBar'; Value='AutoGameModeEnabled'; Type='DWord'; Target=1; Risk='LOW'; Balanced=$false; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='disable-transparency'; Category='Personalization'; Name='Disable transparency effects'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Value='EnableTransparency'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$false; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='dark-apps'; Category='Personalization'; Name='Use dark mode for apps'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Value='AppsUseLightTheme'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$false; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
    [pscustomobject]@{ Id='dark-system'; Category='Personalization'; Name='Use dark mode for Windows'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Value='SystemUsesLightTheme'; Type='DWord'; Target=0; Risk='LOW'; Balanced=$false; UserEditable=$true; Enforcement='None'; ApplyAllowed=$true; LegacyPolicy=$false }
)

$LegacyTweaks = @(
    [pscustomobject]@{ Id='disable-activity-feed'; Category='Legacy'; Name='Legacy policy: Disable Windows Activity Feed (undo only)'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Value='EnableActivityFeed'; Type='DWord'; Target=0; Risk='LEGACY'; Balanced=$false; UserEditable=$false; Enforcement='LegacyPolicy'; ApplyAllowed=$false; LegacyPolicy=$true }
    [pscustomobject]@{ Id='disable-publish-activity'; Category='Legacy'; Name='Legacy policy: Disable publishing user activities (undo only)'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Value='PublishUserActivities'; Type='DWord'; Target=0; Risk='LEGACY'; Balanced=$false; UserEditable=$false; Enforcement='LegacyPolicy'; ApplyAllowed=$false; LegacyPolicy=$true }
    [pscustomobject]@{ Id='disable-upload-activity'; Category='Legacy'; Name='Legacy policy: Disable uploading user activities (undo only)'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Value='UploadUserActivities'; Type='DWord'; Target=0; Risk='LEGACY'; Balanced=$false; UserEditable=$false; Enforcement='LegacyPolicy'; ApplyAllowed=$false; LegacyPolicy=$true }
    [pscustomobject]@{ Id='disable-consumer'; Category='Legacy'; Name='Legacy policy: Disable Microsoft consumer experiences (undo only)'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Value='DisableWindowsConsumerFeatures'; Type='DWord'; Target=1; Risk='LEGACY'; Balanced=$false; UserEditable=$false; Enforcement='LegacyPolicy'; ApplyAllowed=$false; LegacyPolicy=$true }
)

function Write-AppLog([string]$Message) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    if ($script:LogBox) {
        $script:LogBox.AppendText($line + [Environment]::NewLine)
        $script:LogBox.ScrollToEnd()
    }
}

function Load-SnapshotState {
    $state = @{}
    if (Test-Path $StateFile) {
        try {
            $obj = Get-Content -Path $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($obj) {
                foreach ($p in $obj.PSObject.Properties) { $state[$p.Name] = $p.Value }
            }
        } catch { Write-AppLog "WARN snapshot file unreadable: $($_.Exception.Message)" }
    }
    return $state
}

function Save-SnapshotState([hashtable]$State) {
    $obj = New-Object psobject
    foreach ($key in $State.Keys) {
        $obj | Add-Member -MemberType NoteProperty -Name $key -Value $State[$key]
    }
    $obj | ConvertTo-Json -Depth 8 | Set-Content -Path $StateFile -Encoding UTF8
}

function Get-RegistryState($Tweak) {
    if (-not (Test-Path $Tweak.Path)) {
        return [pscustomobject]@{ Exists=$false; Value=$null; Kind=$null }
    }
    try {
        $key = Get-Item -Path $Tweak.Path
        if ($key.GetValueNames() -notcontains $Tweak.Value) {
            return [pscustomobject]@{ Exists=$false; Value=$null; Kind=$null }
        }
        $value = $key.GetValue($Tweak.Value, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $kind = $key.GetValueKind($Tweak.Value).ToString()
        return [pscustomobject]@{ Exists=$true; Value=$value; Kind=$kind }
    } catch {
        return [pscustomobject]@{ Exists=$false; Value=$null; Kind=$null; Error=$_.Exception.Message }
    }
}

function Test-TweakActive($Tweak) {
    $current = Get-RegistryState $Tweak
    return ($current.Exists -and ([string]$current.Value -eq [string]$Tweak.Target))
}

function Capture-OriginalState($Tweak, [hashtable]$State) {
    if ($State.ContainsKey($Tweak.Id)) { return }
    $current = Get-RegistryState $Tweak
    $State[$Tweak.Id] = [pscustomobject]@{
        Captured=(Get-Date).ToString('o'); Path=$Tweak.Path; ValueName=$Tweak.Value
        Exists=$current.Exists; Value=$current.Value; Kind=$current.Kind
    }
    Save-SnapshotState $State
    Write-AppLog "SNAPSHOT $($Tweak.Id) captured"
}

function Apply-Tweak($Tweak, [hashtable]$State) {
    if (-not [bool]$Tweak.ApplyAllowed) {
        Write-AppLog "APPLY BLOCKED $($Tweak.Id): legacy/policy tweak is undo-only"
        return $false
    }
    try {
        Capture-OriginalState $Tweak $State
        New-Item -Path $Tweak.Path -Force | Out-Null
        New-ItemProperty -Path $Tweak.Path -Name $Tweak.Value -PropertyType $Tweak.Type -Value $Tweak.Target -Force | Out-Null
        if (-not (Test-TweakActive $Tweak)) { throw 'verification failed after apply' }
        Write-AppLog "APPLY PASS  $($Tweak.Id)"
        return $true
    } catch {
        Write-AppLog "APPLY FAIL  $($Tweak.Id): $($_.Exception.Message)"
        return $false
    }
}

function Undo-Tweak($Tweak, [hashtable]$State) {
    if (-not $State.ContainsKey($Tweak.Id)) {
        Write-AppLog "UNDO BLOCKED $($Tweak.Id): no original snapshot"
        return $false
    }
    try {
        $original = $State[$Tweak.Id]
        if ([bool]$original.Exists) {
            New-Item -Path $Tweak.Path -Force | Out-Null
            New-ItemProperty -Path $Tweak.Path -Name $Tweak.Value -PropertyType $original.Kind -Value $original.Value -Force | Out-Null
        } elseif (Test-Path $Tweak.Path) {
            Remove-ItemProperty -Path $Tweak.Path -Name $Tweak.Value -ErrorAction SilentlyContinue
        }
        $now = Get-RegistryState $Tweak
        $verified = if ([bool]$original.Exists) {
            $now.Exists -and ([string]$now.Value -eq [string]$original.Value)
        } else { -not $now.Exists }
        if (-not $verified) { throw 'verification failed after undo' }
        $State.Remove($Tweak.Id)
        Save-SnapshotState $State
        Write-AppLog "UNDO PASS   $($Tweak.Id)"
        return $true
    } catch {
        Write-AppLog "UNDO FAIL   $($Tweak.Id): $($_.Exception.Message)"
        return $false
    }
}

function New-RestorePoint {
    try {
        Checkpoint-Computer -Description "986 Windows Utility v$Version" -RestorePointType MODIFY_SETTINGS
        Write-AppLog 'RESTORE POINT created'
        return $true
    } catch {
        Write-AppLog "RESTORE POINT unavailable: $($_.Exception.Message)"
        return $false
    }
}

$AuditModule = Join-Path $Root 'modules\TweakIntelligence.ps1'
if (-not (Test-Path $AuditModule)) { throw 'Tweak Intelligence module is missing.' }
. $AuditModule

$DoctorModule = Join-Path $Root 'modules\Doctor.ps1'
if (-not (Test-Path $DoctorModule)) { throw '986 Doctor module is missing.' }
. $DoctorModule

$ProfilesModule = Join-Path $Root 'modules\Profiles.ps1'
if (-not (Test-Path $ProfilesModule)) { throw '986 Profiles module is missing.' }
. $ProfilesModule

if ($ProfileList) {
    Get-986BuiltInProfiles | Select-Object Name,Description,@{N='Tweaks';E={@($_.TweakIds).Count}} | Format-Table -AutoSize
    exit 0
}

if ($AuditOnly) {
    $report = Get-TweakIntelligenceReport
    $report.Items | Format-Table Area,Name,Current,Classification -AutoSize
    Write-Host "Summary: 986=$($report.Summary.'986 Managed') WinUtil-like=$($report.Summary.'WinUtil-like') Windows-like=$($report.Summary.'Windows-like') Custom=$($report.Summary.Custom) Unknown=$($report.Summary.Unknown)"
    if ($AuditJson) { Write-Host "Exported: $(Export-TweakAuditReport $report)" }
    exit 0
}

if ($DoctorOnly) {
    $report = Get-DoctorReport
    $report.Checks | Format-Table Area,Name,Value,Status -AutoSize
    Write-Host "Doctor: Overall=$($report.Overall) Attention=$($report.Attention) Unknown=$($report.Unknown)"
    if ($DoctorJson) { Write-Host "Exported: $(Export-DoctorReport $report)" }
    exit 0
}

[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="986 Windows Utility v$Version"
        Height="780" Width="1120" MinHeight="650" MinWidth="900"
        Background="#0B1220" Foreground="#E5E7EB" WindowStartupLocation="CenterScreen">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Margin" Value="0,0,8,0"/><Setter Property="Padding" Value="12,7"/>
      <Setter Property="Background" Value="#1F2937"/><Setter Property="Foreground" Value="#F9FAFB"/>
      <Setter Property="BorderBrush" Value="#374151"/><Setter Property="BorderThickness" Value="1"/>
    </Style>
    <Style TargetType="CheckBox"><Setter Property="Foreground" Value="#F9FAFB"/></Style>
  </Window.Resources>
  <Grid Margin="18">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/>
      <RowDefinition Height="220"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0" Margin="0,0,0,14">
      <TextBlock Text="986 WINDOWS UTILITY" FontSize="28" FontWeight="Bold" Foreground="#F59E0B"/>
      <TextBlock Text="State-aware reversible Windows tuning | AbeyyTechXy" Foreground="#9CA3AF" Margin="0,4,0,0"/>
    </StackPanel>
    <Border Grid.Row="1" Background="#111827" BorderBrush="#273244" BorderThickness="1" Padding="10" Margin="0,0,0,10">
      <WrapPanel>
        <Button x:Name="BtnAudit" Content="Audit"/>
        <Button x:Name="BtnIntelligence" Content="Tweak Intelligence"/>
        <Button x:Name="BtnExportAudit" Content="Export Audit"/>
        <Button x:Name="BtnDoctor" Content="986 Doctor"/>
        <Button x:Name="BtnExportDoctor" Content="Export Doctor"/>
        <ComboBox x:Name="ProfilePicker" Width="180" Margin="0,0,8,0" Padding="8,5" Background="#1F2937" Foreground="#F9FAFB"/>
        <Button x:Name="BtnProfileSelect" Content="Select Profile"/>
        <Button x:Name="BtnProfileSave" Content="Save Custom"/>
        <Button x:Name="BtnProfileDelete" Content="Delete Custom"/>
        <Button x:Name="BtnAll" Content="Select All"/>
        <Button x:Name="BtnClear" Content="Clear"/>
        <Button x:Name="BtnRestorePoint" Content="Create Restore Point"/>
        <Button x:Name="BtnOpenState" Content="Open State Folder"/>
      </WrapPanel>
    </Border>
    <Border Grid.Row="2" Background="#0F172A" BorderBrush="#273244" BorderThickness="1" Padding="8" Margin="0,0,0,10">
      <ScrollViewer VerticalScrollBarVisibility="Auto">
        <StackPanel x:Name="TweakPanel"/>
      </ScrollViewer>
    </Border>
    <Border Grid.Row="3" Background="#050A12" BorderBrush="#273244" BorderThickness="1" Padding="8" Margin="0,0,0,10">
      <Grid>
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
        <TextBlock Text="Activity log" FontWeight="SemiBold" Margin="2,0,0,6"/>
        <TextBox x:Name="LogBox" Grid.Row="1" Background="#050A12" Foreground="#D1D5DB" BorderThickness="0"
                 IsReadOnly="True" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="12"/>
      </Grid>
    </Border>
    <Grid Grid.Row="4">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <TextBlock Text="Preferences are applied once only. 986 never locks or auto-reapplies them. Undo requires an original snapshot." Foreground="#9CA3AF" VerticalAlignment="Center"/>
      <StackPanel Grid.Column="1" Orientation="Horizontal">
        <Button x:Name="BtnUndo" Content="Undo Selected" Background="#3F1D2E"/>
        <Button x:Name="BtnApply" Content="Apply Selected" Background="#92400E"/>
      </StackPanel>
    </Grid>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $Xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)
$script:LogBox = $Window.FindName('LogBox')
$TweakPanel = $Window.FindName('TweakPanel')
$BtnAudit = $Window.FindName('BtnAudit')
$BtnIntelligence = $Window.FindName('BtnIntelligence')
$BtnExportAudit = $Window.FindName('BtnExportAudit')
$BtnDoctor = $Window.FindName('BtnDoctor')
$BtnExportDoctor = $Window.FindName('BtnExportDoctor')
$ProfilePicker = $Window.FindName('ProfilePicker')
$BtnProfileSelect = $Window.FindName('BtnProfileSelect')
$BtnProfileSave = $Window.FindName('BtnProfileSave')
$BtnProfileDelete = $Window.FindName('BtnProfileDelete')
$BtnAll = $Window.FindName('BtnAll')
$BtnClear = $Window.FindName('BtnClear')
$BtnRestorePoint = $Window.FindName('BtnRestorePoint')
$BtnOpenState = $Window.FindName('BtnOpenState')
$BtnUndo = $Window.FindName('BtnUndo')
$BtnApply = $Window.FindName('BtnApply')
$script:Rows = @{}
$script:DisplayedTweaks = @($Tweaks)
$startupState = Load-SnapshotState
foreach ($legacy in $LegacyTweaks) {
    if ($startupState.ContainsKey($legacy.Id)) { $script:DisplayedTweaks += $legacy }
}

function New-TweakRow($Tweak) {
    $border = New-Object Windows.Controls.Border
    $border.BorderBrush = '#1F2937'; $border.BorderThickness = [Windows.Thickness]::new(0,0,0,1); $border.Padding = [Windows.Thickness]::new(6)
    $grid = New-Object Windows.Controls.Grid
    foreach ($w in @('42','120','*','80','130')) {
        $c = New-Object Windows.Controls.ColumnDefinition; $c.Width = $w; $grid.ColumnDefinitions.Add($c)
    }
    $check = New-Object Windows.Controls.CheckBox; $check.VerticalAlignment = 'Center'
    [Windows.Controls.Grid]::SetColumn($check,0); $grid.Children.Add($check) | Out-Null
    $cat = New-Object Windows.Controls.TextBlock; $cat.Text = $Tweak.Category; $cat.Foreground = '#93C5FD'; $cat.VerticalAlignment = 'Center'
    [Windows.Controls.Grid]::SetColumn($cat,1); $grid.Children.Add($cat) | Out-Null
    $name = New-Object Windows.Controls.TextBlock; $name.Text = $Tweak.Name; $name.VerticalAlignment = 'Center'
    [Windows.Controls.Grid]::SetColumn($name,2); $grid.Children.Add($name) | Out-Null
    $risk = New-Object Windows.Controls.TextBlock; $risk.Text = $Tweak.Risk; $risk.Foreground = '#86EFAC'; $risk.VerticalAlignment = 'Center'
    [Windows.Controls.Grid]::SetColumn($risk,3); $grid.Children.Add($risk) | Out-Null
    $status = New-Object Windows.Controls.TextBlock; $status.Text = 'UNKNOWN'; $status.FontWeight = 'SemiBold'; $status.VerticalAlignment = 'Center'
    [Windows.Controls.Grid]::SetColumn($status,4); $grid.Children.Add($status) | Out-Null
    $border.Child = $grid; $TweakPanel.Children.Add($border) | Out-Null
    $script:Rows[$Tweak.Id] = [pscustomobject]@{ Tweak=$Tweak; Check=$check; Status=$status }
}

foreach ($t in $script:DisplayedTweaks) { New-TweakRow $t }

function Refresh-TweakStatus {
    $state = Load-SnapshotState
    foreach ($t in $script:DisplayedTweaks) {
        $row = $script:Rows[$t.Id]
        if ([bool]$t.LegacyPolicy) {
            $row.Status.Text = 'LEGACY | UNDO'
            $row.Status.Foreground = '#FCA5A5'
            continue
        }
        if (Test-TweakActive $t) {
            $row.Status.Text = if ($state.ContainsKey($t.Id)) { 'ACTIVE | UNDO' } else { 'ACTIVE' }
            $row.Status.Foreground = '#FBBF24'
        } else {
            $row.Status.Text = if ($state.ContainsKey($t.Id)) { 'CHANGED | UNDO' } else { 'NOT ACTIVE' }
            $row.Status.Foreground = '#9CA3AF'
        }
    }
}

function Get-SelectedTweaks {
    return @($script:DisplayedTweaks | Where-Object { $script:Rows[$_.Id].Check.IsChecked -eq $true })
}

function Set-Selection([string]$Mode) {
    foreach ($t in $script:DisplayedTweaks) {
        switch ($Mode) {
            'All'   { $script:Rows[$t.Id].Check.IsChecked = [bool]$t.ApplyAllowed }
            'Clear' { $script:Rows[$t.Id].Check.IsChecked = $false }
        }
    }
}

function Refresh-ProfilePicker([string]$Preferred='986 Balanced') {
    $ProfilePicker.Items.Clear()
    foreach ($name in @(Get-986ProfileNames)) { [void]$ProfilePicker.Items.Add($name) }
    if ($ProfilePicker.Items.Contains($Preferred)) {
        $ProfilePicker.SelectedItem = $Preferred
    } elseif ($ProfilePicker.Items.Count -gt 0) {
        $ProfilePicker.SelectedIndex = 0
    }
}

function Select-986Profile([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return }
    $requested = @(Get-986ProfileTweakIds $Name)
    $known = @($Tweaks | ForEach-Object { $_.Id })
    $valid = @($requested | Where-Object { $known -contains $_ })
    $missing = @($requested | Where-Object { $known -notcontains $_ })
    foreach ($t in $Tweaks) { $script:Rows[$t.Id].Check.IsChecked = ($valid -contains $t.Id) }
    Write-AppLog "PROFILE SELECT '$Name' | selected=$($valid.Count) missing=$($missing.Count)"
    if ($missing.Count) { Write-AppLog "PROFILE WARN '$Name' unknown IDs: $($missing -join ', ')" }
}

$BtnAudit.Add_Click({
    Refresh-TweakStatus
    $active = @($Tweaks | Where-Object { Test-TweakActive $_ }).Count
    Write-AppLog "AUDIT complete: $active / $($Tweaks.Count) target states active"
})
$BtnIntelligence.Add_Click({ Show-TweakIntelligenceWindow })
$BtnExportAudit.Add_Click({ $r=Get-TweakIntelligenceReport; $p=Export-TweakAuditReport $r; [Windows.MessageBox]::Show("Saved read-only audit report:`n$p",'986 Tweak Intelligence') | Out-Null })
$BtnDoctor.Add_Click({ Show-DoctorWindow })
$BtnExportDoctor.Add_Click({ $r=Get-DoctorReport; $p=Export-DoctorReport $r; [Windows.MessageBox]::Show("Saved Doctor report:`n$p",'986 Doctor') | Out-Null })
$BtnProfileSelect.Add_Click({
    try { Select-986Profile ([string]$ProfilePicker.SelectedItem) }
    catch { [Windows.MessageBox]::Show($_.Exception.Message,'986 Profiles') | Out-Null }
})
$BtnProfileSave.Add_Click({
    $selected = @(Get-SelectedTweaks)
    if ($selected.Count -eq 0) { [Windows.MessageBox]::Show('Select at least one tweak before saving a custom profile.','986 Profiles') | Out-Null; return }
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Name this custom profile:','986 Profiles','My Profile')
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    try {
        [void](Save-986CustomProfile $name @($selected | ForEach-Object { $_.Id }))
        Refresh-ProfilePicker $name.Trim()
        [Windows.MessageBox]::Show("Saved custom profile: $($name.Trim())",'986 Profiles') | Out-Null
    } catch { [Windows.MessageBox]::Show($_.Exception.Message,'986 Profiles') | Out-Null }
})
$BtnProfileDelete.Add_Click({
    $name = [string]$ProfilePicker.SelectedItem
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    if (Test-986BuiltInProfileName $name) { [Windows.MessageBox]::Show('Built-in profiles cannot be deleted.','986 Profiles') | Out-Null; return }
    $answer = [Windows.MessageBox]::Show("Delete custom profile '$name'?",'986 Profiles',[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Warning)
    if ($answer -ne [Windows.MessageBoxResult]::Yes) { return }
    if (Remove-986CustomProfile $name) { Refresh-ProfilePicker '986 Balanced'; Select-986Profile '986 Balanced' }
})
$BtnAll.Add_Click({ Set-Selection 'All' })
$BtnClear.Add_Click({ Set-Selection 'Clear' })
$BtnRestorePoint.Add_Click({ [void](New-RestorePoint) })
$BtnOpenState.Add_Click({ Start-Process explorer.exe -ArgumentList "`"$StateDir`"" })

$BtnApply.Add_Click({
    $selected = @(Get-SelectedTweaks)
    if ($selected.Count -eq 0) { Write-AppLog 'APPLY skipped: nothing selected'; return }
    $state = Load-SnapshotState
    $pass = 0
    foreach ($t in $selected) { if (Apply-Tweak $t $state) { $pass++ } }
    Refresh-TweakStatus
    Write-AppLog "APPLY finished: $pass / $($selected.Count) verified"
})

$BtnUndo.Add_Click({
    $selected = @(Get-SelectedTweaks)
    if ($selected.Count -eq 0) { Write-AppLog 'UNDO skipped: nothing selected'; return }
    $state = Load-SnapshotState
    $pass = 0
    foreach ($t in $selected) { if (Undo-Tweak $t $state) { $pass++ } }
    Refresh-TweakStatus
    Write-AppLog "UNDO finished: $pass / $($selected.Count) verified"
})

Refresh-TweakStatus
Refresh-ProfilePicker '986 Balanced'
Select-986Profile '986 Balanced'
Write-AppLog "$AppName v$Version started | Admin=$(Test-IsAdministrator) | Host=$env:COMPUTERNAME"
Write-AppLog "Baseline loaded. Preferences remain user-editable; 986 does not auto-reapply after Apply Selected."
[void]$Window.ShowDialog()
