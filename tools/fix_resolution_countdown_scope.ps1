$ErrorActionPreference = 'Stop'

$manager = 'display\ResolutionManager.ps1'
$text = Get-Content $manager -Raw -Encoding UTF8
$old = @'
    $script:trialChoice = 'timeout'; $remaining = $Seconds
    $timer = New-Object Windows.Threading.DispatcherTimer; $timer.Interval=[TimeSpan]::FromSeconds(1)
    $update = { $text.Text = "Testing $Width x $Height @ $RefreshRate Hz.`nKeep this mode? Auto-revert in $remaining seconds." }
    & $update
    $timer.Add_Tick({ $remaining--; & $update; if ($remaining -le 0) { $timer.Stop(); $window.Close() } })
    $keep.Add_Click({ $script:trialChoice='keep'; $timer.Stop(); $window.Close() })
    $revert.Add_Click({ $script:trialChoice='revert'; $timer.Stop(); $window.Close() })
    $timer.Start(); $window.ShowDialog() | Out-Null

    if ($script:trialChoice -eq 'keep') {
'@
$new = @'
    $trialState = [pscustomobject]@{ Choice='timeout'; Remaining=[int]$Seconds }
    $timer = New-Object Windows.Threading.DispatcherTimer; $timer.Interval=[TimeSpan]::FromSeconds(1)
    $update = { $text.Text = "Testing $Width x $Height @ $RefreshRate Hz.`nKeep this mode? Auto-revert in $($trialState.Remaining) seconds." }
    & $update
    $timer.Add_Tick({
        $trialState.Remaining = [int]$trialState.Remaining - 1
        & $update
        if ($trialState.Remaining -le 0) { $timer.Stop(); $window.Close() }
    })
    $keep.Add_Click({ $trialState.Choice='keep'; $timer.Stop(); $window.Close() })
    $revert.Add_Click({ $trialState.Choice='revert'; $timer.Stop(); $window.Close() })
    $timer.Start(); $window.ShowDialog() | Out-Null

    if ($trialState.Choice -eq 'keep') {
'@
if ($text.IndexOf($old) -lt 0) { throw 'Resolution countdown anchor missing' }
$text = $text.Replace($old,$new)
[IO.File]::WriteAllText((Resolve-Path $manager),$text,(New-Object Text.UTF8Encoding($false)))

$tests = 'tests\Resolution.Tests.ps1'
$testText = Get-Content $tests -Raw -Encoding UTF8
$anchor = "if (`$moduleText -notmatch 'Start-986TrialTokenCleanup') { throw 'Trial keep token cleanup guard missing.' }"
$insert = $anchor + "`nif (`$moduleText -match '\`$remaining--') { throw 'Scalar countdown mutation is unsafe inside WPF event scope.' }`nif (`$moduleText -notmatch '\`$trialState\.Remaining\s*=\s*\[int\]\`$trialState\.Remaining\s*-\s*1') { throw 'Scoped mutable resolution countdown guard missing.' }"
if ($testText.IndexOf($anchor) -lt 0) { throw 'Resolution test anchor missing' }
$testText = $testText.Replace($anchor,$insert)
[IO.File]::WriteAllText((Resolve-Path $tests),$testText,(New-Object Text.UTF8Encoding($false)))

$changelog = 'CHANGELOG.md'
$changeText = Get-Content $changelog -Raw -Encoding UTF8
$heading = '### Fixed'
$index = $changeText.IndexOf($heading)
if ($index -lt 0) { throw 'CHANGELOG Fixed heading missing' }
$replacement = $heading + "`n- Fixed Custom Resolution Keep/Revert countdown state scoping so the DispatcherTimer always reaches the 15-second auto-revert deadline instead of stalling in a PowerShell event-handler child scope."
$changeText = $changeText.Remove($index,$heading.Length).Insert($index,$replacement)
[IO.File]::WriteAllText((Resolve-Path $changelog),$changeText,(New-Object Text.UTF8Encoding($false)))

Write-Output 'RESOLUTION_COUNTDOWN_SOURCE_PATCHED'
