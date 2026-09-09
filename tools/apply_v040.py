from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def save(rel, text):
    (ROOT / rel).write_text(text, encoding='utf-8', newline='\n')


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing integration anchor: {label}')
    return text.replace(old, new, 1)


app = load('986-Windows-Utility.ps1')
app = replace_once(
    app,
    'param([switch]$NoElevation,[switch]$AuditOnly,[switch]$AuditJson,[switch]$DoctorOnly,[switch]$DoctorJson)',
    'param([switch]$NoElevation,[switch]$AuditOnly,[switch]$AuditJson,[switch]$DoctorOnly,[switch]$DoctorJson,[switch]$ProfileList)',
    'params'
)
app = replace_once(app, "$Version = '0.3.0'", "$Version = '0.4.0-alpha.1'", 'version')
app = replace_once(
    app,
    'if (-not (Test-IsAdministrator) -and -not $NoElevation -and -not $AuditOnly -and -not $DoctorOnly) {',
    'if (-not (Test-IsAdministrator) -and -not $NoElevation -and -not $AuditOnly -and -not $DoctorOnly -and -not $ProfileList) {',
    'elevation'
)
app = replace_once(
    app,
    'Add-Type -AssemblyName WindowsBase\n',
    'Add-Type -AssemblyName WindowsBase\nAdd-Type -AssemblyName Microsoft.VisualBasic\n',
    'visualbasic assembly'
)
app = replace_once(
    app,
    ". $DoctorModule\n\nif ($AuditOnly) {",
    ". $DoctorModule\n\n$ProfilesModule = Join-Path $Root 'modules\\Profiles.ps1'\nif (-not (Test-Path $ProfilesModule)) { throw '986 Profiles module is missing.' }\n. $ProfilesModule\n\nif ($ProfileList) {\n    Get-986BuiltInProfiles | Select-Object Name,Description,@{N='Tweaks';E={@($_.TweakIds).Count}} | Format-Table -AutoSize\n    exit 0\n}\n\nif ($AuditOnly) {",
    'profiles module load'
)
app = replace_once(
    app,
    '        <Button x:Name="BtnBalanced" Content="986 Balanced"/>',
    '        <ComboBox x:Name="ProfilePicker" Width="180" Margin="0,0,8,0" Padding="8,5" Background="#1F2937" Foreground="#F9FAFB"/>\n        <Button x:Name="BtnProfileSelect" Content="Select Profile"/>\n        <Button x:Name="BtnProfileSave" Content="Save Custom"/>\n        <Button x:Name="BtnProfileDelete" Content="Delete Custom"/>',
    'profile toolbar'
)
app = replace_once(
    app,
    "$BtnExportDoctor = $Window.FindName('BtnExportDoctor')\n$BtnBalanced = $Window.FindName('BtnBalanced')\n$BtnAll = $Window.FindName('BtnAll')",
    "$BtnExportDoctor = $Window.FindName('BtnExportDoctor')\n$ProfilePicker = $Window.FindName('ProfilePicker')\n$BtnProfileSelect = $Window.FindName('BtnProfileSelect')\n$BtnProfileSave = $Window.FindName('BtnProfileSave')\n$BtnProfileDelete = $Window.FindName('BtnProfileDelete')\n$BtnAll = $Window.FindName('BtnAll')",
    'profile controls'
)
old_selection = """function Set-Selection([string]$Mode) {
    foreach ($t in $Tweaks) {
        switch ($Mode) {
            'Balanced' { $script:Rows[$t.Id].Check.IsChecked = [bool]$t.Balanced }
            'All'      { $script:Rows[$t.Id].Check.IsChecked = $true }
            'Clear'    { $script:Rows[$t.Id].Check.IsChecked = $false }
        }
    }
}
"""
new_selection = """function Set-Selection([string]$Mode) {
    foreach ($t in $Tweaks) {
        switch ($Mode) {
            'All'   { $script:Rows[$t.Id].Check.IsChecked = $true }
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
"""
app = replace_once(app, old_selection, new_selection, 'selection functions')
app = replace_once(
    app,
    "$BtnExportDoctor.Add_Click({ $r=Get-DoctorReport; $p=Export-DoctorReport $r; [Windows.MessageBox]::Show(\"Saved Doctor report:`n$p\",'986 Doctor') | Out-Null })\n$BtnBalanced.Add_Click({ Set-Selection 'Balanced'; Write-AppLog 'PRESET 986 Balanced selected' })\n$BtnAll.Add_Click({ Set-Selection 'All' })",
    "$BtnExportDoctor.Add_Click({ $r=Get-DoctorReport; $p=Export-DoctorReport $r; [Windows.MessageBox]::Show(\"Saved Doctor report:`n$p\",'986 Doctor') | Out-Null })\n$BtnProfileSelect.Add_Click({\n    try { Select-986Profile ([string]$ProfilePicker.SelectedItem) }\n    catch { [Windows.MessageBox]::Show($_.Exception.Message,'986 Profiles') | Out-Null }\n})\n$BtnProfileSave.Add_Click({\n    $selected = Get-SelectedTweaks\n    if ($selected.Count -eq 0) { [Windows.MessageBox]::Show('Select at least one tweak before saving a custom profile.','986 Profiles') | Out-Null; return }\n    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Name this custom profile:','986 Profiles','My Profile')\n    if ([string]::IsNullOrWhiteSpace($name)) { return }\n    try {\n        [void](Save-986CustomProfile $name @($selected | ForEach-Object { $_.Id }))\n        Refresh-ProfilePicker $name.Trim()\n        [Windows.MessageBox]::Show(\"Saved custom profile: $($name.Trim())\",'986 Profiles') | Out-Null\n    } catch { [Windows.MessageBox]::Show($_.Exception.Message,'986 Profiles') | Out-Null }\n})\n$BtnProfileDelete.Add_Click({\n    $name = [string]$ProfilePicker.SelectedItem\n    if ([string]::IsNullOrWhiteSpace($name)) { return }\n    if (Test-986BuiltInProfileName $name) { [Windows.MessageBox]::Show('Built-in profiles cannot be deleted.','986 Profiles') | Out-Null; return }\n    $answer = [Windows.MessageBox]::Show(\"Delete custom profile '$name'?\",'986 Profiles',[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Warning)\n    if ($answer -ne [Windows.MessageBoxResult]::Yes) { return }\n    if (Remove-986CustomProfile $name) { Refresh-ProfilePicker '986 Balanced'; Select-986Profile '986 Balanced' }\n})\n$BtnAll.Add_Click({ Set-Selection 'All' })",
    'profile handlers'
)
app = replace_once(
    app,
    "Refresh-TweakStatus\nSet-Selection 'Balanced'\nWrite-AppLog \"$AppName v$Version started | Admin=$(Test-IsAdministrator) | Host=$env:COMPUTERNAME\"",
    "Refresh-TweakStatus\nRefresh-ProfilePicker '986 Balanced'\nSelect-986Profile '986 Balanced'\nWrite-AppLog \"$AppName v$Version started | Admin=$(Test-IsAdministrator) | Host=$env:COMPUTERNAME\"",
    'startup profile'
)
save('986-Windows-Utility.ps1', app)

bootstrap = """# 986 Windows Utility bootstrap
$ErrorActionPreference = 'Stop'
$base = 'https://raw.githubusercontent.com/AbeyyN/986-Windows-Utility/main'
$dir = Join-Path $env:TEMP '986-Windows-Utility'
$moduleDir = Join-Path $dir 'modules'
$file = Join-Path $dir '986-Windows-Utility.ps1'
$auditModule = Join-Path $moduleDir 'TweakIntelligence.ps1'
$doctorModule = Join-Path $moduleDir 'Doctor.ps1'
$profilesModule = Join-Path $moduleDir 'Profiles.ps1'
New-Item -ItemType Directory -Force -Path $moduleDir | Out-Null
Write-Host 'Downloading 986 Windows Utility...' -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing -Uri "$base/986-Windows-Utility.ps1" -OutFile $file
Invoke-WebRequest -UseBasicParsing -Uri "$base/modules/TweakIntelligence.ps1" -OutFile $auditModule
Invoke-WebRequest -UseBasicParsing -Uri "$base/modules/Doctor.ps1" -OutFile $doctorModule
Invoke-WebRequest -UseBasicParsing -Uri "$base/modules/Profiles.ps1" -OutFile $profilesModule
Write-Host "Saved to $dir" -ForegroundColor DarkGray
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file
"""
save('bootstrap.ps1', bootstrap)

static = """$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$app = Join-Path $root '986-Windows-Utility.ps1'
$audit = Join-Path $root 'modules\\TweakIntelligence.ps1'
$doctor = Join-Path $root 'modules\\Doctor.ps1'
$profiles = Join-Path $root 'modules\\Profiles.ps1'
$bootstrap = Join-Path $root 'bootstrap.ps1'
foreach ($file in @($app,$audit,$doctor,$profiles,$bootstrap)) {
    if (-not (Test-Path $file)) { throw "Required script not found: $file" }
    $tokens=$null; $errors=$null
    [System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)|Out-Null
    if ($errors.Count -gt 0) { $errors|ForEach-Object{Write-Host $_.Message -ForegroundColor Red}; throw "Parse validation failed: $file" }
}
$text = Get-Content $app -Raw -Encoding UTF8
$auditText = Get-Content $audit -Raw -Encoding UTF8
$doctorText = Get-Content $doctor -Raw -Encoding UTF8
$profilesText = Get-Content $profiles -Raw -Encoding UTF8
$bootText = Get-Content $bootstrap -Raw -Encoding UTF8
$ids = [regex]::Matches($text,"Id='([^']+)'\\s*; Category=") | ForEach-Object { $_.Groups[1].Value }
if ($ids.Count -lt 20 -or ($ids|Sort-Object -Unique).Count -ne $ids.Count) { throw 'Tweak inventory count/uniqueness validation failed.' }
if ($text -notmatch '\\$Version = ''0\\.4\\.0-alpha\\.1''') { throw 'Expected application version 0.4.0-alpha.1.' }
foreach($mode in '\\[switch\\]\\$AuditOnly','\\[switch\\]\\$DoctorOnly','\\[switch\\]\\$ProfileList'){ if($text -notmatch $mode){throw "Missing headless mode: $mode"} }
foreach($fn in 'Get-TweakIntelligenceReport','Export-TweakAuditReport'){if($auditText -notmatch "function\\s+$fn"){throw "Missing audit function: $fn"}}
foreach($fn in 'Get-DoctorReport','Export-DoctorReport','Get-DoctorRepairPreflight','Start-DoctorRepair','Show-DoctorWindow'){if($doctorText -notmatch "function\\s+$fn"){throw "Missing Doctor function: $fn"}}
foreach($fn in 'Get-986BuiltInProfiles','Save-986CustomProfile','Get-986ProfileTweakIds'){if($profilesText -notmatch "function\\s+$fn"){throw "Missing Profiles function: $fn"}}
if ($bootText -notmatch 'modules/TweakIntelligence\\.ps1' -or $bootText -notmatch 'modules/Doctor\\.ps1' -or $bootText -notmatch 'modules/Profiles\\.ps1') { throw 'Bootstrap module downloads are incomplete.' }
Write-Host "PASS: v0.4 alpha app/modules/bootstrap parse clean, $($ids.Count) unique tweaks, Profiles present." -ForegroundColor Green
"""
save('tests/Static.Tests.ps1', static)

readme = load('README.md')
readme = replace_once(readme, '> **Project status:** public alpha v0.3.0. Tweak Intelligence is joined by 986 Doctor diagnostics, preflighted repair actions and exportable health reports.', '> **Project status:** v0.4.0-alpha.1 development line. Profiles are selection-only presets layered on the existing reversible Apply/Undo engine.', 'README status')
readme = replace_once(readme, '## v0.3.0 features', '## v0.4.0-alpha.1 development features', 'README feature heading')
readme = replace_once(readme, '- `986 Balanced` preset', '- **986 Profiles**: Balanced, Performance, Laptop and Technician built-ins\n- user-defined custom profiles stored locally in `state/profiles.json`\n- selecting a profile only changes checkbox selection; it never applies tweaks automatically', 'README profile bullets')
readme = replace_once(readme, '- **v0.4 profiles and technician presets**', '- mature v0.4 profile UX and expand safe profile-specific tweak coverage', 'README direction')
readme = replace_once(readme, '[docs/DOCTOR.md](docs/DOCTOR.md).', '[docs/DOCTOR.md](docs/DOCTOR.md) and [docs/PROFILES.md](docs/PROFILES.md).', 'README docs link')
save('README.md', readme)

roadmap = load('ROADMAP.md')
roadmap = replace_once(roadmap, '## v0.4 — Profiles\n\n- 986 Balanced\n- 986 Performance\n- 986 Laptop\n- 986 Technician\n- user-defined profiles', '## v0.4 — Profiles (in development)\n\n- 986 Balanced selection profile\n- 986 Performance selection profile\n- conservative 986 Laptop profile\n- 986 Technician visibility/troubleshooting profile\n- user-defined local profiles\n- profile actions remain selection-only; Apply/Undo stays explicit and reversible', 'ROADMAP profiles')
save('ROADMAP.md', roadmap)

Path(ROOT / 'tools' / 'apply_v040.py').unlink()
print('v0.4 profile integration applied')
