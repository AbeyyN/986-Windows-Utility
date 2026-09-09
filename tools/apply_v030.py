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

# Main application integration.
rel = '986-Windows-Utility.ps1'
s = load(rel)
s = replace_once(s, 'param([switch]$NoElevation,[switch]$AuditOnly,[switch]$AuditJson)', 'param([switch]$NoElevation,[switch]$AuditOnly,[switch]$AuditJson,[switch]$DoctorOnly,[switch]$DoctorJson)', 'main params')
s = replace_once(s, "$Version = '0.2.0'", "$Version = '0.3.0'", 'version')
s = replace_once(s, 'if (-not (Test-IsAdministrator) -and -not $NoElevation -and -not $AuditOnly) {', 'if (-not (Test-IsAdministrator) -and -not $NoElevation -and -not $AuditOnly -and -not $DoctorOnly) {', 'elevation')
s = replace_once(s, ". $AuditModule\n\nif ($AuditOnly) {", ". $AuditModule\n\n$DoctorModule = Join-Path $Root 'modules\\Doctor.ps1'\nif (-not (Test-Path $DoctorModule)) { throw '986 Doctor module is missing.' }\n. $DoctorModule\n\nif ($AuditOnly) {", 'Doctor module load')
audit_branch = '''if ($AuditOnly) {\n    $report = Get-TweakIntelligenceReport\n    $report.Items | Format-Table Area,Name,Current,Classification -AutoSize\n    Write-Host "Summary: 986=$($report.Summary.'986 Managed') WinUtil-like=$($report.Summary.'WinUtil-like') Windows-like=$($report.Summary.'Windows-like') Custom=$($report.Summary.Custom) Unknown=$($report.Summary.Unknown)"\n    if ($AuditJson) { Write-Host "Exported: $(Export-TweakAuditReport $report)" }\n    exit 0\n}\n'''
doctor_branch = audit_branch + '''\nif ($DoctorOnly) {\n    $report = Get-DoctorReport\n    $report.Checks | Format-Table Area,Name,Value,Status -AutoSize\n    Write-Host "Doctor: Overall=$($report.Overall) Attention=$($report.Attention) Unknown=$($report.Unknown)"\n    if ($DoctorJson) { Write-Host "Exported: $(Export-DoctorReport $report)" }\n    exit 0\n}\n'''
s = replace_once(s, audit_branch, doctor_branch, 'Doctor headless branch')
old_toolbar = '''      <StackPanel Orientation="Horizontal">\n        <Button x:Name="BtnAudit" Content="Audit"/>\n        <Button x:Name="BtnIntelligence" Content="Tweak Intelligence"/>\n        <Button x:Name="BtnExportAudit" Content="Export Audit"/>\n        <Button x:Name="BtnBalanced" Content="986 Balanced"/>\n        <Button x:Name="BtnAll" Content="Select All"/>\n        <Button x:Name="BtnClear" Content="Clear"/>\n        <Button x:Name="BtnRestorePoint" Content="Create Restore Point"/>\n        <Button x:Name="BtnOpenState" Content="Open State Folder"/>\n      </StackPanel>'''
new_toolbar = '''      <WrapPanel>\n        <Button x:Name="BtnAudit" Content="Audit"/>\n        <Button x:Name="BtnIntelligence" Content="Tweak Intelligence"/>\n        <Button x:Name="BtnExportAudit" Content="Export Audit"/>\n        <Button x:Name="BtnDoctor" Content="986 Doctor"/>\n        <Button x:Name="BtnExportDoctor" Content="Export Doctor"/>\n        <Button x:Name="BtnBalanced" Content="986 Balanced"/>\n        <Button x:Name="BtnAll" Content="Select All"/>\n        <Button x:Name="BtnClear" Content="Clear"/>\n        <Button x:Name="BtnRestorePoint" Content="Create Restore Point"/>\n        <Button x:Name="BtnOpenState" Content="Open State Folder"/>\n      </WrapPanel>'''
s = replace_once(s, old_toolbar, new_toolbar, 'toolbar')
s = replace_once(s, "$BtnExportAudit = $Window.FindName('BtnExportAudit')\n$BtnBalanced = $Window.FindName('BtnBalanced')", "$BtnExportAudit = $Window.FindName('BtnExportAudit')\n$BtnDoctor = $Window.FindName('BtnDoctor')\n$BtnExportDoctor = $Window.FindName('BtnExportDoctor')\n$BtnBalanced = $Window.FindName('BtnBalanced')", 'Doctor controls')
s = replace_once(s, "$BtnExportAudit.Add_Click({ $r=Get-TweakIntelligenceReport; $p=Export-TweakAuditReport $r; [Windows.MessageBox]::Show(\"Saved read-only audit report:`n$p\",'986 Tweak Intelligence') | Out-Null })\n$BtnBalanced.Add_Click", "$BtnExportAudit.Add_Click({ $r=Get-TweakIntelligenceReport; $p=Export-TweakAuditReport $r; [Windows.MessageBox]::Show(\"Saved read-only audit report:`n$p\",'986 Tweak Intelligence') | Out-Null })\n$BtnDoctor.Add_Click({ Show-DoctorWindow })\n$BtnExportDoctor.Add_Click({ $r=Get-DoctorReport; $p=Export-DoctorReport $r; [Windows.MessageBox]::Show(\"Saved Doctor report:`n$p\",'986 Doctor') | Out-Null })\n$BtnBalanced.Add_Click", 'Doctor handlers')
save(rel, s)

# Bootstrap downloads both runtime modules.
save('bootstrap.ps1', '''# 986 Windows Utility bootstrap\n$ErrorActionPreference = 'Stop'\n$base = 'https://raw.githubusercontent.com/AbeyyN/986-Windows-Utility/main'\n$dir = Join-Path $env:TEMP '986-Windows-Utility'\n$moduleDir = Join-Path $dir 'modules'\n$file = Join-Path $dir '986-Windows-Utility.ps1'\n$auditModule = Join-Path $moduleDir 'TweakIntelligence.ps1'\n$doctorModule = Join-Path $moduleDir 'Doctor.ps1'\nNew-Item -ItemType Directory -Force -Path $moduleDir | Out-Null\nWrite-Host 'Downloading 986 Windows Utility...' -ForegroundColor Cyan\nInvoke-WebRequest -UseBasicParsing -Uri "$base/986-Windows-Utility.ps1" -OutFile $file\nInvoke-WebRequest -UseBasicParsing -Uri "$base/modules/TweakIntelligence.ps1" -OutFile $auditModule\nInvoke-WebRequest -UseBasicParsing -Uri "$base/modules/Doctor.ps1" -OutFile $doctorModule\nWrite-Host "Saved to $dir" -ForegroundColor DarkGray\n& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file\n''')

# Repository validation understands v0.3 and both modules.
save('tests/Static.Tests.ps1', '''$ErrorActionPreference = 'Stop'\n$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)\n$app = Join-Path $root '986-Windows-Utility.ps1'\n$audit = Join-Path $root 'modules\\TweakIntelligence.ps1'\n$doctor = Join-Path $root 'modules\\Doctor.ps1'\n$bootstrap = Join-Path $root 'bootstrap.ps1'\nforeach ($file in @($app,$audit,$doctor,$bootstrap)) {\n    if (-not (Test-Path $file)) { throw "Required script not found: $file" }\n    $tokens=$null; $errors=$null\n    [System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)|Out-Null\n    if ($errors.Count -gt 0) { $errors|ForEach-Object{Write-Host $_.Message -ForegroundColor Red}; throw "Parse validation failed: $file" }\n}\n$text = Get-Content $app -Raw -Encoding UTF8\n$auditText = Get-Content $audit -Raw -Encoding UTF8\n$doctorText = Get-Content $doctor -Raw -Encoding UTF8\n$bootText = Get-Content $bootstrap -Raw -Encoding UTF8\n$ids = [regex]::Matches($text,"Id='([^']+)'\\s*; Category=") | ForEach-Object { $_.Groups[1].Value }\nif ($ids.Count -lt 20 -or ($ids|Sort-Object -Unique).Count -ne $ids.Count) { throw 'Tweak inventory count/uniqueness validation failed.' }\nif ($text -notmatch '\\$Version = ''0\\.3\\.0''') { throw 'Expected application version 0.3.0.' }\nforeach($mode in '\\[switch\\]\\$AuditOnly','\\[switch\\]\\$DoctorOnly'){ if($text -notmatch $mode){throw "Missing headless mode: $mode"} }\nforeach($fn in 'Get-TweakIntelligenceReport','Export-TweakAuditReport'){if($auditText -notmatch "function\\s+$fn"){throw "Missing audit function: $fn"}}\nforeach($fn in 'Get-DoctorReport','Export-DoctorReport','Get-DoctorRepairPreflight','Start-DoctorRepair','Show-DoctorWindow'){if($doctorText -notmatch "function\\s+$fn"){throw "Missing Doctor function: $fn"}}\nif ($bootText -notmatch 'modules/TweakIntelligence\\.ps1' -or $bootText -notmatch 'modules/Doctor\\.ps1') { throw 'Bootstrap module downloads are incomplete.' }\nWrite-Host "PASS: v0.3 app/modules/bootstrap parse clean, $($ids.Count) unique tweaks, Doctor present." -ForegroundColor Green\n''')

# CI adds a real headless Doctor smoke test.
ci = load('.github/workflows/ci.yml')
if 'Headless Doctor smoke test' not in ci:
    ci += '''      - name: Headless Doctor smoke test\n        shell: powershell\n        run: .\\986-Windows-Utility.ps1 -DoctorOnly\n'''
save('.github/workflows/ci.yml', ci)

# README and project docs.
readme = load('README.md')
readme = replace_once(readme, '> **Project status:** public alpha v0.2.0. The reversible tweak engine now includes a read-only Tweak Intelligence audit layer.', '> **Project status:** public alpha v0.3.0. Tweak Intelligence is joined by 986 Doctor diagnostics, preflighted repair actions and exportable health reports.', 'README status')
readme = replace_once(readme, '## v0.2.0 features', '## v0.3.0 features', 'README version heading')
readme = replace_once(readme, '- JSON audit export and headless `-AuditOnly` mode\n', '- JSON audit export and headless `-AuditOnly` mode\n- **986 Doctor** health dashboard for system, storage, servicing, security and network signals\n- Doctor preflight plus explicit DISM, SFC, DNS flush and Winsock repair actions\n- timestamped repair logs and privacy-hardened Doctor JSON reports\n- headless `-DoctorOnly` and optional `-DoctorJson` modes\n', 'README Doctor bullets')
readme = replace_once(readme, 'Add `-AuditJson` to export the report into the local `state` directory.\n', 'Add `-AuditJson` to export the report into the local `state` directory.\n\nHeadless Doctor check:\n\n```powershell\npowershell -NoProfile -ExecutionPolicy Bypass -File .\\986-Windows-Utility.ps1 -DoctorOnly\n```\n\nAdd `-DoctorJson` to export a privacy-hardened Doctor report.\n', 'README Doctor CLI')
readme = replace_once(readme, '- **v0.3 diagnostics and repair modules**', '- **v0.4 profiles and technician presets**', 'README direction')
readme = replace_once(readme, '[docs/INTELLIGENCE.md](docs/INTELLIGENCE.md).', '[docs/INTELLIGENCE.md](docs/INTELLIGENCE.md) and [docs/DOCTOR.md](docs/DOCTOR.md).', 'README docs link')
save('README.md', readme)

changelog = load('CHANGELOG.md')
entry = '''## [0.3.0] - 2026-09-09\n\n### Added\n\n- 986 Doctor system health dashboard\n- system, storage, servicing, Defender and network diagnostics\n- pending reboot and repair-source connectivity signals\n- privacy-hardened Doctor JSON report export\n- headless `-DoctorOnly` and optional `-DoctorJson` modes\n- DISM CheckHealth, ScanHealth and RestoreHealth actions\n- SFC scan/repair, DNS flush and Winsock reset actions\n- repair preflight, explicit confirmation and timestamped logs\n- CI Doctor safety validation and headless smoke test\n\n### Safety\n\nDoctor refresh and report export are read-only. Actions that can change Windows state require explicit user selection and a confirmation dialog; no repair runs automatically.\n\n'''
changelog = replace_once(changelog, '## [0.2.0] - 2026-09-09\n', entry + '## [0.2.0] - 2026-09-09\n', 'CHANGELOG v0.3')
save('CHANGELOG.md', changelog)

roadmap = load('ROADMAP.md')
roadmap = replace_once(roadmap, '## v0.3 — Diagnostics & Repair\n\n- Windows health dashboard\n- network and update diagnostics\n- repair actions with preflight checks and logs\n- exportable diagnostics report', '## v0.3 — Diagnostics & Repair (implemented)\n\n- Windows health dashboard\n- system, storage, Defender, network and servicing diagnostics\n- repair actions with preflight checks, confirmation and logs\n- exportable privacy-hardened diagnostics report\n- headless Doctor mode for CI and technician workflows', 'ROADMAP v0.3')
save('ROADMAP.md', roadmap)

arch = load('docs/ARCHITECTURE.md')
arch = replace_once(arch, '## v0.2 runtime', '## v0.3 runtime', 'architecture version heading')
arch = replace_once(arch, '986 Windows Utility v0.2 is a Windows PowerShell 5.1 application with a WPF interface and a separate read-only Tweak Intelligence module.', '986 Windows Utility v0.3 is a Windows PowerShell 5.1 application with a WPF interface, a read-only Tweak Intelligence module and a separate 986 Doctor diagnostics/repair module.', 'architecture intro')
arch = replace_once(arch, '- `modules/TweakIntelligence.ps1` — read-only classification, report export and Intelligence UI\n', '- `modules/TweakIntelligence.ps1` — read-only classification, report export and Intelligence UI\n- `modules/Doctor.ps1` — health diagnostics, repair preflight, explicit repair launchers and Doctor UI\n', 'architecture Doctor component')
arch = replace_once(arch, '6. High-risk changes require stronger review and compatibility evidence than low-risk preference changes.\n', '6. High-risk changes require stronger review and compatibility evidence than low-risk preference changes.\n7. Doctor diagnostics never trigger repair automatically; system-changing repair actions require explicit confirmation and log output.\n', 'architecture safety constraint')
save('docs/ARCHITECTURE.md', arch)

getting = load('docs/GETTING_STARTED.md')
getting = replace_once(getting, '- Windows 11 is the primary v0.2 target', '- Windows 11 is the primary v0.3 target', 'getting started version')
getting = replace_once(getting, '4. Press **Tweak Intelligence** for the read-only classification audit.\n5. Press **Audit** to refresh target-state status.\n6. Select individual tweaks or `986 Balanced`.\n7. Press **Apply Selected** only after reviewing the list.\n8. Re-run Audit and confirm expected states.', '4. Press **986 Doctor** for a read-only health overview.\n5. Press **Tweak Intelligence** for the read-only classification audit.\n6. Press **Audit** to refresh target-state status.\n7. Select individual tweaks or `986 Balanced`.\n8. Press **Apply Selected** only after reviewing the list.\n9. Re-run Audit and confirm expected states.', 'getting started steps')
getting += '''\n## Headless Doctor\n\n```powershell\npowershell -NoProfile -ExecutionPolicy Bypass -File .\\986-Windows-Utility.ps1 -DoctorOnly\n```\n\nUse `-DoctorJson` to export a report. Repair buttons remain GUI-only and require explicit action. See [DOCTOR.md](DOCTOR.md).\n'''
save('docs/GETTING_STARTED.md', getting)

# Remove this temporary bootstrap and its workflow from the final branch commit.
for rel in ('tools/apply_v030.py','.github/workflows/v03-integration-bootstrap.yml'):
    path = ROOT / rel
    if path.exists():
        path.unlink()

print('v0.3 integration patch applied')
