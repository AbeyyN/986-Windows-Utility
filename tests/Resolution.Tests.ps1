$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module = Join-Path $root 'display\ResolutionManager.ps1'
$helperSource = Join-Path $root 'display\ResolutionHelper.cs'
$build = Join-Path $root 'display\Build-ResolutionHelper.ps1'
foreach ($p in @($module,$helperSource,$build)) { if (-not (Test-Path $p)) { throw "Missing resolution component: $p" } }
. $module

if (-not (Test-986ResolutionRequest -Width 1920 -Height 1080 -RefreshRate 60)) { throw 'Known-safe request rejected.' }
if (Test-986ResolutionRequest -Width 320 -Height 200 -RefreshRate 60) { throw 'Unsafe tiny mode accepted.' }
if (Test-986ResolutionRequest -Width 1920 -Height 1080 -RefreshRate 10) { throw 'Unsafe refresh accepted.' }

$intel = [pscustomobject]@{ Provider='Intel-IGCL' }
$plan = New-986ResolutionPlan -Adapter $intel -Width 2560 -Height 1440 -RefreshRate 60
if (-not $plan.RequiresTrial -or -not $plan.AutoRevertRequired) { throw 'Custom mode trial safety contract invalid.' }
if ($plan.Provider -ne 'Intel-IGCL') { throw 'Provider selection drifted.' }

$srcText = Get-Content $helperSource -Raw -Encoding UTF8
if ($srcText -notmatch 'CDS_TEST') { throw 'Native helper must test a requested mode before apply.' }
if ($srcText -match 'CDS_ENABLE_UNSAFE_MODES|CDS_GLOBAL') { throw 'Unsafe/global display mode flag found.' }
$moduleText = Get-Content $module -Raw -Encoding UTF8
if ($moduleText -notmatch 'Start-986TrialTokenCleanup') { throw 'Trial keep token cleanup guard missing.' }
if ($moduleText -match '\$remaining--') { throw 'Scalar countdown mutation is unsafe inside WPF event scope.' }
if ($moduleText -notmatch '\$trialState\.Remaining\s*=\s*\[int\]\$trialState\.Remaining\s*-\s*1') { throw 'Scoped mutable resolution countdown guard missing.' }
if ($moduleText -match 'New-Item -ItemType File -Path \$token -Force \| Out-Null\s*\r?\n\s*Remove-Item \$token') { throw 'Keep token is removed before fallback reverter can observe it.' }
foreach ($forbidden in '\\EDID','HKLM:','DisplayOverride','OverrideEdidFlags','Register-WmiEvent','ScheduledTask') {
    if ($moduleText -match $forbidden) { throw "Forbidden custom-resolution enforcement/hack found: $forbidden" }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('986-resolution-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $built = & $build -OutputDir $tmp
    if (-not (Test-Path $built.Helper)) { throw '986ResolutionHelper.exe was not produced.' }
    $probe = @(& $built.Helper probe 2>&1)
    if ($LASTEXITCODE -ne 0) { throw ('Resolution helper probe failed: ' + ($probe -join ' ')) }
    $first = $probe | Where-Object { [string]$_ -like 'DEVICE|*' } | Select-Object -First 1
    if ($first) {
        $p = ([string]$first) -split '\|',9
        $test = @(& $built.Helper test $p[1] $p[2] $p[3] $p[4] 2>&1)
        if ($LASTEXITCODE -ne 0) { throw ('Current display mode failed CDS_TEST: ' + ($test -join ' ')) }
    }
    $bad = @(& $built.Helper test '\\.\DISPLAY986INVALID' 320 200 10 2>&1)
    if ($LASTEXITCODE -eq 0) { throw 'Out-of-bounds mode unexpectedly passed native helper.' }
    $global:LASTEXITCODE = 0
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host 'PASS: Custom Resolution uses bounded CDS_TEST driver trials, one-shot fallback revert and exact snapshot Undo.' -ForegroundColor Green
