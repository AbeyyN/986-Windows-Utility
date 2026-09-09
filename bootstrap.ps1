# 986 Windows Utility bootstrap
$ErrorActionPreference = 'Stop'
$base = 'https://raw.githubusercontent.com/AbeyyN/986-Windows-Utility/main'
$dir = Join-Path $env:TEMP '986-Windows-Utility'
$moduleDir = Join-Path $dir 'modules'
$file = Join-Path $dir '986-Windows-Utility.ps1'
$auditModule = Join-Path $moduleDir 'TweakIntelligence.ps1'
$doctorModule = Join-Path $moduleDir 'Doctor.ps1'
New-Item -ItemType Directory -Force -Path $moduleDir | Out-Null
Write-Host 'Downloading 986 Windows Utility...' -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing -Uri "$base/986-Windows-Utility.ps1" -OutFile $file
Invoke-WebRequest -UseBasicParsing -Uri "$base/modules/TweakIntelligence.ps1" -OutFile $auditModule
Invoke-WebRequest -UseBasicParsing -Uri "$base/modules/Doctor.ps1" -OutFile $doctorModule
Write-Host "Saved to $dir" -ForegroundColor DarkGray
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file
