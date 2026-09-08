$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$app = Join-Path $root '986-Windows-Utility.ps1'
if (-not (Test-Path $app)) { throw 'Application script not found.' }

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($app, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host $_.Message -ForegroundColor Red }
    throw 'PowerShell parse validation failed.'
}

$text = Get-Content $app -Raw
$ids = [regex]::Matches($text, "Id='([^']+)'\s*; Category=") | ForEach-Object { $_.Groups[1].Value }
if ($ids.Count -lt 18) { throw "Expected at least 18 tweaks; found $($ids.Count)." }
if (($ids | Sort-Object -Unique).Count -ne $ids.Count) { throw 'Duplicate tweak IDs detected.' }
if ($text -notmatch '\$Version = ''0\.1\.0''') { throw 'Expected application version 0.1.0.' }
foreach ($fn in 'Test-IsAdministrator','Load-SnapshotState','Save-SnapshotState') {
    if ($text -notmatch "function\s+$fn") { throw "Missing required function: $fn" }
}
Write-Host "PASS: parse clean, $($ids.Count) unique tweaks, required state functions present." -ForegroundColor Green