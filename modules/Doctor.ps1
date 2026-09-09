# 986 Doctor - diagnostics and explicit repair helpers
# PowerShell 5.1 compatible. No repair runs automatically.
$script:DoctorCurrentReport = $null

function Get-DoctorPendingReboot {
    $reasons = New-Object System.Collections.Generic.List[string]
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($key in $keys) {
        if (Test-Path $key) { $reasons.Add($key) }
    }
    try {
        $sm = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction Stop
        if ($sm.PendingFileRenameOperations) { $reasons.Add('PendingFileRenameOperations') }
    } catch {}
    return [pscustomobject]@{ Pending=($reasons.Count -gt 0); Reasons=$reasons.ToArray() }
}

function New-DoctorCheck($Area,$Name,$Value,$Status,$Detail) {
    return [pscustomobject]@{
        Area=$Area
        Name=$Name
        Value=[string]$Value
        Status=$Status
        Detail=$Detail
    }
}

function Get-DoctorReport {
    $checks = New-Object System.Collections.Generic.List[object]
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"

    $uptime = (Get-Date) - $os.LastBootUpTime
    $memTotalGb = [math]::Round($os.TotalVisibleMemorySize / 1MB,1)
    $memFreeGb = [math]::Round($os.FreePhysicalMemory / 1MB,1)
    $memFreePct = if ($os.TotalVisibleMemorySize) { [math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize)*100,0) } else { 0 }
    $diskTotalGb = if ($disk.Size) { [math]::Round($disk.Size/1GB,1) } else { 0 }
    $diskFreeGb = if ($disk.FreeSpace) { [math]::Round($disk.FreeSpace/1GB,1) } else { 0 }
    $diskFreePct = if ($disk.Size) { [math]::Round(($disk.FreeSpace/$disk.Size)*100,0) } else { 0 }

    $checks.Add((New-DoctorCheck 'System' 'Windows' "$($os.Caption) build $($os.BuildNumber)" 'INFO' $os.Version))
    $checks.Add((New-DoctorCheck 'System' 'CPU' $cpu.Name 'INFO' "Load $($cpu.LoadPercentage)%"))
    $memStatus = if ($memFreePct -lt 10) { 'ATTENTION' } else { 'GOOD' }
    $checks.Add((New-DoctorCheck 'System' 'Memory free' "$memFreeGb GB / $memTotalGb GB" $memStatus "$memFreePct% free"))
    $diskStatus = if ($diskFreePct -lt 10 -or $diskFreeGb -lt 5) { 'ATTENTION' } else { 'GOOD' }
    $checks.Add((New-DoctorCheck 'Storage' "$($env:SystemDrive) free" "$diskFreeGb GB / $diskTotalGb GB" $diskStatus "$diskFreePct% free"))
    $checks.Add((New-DoctorCheck 'System' 'Uptime' ("{0}d {1}h" -f [int]$uptime.TotalDays,$uptime.Hours) 'INFO' 'Restart can clear pending servicing state.'))

    $reboot = Get-DoctorPendingReboot
    $rebootStatus = if ($reboot.Pending) { 'ATTENTION' } else { 'GOOD' }
    $checks.Add((New-DoctorCheck 'Servicing' 'Pending reboot' $reboot.Pending $rebootStatus ($reboot.Reasons -join '; ')))

    foreach ($svcName in 'wuauserv','BITS','WinDefend','mpssvc') {
        try {
            $svc = Get-Service $svcName -ErrorAction Stop
            $checks.Add((New-DoctorCheck 'Service' $svcName $svc.Status 'INFO' 'Observed state only; stopped is not automatically treated as failure.'))
        } catch {
            $checks.Add((New-DoctorCheck 'Service' $svcName '<missing>' 'UNKNOWN' 'Service could not be read.'))
        }
    }

    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $defStatus = if ($mp.AntivirusEnabled -and $mp.RealTimeProtectionEnabled) { 'GOOD' } else { 'ATTENTION' }
        $defValue = "AV=$($mp.AntivirusEnabled) RTP=$($mp.RealTimeProtectionEnabled)"
        $checks.Add((New-DoctorCheck 'Security' 'Microsoft Defender' $defValue $defStatus "Signature age: $($mp.AntivirusSignatureAge) day(s)"))
    } catch {
        $checks.Add((New-DoctorCheck 'Security' 'Microsoft Defender' '<unavailable>' 'UNKNOWN' 'Get-MpComputerStatus unavailable or blocked.'))
    }

    $net = $null
    try { $net = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1 } catch {}
    if ($net) {
        $ip = ($net.IPv4Address.IPAddress | Select-Object -First 1)
        $gw = $net.IPv4DefaultGateway.NextHop
        $dns = ($net.DNSServer.ServerAddresses -join ', ')
        $checks.Add((New-DoctorCheck 'Network' 'Active adapter' $net.InterfaceAlias 'GOOD' "IPv4=$ip Gateway=$gw DNS=$dns"))
    } else {
        $checks.Add((New-DoctorCheck 'Network' 'Active adapter' '<none detected>' 'ATTENTION' 'No IPv4 default gateway was detected.'))
    }

    $internet = $false
    try { $internet = Test-NetConnection www.microsoft.com -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue } catch {}
    $internetStatus = if ($internet) { 'GOOD' } else { 'ATTENTION' }
    $checks.Add((New-DoctorCheck 'Network' 'Microsoft connectivity' $internet $internetStatus 'TCP 443 reachability; used as a repair-source connectivity signal.'))

    $attention = @($checks | Where-Object Status -eq 'ATTENTION').Count
    $unknown = @($checks | Where-Object Status -eq 'UNKNOWN').Count
    $overall = if ($attention -gt 0) { 'ATTENTION' } elseif ($unknown -gt 0) { 'CHECK' } else { 'GOOD' }
    return [pscustomobject]@{
        Generated=(Get-Date).ToString('o')
        Version=$Version
        OSBuild=$os.BuildNumber
        ReadOnly=$true
        Overall=$overall
        Attention=$attention
        Unknown=$unknown
        Checks=$checks.ToArray()
    }
}

function Export-DoctorReport($Report) {
    if (-not $Report) { $Report = Get-DoctorReport }
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    $path = Join-Path $StateDir ("doctor-report-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $json = $Report | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($path,$json,[Text.UTF8Encoding]::new($false))
    Write-AppLog "DOCTOR EXPORT $path"
    return $path
}

function Get-DoctorRepairDefinition([string]$Action) {
    $defs = @{
        'DISM-CheckHealth'   = @{ Exe='DISM.exe'; Args='/Online /Cleanup-Image /CheckHealth'; Changes=$false; NeedsInternet=$false; Reboot=$false }
        'DISM-ScanHealth'    = @{ Exe='DISM.exe'; Args='/Online /Cleanup-Image /ScanHealth'; Changes=$false; NeedsInternet=$false; Reboot=$false }
        'DISM-RestoreHealth' = @{ Exe='DISM.exe'; Args='/Online /Cleanup-Image /RestoreHealth'; Changes=$true; NeedsInternet=$true; Reboot=$false }
        'SFC-Scannow'        = @{ Exe='sfc.exe'; Args='/scannow'; Changes=$true; NeedsInternet=$false; Reboot=$false }
        'Flush-DNS'          = @{ Exe='ipconfig.exe'; Args='/flushdns'; Changes=$true; NeedsInternet=$false; Reboot=$false }
        'Winsock-Reset'      = @{ Exe='netsh.exe'; Args='winsock reset'; Changes=$true; NeedsInternet=$false; Reboot=$true }
    }
    if (-not $defs.ContainsKey($Action)) { throw "Unknown Doctor action: $Action" }
    return $defs[$Action]
}

function Get-DoctorRepairPreflight([string]$Action) {
    $def = Get-DoctorRepairDefinition $Action
    $blockers = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    if (-not (Test-IsAdministrator)) { $blockers.Add('Administrator rights are required.') }
    if (-not (Get-Command $def.Exe -ErrorAction SilentlyContinue)) { $blockers.Add("Executable not found: $($def.Exe)") }
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    if ($disk.FreeSpace -lt 5GB) { $warnings.Add('System drive has less than 5 GB free space.') }
    $reboot = Get-DoctorPendingReboot
    if ($reboot.Pending) { $warnings.Add('Windows reports a pending reboot; restart first when practical.') }
    if ($def.NeedsInternet) {
        $online = $false
        try { $online = Test-NetConnection www.microsoft.com -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue } catch {}
        if (-not $online) { $warnings.Add('Microsoft connectivity was not confirmed; DISM RestoreHealth may fail without a repair source.') }
    }
    return [pscustomobject]@{
        Action=$Action
        Ready=($blockers.Count -eq 0)
        ChangesSystem=[bool]$def.Changes
        RestartRecommended=[bool]$def.Reboot
        Blockers=$blockers.ToArray()
        Warnings=$warnings.ToArray()
    }
}

function Start-DoctorRepair([string]$Action) {
    $def = Get-DoctorRepairDefinition $Action
    $pre = Get-DoctorRepairPreflight $Action
    if (-not $pre.Ready) { throw ($pre.Blockers -join [Environment]::NewLine) }
    if ($pre.ChangesSystem) {
        $warning = "This action can change Windows system state.`n`nAction: $Action"
        if ($pre.Warnings.Count) { $warning += "`n`nPreflight warnings:`n- " + ($pre.Warnings -join "`n- ") }
        $answer = [Windows.MessageBox]::Show($warning + "`n`nContinue?",'986 Doctor',[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Warning)
        if ($answer -ne [Windows.MessageBoxResult]::Yes) {
            Write-AppLog "DOCTOR CANCEL $Action"
            return $null
        }
    }
    $log = Join-Path $StateDir ("doctor-{0}-{1}.log" -f ($Action -replace '[^A-Za-z0-9-]','_'),(Get-Date -Format 'yyyyMMdd-HHmmss'))
    $exe = $def.Exe.Replace("'","''")
    $args = $def.Args.Replace("'","''")
    $logEsc = $log.Replace("'","''")
    $body = "& '$exe' $args 2>&1 | Tee-Object -FilePath '$logEsc'; Write-Host ''; Write-Host '986 Doctor action completed. Log: $logEsc' -ForegroundColor Cyan; Read-Host 'Press Enter to close'"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($body))
    Write-AppLog "DOCTOR START $Action | log=$log"
    Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded
    return $log
}

function New-DoctorButton($Content,$Tag) {
    $b = New-Object Windows.Controls.Button
    $b.Content=$Content
    $b.Tag=$Tag
    $b.Margin='0,0,8,8'
    $b.Padding='10,6'
    return $b
}

function Show-DoctorWindow {
    $report = Get-DoctorReport
    $win = New-Object Windows.Window
    $win.Title = "986 Doctor v$Version"
    $win.Width=1180
    $win.Height=760
    $win.MinWidth=920
    $win.MinHeight=600
    $win.Background='#0B1220'
    $win.Foreground='#E5E7EB'
    $win.WindowStartupLocation='CenterOwner'
    if ($Window) { $win.Owner=$Window }

    $grid = New-Object Windows.Controls.Grid
    foreach ($h in 'Auto','Auto','*','Auto') {
        $r=New-Object Windows.Controls.RowDefinition
        $r.Height=$h
        $grid.RowDefinitions.Add($r)
    }

    $title = New-Object Windows.Controls.TextBlock
    $title.Text="986 DOCTOR | $($report.Overall) | Attention $($report.Attention) | Unknown $($report.Unknown)"
    $title.FontSize=22
    $title.FontWeight='Bold'
    $title.Foreground='#F59E0B'
    $title.Margin='14,14,14,8'
    [Windows.Controls.Grid]::SetRow($title,0)
    $grid.Children.Add($title)|Out-Null

    $bar = New-Object Windows.Controls.WrapPanel
    $bar.Margin='14,0,14,8'
    $refresh=New-DoctorButton 'Refresh' 'Refresh'
    $export=New-DoctorButton 'Export Report' 'Export'
    foreach($b in @($refresh,$export)){ $bar.Children.Add($b)|Out-Null }
    [Windows.Controls.Grid]::SetRow($bar,1)
    $grid.Children.Add($bar)|Out-Null

    $table = New-Object Windows.Controls.DataGrid
    $table.Margin='14,0,14,10'
    $table.AutoGenerateColumns=$true
    $table.IsReadOnly=$true
    $table.Background='#0F172A'
    $table.Foreground='#E5E7EB'
    $table.GridLinesVisibility='Horizontal'
    $table.ItemsSource=$report.Checks
    [Windows.Controls.Grid]::SetRow($table,2)
    $grid.Children.Add($table)|Out-Null

    $actions = New-Object Windows.Controls.WrapPanel
    $actions.Margin='14,0,14,10'
    $actionButtons = @()
    foreach($pair in @(
        @('DISM CheckHealth','DISM-CheckHealth'),
        @('DISM ScanHealth','DISM-ScanHealth'),
        @('DISM RestoreHealth','DISM-RestoreHealth'),
        @('SFC Scan/Repair','SFC-Scannow'),
        @('Flush DNS','Flush-DNS'),
        @('Winsock Reset','Winsock-Reset')
    )) {
        $button=New-DoctorButton $pair[0] $pair[1]
        $actionButtons += $button
        $actions.Children.Add($button)|Out-Null
    }
    [Windows.Controls.Grid]::SetRow($actions,3)
    $grid.Children.Add($actions)|Out-Null

    $refresh.Add_Click({
        try {
            $script:DoctorCurrentReport = Get-DoctorReport
            $table.ItemsSource = $null
            $table.ItemsSource = $script:DoctorCurrentReport.Checks
            $title.Text = "986 DOCTOR | $($script:DoctorCurrentReport.Overall) | Attention $($script:DoctorCurrentReport.Attention) | Unknown $($script:DoctorCurrentReport.Unknown)"
            Write-AppLog 'DOCTOR refresh complete'
        } catch {
            [Windows.MessageBox]::Show($_.Exception.Message,'986 Doctor')|Out-Null
        }
    })
    $export.Add_Click({
        try {
            $r = if ($script:DoctorCurrentReport) { $script:DoctorCurrentReport } else { Get-DoctorReport }
            $p = Export-DoctorReport $r
            [Windows.MessageBox]::Show("Saved Doctor report:`n$p",'986 Doctor')|Out-Null
        } catch {
            [Windows.MessageBox]::Show($_.Exception.Message,'986 Doctor')|Out-Null
        }
    })
    foreach($button in $actionButtons) {
        $button.Add_Click({
            param($sender,$eventArgs)
            try { [void](Start-DoctorRepair ([string]$sender.Tag)) }
            catch { [Windows.MessageBox]::Show($_.Exception.Message,'986 Doctor',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)|Out-Null }
        })
    }
    $script:DoctorCurrentReport=$report
    $win.Content=$grid
    [void]$win.ShowDialog()
}
