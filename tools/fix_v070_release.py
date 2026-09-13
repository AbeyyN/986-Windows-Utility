from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'display' / 'ResolutionManager.ps1'
t = p.read_text(encoding='utf-8')
old = """function Start-986FallbackReverter {\n    param([Parameter(Mandatory=$true)]$Display,[Parameter(Mandatory=$true)][string]$TokenPath,[int]$Seconds=20)\n    $helper = Get-986ResolutionHelperPath\n    $device = [string]$Display.DeviceName\n    $script = @\"\nStart-Sleep -Seconds $Seconds\nif (-not (Test-Path '$($TokenPath.Replace(\"'\",\"''\"))')) {\n    & '$($helper.Replace(\"'\",\"''\"))' apply-temp '$($device.Replace(\"'\",\"''\"))' $($Display.Width) $($Display.Height) $($Display.RefreshRate) | Out-Null\n}\n\"@\n    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))\n    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) | Out-Null\n}\n"""
new = old + """\nfunction Start-986TrialTokenCleanup {\n    param([Parameter(Mandatory=$true)][string]$TokenPath,[int]$Seconds=35)\n    $script = @\"\nStart-Sleep -Seconds $Seconds\nRemove-Item -LiteralPath '$($TokenPath.Replace(\"'\",\"''\"))' -Force -ErrorAction SilentlyContinue\n\"@\n    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))\n    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) | Out-Null\n}\n"""
if old not in t: raise SystemExit('fallback function anchor missing')
t = t.replace(old,new,1)
t = t.replace("""        Remove-Item $token -Force -ErrorAction SilentlyContinue\n        return [pscustomobject]@{ Kept=($persist.ExitCode -eq 0);""", """        Start-986TrialTokenCleanup -TokenPath $token -Seconds ($Seconds + 20)\n        return [pscustomobject]@{ Kept=($persist.ExitCode -eq 0);""",1)
t = t.replace("""    Remove-Item $token -Force -ErrorAction SilentlyContinue\n    [pscustomobject]@{ Kept=$false; Status='REVERTED';""", """    Start-986TrialTokenCleanup -TokenPath $token -Seconds ($Seconds + 20)\n    [pscustomobject]@{ Kept=$false; Status='REVERTED';""",1)
p.write_text(t,encoding='utf-8',newline='\n')

tp = Path(__file__).resolve().parents[1] / 'tests' / 'Resolution.Tests.ps1'
s = tp.read_text(encoding='utf-8')
anchor = "$moduleText = Get-Content $module -Raw -Encoding UTF8\n"
insert = anchor + "if ($moduleText -notmatch 'Start-986TrialTokenCleanup') { throw 'Trial keep token cleanup guard missing.' }\nif ($moduleText -match 'New-Item -ItemType File -Path \\$token -Force \\| Out-Null\\s*\\r?\\n\\s*Remove-Item \\$token') { throw 'Keep token is removed before fallback reverter can observe it.' }\n"
if anchor not in s: raise SystemExit('resolution test anchor missing')
s=s.replace(anchor,insert,1)
tp.write_text(s,encoding='utf-8',newline='\n')
print('V070_RELEASE_SAFETY_FIXED')
# trigger
