from pathlib import Path

root = Path(__file__).resolve().parents[1]
cpp = root / 'storage' / 'shell' / 'StorageShell.cpp'
test = root / 'tests' / 'StorageShell.Tests.ps1'

text = cpp.read_text(encoding='utf-8')
old_layout = """        for (auto& d : drives_) {
            const int left = 28, right = max(left + 640, client.right - 28), cardH = 184;
            RECT card{ left, top, right, top + cardH };
"""
new_layout = """        for (auto& d : drives_) {
            const int margin = client.right < 520 ? 14 : 28;
            const int left = margin;
            const int right = max(left + 180, client.right - margin);
            const int contentWidth = max(1, right - left - 36);
            const int labelColumns = contentWidth >= 700 ? 4 : (contentWidth >= 260 ? 2 : 1);
            const int labelRows = (7 + labelColumns - 1) / labelColumns;
            const int labelY = top + 82;
            const int buttonTop = labelY + labelRows * 25 + 8;
            const int cardH = (buttonTop - top) + 32 + 16;
            RECT card{ left, top, right, top + cardH };
"""
if text.count(old_layout) != 1:
    raise SystemExit('responsive layout anchor missing or duplicated')
text = text.replace(old_layout, new_layout, 1)

old_labels = """            SetTextColor(dc, RGB(203, 213, 225));
            const wchar_t* names[] = { L\"Apps\", L\"Videos\", L\"Pictures\", L\"Documents\", L\"Audio\", L\"System\", L\"Other\" };
            int labelY = top + 82;
            if (d.cacheLoaded) {
                for (int row = 0; row < 2; ++row) {
                    int labelX = left + 18;
                    int start = row * 4, end = min(start + 4, 7);
                    for (int i = start; i < end; ++i) {
                        std::wstring value = FormatGb(values[i]);
                        wchar_t line[96]{}; swprintf_s(line, L\"%s %s\", names[i], value.c_str());
                        TextOutW(dc, labelX, labelY + row * 25, line, static_cast<int>(wcslen(line)));
                        labelX += 185;
                    }
                }
            } else {
                const wchar_t* msg = d.scanning ? L\"Scanning in background... Explorer remains responsive.\" : L\"No category cache yet. Scan this drive to analyze storage.\";
                TextOutW(dc, left + 18, labelY, msg, static_cast<int>(wcslen(msg)));
            }

            d.scanButton = RECT{ right - 150, top + 136, right - 18, top + 168 };
"""
new_labels = """            SetTextColor(dc, RGB(203, 213, 225));
            const wchar_t* names[] = { L\"Apps\", L\"Videos\", L\"Pictures\", L\"Documents\", L\"Audio\", L\"System\", L\"Other\" };
            if (d.cacheLoaded) {
                const int columnWidth = max(1, contentWidth / labelColumns);
                for (int i = 0; i < 7; ++i) {
                    const int row = i / labelColumns;
                    const int col = i % labelColumns;
                    const int labelX = left + 18 + col * columnWidth;
                    std::wstring value = FormatGb(values[i]);
                    wchar_t line[96]{}; swprintf_s(line, L\"%s %s\", names[i], value.c_str());
                    TextOutW(dc, labelX, labelY + row * 25, line, static_cast<int>(wcslen(line)));
                }
            } else {
                const wchar_t* msg = d.scanning ? L\"Scanning in background... Explorer remains responsive.\" : L\"No category cache yet. Scan this drive to analyze storage.\";
                RECT messageRect{ left + 18, labelY, right - 18, buttonTop - 4 };
                DrawTextW(dc, msg, -1, &messageRect, DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
            }

            d.scanButton = RECT{ max(left + 18, right - 150), buttonTop, right - 18, buttonTop + 32 };
"""
if text.count(old_labels) != 1:
    raise SystemExit('responsive label/button anchor missing or duplicated')
text = text.replace(old_labels, new_labels, 1)
cpp.write_text(text, encoding='utf-8', newline='\n')

ps = test.read_text(encoding='utf-8')
anchor = "if ($defText -match 'DllRegisterServer|DllUnregisterServer') { throw 'Self-registration export found.' }\n"
extra = anchor + "if ($cppText -match 'max\\(left \\+ 640') { throw 'Storage view must not force a 640px card width.' }\nforeach ($marker in 'client.right < 520','labelColumns','buttonTop','max(left + 18, right - 150)') {\n    if ($cppText -notmatch [regex]::Escape($marker)) { throw \"Missing responsive Storage view marker: $marker\" }\n}\n"
if ps.count(anchor) != 1:
    raise SystemExit('StorageShell test anchor missing or duplicated')
ps = ps.replace(anchor, extra, 1)
test.write_text(ps, encoding='utf-8', newline='\n')
print('V07_STORAGE_RESPONSIVE_PATCHED')
