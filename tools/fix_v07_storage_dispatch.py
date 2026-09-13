from pathlib import Path

root = Path(__file__).resolve().parents[1]
cpp = root / 'storage' / 'shell' / 'StorageShell.cpp'
test = root / 'tests' / 'StorageShell.Tests.ps1'

text = cpp.read_text(encoding='utf-8')

old_drive = '''struct DriveCard {
    std::wstring root;
    ULONGLONG total = 0, free = 0;
    CategoryBytes categories;
    bool cacheLoaded = false;
    bool scanning = false;
    RECT scanButton{};
};
'''
new_drive = '''struct DriveCard {
    std::wstring root;
    ULONGLONG total = 0, free = 0;
    CategoryBytes categories;
    bool cacheLoaded = false;
    bool scanning = false;
    DWORD scanError = ERROR_SUCCESS;
};

struct CardLayout {
    RECT card{};
    RECT bar{};
    RECT scanButton{};
    int contentWidth = 0;
    int labelColumns = 1;
    int labelRows = 1;
    int labelY = 0;
    int buttonTop = 0;
    int cardHeight = 0;
};

static CardLayout BuildCardLayout(const RECT& client, int top) {
    CardLayout layout{};
    const int margin = client.right < 520 ? 14 : 28;
    const int left = margin;
    const int right = max(left + 180, client.right - margin);
    layout.contentWidth = max(1, right - left - 36);
    layout.labelColumns = layout.contentWidth >= 700 ? 4 : (layout.contentWidth >= 260 ? 2 : 1);
    layout.labelRows = (7 + layout.labelColumns - 1) / layout.labelColumns;
    layout.labelY = top + 82;
    layout.buttonTop = layout.labelY + layout.labelRows * 25 + 8;
    layout.cardHeight = (layout.buttonTop - top) + 32 + 16;
    layout.card = RECT{ left, top, right, top + layout.cardHeight };
    layout.bar = RECT{ left + 18, top + 48, right - 18, top + 68 };
    layout.scanButton = RECT{ max(left + 18, right - 150), layout.buttonTop, right - 18, layout.buttonTop + 32 };
    return layout;
}
'''
if text.count(old_drive) != 1:
    raise SystemExit('DriveCard anchor missing or duplicated')
text = text.replace(old_drive, new_drive, 1)

old_start = '''    bool StartScan(DriveCard& d) {
        std::wstring scanner = ModuleDirectory() + L"\\\\986StorageScanner.exe";
        if (GetFileAttributesW(scanner.c_str()) == INVALID_FILE_ATTRIBUTES) return false;
        std::wstring cache = CachePath(d.root);
        DeleteFileW(cache.c_str());
        std::wstring cmd = L"\\\"" + scanner + L"\\\" \\\"" + d.root + L"\\\" \\\"" + cache + L"\\\"";
        std::vector<wchar_t> mutableCmd(cmd.begin(), cmd.end()); mutableCmd.push_back(L'\\0');
        STARTUPINFOW si{}; si.cb = sizeof(si); si.dwFlags = STARTF_USESHOWWINDOW; si.wShowWindow = SW_HIDE;
        PROCESS_INFORMATION pi{};
        if (!CreateProcessW(nullptr, mutableCmd.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) return false;
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        d.scanning = true; d.cacheLoaded = false; d.categories = CategoryBytes{};
        return true;
    }

    void Click(int x, int y) {
        POINT p{ x, y };
        for (auto& d : drives_) {
            if (PtInRect(&d.scanButton, p) && !d.scanning) {
                StartScan(d); InvalidateRect(hwnd_, nullptr, FALSE); break;
            }
        }
    }
'''
new_start = '''    bool StartScan(DriveCard& d) {
        const std::wstring moduleDir = ModuleDirectory();
        const std::wstring scanner = moduleDir + L"\\\\986StorageScanner.exe";
        if (GetFileAttributesW(scanner.c_str()) == INVALID_FILE_ATTRIBUTES) {
            d.scanError = GetLastError();
            return false;
        }
        std::wstring cache = CachePath(d.root);
        DeleteFileW(cache.c_str());
        std::wstring cmd = L"\\\"" + scanner + L"\\\" \\\"" + d.root + L"\\\" \\\"" + cache + L"\\\"";
        std::vector<wchar_t> mutableCmd(cmd.begin(), cmd.end()); mutableCmd.push_back(L'\\0');
        STARTUPINFOW si{}; si.cb = sizeof(si); si.dwFlags = STARTF_USESHOWWINDOW; si.wShowWindow = SW_HIDE;
        PROCESS_INFORMATION pi{};
        if (!CreateProcessW(scanner.c_str(), mutableCmd.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, moduleDir.c_str(), &si, &pi)) {
            d.scanError = GetLastError();
            return false;
        }
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        d.scanError = ERROR_SUCCESS;
        d.scanning = true; d.cacheLoaded = false; d.categories = CategoryBytes{};
        return true;
    }

    void Click(int x, int y) {
        POINT p{ x, y };
        RECT client{};
        GetClientRect(hwnd_, &client);
        int top = 88;
        for (auto& d : drives_) {
            CardLayout layout = BuildCardLayout(client, top);
            if (PtInRect(&layout.scanButton, p) && !d.scanning) {
                StartScan(d); InvalidateRect(hwnd_, nullptr, FALSE); break;
            }
            top += layout.cardHeight + 18;
        }
    }
'''
if text.count(old_start) != 1:
    raise SystemExit('StartScan/Click anchor missing or duplicated')
text = text.replace(old_start, new_start, 1)

old_layout = '''        for (auto& d : drives_) {
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
            HBRUSH cardBrush = CreateSolidBrush(RGB(30, 41, 59)); FillRect(dc, &card, cardBrush); DeleteObject(cardBrush);
'''
new_layout = '''        for (auto& d : drives_) {
            CardLayout layout = BuildCardLayout(client, top);
            const int left = layout.card.left;
            const int right = layout.card.right;
            const int contentWidth = layout.contentWidth;
            const int labelColumns = layout.labelColumns;
            const int labelY = layout.labelY;
            const int buttonTop = layout.buttonTop;
            const int cardH = layout.cardHeight;
            HBRUSH cardBrush = CreateSolidBrush(RGB(30, 41, 59)); FillRect(dc, &layout.card, cardBrush); DeleteObject(cardBrush);
'''
if text.count(old_layout) != 1:
    raise SystemExit('Paint layout anchor missing or duplicated')
text = text.replace(old_layout, new_layout, 1)

old_bar = '''            RECT bar{ left + 18, top + 48, right - 18, top + 68 };
            HBRUSH usedBase = CreateSolidBrush(RGB(71, 85, 105)); FillRect(dc, &bar, usedBase); DeleteObject(usedBase);
'''
new_bar = '''            RECT bar = layout.bar;
            HBRUSH usedBase = CreateSolidBrush(RGB(71, 85, 105)); FillRect(dc, &bar, usedBase); DeleteObject(usedBase);
'''
if text.count(old_bar) != 1:
    raise SystemExit('bar anchor missing or duplicated')
text = text.replace(old_bar, new_bar, 1)

old_message = '''            } else {
                const wchar_t* msg = d.scanning ? L"Scanning in background... Explorer remains responsive." : L"No category cache yet. Scan this drive to analyze storage.";
                RECT messageRect{ left + 18, labelY, right - 18, buttonTop - 4 };
                DrawTextW(dc, msg, -1, &messageRect, DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
            }

            d.scanButton = RECT{ max(left + 18, right - 150), buttonTop, right - 18, buttonTop + 32 };
            HBRUSH button = CreateSolidBrush(d.scanning ? RGB(71, 85, 105) : RGB(234, 88, 12)); FillRect(dc, &d.scanButton, button); DeleteObject(button);
            SetTextColor(dc, RGB(255, 255, 255));
            const wchar_t* btn = d.scanning ? L"Scanning..." : L"Scan / Refresh";
            DrawTextW(dc, btn, -1, &d.scanButton, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
            top += cardH + 18;
'''
new_message = '''            } else {
                std::wstring msg;
                if (d.scanning) msg = L"Scanning in background... Explorer remains responsive.";
                else if (d.scanError != ERROR_SUCCESS) {
                    wchar_t errorText[160]{};
                    swprintf_s(errorText, L"Scanner launch failed (Windows error %lu). Try Scan / Refresh again.", d.scanError);
                    msg = errorText;
                } else msg = L"No category cache yet. Scan this drive to analyze storage.";
                RECT messageRect{ left + 18, labelY, right - 18, buttonTop - 4 };
                DrawTextW(dc, msg.c_str(), -1, &messageRect, DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
            }

            HBRUSH button = CreateSolidBrush(d.scanning ? RGB(71, 85, 105) : RGB(234, 88, 12)); FillRect(dc, &layout.scanButton, button); DeleteObject(button);
            SetTextColor(dc, RGB(255, 255, 255));
            const wchar_t* btn = d.scanning ? L"Scanning..." : L"Scan / Refresh";
            DrawTextW(dc, btn, -1, &layout.scanButton, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
            top += cardH + 18;
'''
if text.count(old_message) != 1:
    raise SystemExit('message/button anchor missing or duplicated')
text = text.replace(old_message, new_message, 1)

cpp.write_text(text, encoding='utf-8', newline='\n')

ps = test.read_text(encoding='utf-8')
anchor = "foreach ($marker in 'client.right < 520','labelColumns','buttonTop','max(left + 18, right - 150)') {\n    if ($cppText -notmatch [regex]::Escape($marker)) { throw \"Missing responsive Storage view marker: $marker\" }\n}\n"
replacement = "foreach ($marker in 'BuildCardLayout','client.right < 520','labelColumns','buttonTop','layout.scanButton','GetClientRect(hwnd_, &client)','CreateProcessW(scanner.c_str()','scanError = GetLastError()') {\n    if ($cppText -notmatch [regex]::Escape($marker)) { throw \"Missing responsive/dispatch Storage view marker: $marker\" }\n}\nif ($cppText -match 'PtInRect\\(&d\\.scanButton') { throw 'Click dispatch must not depend on a paint-populated DriveCard hitbox.' }\n"
if ps.count(anchor) != 1:
    raise SystemExit('StorageShell responsive test anchor missing or duplicated')
ps = ps.replace(anchor, replacement, 1)
test.write_text(ps, encoding='utf-8', newline='\n')

print('V07_STORAGE_DISPATCH_HARDENED')
