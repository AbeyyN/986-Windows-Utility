$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$app = Join-Path $root '986-Windows-Utility.ps1'
$tokens=$null; $errors=$null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($app,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'Main app has parse errors.' }
$needed = @('Save-SnapshotState','Get-RegistryState','Test-TweakActive','Capture-OriginalState','Apply-Tweak','Undo-Tweak')
foreach ($name in $needed) {
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name },$true) | Select-Object -First 1
    if (-not $fn) { throw "Missing engine function: $name" }
    Invoke-Expression $fn.Extent.Text
}

$testId = [guid]::NewGuid().ToString('N')
$StateDir = Join-Path ([IO.Path]::GetTempPath()) ('986-pref-' + $testId)
$StateFile = Join-Path $StateDir 'state.json'
New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
function Write-AppLog([string]$Message) { }
$key = "HKCU:\Software\AbeyyTechXy\986-Windows-Utility\Tests\$testId"
$tweak = [pscustomobject]@{ Id='test-pref'; Path=$key; Value='Preference'; Type='DWord'; Target=1; ApplyAllowed=$true }
$state = @{}
try {
    if (-not (Apply-Tweak $tweak $state)) { throw 'Engine apply failed on isolated preference key.' }
    if (-not (Test-TweakActive $tweak)) { throw 'Target did not verify after apply.' }
    Set-ItemProperty -Path $key -Name 'Preference' -Value 0
    Start-Sleep -Seconds 2
    $manual = Get-RegistryState $tweak
    if (-not $manual.Exists -or [int]$manual.Value -ne 0) { throw 'Manual user override did not persist.' }
    if (Test-TweakActive $tweak) { throw '986 unexpectedly re-applied target after manual override.' }

    $blocked = [pscustomobject]@{ Id='test-legacy'; Path=$key; Value='Blocked'; Type='DWord'; Target=1; ApplyAllowed=$false }
    if (Apply-Tweak $blocked $state) { throw 'Undo-only legacy tweak was allowed to apply.' }
    if ((Get-RegistryState $blocked).Exists) { throw 'Blocked legacy apply changed Registry state.' }

    if (-not (Undo-Tweak $tweak $state)) { throw 'Undo failed after user override.' }
    if ((Get-RegistryState $tweak).Exists) { throw 'Undo did not restore original absent state.' }
    Write-Host 'PASS: Apply is one-shot, manual user override persists, legacy apply is blocked, Undo restores exact original.' -ForegroundColor Green
} finally {
    Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $StateDir -Recurse -Force -ErrorAction SilentlyContinue
}