# 986 Windows Utility bootstrap
$ErrorActionPreference = 'Stop'
$uri = 'https://raw.githubusercontent.com/AbeyyN/986-Windows-Utility/main/986-Windows-Utility.ps1'
$dir = Join-Path $env:TEMP '986-Windows-Utility'
$file = Join-Path $dir '986-Windows-Utility.ps1'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Write-Host 'Downloading 986 Windows Utility...' -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $file
Write-Host "Saved to $file" -ForegroundColor DarkGray
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file
