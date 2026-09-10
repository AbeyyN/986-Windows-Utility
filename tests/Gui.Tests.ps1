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

foreach ($name in 'ProfilePicker','BtnProfileSelect','BtnProfileSave','BtnProfileDelete','BtnApply','BtnUndo','TweakPanel','LogBox') {
    if (-not $window.FindName($name)) { throw "WPF control missing: $name" }
}
foreach ($handler in '$BtnProfileSelect.Add_Click','$BtnProfileSave.Add_Click','$BtnProfileDelete.Add_Click') {
    if ($text -notmatch [regex]::Escape($handler)) { throw "Profile UI handler missing: $handler" }
}
if ($text -notmatch [regex]::Escape('986 never locks or auto-reapplies them')) { throw 'Never-Lock user message missing from GUI.' }
$window.Close()
Write-Host 'PASS: v0.5 WPF XAML loads, profile controls are wired, and Never-Lock message is present.' -ForegroundColor Green