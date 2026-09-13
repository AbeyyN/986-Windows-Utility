param([string]$OutputDir)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $OutputDir) { $OutputDir = Join-Path $root 'artifacts\986Storage' }
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$scannerSource = Join-Path $root 'storage\scanner\StorageScanner.cs'
$shellSource = Join-Path $root 'storage\shell\StorageShell.cpp'
$shellDef = Join-Path $root 'storage\shell\StorageShell.def'
$scannerOut = Join-Path $OutputDir '986StorageScanner.exe'
$shellOut = Join-Path $OutputDir '986StorageShell.dll'

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw 'Framework64 csc.exe not found.' }
& $csc /nologo /target:exe /out:$scannerOut /r:System.Runtime.Serialization.dll $scannerSource
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $scannerOut)) { throw 'Storage scanner build failed.' }

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { throw 'vswhere.exe not found; Visual C++ Build Tools are required for the shell DLL.' }
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Visual C++ x64 toolchain not found.' }
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
if (-not (Test-Path $vcvars)) { throw "vcvars64.bat not found: $vcvars" }
$cmd = '"' + $vcvars + '" && cl /nologo /std:c++17 /EHsc /DUNICODE /D_UNICODE /LD "' + $shellSource + '" /link /DEF:"' + $shellDef + '" ole32.lib shell32.lib user32.lib gdi32.lib uuid.lib /OUT:"' + $shellOut + '"'
$compileOutput = @(& cmd.exe /d /c $cmd 2>&1)
$compileOutput | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $shellOut)) { throw 'Storage shell DLL build failed.' }

[pscustomobject]@{
    OutputDir = $OutputDir
    Scanner = $scannerOut
    Shell = $shellOut
    ScannerSha256 = (Get-FileHash $scannerOut -Algorithm SHA256).Hash.ToLowerInvariant()
    ShellSha256 = (Get-FileHash $shellOut -Algorithm SHA256).Hash.ToLowerInvariant()
}
