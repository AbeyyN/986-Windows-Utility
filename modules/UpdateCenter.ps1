Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:986BootstrapUrl = 'https://986-winutil.abeyytechxy.com'
$script:986ReleaseApi = 'https://api.github.com/repos/AbeyyN/986-Windows-Utility/releases/latest'

function ConvertTo-986Version {
    param([Parameter(Mandatory)][string]$Value)
    $m = [regex]::Match($Value.Trim(), '^v?(\d+)\.(\d+)\.(\d+)')
    if (-not $m.Success) { throw "Invalid 986 version: $Value" }
    return [version]("{0}.{1}.{2}" -f $m.Groups[1].Value,$m.Groups[2].Value,$m.Groups[3].Value)
}

function Get-986LatestStableRelease {
    $headers = @{ Accept='application/vnd.github+json'; 'User-Agent'='986-Windows-Utility-UpdateCenter/1.1' }
    $release = Invoke-RestMethod -UseBasicParsing -Uri $script:986ReleaseApi -Headers $headers
    if (-not $release -or $release.draft -or $release.prerelease) { throw 'Latest stable 986 release is unavailable.' }
    [pscustomobject]@{
        Tag = [string]$release.tag_name
        Version = ConvertTo-986Version ([string]$release.tag_name)
        Name = [string]$release.name
        Url = [string]$release.html_url
        PublishedAt = [datetime]$release.published_at
        Notes = [string]$release.body
    }
}

function Start-986VerifiedUpdate {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$CurrentVersion,
        [object]$OwnerWindow
    )
    $app = Join-Path $Root '986-Windows-Utility.ps1'
    $escapedRoot = $Root.Replace("'","''")
    $escapedApp = $app.Replace("'","''")
    $cmd = @"
Start-Sleep -Seconds 2
`$ErrorActionPreference='Stop'
`$bootstrap = Invoke-RestMethod -UseBasicParsing -Uri '$($script:986BootstrapUrl)'
`$runner = [scriptblock]::Create([string]`$bootstrap)
& `$runner -NoLaunch -InstallDir '$escapedRoot'
Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','$escapedApp')
"@
    Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-Command',$cmd) | Out-Null
    if ($OwnerWindow) { $OwnerWindow.Close() }
}

function Show-986UpdateCenter {
    param(
        [Parameter(Mandatory)][string]$CurrentVersion,
        [Parameter(Mandatory)][string]$Root,
        [object]$OwnerWindow
    )
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="986 Update Center" Width="650" Height="470" MinWidth="590" MinHeight="430" Background="#050505" Foreground="#F5F1EE" WindowStartupLocation="CenterOwner">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Background" Value="#171213"/><Setter Property="Foreground" Value="#F5F1EE"/><Setter Property="BorderBrush" Value="#5A3C40"/><Setter Property="Padding" Value="12,7"/><Setter Property="Margin" Value="0,0,8,0"/></Style>
 </Window.Resources>
 <Grid Margin="20">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <TextBlock Text="986 UPDATE CENTER" FontSize="24" FontWeight="Bold" Foreground="#D8A0A8"/>
  <TextBlock x:Name="VersionText" Grid.Row="1" Margin="0,14,0,0" FontSize="15"/>
  <TextBlock x:Name="StatusText" Grid.Row="2" Margin="0,8,0,10" Foreground="#FF8A00" TextWrapping="Wrap"/>
  <TextBox x:Name="NotesBox" Grid.Row="3" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#0D0D0F" Foreground="#F5F1EE" BorderBrush="#3B2729" Padding="10"/>
  <WrapPanel Grid.Row="4" Margin="0,14,0,0">
   <Button x:Name="CheckButton" Content="Check Latest"/>
   <Button x:Name="ReleaseButton" Content="View Release" IsEnabled="False"/>
   <Button x:Name="CopyButton" Content="Copy Update Command"/>
   <Button x:Name="UpdateButton" Content="Update &amp; Restart" Background="#C85A00" BorderBrush="#FF8A00" IsEnabled="False"/>
  </WrapPanel>
 </Grid>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $win = [Windows.Markup.XamlReader]::Load($reader)
    if ($OwnerWindow) { $win.Owner = $OwnerWindow }
    $versionText=$win.FindName('VersionText'); $status=$win.FindName('StatusText'); $notes=$win.FindName('NotesBox')
    $check=$win.FindName('CheckButton'); $releaseBtn=$win.FindName('ReleaseButton'); $copy=$win.FindName('CopyButton'); $update=$win.FindName('UpdateButton')
    $script:updateRelease = $null
    $versionText.Text = "Installed: v$CurrentVersion"
    $notes.Text = 'Check the latest stable release. Updates use the same checksum-verified 986 bootstrap used by the official short command. 986 Storage uses side-by-side native payloads, so Explorer is never force-restarted during an update.'
    $doCheck = {
        try {
            $status.Text='Checking latest stable release...'; $update.IsEnabled=$false; $releaseBtn.IsEnabled=$false
            $r=Get-986LatestStableRelease; $script:updateRelease=$r
            $current=ConvertTo-986Version $CurrentVersion
            $versionText.Text="Installed: v$CurrentVersion    |    Latest stable: $($r.Tag)"
            $notes.Text=if([string]::IsNullOrWhiteSpace($r.Notes)){'No release notes were provided.'}{$r.Notes}
            $releaseBtn.IsEnabled=$true
            if($CurrentVersion -match '-') { $status.Text='Development build detected. Stable auto-update is disabled for this preview.' }
            elseif($r.Version -gt $current) { $status.Text="Update available: $($r.Tag)."; $update.IsEnabled=$true }
            elseif($r.Version -eq $current) { $status.Text='You are on the latest stable 986 release.' }
            else { $status.Text='Installed build is newer than the latest stable release.' }
        } catch { $status.Text="Update check failed: $($_.Exception.Message)" }
    }
    $check.Add_Click({ & $doCheck })
    $releaseBtn.Add_Click({ if($script:updateRelease -and $script:updateRelease.Url){ Start-Process $script:updateRelease.Url } })
    $copy.Add_Click({ [Windows.Clipboard]::SetText("irm $($script:986BootstrapUrl) | iex"); $status.Text='Official update/install command copied to clipboard.' })
    $update.Add_Click({
        try {
            if(-not $script:updateRelease){ throw 'Check Latest before updating.' }
            Start-986VerifiedUpdate -Root $Root -CurrentVersion $CurrentVersion -OwnerWindow $win
        } catch { [Windows.MessageBox]::Show($_.Exception.Message,'986 Update Center',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Warning)|Out-Null }
    })
    & $doCheck
    [void]$win.ShowDialog()
}
