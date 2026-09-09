$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$doctor = Join-Path $root 'modules\Doctor.ps1'
if (-not (Test-Path $doctor)) { throw 'Doctor module missing.' }
$text = Get-Content $doctor -Raw -Encoding UTF8
$tokens=$null; $errors=$null
[System.Management.Automation.Language.Parser]::ParseFile($doctor,[ref]$tokens,[ref]$errors)|Out-Null
if ($errors.Count) { throw 'Doctor module parse failed.' }
foreach($fn in 'Get-DoctorReport','Export-DoctorReport','Get-DoctorRepairPreflight','Start-DoctorRepair','Show-DoctorWindow') {
    if($text -notmatch "function\s+$fn"){throw "Missing Doctor function: $fn"}
}
if($text -notmatch "DISM\.exe'.*?/Online /Cleanup-Image /RestoreHealth") { throw 'DISM RestoreHealth definition missing.' }
if($text -notmatch "sfc\.exe'.*?/scannow") { throw 'SFC definition missing.' }
if($text -notmatch 'MessageBoxButton\]::YesNo') { throw 'Repair confirmation guard missing.' }
if($text -match '\$env:(USERNAME|COMPUTERNAME)') { throw 'Doctor report must not include username/computer name.' }
if($text -notmatch 'UTF8Encoding\]::new\(\$false\)') { throw 'Doctor report must export UTF-8 without BOM.' }
if($text -notmatch 'No repair runs automatically') { throw 'Doctor safety declaration missing.' }
Write-Host 'PASS: Doctor diagnostics, repair definitions, privacy and confirmation guards validated.' -ForegroundColor Green
