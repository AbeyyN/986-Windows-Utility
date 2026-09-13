$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$scriptPath = Join-Path $root 'storage\registration\Register-StorageView.ps1'
if (-not (Test-Path $scriptPath)) { throw 'Register-StorageView.ps1 missing.' }

$token = [guid]::NewGuid().ToString('N')
$base = "HKCU:\Software\AbeyyTechXy\986StorageTests\$token"
$class = Join-Path $base 'Class'
$namespace = Join-Path $base 'Namespace'
$tempDll = Join-Path $env:TEMP ("986StorageShell-$token.dll")
[IO.File]::WriteAllBytes($tempDll, (New-Object byte[] 16))
try {
    & $scriptPath -Action Install -DllPath $tempDll -ClassRoot $class -NamespaceRoot $namespace -NoNotify | Out-Null
    if (-not (Test-Path $class) -or -not (Test-Path $namespace)) { throw 'Registration keys not created.' }
    $owner = (Get-ItemProperty $class -Name '986Owner').'986Owner'
    if ($owner -ne 'AbeyyTechXy/986-Windows-Utility') { throw 'Ownership marker missing.' }
    $threading = (Get-Item (Join-Path $class 'InprocServer32')).GetValue('ThreadingModel')
    if ($threading -ne 'Apartment') { throw 'ThreadingModel must be Apartment.' }

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
    Write-Host 'PASS: 986 Storage registration is per-user, reversible and collision-safe.' -ForegroundColor Green
} finally {
    Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $tempDll -Force -ErrorAction SilentlyContinue
}
