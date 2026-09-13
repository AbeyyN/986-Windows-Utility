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
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="986 Custom Resolution"
 Height="460" Width="620" MinHeight="420" MinWidth="560" Background="#0B1220" Foreground="#E5E7EB" WindowStartupLocation="CenterOwner">
 <Grid Margin="20">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
  <TextBlock Text="986 CUSTOM RESOLUTION" FontSize="24" FontWeight="Bold" Foreground="#F59E0B"/>
  <StackPanel Grid.Row="1" Margin="0,16,0,0"><TextBlock Text="Display"/><ComboBox x:Name="DisplayPicker" Height="32" Margin="0,4,0,0"/></StackPanel>
  <TextBlock x:Name="CurrentText" Grid.Row="2" Margin="0,14,0,0" Foreground="#9CA3AF"/>
  <Grid Grid.Row="3" Margin="0,16,0,0"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
   <StackPanel><TextBlock Text="Width"/><TextBox x:Name="WidthBox" Height="30" Margin="0,4,8,0"/></StackPanel>
   <StackPanel Grid.Column="1"><TextBlock Text="Height"/><TextBox x:Name="HeightBox" Height="30" Margin="0,4,8,0"/></StackPanel>
   <StackPanel Grid.Column="2"><TextBlock Text="Refresh Hz"/><TextBox x:Name="HzBox" Height="30" Margin="0,4,0,0"/></StackPanel>
  </Grid>
  <WrapPanel Grid.Row="4" Margin="0,18,0,0">
   <Button x:Name="TestButton" Content="Test Support" Padding="14,8" Margin="0,0,8,0"/>
   <Button x:Name="TrialButton" Content="Apply 15s Trial" Padding="14,8" Margin="0,0,8,0" Background="#92400E" Foreground="White"/>
   <Button x:Name="UndoButton" Content="Undo to Original" Padding="14,8"/>
  </WrapPanel>
  <TextBox x:Name="StatusBox" Grid.Row="5" Margin="0,16,0,0" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#050A12" Foreground="#D1D5DB" BorderBrush="#273244"/>
 </Grid>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $win = [Windows.Markup.XamlReader]::Load($reader)
    $picker=$win.FindName('DisplayPicker'); $current=$win.FindName('CurrentText')
    $wbox=$win.FindName('WidthBox'); $hbox=$win.FindName('HeightBox'); $hzbox=$win.FindName('HzBox')
    $test=$win.FindName('TestButton'); $trial=$win.FindName('TrialButton'); $undo=$win.FindName('UndoButton'); $status=$win.FindName('StatusBox')
    foreach ($d in $displays) { [void]$picker.Items.Add("$($d.DeviceName) | $($d.Description)") }

    $refresh = {
        $i=$picker.SelectedIndex; if ($i -lt 0) { return }
        $d=$displays[$i]
        $current.Text="Current: $($d.Width) x $($d.Height) @ $($d.RefreshRate) Hz | Provider: $provider"
        $wbox.Text=[string]$d.Width; $hbox.Text=[string]$d.Height; $hzbox.Text=[string]$d.RefreshRate
    }
    $picker.Add_SelectionChanged({ & $refresh })
    $picker.SelectedIndex=0; & $refresh

    $readRequest = {
        $width=0; $height=0; $hz=0
        if (-not [int]::TryParse($wbox.Text,[ref]$width) -or -not [int]::TryParse($hbox.Text,[ref]$height) -or -not [int]::TryParse($hzbox.Text,[ref]$hz)) { throw 'Width, height and refresh must be integers.' }
        if (-not (Test-986ResolutionRequest -Width $width -Height $height -RefreshRate $hz)) { throw 'Requested mode is outside 986 safety bounds.' }
        [pscustomobject]@{ Width=$width; Height=$height; Hz=$hz }
    }
    $test.Add_Click({
        try {
            $r=& $readRequest; $d=$displays[$picker.SelectedIndex]
            $result=Test-986DriverResolution -DeviceName $d.DeviceName -Width $r.Width -Height $r.Height -RefreshRate $r.Hz
            $status.Text="Driver test: $($result.Status)`nNo display change was made."
        } catch { $status.Text=$_.Exception.Message }
    })
    $trial.Add_Click({
        try {
            $r=& $readRequest; $d=$displays[$picker.SelectedIndex]
            $status.Text='Starting temporary mode trial. If 986 closes, fallback revert remains armed.'
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
