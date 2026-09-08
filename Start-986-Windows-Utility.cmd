@echo off
set "APP=%~dp0986-Windows-Utility.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%APP%"
if errorlevel 1 pause
