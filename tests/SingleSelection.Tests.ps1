$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$app = Join-Path $root '986-Windows-Utility.ps1'
$text = Get-Content $app -Raw -Encoding UTF8
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($app,[ref]$tokens,[ref]$errors)
$fn=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-SelectedTweaks'},$true) | Select-Object -First 1
if (-not $fn) { throw 'Get-SelectedTweaks missing.' }
Invoke-Expression $fn.Extent.Text
$script:DisplayedTweaks=@([pscustomobject]@{Id='only-one'})
$script:Rows=@{'only-one'=[pscustomobject]@{Check=[pscustomobject]@{IsChecked=$true}}}
$selected=@(Get-SelectedTweaks)
if ($selected.Count -ne 1) { throw 'Single tweak selection did not normalize to a one-item array.' }
$calls=([regex]::Matches($text,[regex]::Escape('$selected = @(Get-SelectedTweaks)'))).Count
if ($calls -ne 3) { throw "Expected 3 array-safe selection call sites; found $calls." }
Write-Host 'PASS: exactly-one-tweak selection is array-safe in Save, Apply and Undo paths.' -ForegroundColor Green