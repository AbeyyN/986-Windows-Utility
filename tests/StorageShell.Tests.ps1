$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$cpp = Join-Path $root 'storage\shell\StorageShell.cpp'
$guid = Join-Path $root 'storage\shell\StorageGuids.h'
$def = Join-Path $root 'storage\shell\StorageShell.def'
foreach ($file in @($cpp,$guid,$def)) { if (-not (Test-Path $file)) { throw "Missing shell source: $file" } }

$cppText = Get-Content $cpp -Raw -Encoding UTF8
$guidText = Get-Content $guid -Raw -Encoding UTF8
$defText = Get-Content $def -Raw -Encoding UTF8
$clsid = '{5FCCE720-D806-4B6A-A5F1-F060344FC88D}'
if ($guidText -notmatch [regex]::Escape($clsid)) { throw '986 Storage CLSID drifted.' }
foreach ($surface in 'IShellFolder','IPersistFolder2','IShellView','IClassFactory','DllGetClassObject','DllCanUnloadNow') {
    if ($cppText -notmatch [regex]::Escape($surface)) { throw "Missing native shell surface: $surface" }
}
if ($cppText -match 'DllRegisterServer|DllUnregisterServer|RegCreateKey|RegSetValue|HKEY_LOCAL_MACHINE') {
    throw 'Native shell DLL must not self-register or write registry state.'
}
if ($defText -match 'DllRegisterServer|DllUnregisterServer') { throw 'Self-registration export found.' }
if ($cppText -match 'max\(left \+ 640') { throw 'Storage view must not force a 640px card width.' }
foreach ($marker in 'BuildCardLayout','client.right < 520','labelColumns','buttonTop','layout.scanButton','GetClientRect(hwnd_, &client)','CreateProcessW(scanner.c_str()','scanError = GetLastError()') {
    if ($cppText -notmatch [regex]::Escape($marker)) { throw "Missing responsive/dispatch Storage view marker: $marker" }
}
if ($cppText -match 'PtInRect\(&d\.scanButton') { throw 'Click dispatch must not depend on a paint-populated DriveCard hitbox.' }
foreach ($marker in 'QuoteCommandLineArg','QuoteCommandLineArg(scanner)','QuoteCommandLineArg(d.root)','QuoteCommandLineArg(cache)') {
    if ($cppText -notmatch [regex]::Escape($marker)) { throw "Missing safe scanner command-line marker: $marker" }
}
if ($cppText -match [regex]::Escape('L"\\" " + d.root')) { throw 'Drive roots must not use naive quoted trailing-backslash command-line construction.' }
Write-Host 'PASS: Storage shell CLSID, COM surface and no-self-registration contract validated.' -ForegroundColor Green
