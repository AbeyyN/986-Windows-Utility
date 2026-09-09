$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$app = Join-Path $root '986-Windows-Utility.ps1'
$audit = Join-Path $root 'modules\TweakIntelligence.ps1'
$bootstrap = Join-Path $root 'bootstrap.ps1'
foreach ($file in @($app,$audit,$bootstrap)) {
    if (-not (Test-Path $file)) { throw "Required script not found: $file" }
    $tokens=$null; $errors=$null
    [System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)|Out-Null
    if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Host $_.Message -ForegroundColor Red }; throw "Parse validation failed: $file" }
}
$text = Get-Content $app -Raw -Encoding UTF8
$auditText = Get-Content $audit -Raw -Encoding UTF8
$ids = [regex]::Matches($text,"Id='([^']+)'\s*; Category=") | ForEach-Object { $_.Groups[1].Value }
if ($ids.Count -lt 20) { throw "Expected at least 20 tweaks; found $($ids.Count)." }
if (($ids | Sort-Object -Unique).Count -ne $ids.Count) { throw 'Duplicate tweak IDs detected.' }
if ($text -notmatch "Id='taskbar-end-task'.*TaskbarDeveloperSettings'.*Value='TaskbarEndTask'.*Target=1") { throw 'Taskbar End task tweak definition is invalid.' }
if ($text -notmatch '\$Version = ''0\.2\.0''') { throw 'Expected application version 0.2.0.' }
if ($text -notmatch '\[switch\]\$AuditOnly') { throw 'AuditOnly mode is missing.' }
foreach ($fn in 'Test-IsAdministrator','Load-SnapshotState','Save-SnapshotState') { if ($text -notmatch "function\s+$fn") { throw "Missing required function: $fn" } }
foreach ($fn in 'Get-TweakIntelligenceReport','Export-TweakAuditReport','Show-TweakIntelligenceWindow') { if ($auditText -notmatch "function\s+$fn") { throw "Missing audit function: $fn" } }
if ((Get-Content $bootstrap -Raw -Encoding UTF8) -notmatch 'modules/TweakIntelligence\.ps1') { throw 'Bootstrap does not fetch Tweak Intelligence module.' }
Write-Host "PASS: app/module/bootstrap parse clean, $($ids.Count) unique tweaks, v0.2 audit engine present." -ForegroundColor Green
