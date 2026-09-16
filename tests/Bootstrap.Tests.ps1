$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$bootstrap = Join-Path $root 'bootstrap.ps1'
$updateCenter = Join-Path $root 'modules\UpdateCenter.ps1'
$registration = Join-Path $root 'storage\registration\Register-StorageView.ps1'
foreach ($file in @($bootstrap,$updateCenter,$registration)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing update lifecycle file: $file" }
}

$bootstrapText = Get-Content -LiteralPath $bootstrap -Raw -Encoding UTF8
$updateText = Get-Content -LiteralPath $updateCenter -Raw -Encoding UTF8
$registrationText = Get-Content -LiteralPath $registration -Raw -Encoding UTF8

foreach ($entry in @(
    @{ Name='bootstrap'; Path=$bootstrap; Text=$bootstrapText },
    @{ Name='Update Center'; Path=$updateCenter; Text=$updateText },
    @{ Name='Storage registration'; Path=$registration; Text=$registrationText }
)) {
    try { [void][scriptblock]::Create($entry.Text) }
    catch { throw "$($entry.Name) PowerShell syntax is invalid: $($_.Exception.Message)" }
}

foreach ($marker in 'Get-986InstalledVersion','Copy-986MergeItem','Install-986StoragePayload','versionedShellDir','versionedLogo','SourceLogo','AbeyyTechXy-logo.png','repairMode','Refusing to overwrite a possibly loaded DLL','Explorer restart is not forced') {
    if ($bootstrapText -notmatch [regex]::Escape($marker)) { throw "Missing bootstrap update-safety marker: $marker" }
}
if ($bootstrapText -notmatch [regex]::Escape('Get-FileHash -LiteralPath $Destination -Algorithm SHA256')) {
    throw 'Bootstrap identical-file repair guard is missing.'
}
if ($bootstrapText -notmatch [regex]::Escape("$item.Name -eq 'assets'")) {
    throw 'Bootstrap must merge shared assets so an identical locked legacy logo is not replaced.'
}
if ($bootstrapText -notmatch [regex]::Escape('$installedVersion -eq $releaseVersion')) {
    throw 'Bootstrap same-version repair guard is missing.'
}
if ($bootstrapText -match '(?i)Stop-Process[^\r\n]*explorer|taskkill[^\r\n]*explorer|Stop-Process[^\r\n]*-Name\s+explorer') {
    throw 'Bootstrap must never force-restart Explorer to replace a loaded Storage shell DLL.'
}

foreach ($marker in 'Resolve-986StorageDllPath','versionsRoot','RegisteredDll') {
    if ($registrationText -notmatch [regex]::Escape($marker)) { throw "Missing version-aware Storage registration marker: $marker" }
}

if ($updateText -match [regex]::Escape('Test-986StorageShellLoaded')) {
    throw 'Update Center must not block side-by-side updates merely because the old Storage shell DLL is loaded.'
}
if ($updateText -match [regex]::Escape('Close every 986 Storage window')) {
    throw 'Legacy close-Explorer update blocker text is still present.'
}
foreach ($marker in 'Start-986VerifiedUpdate','-NoLaunch -InstallDir','side-by-side native payloads','Explorer is never force-restarted') {
    if ($updateText -notmatch [regex]::Escape($marker)) { throw "Missing Update Center side-by-side marker: $marker" }
}

Write-Host 'PASS: bootstrap and Update Center use non-destructive, version-aware Storage shell update lifecycle.' -ForegroundColor Green
