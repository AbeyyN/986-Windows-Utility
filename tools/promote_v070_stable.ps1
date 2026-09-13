$ErrorActionPreference = 'Stop'

$app = '986-Windows-Utility.ps1'
$appText = Get-Content $app -Raw -Encoding UTF8
if ($appText -notmatch "\$Version = '0\.7\.0-rc\.3'") {
    throw 'Expected v0.7.0-rc.3 source version was not found.'
}
$appText = $appText.Replace("`$Version = '0.7.0-rc.3'", "`$Version = '0.7.0'")
[IO.File]::WriteAllText((Resolve-Path $app), $appText, (New-Object Text.UTF8Encoding($false)))

$changelog = 'CHANGELOG.md'
$changeText = Get-Content $changelog -Raw -Encoding UTF8
if ($changeText -notmatch '## \[0\.7\.0-rc\.3\] - 2026-09-13') {
    throw 'Expected RC3 changelog heading was not found.'
}
$changeText = $changeText.Replace('## [0.7.0-rc.3] - 2026-09-13', '## [0.7.0] - 2026-09-13')
$validationAnchor = '- The hardened shell contract and complete native Storage payload compile passed on the GitHub Windows runner before RC3 promotion.'
$stableValidation = '- Stable promotion gates passed on AbeyyN986: real File Explorer Storage scan/unregister recovery and physical 2240x1400 to 1920x1200 timeout-revert, Keep, fallback-window and exact Undo verification.'
if ($changeText.IndexOf($validationAnchor) -lt 0) { throw 'Stable validation changelog anchor missing.' }
$changeText = $changeText.Replace($validationAnchor, $validationAnchor + "`n" + $stableValidation)
[IO.File]::WriteAllText((Resolve-Path $changelog), $changeText, (New-Object Text.UTF8Encoding($false)))

$tests = @(
    'Encoding.Tests.ps1','Static.Tests.ps1','Audit.Tests.ps1','Doctor.Tests.ps1',
    'Profile.Tests.ps1','NoLock.Tests.ps1','Wave2.Tests.ps1','PreferenceOverride.Tests.ps1',
    'SingleSelection.Tests.ps1','Resolution.Tests.ps1','StorageScanner.Tests.ps1',
    'StorageRegistration.Tests.ps1','StorageShell.Tests.ps1','Gui.Tests.ps1'
)
foreach ($test in $tests) {
    Write-Output ('TEST=' + $test)
    & (Join-Path '.\tests' $test)
    if (-not $?) { throw ('Test failed: ' + $test) }
}

.\986-Windows-Utility.ps1 -AuditOnly | Out-Null
if (-not $?) { throw 'Headless Audit smoke failed.' }
.\986-Windows-Utility.ps1 -DoctorOnly | Out-Null
if (-not $?) { throw 'Headless Doctor smoke failed.' }
.\986-Windows-Utility.ps1 -ProfileList | Out-Null
if (-not $?) { throw 'Headless ProfileList smoke failed.' }

$displayBuild = & .\display\Build-ResolutionHelper.ps1 -OutputDir (Join-Path $env:TEMP '986-v070-display-build')
$storageBuild = & .\storage\Build-StorageView.ps1 -OutputDir (Join-Path $env:TEMP '986-v070-storage-build')
Write-Output ('DISPLAY_SHA256=' + $displayBuild.Sha256)
Write-Output ('STORAGE_SHELL_SHA256=' + $storageBuild.ShellSha256)
Write-Output ('STORAGE_SCANNER_SHA256=' + $storageBuild.ScannerSha256)

Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force
git config user.name 'AbeyyN'
git config user.email '86111714+AbeyyN@users.noreply.github.com'
git add -A
git commit -m 'Promote 986 Windows Utility v0.7.0'
if ($LASTEXITCODE -ne 0) { throw 'Stable promotion commit failed.' }
$newHead = (git rev-parse HEAD).Trim()
git push origin HEAD:feature/v0.7-storage-view
if ($LASTEXITCODE -ne 0) { throw 'Stable promotion push failed.' }
Write-Output ('STABLE_PROMOTION_COMMIT=' + $newHead)
Write-Output 'V070_STABLE_LOCAL_VALIDATION_PASS'
