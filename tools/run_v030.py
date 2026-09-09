from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
target = root / 'tools' / 'apply_v030.py'
s = target.read_text(encoding='utf-8')
old_open = "save('tests/Static.Tests.ps1', '''"
old_close = "\\n''')\n\n# CI adds a real headless Doctor smoke test."
if old_open not in s or old_close not in s:
    raise SystemExit('v0.3 delimiter anchors not found')
s = s.replace(old_open, "save('tests/Static.Tests.ps1', \"\"\"", 1)
s = s.replace(old_close, "\\n\"\"\")\n\n# CI adds a real headless Doctor smoke test.", 1)
target.write_text(s, encoding='utf-8', newline='\n')
runpy.run_path(str(target), run_name='__main__')
Path(__file__).unlink()
