$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$app = Join-Path $root '986-Windows-Utility.ps1'
$audit = Join-Path $root 'modules\TweakIntelligence.ps1'
$doctor = Join-Path $root 'modules\Doctor.ps1'
$profiles = Join-Path $root 'modules\Profiles.ps1'
$resolution = Join-Path $root 'display\ResolutionManager.ps1'
$resolutionUi = Join-Path $root 'display\ResolutionUi.ps1'
$bootstrap = Join-Path $root 'bootstrap.ps1'
$changelog = Join-Path $root 'CHANGELOG.md'
foreach ($file in @($app,$audit,$doctor,$profiles,$resolution,$resolutionUi,$bootstrap)) {
    if (-not (Test-Path $file)) { throw "Required script not found: $file" }
    $tokens=$null; $errors=$null
    [System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)|Out-Null
    if ($errors.Count -gt 0) { $errors|ForEach-Object{Write-Host $_.Message -ForegroundColor Red}; throw "Parse validation failed: $file" }
}
if (-not (Test-Path $changelog)) { throw "Required changelog not found: $changelog" }
$text = Get-Content $app -Raw -Encoding UTF8
$auditText = Get-Content $audit -Raw -Encoding UTF8
$doctorText = Get-Content $doctor -Raw -Encoding UTF8
$profilesText = Get-Content $profiles -Raw -Encoding UTF8
$bootText = Get-Content $bootstrap -Raw -Encoding UTF8
$changelogText = Get-Content $changelog -Raw -Encoding UTF8
$ids = [regex]::Matches($text,"Id='([^']+)'\s*; Category=") | ForEach-Object { $_.Groups[1].Value }
if ($ids.Count -ne 34 -or ($ids|Sort-Object -Unique).Count -ne $ids.Count) { throw 'Expected 30 active + 4 legacy unique tweak IDs.' }
$appVersionMatch = [regex]::Match($text,'\$Version = ''([^'']+)''')
$changelogVersionMatch = [regex]::Match($changelogText,'(?m)^## \[([^\]]+)\] - ')
if (-not $appVersionMatch.Success) { throw 'Application version declaration was not found.' }
if (-not $changelogVersionMatch.Success) { throw 'Latest changelog version heading was not found.' }
$appVersion = $appVersionMatch.Groups[1].Value
$changelogVersion = $changelogVersionMatch.Groups[1].Value
if ($appVersion -ne $changelogVersion) { throw "Application version $appVersion does not match latest CHANGELOG version $changelogVersion." }
foreach($mode in '\[switch\]\$AuditOnly','\[switch\]\$DoctorOnly','\[switch\]\$ProfileList'){ if($text -notmatch $mode){throw "Missing headless mode: $mode"} }
foreach($fn in 'Get-TweakIntelligenceReport','Export-TweakAuditReport'){if($auditText -notmatch "function\s+$fn"){throw "Missing audit function: $fn"}}
foreach($fn in 'Get-DoctorReport','Export-DoctorReport','Get-DoctorRepairPreflight','Start-DoctorRepair','Show-DoctorWindow'){if($doctorText -notmatch "function\s+$fn"){throw "Missing Doctor function: $fn"}}
foreach($fn in 'Get-986BuiltInProfiles','Save-986CustomProfile','Get-986ProfileTweakIds'){if($profilesText -notmatch "function\s+$fn"){throw "Missing Profiles function: $fn"}}

$bootstrapContracts = @(
    'releases/latest',
    'SHA256SUMS-v',
    'Get-FileHash',
    'Expand-Archive',
    'display\\986ResolutionHelper\.exe',
    'storage\\bin\\986StorageShell\.dll',
    'storage\\bin\\986StorageScanner\.exe',
    'storage\\registration\\Register-StorageView\.ps1',
    '\$item\.Name -eq ''state'''
)
foreach ($contract in $bootstrapContracts) {
    if ($bootText -notmatch $contract) { throw "Bootstrap stable-release contract missing: $contract" }
}
if ($bootText -match 'raw\.githubusercontent\.com/.+/main/modules/') {
    throw 'Bootstrap must install the complete verified stable release, not partial raw modules.'
}

Write-Host "PASS: v0.7 app/modules parse clean, release version matches CHANGELOG, 30 active + 4 legacy tweaks, Storage and Resolution UI present, verified stable-release bootstrap contract present." -ForegroundColor Green
