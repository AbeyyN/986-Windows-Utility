Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Show-986ResolutionWindow {
    param([string]$StateDir)
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    $displays = @(Get-986NativeDisplays)
    if ($displays.Count -eq 0) {
        [Windows.MessageBox]::Show('No active display was returned by 986ResolutionHelper.exe.','986 Custom Resolution') | Out-Null
        return
    }
    $adapter = @(Get-986DisplayAdapters | Select-Object -First 1)
    $provider = if ($adapter.Count) { [string]$adapter[0].Provider } else { 'Windows-Driver' }

    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="986 Custom Resolution"
 Height="460" Width="620" MinHeight="420" MinWidth="560" Background="#050505" Foreground="#F5F1EE" WindowStartupLocation="CenterOwner">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Background" Value="#171213"/><Setter Property="Foreground" Value="#F5F1EE"/><Setter Property="BorderBrush" Value="#5A3C40"/></Style>
  <Style TargetType="TextBox"><Setter Property="Background" Value="#0D0D0F"/><Setter Property="Foreground" Value="#F5F1EE"/><Setter Property="BorderBrush" Value="#5A3C40"/></Style>
  <Style TargetType="ComboBox"><Setter Property="Background" Value="#171213"/><Setter Property="Foreground" Value="#F5F1EE"/><Setter Property="BorderBrush" Value="#B76E79"/><Setter Property="BorderThickness" Value="1"/></Style>
  <Style TargetType="ComboBoxItem">
   <Setter Property="Background" Value="#171213"/><Setter Property="Foreground" Value="#F5F1EE"/><Setter Property="Padding" Value="8,5"/><Setter Property="HorizontalContentAlignment" Value="Stretch"/>
   <Style.Triggers><Trigger Property="IsHighlighted" Value="True"><Setter Property="Background" Value="#7A414B"/></Trigger><Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="#B76E79"/><Setter Property="Foreground" Value="#050505"/></Trigger></Style.Triggers>
  </Style>
 </Window.Resources>
 <Grid Margin="20">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
  <TextBlock Text="986 CUSTOM RESOLUTION" FontSize="24" FontWeight="Bold" Foreground="#D8A0A8"/>
  <StackPanel Grid.Row="1" Margin="0,16,0,0"><TextBlock Text="Display"/><ComboBox x:Name="DisplayPicker" Height="32" Margin="0,4,0,0"/></StackPanel>
  <StackPanel Grid.Row="2" Margin="0,14,0,0"><TextBlock x:Name="CurrentText" Foreground="#AFA8A3"/><TextBlock x:Name="RatioText" Margin="0,4,0,0" Foreground="#D8A0A8"/></StackPanel>
  <Grid Grid.Row="3" Margin="0,16,0,0"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
   <StackPanel><TextBlock Text="Width"/><TextBox x:Name="WidthBox" Height="30" Margin="0,4,8,0"/></StackPanel>
   <StackPanel Grid.Column="1"><TextBlock Text="Height (auto)"/><TextBox x:Name="HeightBox" Height="30" Margin="0,4,8,0" IsReadOnly="True" Background="#101010" Foreground="#D8A0A8"/></StackPanel>
   <StackPanel Grid.Column="2"><TextBlock Text="Refresh Hz"/><TextBox x:Name="HzBox" Height="30" Margin="0,4,0,0"/></StackPanel>
  </Grid>
  <WrapPanel Grid.Row="4" Margin="0,18,0,0">
   <Button x:Name="TestButton" Content="Test Exact Mode" Padding="14,8" Margin="0,0,8,0"/>
   <Button x:Name="TrialButton" Content="Apply 15s Trial" Padding="14,8" Margin="0,0,8,0" Background="#C85A00" Foreground="White" BorderBrush="#FF8A00"/>
   <Button x:Name="UndoButton" Content="Undo to Original" Padding="14,8"/>
  </WrapPanel>
  <TextBox x:Name="StatusBox" Grid.Row="5" Margin="0,16,0,0" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#050505" Foreground="#F5F1EE" BorderBrush="#3B2729"/>
 </Grid>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $win = [Windows.Markup.XamlReader]::Load($reader)
    $picker=$win.FindName('DisplayPicker'); $current=$win.FindName('CurrentText'); $ratio=$win.FindName('RatioText')
    $wbox=$win.FindName('WidthBox'); $hbox=$win.FindName('HeightBox'); $hzbox=$win.FindName('HzBox')
    $test=$win.FindName('TestButton'); $trial=$win.FindName('TrialButton'); $undo=$win.FindName('UndoButton'); $status=$win.FindName('StatusBox')
    foreach ($d in $displays) { [void]$picker.Items.Add("$($d.DeviceName) | $($d.Description)") }

    $updateLockedHeight = {
        $i=$picker.SelectedIndex; if ($i -lt 0) { return }
        $width=0
        if (-not [int]::TryParse($wbox.Text,[ref]$width) -or $width -le 0) { $hbox.Text=''; return }
        $locked=Get-986AspectLockedResolution -Display $displays[$i] -Width $width
        $hbox.Text=[string]$locked.Height
        $ratio.Text="Aspect ratio locked: $($locked.RatioText) | Width controls height automatically."
    }
    $refresh = {
        $i=$picker.SelectedIndex; if ($i -lt 0) { return }
        $d=$displays[$i]
        $current.Text="Current: $($d.Width) x $($d.Height) @ $($d.RefreshRate) Hz | Provider: $provider"
        $wbox.Text=[string]$d.Width; $hzbox.Text=[string]$d.RefreshRate
        & $updateLockedHeight
    }
    $picker.Add_SelectionChanged({ & $refresh })
    $wbox.Add_TextChanged({ & $updateLockedHeight })
    $picker.SelectedIndex=0; & $refresh

    $readRequest = {
        $width=0; $height=0; $hz=0
        if (-not [int]::TryParse($wbox.Text,[ref]$width) -or -not [int]::TryParse($hbox.Text,[ref]$height) -or -not [int]::TryParse($hzbox.Text,[ref]$hz)) { throw 'Width and refresh must be integers; height is generated automatically.' }
        $locked=Get-986AspectLockedResolution -Display $displays[$picker.SelectedIndex] -Width $width
        $height=[int]$locked.Height; $hbox.Text=[string]$height
        if (-not (Test-986ResolutionRequest -Width $width -Height $height -RefreshRate $hz)) { throw 'Aspect-locked mode is outside 986 safety bounds.' }
        [pscustomobject]@{ Width=$width; Height=$height; Hz=$hz; Ratio=$locked.RatioText }
    }
    $test.Add_Click({
        try {
            $r=& $readRequest; $d=$displays[$picker.SelectedIndex]
            $result=Test-986DriverResolution -DeviceName $d.DeviceName -Width $r.Width -Height $r.Height -RefreshRate $r.Hz
            if($result.Supported) {
                $status.Text="PASS: exact aspect-locked mode $($r.Width) x $($r.Height) @ $($r.Hz) Hz ($($r.Ratio)) is accepted.`nNo display change was made."
            } else {
                $intelNote = if($provider -eq 'Intel-IGCL') { "`nIntel internal laptop panels can hardware-block custom resolutions even when the ratio is correct." } else { '' }
                $status.Text="DRIVER REJECTED: $($r.Width) x $($r.Height) @ $($r.Hz) Hz ($($r.Ratio)).`n$($result.Status)$intelNote`n986 did not change the display."
            }
        } catch { $status.Text=$_.Exception.Message }
    })
    $trial.Add_Click({
        try {
            $r=& $readRequest; $d=$displays[$picker.SelectedIndex]
            $status.Text="Starting 15s aspect-locked trial: $($r.Width) x $($r.Height) ($($r.Ratio)). Fallback revert remains armed."
            $result=Invoke-986ResolutionTrial -Display $d -Width $r.Width -Height $r.Height -RefreshRate $r.Hz -StateDir $StateDir -Seconds 15
            $status.Text="Trial result: $($result.Status)"
            $displays=@(Get-986NativeDisplays); & $refresh
        } catch { $status.Text=$_.Exception.Message }
    })
    $undo.Add_Click({
        try {
            $d=$displays[$picker.SelectedIndex]
            [void](Undo-986Resolution -DeviceName $d.DeviceName -StateDir $StateDir)
            $status.Text='UNDO PASS: exact original 986 resolution snapshot restored.'
            $displays=@(Get-986NativeDisplays); & $refresh
        } catch { $status.Text=$_.Exception.Message }
    })
    [void]$win.ShowDialog()
}
