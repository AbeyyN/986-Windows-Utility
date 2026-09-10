$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$app = Join-Path $root '986-Windows-Utility.ps1'
$text = Get-Content $app -Raw -Encoding UTF8

$activeMatch = [regex]::Match($text,'(?s)\$Tweaks = @\((.*?)\)\r?\n\r?\n\$LegacyTweaks = @\(')
if (-not $activeMatch.Success) { throw 'Cannot isolate active tweak catalog.' }
$active = $activeMatch.Groups[1].Value
$legacyMatch = [regex]::Match($text,'(?s)\$LegacyTweaks = @\((.*?)\)\r?\n\r?\nfunction Write-AppLog')
if (-not $legacyMatch.Success) { throw 'Cannot isolate legacy tweak catalog.' }
$legacy = $legacyMatch.Groups[1].Value

$activeRows = [regex]::Matches($active,"(?m)^\s*\[pscustomobject\]@\{.*Id='([^']+)'.*$")
if ($activeRows.Count -ne 25) { throw "Expected 25 active preference tweaks; found $($activeRows.Count)." }
foreach ($row in $activeRows) {
    $line = $row.Value
    $id = $row.Groups[1].Value
    if ($line -match '\\Policies\\') { throw "Active tweak uses a Policy path: $id" }
    foreach ($required in 'UserEditable=$true',"Enforcement='None'",'ApplyAllowed=$true','LegacyPolicy=$false') {
        if ($line -notmatch [regex]::Escape($required)) { throw "Active tweak '$id' missing baseline metadata: $required" }
    }
}
$legacyRows = [regex]::Matches($legacy,"(?m)^\s*\[pscustomobject\]@\{.*Id='([^']+)'.*$")
if ($legacyRows.Count -ne 4) { throw "Expected 4 legacy policy tweaks; found $($legacyRows.Count)." }
foreach ($row in $legacyRows) {
    $line = $row.Value
    $id = $row.Groups[1].Value
    foreach ($required in 'UserEditable=$false',"Enforcement='LegacyPolicy'",'ApplyAllowed=$false','LegacyPolicy=$true') {
        if ($line -notmatch [regex]::Escape($required)) { throw "Legacy tweak '$id' missing undo-only metadata: $required" }
    }
}

if ($text -notmatch 'APPLY BLOCKED.*legacy/policy tweak is undo-only') { throw 'Apply engine does not visibly block legacy policy tweaks.' }
$forbiddenAutomation = @('Register-WmiEvent','Register-ObjectEvent','DispatcherTimer','System.Timers.Timer','FileSystemWatcher')
$productionFiles = @((Get-Item $app)) + @(Get-ChildItem (Join-Path $root 'modules') -Filter '*.ps1')
foreach ($file in $productionFiles) {
    $source = Get-Content $file.FullName -Raw -Encoding UTF8
    foreach ($term in $forbiddenAutomation) {
        if ($source -match [regex]::Escape($term)) { throw "Automatic enforcement primitive '$term' found in $($file.Name)." }
    }
}
Write-Host 'PASS: 25 active tweaks are non-policy, user-editable, one-shot preferences; 4 old policy tweaks are undo-only.' -ForegroundColor Green