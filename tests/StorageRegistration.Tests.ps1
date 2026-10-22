$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$scriptPath = Join-Path $root 'storage\registration\Register-StorageView.ps1'
if (-not (Test-Path $scriptPath)) { throw 'Register-StorageView.ps1 missing.' }

$token = [guid]::NewGuid().ToString('N')
$base = "HKCU:\Software\AbeyyTechXy\986StorageTests\$token"
$class = Join-Path $base 'Class'
$namespace = Join-Path $base 'Namespace'
$tempRoot = Join-Path $env:TEMP ("986StorageRegistration-$token")
$binDir = Join-Path $tempRoot 'storage\bin'
$v81Dir = Join-Path $tempRoot 'storage\versions\v0.8.1'
$v82Dir = Join-Path $tempRoot 'storage\versions\v0.8.2'
New-Item -ItemType Directory -Force -Path $binDir,$v81Dir,$v82Dir | Out-Null
$tempDll = Join-Path $binDir '986StorageShell.dll'
$v81Dll = Join-Path $v81Dir '986StorageShell.dll'
$v82Dll = Join-Path $v82Dir '986StorageShell.dll'
[IO.File]::WriteAllBytes($tempDll, (New-Object byte[] 16))
[IO.File]::WriteAllBytes($v81Dll, (New-Object byte[] 17))
[IO.File]::WriteAllBytes($v82Dll, (New-Object byte[] 18))
try {
    $status = & $scriptPath -Action Install -DllPath $tempDll -ClassRoot $class -NamespaceRoot $namespace -NoNotify
    if (-not (Test-Path $class) -or -not (Test-Path $namespace)) { throw 'Registration keys not created.' }
    $owner = (Get-ItemProperty $class -Name '986Owner').'986Owner'
    if ($owner -ne 'AbeyyTechXy/986-Windows-Utility') { throw 'Ownership marker missing.' }
    $threading = (Get-Item (Join-Path $class 'InprocServer32')).GetValue('ThreadingModel')
    if ($threading -ne 'Apartment') { throw 'ThreadingModel must be Apartment.' }

    $registered = [IO.Path]::GetFullPath([string](Get-Item (Join-Path $class 'InprocServer32')).GetValue(''))
    $expected = [IO.Path]::GetFullPath($v82Dll)
    if (-not [string]::Equals($registered,$expected,[StringComparison]::OrdinalIgnoreCase)) {
        throw "Versioned shell resolver did not choose newest stable payload. Got: $registered"
    }
    if (-not [string]::Equals([IO.Path]::GetFullPath([string]$status.RegisteredDll),$expected,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Status did not report the registered versioned DLL.'
    }

    & $scriptPath -Action Remove -ClassRoot $class -NamespaceRoot $namespace -NoNotify | Out-Null
    if ((Test-Path $class) -or (Test-Path $namespace)) { throw 'Owned registration was not removed.' }

    New-Item -ItemType Directory -Path $class -Force | Out-Null
    New-ItemProperty -Path $class -Name '986Owner' -Value 'ForeignOwner' -PropertyType String -Force | Out-Null
    $blocked = $false
    try { & $scriptPath -Action Install -DllPath $tempDll -ClassRoot $class -NamespaceRoot $namespace -NoNotify | Out-Null } catch { $blocked = $true }
    if (-not $blocked) { throw 'Foreign CLSID collision was not blocked.' }
    if (-not (Test-Path $class)) { throw 'Foreign registration was deleted.' }

    $text = Get-Content $scriptPath -Raw -Encoding UTF8
    if ($text -match 'HKLM:|regsvr32|DllRegisterServer') { throw 'Machine-wide/self-registration path found.' }
    foreach ($marker in 'Resolve-986StorageDllPath','storage\versions','RegisteredDll') {
        if ($text -notmatch [regex]::Escape($marker)) { throw "Missing versioned shell registration marker: $marker" }
    }
    Write-Host 'PASS: 986 Storage registration is per-user, reversible, collision-safe and version-aware.' -ForegroundColor Green
} finally {
    Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
