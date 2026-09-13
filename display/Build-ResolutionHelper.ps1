param([string]$OutputDir)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $OutputDir) { $OutputDir = Join-Path $root 'artifacts\986Display' }
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$source = Join-Path $root 'display\ResolutionHelper.cs'
$out = Join-Path $OutputDir '986ResolutionHelper.exe'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw 'Framework64 csc.exe not found.' }
& $csc /nologo /target:exe /out:$out $source
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) { throw 'Resolution helper build failed.' }
[pscustomobject]@{
    Helper = $out
    Sha256 = (Get-FileHash $out -Algorithm SHA256).Hash.ToLowerInvariant()
}
