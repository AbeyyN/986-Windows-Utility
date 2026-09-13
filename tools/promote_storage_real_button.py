from pathlib import Path

root = Path(__file__).resolve().parents[1]
cpp = root / "storage" / "shell" / "StorageShell.cpp"
test = root / "tests" / "StorageShell.Tests.ps1"
changelog = root / "CHANGELOG.md"

t = cpp.read_text(encoding="utf-8")

def replace_once(old, new, label):
    global t
    if t.count(old) != 1:
        raise SystemExit(f"{label} anchor count={t.count(old)}")
    t = t.replace(old, new, 1)

replace_once(
r"""struct DriveCard {
    std::wstring root;
    ULONGLONG total = 0, free = 0;
    CategoryBytes categories;
    bool cacheLoaded = false;
    bool scanning = false;
    DWORD scanError = ERROR_SUCCESS;
};
""",
r"""struct DriveCard {
    std::wstring root;
    ULONGLONG total = 0, free = 0;
    CategoryBytes categories;
    bool cacheLoaded = false;
    bool scanning = false;
    DWORD scanError = ERROR_SUCCESS;
    HWND scanButton = nullptr;
};
""", "DriveCard")

replace_once(
r"""        if (!hwnd_) return HRESULT_FROM_WIN32(GetLastError());
        settings_ = pfs ? *pfs : FOLDERSETTINGS{};
        SetTimer(hwnd_, 986, 1000, nullptr);
""",
r"""        if (!hwnd_) return HRESULT_FROM_WIN32(GetLastError());
        CreateScanButtons();
        LayoutScanButtons();
        settings_ = pfs ? *pfs : FOLDERSETTINGS{};
        SetTimer(hwnd_, 986, 1000, nullptr);
""", "CreateViewWindow")

replace_once(
r"""        switch (msg) {
            case WM_PAINT: self->Paint(hwnd); return 0;
            case WM_LBUTTONUP: self->Click(GET_X_LPARAM(lp), GET_Y_LPARAM(lp)); return 0;
            case WM_TIMER: self->RefreshCaches(); InvalidateRect(hwnd, nullptr, FALSE); return 0;
            case WM_ERASEBKGND: return 1;
        }
""",
r"""        switch (msg) {
            case WM_PAINT: self->Paint(hwnd); return 0;
            case WM_SIZE: self->LayoutScanButtons(); InvalidateRect(hwnd, nullptr, FALSE); return 0;
            case WM_COMMAND:
                if (HIWORD(wp) == BN_CLICKED && self->ActivateScanButton(LOWORD(wp))) return 0;
                break;
            case WM_DRAWITEM:
                if (self->DrawScanButton(reinterpret_cast<DRAWITEMSTRUCT*>(lp))) return TRUE;
                break;
            case WM_LBUTTONUP: self->Click(GET_X_LPARAM(lp), GET_Y_LPARAM(lp)); return 0;
            case WM_TIMER: self->RefreshCaches(); InvalidateRect(hwnd, nullptr, FALSE); return 0;
            case WM_ERASEBKGND: return 1;
        }
""", "WndProc")

marker = r"""    void RefreshCaches() {
        for (auto& d : drives_) {
            RefreshSpace(d);
            if (d.scanning) {
                if (LoadCache(d)) d.scanning = false;
            }
        }
    }

"""
if t.count(marker) != 1:
    raise SystemExit("RefreshCaches anchor missing")
methods = r"""    enum { kScanButtonBase = 2000 };

    void CreateScanButtons() {
        for (size_t i = 0; i < drives_.size(); ++i) {
            HWND button = CreateWindowExW(0, L"BUTTON", L"Scan / Refresh",
                WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_OWNERDRAW,
                0, 0, 120, 32, hwnd_,
                reinterpret_cast<HMENU>(static_cast<INT_PTR>(kScanButtonBase + i)),
                g_instance, nullptr);
            drives_[i].scanButton = button;
            if (button) {
                HFONT font = static_cast<HFONT>(GetStockObject(DEFAULT_GUI_FONT));
                SendMessageW(button, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE);
            }
        }
    }

    void LayoutScanButtons() {
        if (!hwnd_) return;
        RECT client{};
        GetClientRect(hwnd_, &client);
        int top = 88;
        for (auto& d : drives_) {
            CardLayout layout = BuildCardLayout(client, top);
            if (d.scanButton) {
                MoveWindow(d.scanButton,
                    layout.scanButton.left, layout.scanButton.top,
                    layout.scanButton.right - layout.scanButton.left,
                    layout.scanButton.bottom - layout.scanButton.top, TRUE);
            }
            top += layout.cardHeight + 18;
        }
    }

    bool ActivateScanButton(UINT id) {
        if (id < kScanButtonBase) return false;
        size_t index = static_cast<size_t>(id - kScanButtonBase);
        if (index >= drives_.size()) return false;
        DriveCard& d = drives_[index];
        if (!d.scanning) StartScan(d);
        if (d.scanButton) InvalidateRect(d.scanButton, nullptr, TRUE);
        InvalidateRect(hwnd_, nullptr, FALSE);
        return true;
    }

    bool DrawScanButton(DRAWITEMSTRUCT* dis) {
        if (!dis || dis->CtlType != ODT_BUTTON) return false;
        DriveCard* drive = nullptr;
        for (auto& d : drives_) {
            if (d.scanButton == dis->hwndItem) { drive = &d; break; }
        }
        if (!drive) return false;
        COLORREF fill = drive->scanning ? RGB(71, 85, 105) : RGB(234, 88, 12);
        if ((dis->itemState & ODS_SELECTED) && !drive->scanning) fill = RGB(194, 65, 12);
        HBRUSH brush = CreateSolidBrush(fill);
        FillRect(dis->hDC, &dis->rcItem, brush);
        DeleteObject(brush);
        SetBkMode(dis->hDC, TRANSPARENT);
        SetTextColor(dis->hDC, RGB(255, 255, 255));
        const wchar_t* text = drive->scanning ? L"Scanning..." : L"Scan / Refresh";
        RECT textRect = dis->rcItem;
        DrawTextW(dis->hDC, text, -1, &textRect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        if (dis->itemState & ODS_FOCUS) {
            RECT focus = dis->rcItem;
            InflateRect(&focus, -3, -3);
            DrawFocusRect(dis->hDC, &focus);
        }
        return true;
    }

"""
t = t.replace(marker, methods + marker, 1)

replace_once(
r"""            if (d.scanning) {
                if (LoadCache(d)) d.scanning = false;
            }
""",
r"""            if (d.scanning) {
                if (LoadCache(d)) {
                    d.scanning = false;
                    if (d.scanButton) InvalidateRect(d.scanButton, nullptr, TRUE);
                }
            }
""", "RefreshCaches body")

replace_once(
r"""        d.scanError = ERROR_SUCCESS;
        d.scanning = true; d.cacheLoaded = false; d.categories = CategoryBytes{};
        return true;
""",
r"""        d.scanError = ERROR_SUCCESS;
        d.scanning = true; d.cacheLoaded = false; d.categories = CategoryBytes{};
        if (d.scanButton) InvalidateRect(d.scanButton, nullptr, TRUE);
        return true;
""", "StartScan state")

replace_once(
r"""            HBRUSH button = CreateSolidBrush(d.scanning ? RGB(71, 85, 105) : RGB(234, 88, 12)); FillRect(dc, &layout.scanButton, button); DeleteObject(button);
            SetTextColor(dc, RGB(255, 255, 255));
            const wchar_t* btn = d.scanning ? L"Scanning..." : L"Scan / Refresh";
            DrawTextW(dc, btn, -1, &layout.scanButton, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
            top += cardH + 18;
""",
r"""            top += cardH + 18;
""", "paint pseudo-button")

cpp.write_text(t, encoding="utf-8", newline="\n")

ps = test.read_text(encoding="utf-8")
anchor_test = """foreach ($marker in 'BuildCardLayout','client.right < 520','labelColumns','buttonTop','layout.scanButton','GetClientRect(hwnd_, &client)','CreateProcessW(scanner.c_str()','scanError = GetLastError()') {
    if ($cppText -notmatch [regex]::Escape($marker)) { throw "Missing responsive/dispatch Storage view marker: $marker" }
}
"""
if anchor_test not in ps:
    raise SystemExit("StorageShell.Tests marker missing")
new_test = """foreach ($marker in 'BuildCardLayout','client.right < 520','labelColumns','buttonTop','layout.scanButton','GetClientRect(hwnd_, &client)','CreateProcessW(scanner.c_str()','scanError = GetLastError()','CreateScanButtons','LayoutScanButtons','ActivateScanButton','BN_CLICKED','BS_OWNERDRAW','DrawScanButton') {
    if ($cppText -notmatch [regex]::Escape($marker)) { throw "Missing responsive/dispatch Storage view marker: $marker" }
}
"""
ps = ps.replace(anchor_test, new_test, 1)
test.write_text(ps, encoding="utf-8", newline="\n")

cl = changelog.read_text(encoding="utf-8")
anchor_ch = "- Scan hit-testing now derives from the current Explorer client geometry instead of depending on a hitbox populated by a prior paint cycle.\n"
addition = anchor_ch + "- Promoted Scan / Refresh to a real owner-drawn child `BUTTON` control with `BN_CLICKED` dispatch, keyboard focus and resize-aware layout instead of relying only on parent-window mouse hit-testing.\n"
if cl.count(anchor_ch) != 1:
    raise SystemExit("changelog anchor missing")
changelog.write_text(cl.replace(anchor_ch, addition, 1), encoding="utf-8", newline="\n")

print("STORAGE_REAL_BUTTON_PATCHED")
