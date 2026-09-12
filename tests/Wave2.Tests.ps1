$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$app=Join-Path $root '986-Windows-Utility.ps1'
$text=Get-Content $app -Raw -Encoding UTF8
$defs=@(
 @{Id='always-show-scrollbars';Path='HKCU:\Control Panel\Accessibility';Value='DynamicScrollbars';Type='DWord';Target='0'},
 @{Id='show-battery-percentage';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Value='IsBatteryPercentageEnabled';Type='DWord';Target='1'},
 @{Id='center-taskbar';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Value='TaskbarAl';Type='DWord';Target='1'},
 @{Id='enable-window-snapping';Path='HKCU:\Control Panel\Desktop';Value='WindowArrangementActive';Type='String';Target='1'},
 @{Id='disable-storage-sense';Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy';Value='01';Type='DWord';Target='0'}
)
foreach($d in $defs){
 $line=($text -split "`r?`n" | Where-Object {$_ -match "Id='$([regex]::Escape($d.Id))'"})
 if(@($line).Count -ne 1){throw "Expected exactly one Wave 2 definition: $($d.Id)"}
 $line=[string]$line
 foreach($required in @("Path='$($d.Path)'","Value='$($d.Value)'","Type='$($d.Type)'","UserEditable=`$true","Enforcement='None'","ApplyAllowed=`$true","LegacyPolicy=`$false")){
  if($line -notmatch [regex]::Escape($required)){throw "Wave 2 '$($d.Id)' missing: $required"}
 }
 if($line -notmatch ("Target=('?"+[regex]::Escape($d.Target)+"'?)")){throw "Wave 2 '$($d.Id)' target mismatch"}
}
Write-Host 'PASS: 5 Wave 2 Windows Settings tweaks have exact user-editable preference definitions.' -ForegroundColor Green
