$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module = Join-Path $root 'display\ResolutionManager.ps1'
if (-not (Test-Path $module)) { throw 'ResolutionManager.ps1 missing.' }
. $module

if (-not (Test-986ResolutionRequest -Width 1920 -Height 1080 -RefreshRate 60)) { throw 'Known-safe request rejected.' }
if (Test-986ResolutionRequest -Width 320 -Height 200 -RefreshRate 60) { throw 'Unsafe tiny mode accepted.' }
if (Test-986ResolutionRequest -Width 1920 -Height 1080 -RefreshRate 10) { throw 'Unsafe refresh accepted.' }

$intel = [pscustomobject]@{ Provider='Intel-IGCL' }
$existing = New-986ResolutionPlan -Adapter $intel -Width 1920 -Height 1080 -RefreshRate 60 -ExistingMode
if (-not $existing.CanApply -or -not $existing.AutoRevertRequired) { throw 'Existing-mode plan safety contract invalid.' }
$custom = New-986ResolutionPlan -Adapter $intel -Width 2560 -Height 1440 -RefreshRate 60
if ($custom.CanApply) { throw 'True custom mode must remain disabled until provider binding is validated.' }
if ($custom.Provider -ne 'Intel-IGCL') { throw 'Provider selection drifted.' }

$text = Get-Content $module -Raw -Encoding UTF8
foreach ($forbidden in '\\EDID','HKLM:','DisplayOverride','OverrideEdidFlags','Set-ItemProperty','New-ItemProperty') {
    if ($text -match $forbidden) { throw "Forbidden custom-resolution hack/enforcement found: $forbidden" }
}
if ($text -match 'Register-WmiEvent|Register-ObjectEvent|ScheduledTask|while\s*\(\s*\$true') {
    throw 'Persistent resolution enforcement primitive found.'
}
Write-Host 'PASS: Custom Resolution capability layer is provider-based, bounded and apply-locked until rollback validation.' -ForegroundColor Green
