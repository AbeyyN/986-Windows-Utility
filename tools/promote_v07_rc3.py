from pathlib import Path

root = Path(__file__).resolve().parents[1]

app = root / '986-Windows-Utility.ps1'
text = app.read_text(encoding='utf-8')
old = "$Version = '0.7.0-rc.2'"
new = "$Version = '0.7.0-rc.3'"
if text.count(old) != 1:
    raise SystemExit('RC2 application version anchor missing or duplicated')
app.write_text(text.replace(old, new, 1), encoding='utf-8', newline='\n')

changelog = root / 'CHANGELOG.md'
c = changelog.read_text(encoding='utf-8')
anchor = '## [0.7.0-rc.2] - 2026-09-13\n'
if anchor not in c:
    raise SystemExit('RC2 changelog anchor missing')
entry = '''## [0.7.0-rc.3] - 2026-09-13

### Fixed
- Hardened native `986 Storage` Scan / Refresh dispatch after RC2 physical-machine testing proved the scanner binary was healthy but the Explorer button path did not launch it.
- Scan hit-testing now derives from the current Explorer client geometry instead of depending on a hitbox populated by a prior paint cycle.
- Scanner process launch now supplies the executable path and working directory explicitly and records Windows launch errors for the user-visible storage card.

### Validation
- RC2 official ZIP checksum, per-user COM registration, real File Explorer `986StorageViewWindow`, and responsive 374px-wide button geometry were verified on `AbeyyN986`.
- The RC2 scanner executable independently produced valid JSON on the same machine, isolating the failure to Explorer dispatch rather than scanner packaging or scan logic.
- The hardened shell contract and complete native Storage payload compile passed on the GitHub Windows runner before RC3 promotion.

'''
changelog.write_text(c.replace(anchor, entry + anchor, 1), encoding='utf-8', newline='\n')

for rel in ('validation/v07-storage-real-machine.ps1','validation/v07-display-real-machine.ps1'):
    p = root / rel
    s = p.read_text(encoding='utf-8')
    if '986-v07-rc2-validation' in s:
        s = s.replace('986-v07-rc2-validation','986-v07-rc3-validation')
        p.write_text(s, encoding='utf-8', newline='\n')

print('V07_RC3_PROMOTED')
