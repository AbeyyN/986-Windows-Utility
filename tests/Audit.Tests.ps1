$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$audit = Join-Path $root 'modules\TweakIntelligence.ps1'
$text = Get-Content $audit -Raw -Encoding UTF8
$forbidden = @(
    'Set-ItemProperty','New-ItemProperty','Remove-ItemProperty',
    'Set-Service','Stop-Service','Start-Service',
    'Disable-ScheduledTask','Enable-ScheduledTask','Set-ScheduledTask','Unregister-ScheduledTask'
)
foreach ($command in $forbidden) {
    if ($text -match "(?im)^\s*$([regex]::Escape($command))\b") {
        throw "Read-only audit module contains forbidden system mutation command: $command"
    }
}
if ($text -notmatch 'ReadOnly=\$true') { throw 'Audit report must declare ReadOnly=true.' }
if ($text -notmatch 'attribution is not proven') { throw 'Attribution warning is missing.' }
Write-Host 'PASS: Tweak Intelligence module is statically read-only and attribution-safe.' -ForegroundColor Green
