# 986 Tweak Intelligence Engine - read-only audit module
$script:WinUtilRegistrySignatures = @(
    [pscustomobject]@{ Id='show-ext'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Value='HideFileExt'; Target=0 },
    [pscustomobject]@{ Id='open-thispc'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Value='LaunchTo'; Target=1 },
    [pscustomobject]@{ Id='disable-publish-activity'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Value='PublishUserActivities'; Target=0 },
    [pscustomobject]@{ Id='disable-upload-activity'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Value='UploadUserActivities'; Target=0 },
    [pscustomobject]@{ Id='disable-consumer'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Value='DisableWindowsConsumerFeatures'; Target=1 },
    [pscustomobject]@{ Id='taskbar-end-task'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'; Value='TaskbarEndTask'; Target=1 }
)

$script:WinUtilServiceSignatures = @(
    [pscustomobject]@{ Name='CscService'; Target='Disabled' },
    [pscustomobject]@{ Name='DiagTrack'; Target='Disabled' },
    [pscustomobject]@{ Name='MapsBroker'; Target='Manual' },
    [pscustomobject]@{ Name='StorSvc'; Target='Manual' },
    [pscustomobject]@{ Name='SharedAccess'; Target='Disabled' }
)

$script:AuditScheduledTasks = @(
    [pscustomobject]@{ Path='\Microsoft\Windows\Application Experience\'; Name='Microsoft Compatibility Appraiser' },
    [pscustomobject]@{ Path='\Microsoft\Windows\Application Experience\'; Name='ProgramDataUpdater' },
    [pscustomobject]@{ Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='Consolidator' },
    [pscustomobject]@{ Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='UsbCeip' }
)

function Test-WinUtilRegistrySignature($Tweak, $Current) {
    if (-not $Current.Exists) { return $false }
    foreach ($sig in $script:WinUtilRegistrySignatures) {
        if ($sig.Path -ieq $Tweak.Path -and $sig.Value -ieq $Tweak.Value -and
            [string]$sig.Target -eq [string]$Current.Value) { return $true }
    }
    return $false
}

function Get-ServiceStartMode([string]$Name) {
    try {
        $svc = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
        if (-not $svc) { return $null }
        switch ($svc.StartMode) {
            'Auto' { return 'Automatic' }
            default { return [string]$svc.StartMode }
        }
    } catch { return $null }
}

function New-AuditItem($Area,$Id,$Name,$Current,$Classification,$Evidence) {
    [pscustomobject]@{
        Area=$Area; Id=$Id; Name=$Name; Current=$Current
        Classification=$Classification; Evidence=$Evidence
    }
}

function Get-TweakIntelligenceReport {
    $items = New-Object System.Collections.Generic.List[object]
    $managed = Load-SnapshotState
    foreach ($t in $Tweaks) {
        $current = Get-RegistryState $t
        $area = if ($t.Path -match '^HK(CU|LM):\\SOFTWARE\\Policies\\') { 'Policy' } else { 'Registry' }
        $currentText = if ($current.Exists) { [string]$current.Value } else { '<absent>' }
        if ($current.PSObject.Properties['Error']) {
            $items.Add((New-AuditItem $area $t.Id $t.Name $currentText 'Unknown' 'Registry read failed.'))
        } elseif ($managed.ContainsKey($t.Id)) {
            $items.Add((New-AuditItem $area $t.Id $t.Name $currentText '986 Managed' '986 original-state snapshot exists.'))
        } elseif (Test-WinUtilRegistrySignature $t $current) {
            $items.Add((New-AuditItem $area $t.Id $t.Name $currentText 'WinUtil-like' 'Shared key/value signature found in WinUtil config; attribution is not proven.'))
        } elseif (-not $current.Exists) {
            $items.Add((New-AuditItem $area $t.Id $t.Name $currentText 'Windows-like' 'Value is absent; Windows/default ownership is a heuristic.'))
        } else {
            $items.Add((New-AuditItem $area $t.Id $t.Name $currentText 'Custom' 'Present state is unmanaged and no verified shared WinUtil signature matched.'))
        }
    }
    foreach ($sig in $script:WinUtilServiceSignatures) {
        $mode = Get-ServiceStartMode $sig.Name
        if (-not $mode) {
            $items.Add((New-AuditItem 'Service' $sig.Name $sig.Name '<missing>' 'Unknown' 'Service was not found or could not be read.'))
        } elseif ($mode -eq $sig.Target) {
            $items.Add((New-AuditItem 'Service' $sig.Name $sig.Name $mode 'WinUtil-like' 'Startup mode matches a WinUtil service signature; attribution is not proven.'))
        } else {
            $items.Add((New-AuditItem 'Service' $sig.Name $sig.Name $mode 'Custom' 'Service state differs from the known WinUtil signature.'))
        }
    }

    foreach ($taskDef in $script:AuditScheduledTasks) {
        try {
            $task = Get-ScheduledTask -TaskPath $taskDef.Path -TaskName $taskDef.Name -ErrorAction Stop
            $state = [string]$task.State
            $class = if ($state -eq 'Disabled') { 'Custom' } else { 'Windows-like' }
            $evidence = if ($state -eq 'Disabled') { 'Task is disabled; no tool attribution is inferred.' } else { 'Task exists and is enabled/ready; treated as Windows-like heuristic.' }
            $items.Add((New-AuditItem 'ScheduledTask' ($taskDef.Path + $taskDef.Name) $taskDef.Name $state $class $evidence))
        } catch {
            $items.Add((New-AuditItem 'ScheduledTask' ($taskDef.Path + $taskDef.Name) $taskDef.Name '<missing>' 'Unknown' 'Task was not found or could not be read.'))
        }
    }
    $summary = [ordered]@{}
    foreach ($name in '986 Managed','WinUtil-like','Windows-like','Custom','Unknown') {
        $summary[$name] = @($items | Where-Object Classification -eq $name).Count
    }
    return [pscustomobject]@{
        Generated=(Get-Date).ToString('o')
        Version=$Version
        OSBuild=[Environment]::OSVersion.Version.ToString()
        ReadOnly=$true
        Summary=$summary
        Items=$items.ToArray()
    }
}

function Export-TweakAuditReport($Report) {
    if (-not $Report) { $Report = Get-TweakIntelligenceReport }
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $path = Join-Path $StateDir "audit-report-$stamp.json"
    $json = $Report | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($path,$json,[Text.UTF8Encoding]::new($false))
    Write-AppLog "AUDIT EXPORT $path"
    return $path
}

function Show-TweakIntelligenceWindow {
    $report = Get-TweakIntelligenceReport
    $win = New-Object Windows.Window
    $win.Title = "986 Tweak Intelligence v$Version - READ ONLY"
    $win.Width = 1180; $win.Height = 720; $win.MinWidth = 900; $win.MinHeight = 560
    $win.Background = '#0B1220'; $win.Foreground = '#E5E7EB'; $win.WindowStartupLocation = 'CenterOwner'
    if ($Window) { $win.Owner = $Window }

    $grid = New-Object Windows.Controls.Grid
    foreach ($h in @('Auto','*','Auto')) { $r=New-Object Windows.Controls.RowDefinition; $r.Height=$h; $grid.RowDefinitions.Add($r) }
    $summary = New-Object Windows.Controls.TextBlock
    $summary.Margin = [Windows.Thickness]::new(12)
    $summary.FontSize = 15; $summary.FontWeight = 'SemiBold'; $summary.Foreground = '#FBBF24'
    $summary.Text = "READ ONLY | 986 Managed $($report.Summary.'986 Managed') | WinUtil-like $($report.Summary.'WinUtil-like') | Windows-like $($report.Summary.'Windows-like') | Custom $($report.Summary.Custom) | Unknown $($report.Summary.Unknown)"
    [Windows.Controls.Grid]::SetRow($summary,0); $grid.Children.Add($summary) | Out-Null

    $data = New-Object Windows.Controls.DataGrid
    $data.Margin = [Windows.Thickness]::new(12,0,12,10); $data.IsReadOnly=$true; $data.AutoGenerateColumns=$true
    $data.Background='#111827'; $data.Foreground='#111827'; $data.GridLinesVisibility='Horizontal'
    $data.ItemsSource = $report.Items
    [Windows.Controls.Grid]::SetRow($data,1); $grid.Children.Add($data) | Out-Null
    $buttons = New-Object Windows.Controls.StackPanel
    $buttons.Orientation='Horizontal'; $buttons.HorizontalAlignment='Right'; $buttons.Margin=[Windows.Thickness]::new(12,0,12,12)
    $btnRefresh=New-Object Windows.Controls.Button; $btnRefresh.Content='Refresh Audit'; $btnRefresh.Margin=[Windows.Thickness]::new(0,0,8,0); $btnRefresh.Padding=[Windows.Thickness]::new(12,7,12,7)
    $btnExport=New-Object Windows.Controls.Button; $btnExport.Content='Export JSON'; $btnExport.Margin=[Windows.Thickness]::new(0,0,8,0); $btnExport.Padding=[Windows.Thickness]::new(12,7,12,7)
    $btnClose=New-Object Windows.Controls.Button; $btnClose.Content='Close'; $btnClose.Padding=[Windows.Thickness]::new(12,7,12,7)
    $buttons.Children.Add($btnRefresh)|Out-Null; $buttons.Children.Add($btnExport)|Out-Null; $buttons.Children.Add($btnClose)|Out-Null
    [Windows.Controls.Grid]::SetRow($buttons,2); $grid.Children.Add($buttons)|Out-Null

    $btnRefresh.Add_Click({
        $script:AuditWindowReport = Get-TweakIntelligenceReport
        $data.ItemsSource = $null; $data.ItemsSource = $script:AuditWindowReport.Items
        $summary.Text = "READ ONLY | 986 Managed $($script:AuditWindowReport.Summary.'986 Managed') | WinUtil-like $($script:AuditWindowReport.Summary.'WinUtil-like') | Windows-like $($script:AuditWindowReport.Summary.'Windows-like') | Custom $($script:AuditWindowReport.Summary.Custom) | Unknown $($script:AuditWindowReport.Summary.Unknown)"
        Write-AppLog 'INTELLIGENCE audit refreshed'
    })
    $script:AuditWindowReport = $report
    $btnExport.Add_Click({ $p=Export-TweakAuditReport $script:AuditWindowReport; [Windows.MessageBox]::Show("Saved read-only audit report:`n$p",'986 Tweak Intelligence') | Out-Null })
    $btnClose.Add_Click({ $win.Close() })
    $win.Content=$grid
    Write-AppLog "INTELLIGENCE audit opened: $($report.Items.Count) observations"
    [void]$win.ShowDialog()
}
