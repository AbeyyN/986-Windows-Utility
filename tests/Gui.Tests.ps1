$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$app = Join-Path $root '986-Windows-Utility.ps1'
$text = Get-Content $app -Raw -Encoding UTF8

$match = [regex]::Match($text,'(?s)\[xml\]\$Xaml\s*=\s*@"\r?\n(.*?)\r?\n"@')
if (-not $match.Success) { throw 'Unable to extract WPF XAML from main application.' }

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
[xml]$xml = $match.Groups[1].Value
$reader = New-Object System.Xml.XmlNodeReader $xml
$window = [Windows.Markup.XamlReader]::Load($reader)

foreach ($name in 'ProfilePicker','BtnProfileSelect','BtnProfileSave','BtnProfileDelete','BtnApply','BtnUndo','BtnStorage','BtnResolution','BrandWatermark','TweakPanel','LogBox') {
    if (-not $window.FindName($name)) { throw "WPF control missing: $name" }
}
foreach ($handler in '$BtnProfileSelect.Add_Click','$BtnProfileSave.Add_Click','$BtnProfileDelete.Add_Click','$BtnStorage.Add_Click','$BtnResolution.Add_Click') {
    if ($text -notmatch [regex]::Escape($handler)) { throw "Profile UI handler missing: $handler" }
}
if ($text -notmatch [regex]::Escape('986 never locks or auto-reapplies them')) { throw 'Never-Lock user message missing from GUI.' }
if ($text -notmatch 'x:Name="BrandWatermark"[^>]+Opacity="0\.30"') { throw 'Main-shell 30% brand watermark host missing.' }
if ($text -notmatch 'x:Name="BrandWatermark"[^>]+Panel\.ZIndex="50"') { throw 'Main-shell watermark must render above opaque content layers.' }
if ($text -notmatch 'Style TargetType="ComboBoxItem"') { throw 'Dark ComboBoxItem popup theme missing.' }
if ($text -notmatch [regex]::Escape("assets\AbeyyTechXy-logo.png")) { throw 'Canonical AbeyyTechXy logo path missing from main shell.' }
$brandAsset = Join-Path $root 'assets\AbeyyTechXy-logo.png'
if (-not (Test-Path $brandAsset)) { throw 'Canonical AbeyyTechXy logo asset missing.' }


$resolutionUi = Get-Content (Join-Path $root 'display\ResolutionUi.ps1') -Raw -Encoding UTF8
if ($resolutionUi -notmatch 'x:Name="HeightBox"[^>]+IsReadOnly="True"') { throw 'Custom Resolution height must be read-only.' }
if ($resolutionUi -notmatch 'Aspect ratio locked') { throw 'Aspect-lock user message missing.' }
if ($resolutionUi -notmatch [regex]::Escape('Optimized for external monitors and desktop displays. Laptop built-in panels may have limited custom-resolution support.')) { throw '986 Custom Resolution suitability note missing.' }

$window.Close()
Write-Host 'PASS: v0.8 alpha WPF loads, Storage/Resolution controls are wired, and Never-Lock message is present.' -ForegroundColor Green