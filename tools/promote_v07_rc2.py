from pathlib import Path

root = Path(__file__).resolve().parents[1]

app = root / '986-Windows-Utility.ps1'
t = app.read_text(encoding='utf-8')
old = "$Version = '0.7.0-rc.1'"
new = "$Version = '0.7.0-rc.2'"
if t.count(old) != 1:
    raise SystemExit('app version anchor missing or duplicated')
app.write_text(t.replace(old, new, 1), encoding='utf-8', newline='\n')

changelog = root / 'CHANGELOG.md'
c = changelog.read_text(encoding='utf-8')
anchor = '## [0.7.0-rc.1] - 2026-09-13\n'
if anchor not in c:
    raise SystemExit('RC1 changelog anchor missing')
rc2 = '''## [0.7.0-rc.2] - 2026-09-13

### Fixed
- Made the native `986 Storage` renderer responsive to narrow real File Explorer content panes instead of forcing a 640px minimum card width.
- Storage category labels now adapt between 4, 2, or 1 columns and the `Scan / Refresh` control remains inside the visible card geometry.

### Validation
- RC1 physical-machine smoke testing on `AbeyyN986` proved per-user COM registration and a real `986StorageViewWindow` opened inside File Explorer, and exposed the narrow-pane Scan button regression before stable promotion.
- Added a regression guard that rejects the old forced 640px card layout.

'''
changelog.write_text(c.replace(anchor, rc2 + anchor, 1), encoding='utf-8', newline='\n')

storage = root / 'validation' / 'v07-storage-real-machine.ps1'
s = storage.read_text(encoding='utf-8')
s = s.replace("$work = Join-Path $env:TEMP '986-v07-rc1-validation'", "$work = Join-Path $env:TEMP '986-v07-rc2-validation'", 1)
old_click = '''    $x = $rect.Right - 84
    $y = 240
    if ($x -lt 1 -or $rect.Bottom -lt 257) { throw 'Explorer storage view too small for scan button gate' }
'''
new_click = '''    $cardTop = 88
    $margin = if ($rect.Right -lt 520) { 14 } else { 28 }
    $left = $margin
    $right = [Math]::Max($left + 180, $rect.Right - $margin)
    $contentWidth = [Math]::Max(1, $right - $left - 36)
    $columns = if ($contentWidth -ge 700) { 4 } elseif ($contentWidth -ge 260) { 2 } else { 1 }
    $rows = [int][Math]::Ceiling(7.0 / $columns)
    $labelY = $cardTop + 82
    $buttonTop = $labelY + ($rows * 25) + 8
    $buttonLeft = [Math]::Max($left + 18, $right - 150)
    $buttonRight = $right - 18
    $x = [int](($buttonLeft + $buttonRight) / 2)
    $y = $buttonTop + 16
    Write-Output ('SCAN_BUTTON_RECT=' + $buttonLeft + ',' + $buttonTop + ',' + $buttonRight + ',' + ($buttonTop + 32))
    if ($x -lt 1 -or $y -lt 1 -or $x -ge $rect.Right -or $y -ge $rect.Bottom) { throw 'Responsive Scan button is outside the real Explorer client area' }
'''
if old_click not in s:
    raise SystemExit('storage click anchor missing')
s = s.replace(old_click, new_click, 1)
storage.write_text(s, encoding='utf-8', newline='\n')

display = root / 'validation' / 'v07-display-real-machine.ps1'
d = display.read_text(encoding='utf-8')
old_work = "$work = Join-Path $env:TEMP '986-v07-rc1-validation'"
if old_work not in d:
    raise SystemExit('display work anchor missing')
display.write_text(d.replace(old_work, "$work = Join-Path $env:TEMP '986-v07-rc2-validation'", 1), encoding='utf-8', newline='\n')

print('V07_RC2_PROMOTED')
