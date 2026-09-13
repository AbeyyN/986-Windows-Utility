from pathlib import Path

root = Path(__file__).resolve().parents[1]

def replace(path, old, new):
    p = root / path
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'missing anchor: {path}: {old[:80]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8', newline='\n')

app = '986-Windows-Utility.ps1'
replace(app, "$Version = '0.6.0'", "$Version = '0.7.0-rc.1'")
replace(app,
"$ProfilesModule = Join-Path $Root 'modules\\Profiles.ps1'\nif (-not (Test-Path $ProfilesModule)) { throw '986 Profiles module is missing.' }\n. $ProfilesModule",
"$ProfilesModule = Join-Path $Root 'modules\\Profiles.ps1'\nif (-not (Test-Path $ProfilesModule)) { throw '986 Profiles module is missing.' }\n. $ProfilesModule\n\n$ResolutionModule = Join-Path $Root 'display\\ResolutionManager.ps1'\nif (-not (Test-Path $ResolutionModule)) { throw '986 Resolution module is missing.' }\n. $ResolutionModule\n$ResolutionUi = Join-Path $Root 'display\\ResolutionUi.ps1'\nif (-not (Test-Path $ResolutionUi)) { throw '986 Resolution UI is missing.' }\n. $ResolutionUi")
replace(app,
'        <Button x:Name="BtnExportDoctor" Content="Export Doctor"/>',
'        <Button x:Name="BtnExportDoctor" Content="Export Doctor"/>\n        <Button x:Name="BtnStorage" Content="986 Storage" Background="#1E3A5F"/>\n        <Button x:Name="BtnResolution" Content="Custom Resolution" Background="#4C1D95"/>')
replace(app,
"$BtnExportDoctor = $Window.FindName('BtnExportDoctor')",
"$BtnExportDoctor = $Window.FindName('BtnExportDoctor')\n$BtnStorage = $Window.FindName('BtnStorage')\n$BtnResolution = $Window.FindName('BtnResolution')")
replace(app,
"$BtnExportDoctor.Add_Click({ $r=Get-DoctorReport; $p=Export-DoctorReport $r; [Windows.MessageBox]::Show(\"Saved Doctor report:`n$p\",'986 Doctor') | Out-Null })",
"$BtnExportDoctor.Add_Click({ $r=Get-DoctorReport; $p=Export-DoctorReport $r; [Windows.MessageBox]::Show(\"Saved Doctor report:`n$p\",'986 Doctor') | Out-Null })\n$StorageRegScript = Join-Path $Root 'storage\\registration\\Register-StorageView.ps1'\n$StorageShellDll = Join-Path $Root 'storage\\bin\\986StorageShell.dll'\n$StorageClsid = '{5FCCE720-D806-4B6A-A5F1-F060344FC88D}'\n$BtnStorage.Add_Click({\n    try {\n        if (-not (Test-Path $StorageRegScript)) { throw '986 Storage registration component is missing.' }\n        $s = & $StorageRegScript -Action Status\n        if ($s.Owned -and $s.NamespaceRegistered) {\n            $choice = [Windows.MessageBox]::Show('986 Storage is enabled. Yes = Open, No = Disable, Cancel = leave unchanged.','986 Storage',[Windows.MessageBoxButton]::YesNoCancel,[Windows.MessageBoxImage]::Information)\n            if ($choice -eq [Windows.MessageBoxResult]::Yes) { Start-Process explorer.exe -ArgumentList ('shell:::' + $StorageClsid) }\n            elseif ($choice -eq [Windows.MessageBoxResult]::No) { [void](& $StorageRegScript -Action Remove); Write-AppLog '986 STORAGE disabled and unregistered' }\n        } else {\n            if (-not (Test-Path $StorageShellDll)) { throw '986StorageShell.dll is missing. Install the complete v0.7 package.' }\n            [void](& $StorageRegScript -Action Install -DllPath $StorageShellDll)\n            Write-AppLog '986 STORAGE enabled under This PC'\n            Start-Process explorer.exe -ArgumentList ('shell:::' + $StorageClsid)\n        }\n    } catch { [Windows.MessageBox]::Show($_.Exception.Message,'986 Storage') | Out-Null }\n})\n$BtnResolution.Add_Click({\n    try { Show-986ResolutionWindow -StateDir $StateDir }\n    catch { [Windows.MessageBox]::Show($_.Exception.Message,'986 Custom Resolution') | Out-Null }\n})")
replace(app,
"Write-AppLog \"Baseline loaded. Preferences remain user-editable; 986 does not auto-reapply after Apply Selected.\"",
"Write-AppLog \"Baseline loaded. Preferences remain user-editable; 986 does not auto-reapply after Apply Selected.\"\nWrite-AppLog 'v0.7 optional features: 986 Storage and Custom Resolution use explicit enable/trial actions only.'")

# Static validation: v0.7 modules and version.
p = root / 'tests/Static.Tests.ps1'
t = p.read_text(encoding='utf-8')
t = t.replace("$profiles = Join-Path $root 'modules\\Profiles.ps1'", "$profiles = Join-Path $root 'modules\\Profiles.ps1'\n$resolution = Join-Path $root 'display\\ResolutionManager.ps1'\n$resolutionUi = Join-Path $root 'display\\ResolutionUi.ps1'")
t = t.replace('@($app,$audit,$doctor,$profiles,$bootstrap)', '@($app,$audit,$doctor,$profiles,$resolution,$resolutionUi,$bootstrap)')
t = t.replace("if ($text -notmatch '\\$Version = ''0\\.6\\.0''') { throw 'Expected application version 0.6.0.' }", "if ($text -notmatch '\\$Version = ''0\\.7\\.0-rc\\.1''') { throw 'Expected application version 0.7.0-rc.1.' }")
t = t.replace('PASS: v0.6 app/modules/bootstrap parse clean, 30 active + 4 legacy tweaks, Profiles present.', 'PASS: v0.7 RC app/modules parse clean, 30 active + 4 legacy tweaks, Storage and Resolution UI present.')
p.write_text(t, encoding='utf-8', newline='\n')

# GUI validation: require v0.7 buttons and handlers.
p = root / 'tests/Gui.Tests.ps1'
t = p.read_text(encoding='utf-8')
t = t.replace("'BtnApply','BtnUndo','TweakPanel','LogBox'", "'BtnApply','BtnUndo','BtnStorage','BtnResolution','TweakPanel','LogBox'")
t = t.replace("'$BtnProfileDelete.Add_Click'", "'$BtnProfileDelete.Add_Click','$BtnStorage.Add_Click','$BtnResolution.Add_Click'")
t = t.replace('PASS: v0.6 WPF XAML loads, profile controls are wired, and Never-Lock message is present.', 'PASS: v0.7 RC WPF loads, Storage/Resolution controls are wired, and Never-Lock message is present.')
p.write_text(t, encoding='utf-8', newline='\n')

# Roadmap and changelog checkpoint.
p = root / 'ROADMAP.md'; t = p.read_text(encoding='utf-8')
anchor = '## v1.0 — Stable'
block = '''## v0.7 — Storage View + Custom Resolution (release candidate)\n\n- Android-style segmented storage cards inside an optional This PC namespace view\n- out-of-process scanner; no permanent background service\n- per-user reversible shell registration with foreign-collision guard\n- arbitrary driver-tested width/height/refresh via CDS_TEST\n- 15-second Keep/Revert trial with one-shot crash fallback reverter\n- exact original resolution snapshot + Undo; no auto-reapply\n\n'''
if anchor not in t: raise SystemExit('missing ROADMAP v1.0 anchor')
p.write_text(t.replace(anchor, block + anchor, 1), encoding='utf-8', newline='\n')

p = root / 'CHANGELOG.md'; t = p.read_text(encoding='utf-8')
anchor = '## [0.6.0]'
block = '''## [0.7.0-rc.1] - 2026-09-13\n\n- Added optional 986 Storage native File Explorer view with segmented per-drive storage categories.\n- Added out-of-process storage scanner and reversible per-user This PC registration.\n- Added 986 Custom Resolution driver trial engine with CDS_TEST, timed Keep/Revert and exact Undo.\n- Preserved the 30 active tweak + 4 legacy Undo-only baseline and Never-Lock rule.\n\n'''
if anchor not in t: raise SystemExit('missing CHANGELOG v0.6 anchor')
p.write_text(t.replace(anchor, block + anchor, 1), encoding='utf-8', newline='\n')

print('V070_INTEGRATION_APPLIED')
