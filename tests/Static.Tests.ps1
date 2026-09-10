$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$app = Join-Path $root '986-Windows-Utility.ps1'
$audit = Join-Path $root 'modules\TweakIntelligence.ps1'
$doctor = Join-Path $root 'modules\Doctor.ps1'
$profiles = Join-Path $root 'modules\Profiles.ps1'
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
$ids = [regex]::Matches($text,"Id='([^']+)'\s*; Category=") | ForEach-Object { $_.Groups[1].Value }
if ($ids.Count -ne 29 -or ($ids|Sort-Object -Unique).Count -ne $ids.Count) { throw 'Expected 25 active + 4 legacy unique tweak IDs.' }
if ($text -notmatch '\$Version = ''0\.5\.0-alpha\.1''') { throw 'Expected application version 0.5.0-alpha.1.' }
foreach($mode in '\[switch\]\$AuditOnly','\[switch\]\$DoctorOnly','\[switch\]\$ProfileList'){ if($text -notmatch $mode){throw "Missing headless mode: $mode"} }
foreach($fn in 'Get-TweakIntelligenceReport','Export-TweakAuditReport'){if($auditText -notmatch "function\s+$fn"){throw "Missing audit function: $fn"}}
foreach($fn in 'Get-DoctorReport','Export-DoctorReport','Get-DoctorRepairPreflight','Start-DoctorRepair','Show-DoctorWindow'){if($doctorText -notmatch "function\s+$fn"){throw "Missing Doctor function: $fn"}}
foreach($fn in 'Get-986BuiltInProfiles','Save-986CustomProfile','Get-986ProfileTweakIds'){if($profilesText -notmatch "function\s+$fn"){throw "Missing Profiles function: $fn"}}
if ($bootText -notmatch 'modules/TweakIntelligence\.ps1' -or $bootText -notmatch 'modules/Doctor\.ps1' -or $bootText -notmatch 'modules/Profiles\.ps1') { throw 'Bootstrap module downloads are incomplete.' }
Write-Host "PASS: v0.5 alpha app/modules/bootstrap parse clean, 25 active + 4 legacy tweaks, Profiles present." -ForegroundColor Green