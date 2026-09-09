$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$app = Join-Path $root '986-Windows-Utility.ps1'
$module = Join-Path $root 'modules\Profiles.ps1'
if (-not (Test-Path $app)) { throw 'Main application not found.' }
if (-not (Test-Path $module)) { throw 'Profiles module not found.' }

$appText = Get-Content $app -Raw -Encoding UTF8
$profileText = Get-Content $module -Raw -Encoding UTF8
$tokens=$null; $errors=$null
[System.Management.Automation.Language.Parser]::ParseFile($module,[ref]$tokens,[ref]$errors) | Out-Null
if ($errors.Count -gt 0) { throw 'Profiles module has PowerShell parse errors.' }

foreach ($fn in 'Get-986BuiltInProfiles','Get-986CustomProfiles','Save-986CustomProfile','Remove-986CustomProfile','Get-986ProfileNames','Get-986ProfileTweakIds') {
    if ($profileText -notmatch "function\s+$fn") { throw "Missing profile function: $fn" }
}

$forbidden = @('New-ItemProperty','Remove-ItemProperty','Set-ItemProperty','Set-Service','Stop-Service','Start-Service','DISM.exe','sfc.exe','netsh.exe','ipconfig.exe /flushdns','Checkpoint-Computer')
foreach ($term in $forbidden) {
    if ($profileText -match [regex]::Escape($term)) { throw "Profiles module must not change Windows state: $term" }
}

$ids = [regex]::Matches($appText,"Id='([^']+)'\s*; Category=") | ForEach-Object { $_.Groups[1].Value }
$balancedIds = [regex]::Matches($appText,"Id='([^']+)'[^\r\n]+Balanced=\$true") | ForEach-Object { $_.Groups[1].Value }

$StateDir = Join-Path $env:TEMP ('986-profile-test-' + [guid]::NewGuid().ToString('N'))
function Write-AppLog([string]$Message) { }
. $module

$profiles = @(Get-986BuiltInProfiles)
$expectedNames = @('986 Balanced','986 Performance','986 Laptop','986 Technician')
foreach ($name in $expectedNames) {
    if (-not @($profiles | Where-Object Name -eq $name).Count) { throw "Missing built-in profile: $name" }
}

foreach ($profile in $profiles) {
    if (@($profile.TweakIds).Count -eq 0) { throw "Profile is empty: $($profile.Name)" }
    foreach ($id in @($profile.TweakIds)) {
        if ($ids -notcontains $id) { throw "Profile '$($profile.Name)' references unknown tweak '$id'." }
    }
}

$balancedProfile = @(Get-986ProfileTweakIds '986 Balanced' | Sort-Object -Unique)
$balancedSource = @($balancedIds | Sort-Object -Unique)
if (($balancedProfile -join '|') -ne ($balancedSource -join '|')) { throw '986 Balanced profile must exactly match Balanced=$true tweak metadata.' }

try {
    $saved = Save-986CustomProfile 'Test Profile' @('show-ext','taskbar-end-task','show-ext')
    if ($saved -ne 'Test Profile') { throw 'Custom profile save did not return expected name.' }
    $custom = Get-986Profile 'Test Profile'
    if (-not $custom -or @($custom.TweakIds).Count -ne 2) { throw 'Custom profile did not persist unique tweak IDs.' }
    if (-not (Remove-986CustomProfile 'Test Profile')) { throw 'Custom profile delete failed.' }
    if (Get-986Profile 'Test Profile') { throw 'Deleted custom profile is still present.' }
    if (Test-986CustomProfileName '986 Balanced') { throw 'Built-in profile name must be reserved.' }
} finally {
    Remove-Item -Path $StateDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "PASS: $($profiles.Count) built-in profiles are selection-only, valid and custom profile persistence works." -ForegroundColor Green
