#define INITGUID
#include <windows.h>
#include <windowsx.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <new>
#include <vector>
#include <string>
#include <algorithm>
#include <gdiplus.h>
#include "StorageGuids.h"

static HINSTANCE g_instance = nullptr;
static long g_moduleRefs = 0;
static const wchar_t kStorageViewClass[] = L"986StorageViewWindow";
static const COLORREF k986Black = RGB(0, 0, 0);

static void ModuleAddRef() { InterlockedIncrement(&g_moduleRefs); }
static void ModuleRelease() { InterlockedDecrement(&g_moduleRefs); }

struct CategoryBytes {
    ULONGLONG apps = 0, videos = 0, pictures = 0, documents = 0;
    ULONGLONG audio = 0, system = 0, other = 0;
};

struct DriveCard {
    std::wstring root;
    ULONGLONG total = 0, free = 0;
    CategoryBytes categories;
    bool cacheLoaded = false;
    bool scanning = false;
    DWORD scanError = ERROR_SUCCESS;
    HWND scanButton = nullptr;
    std::wstring topFilesPreview;
    std::wstring topFoldersPreview;
    std::wstring recommendationPreview;
};

struct CardLayout {
    RECT card{};
    RECT bar{};
    RECT scanButton{};
    int contentWidth = 0;
    int labelColumns = 1;
    int labelRows = 1;
    int labelY = 0;
    int intelY = 0;
    int intelHeight = 0;
    int buttonTop = 0;
    int cardHeight = 0;
};

static CardLayout BuildCardLayout(const RECT& client, int top, bool intelligence) {
    CardLayout layout{};
    const int margin = client.right < 520 ? 14 : 28;
    const int left = margin;
    const int right = max(left + 180, client.right - margin);
    layout.contentWidth = max(1, right - left - 36);
    layout.labelColumns = layout.contentWidth >= 700 ? 4 : (layout.contentWidth >= 260 ? 2 : 1);
    layout.labelRows = (7 + layout.labelColumns - 1) / layout.labelColumns;
    layout.labelY = top + 82;
    layout.intelY = layout.labelY + layout.labelRows * 25 + 10;
    layout.intelHeight = intelligence ? (layout.contentWidth >= 520 ? 150 : 235) : 0;
    layout.buttonTop = layout.intelY + layout.intelHeight + 8;
    layout.cardHeight = (layout.buttonTop - top) + 32 + 16;
    layout.card = RECT{ left, top, right, top + layout.cardHeight };
    layout.bar = RECT{ left + 18, top + 48, right - 18, top + 68 };
    layout.scanButton = RECT{ max(left + 18, right - 150), layout.buttonTop, right - 18, layout.buttonTop + 32 };
    return layout;
}

static std::wstring ModuleDirectory() {
    wchar_t path[MAX_PATH]{};
    GetModuleFileNameW(g_instance, path, MAX_PATH);
    wchar_t* slash = wcsrchr(path, L'\\');
    if (slash) *slash = L'\0';
    return path;
}

static std::wstring CacheDirectory() {
    wchar_t local[MAX_PATH]{};
    DWORD n = GetEnvironmentVariableW(L"LOCALAPPDATA", local, MAX_PATH);
    std::wstring path = n ? local : L".";
    path += L"\\AbeyyTechXy\\986-Windows-Utility\\storage-cache";
    SHCreateDirectoryExW(nullptr, path.c_str(), nullptr);
    return path;
}

static std::wstring CachePath(const std::wstring& root) {
    wchar_t drive = root.empty() ? L'X' : root[0];
    std::wstring path = CacheDirectory();
    path += L"\\drive-";
    path.push_back(drive);
    path += L".json";
    return path;
}

static std::wstring QuoteCommandLineArg(const std::wstring& arg) {
    if (arg.empty()) return L"\"\"";
    if (arg.find_first_of(L" \t\n\v\"") == std::wstring::npos) return arg;
    std::wstring out = L"\"";
    size_t backslashes = 0;
    for (wchar_t ch : arg) {
        if (ch == L'\\') {
            ++backslashes;
            continue;
        }
        if (ch == L'\"') {
            out.append(backslashes * 2 + 1, L'\\');
            out.push_back(L'\"');
            backslashes = 0;
            continue;
        }
        out.append(backslashes, L'\\');
        backslashes = 0;
        out.push_back(ch);
    }
    out.append(backslashes * 2, L'\\');
    out.push_back(L'\"');
    return out;
}

static bool ReadUtf8File(const std::wstring& path, std::string& out) {
    HANDLE h = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return false;
    LARGE_INTEGER size{};
    if (!GetFileSizeEx(h, &size) || size.QuadPart <= 0 || size.QuadPart > 4 * 1024 * 1024) {
        CloseHandle(h);
        return false;
    }
    out.resize(static_cast<size_t>(size.QuadPart));
    DWORD got = 0;
    BOOL ok = ReadFile(h, &out[0], static_cast<DWORD>(out.size()), &got, nullptr);
    CloseHandle(h);
    if (!ok) return false;
    out.resize(got);
    return true;
}

static ULONGLONG JsonNumber(const std::string& json, const char* name) {
    std::string key = std::string("\"") + name + "\":";
    size_t p = json.find(key);
    if (p == std::string::npos) return 0;
    p += key.size();
    while (p < json.size() && (json[p] == ' ' || json[p] == '\t')) ++p;
    ULONGLONG value = 0;
    while (p < json.size() && json[p] >= '0' && json[p] <= '9') {
        value = value * 10 + static_cast<unsigned>(json[p] - '0');
        ++p;
    }
    return value;
}

static int HexValue(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static void AppendUtf8CodePoint(std::string& out, unsigned cp) {
    if (cp <= 0x7F) out.push_back(static_cast<char>(cp));
    else if (cp <= 0x7FF) {
        out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else {
        out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
}

static std::wstring Utf8ToWide(const std::string& text) {
    if (text.empty()) return L"";
    int chars = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0);
    if (chars <= 0) return L"";
    std::wstring out(static_cast<size_t>(chars), L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), &out[0], chars);
    return out;
}

static std::wstring JsonString(const std::string& json, const char* name) {
    std::string key = std::string("\"") + name + "\":";
    size_t p = json.find(key);
    if (p == std::string::npos) return L"";
    p += key.size();
    while (p < json.size() && (json[p] == ' ' || json[p] == '\t')) ++p;
    if (p >= json.size() || json[p] != '"') return L"";
    ++p;
    std::string decoded;
    while (p < json.size()) {
        char c = json[p++];
        if (c == '"') break;
        if (c != '\\') { decoded.push_back(c); continue; }
        if (p >= json.size()) break;
        char esc = json[p++];
        switch (esc) {
            case '"': decoded.push_back('"'); break;
            case '\\': decoded.push_back('\\'); break;
            case '/': decoded.push_back('/'); break;
            case 'b': decoded.push_back('\b'); break;
            case 'f': decoded.push_back('\f'); break;
            case 'n': decoded.push_back('\n'); break;
            case 'r': decoded.push_back('\r'); break;
            case 't': decoded.push_back('\t'); break;
            case 'u': {
                if (p + 4 > json.size()) break;
                unsigned cp = 0; bool ok = true;
                for (int i = 0; i < 4; ++i) { int h = HexValue(json[p + i]); if (h < 0) { ok = false; break; } cp = (cp << 4) | static_cast<unsigned>(h); }
                if (ok) { AppendUtf8CodePoint(decoded, cp); p += 4; }
                break;
            }
            default: decoded.push_back(esc); break;
        }
    }
    return Utf8ToWide(decoded);
}

static bool LoadCache(DriveCard& d) {
    std::string json;
    if (!ReadUtf8File(CachePath(d.root), json)) return false;
    d.categories.apps = JsonNumber(json, "Apps");
    d.categories.videos = JsonNumber(json, "Videos");
    d.categories.pictures = JsonNumber(json, "Pictures");
    d.categories.documents = JsonNumber(json, "Documents");
    d.categories.audio = JsonNumber(json, "Audio");
    d.categories.system = JsonNumber(json, "System");
    d.categories.other = JsonNumber(json, "Other");
    d.topFilesPreview = JsonString(json, "TopFilesPreview");
    d.topFoldersPreview = JsonString(json, "TopFoldersPreview");
    d.recommendationPreview = JsonString(json, "RecommendationPreview");
    d.cacheLoaded = true;
    d.scanning = false;
    return true;
}

static std::wstring FormatGb(ULONGLONG bytes) {
    wchar_t text[64]{};
    double gb = static_cast<double>(bytes) / (1024.0 * 1024.0 * 1024.0);
    swprintf_s(text, L"%.1f GB", gb);
    return text;
}

static COLORREF SegmentColor(size_t index) {
    static const COLORREF colors[] = {
        RGB(183, 110, 121), RGB(255, 138, 0), RGB(216, 160, 168),
        RGB(200, 90, 0), RGB(122, 65, 75), RGB(175, 168, 163),
        RGB(90, 60, 64), RGB(59, 39, 41), RGB(23, 18, 19)
    };
    return colors[index < ARRAYSIZE(colors) ? index : ARRAYSIZE(colors) - 1];
}

class StorageView final : public IShellView {
public:
    StorageView() : refs_(1), hwnd_(nullptr), gdiplusToken_(0), watermark_(nullptr) { ModuleAddRef(); LoadBrandWatermark(); EnumerateDrives(); }
    ~StorageView() { if (hwnd_) DestroyWindow(hwnd_); delete watermark_; if (gdiplusToken_) Gdiplus::GdiplusShutdown(gdiplusToken_); ModuleRelease(); }

    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (!ppv) return E_POINTER;
        *ppv = nullptr;
        if (riid == IID_IUnknown || riid == IID_IOleWindow || riid == IID_IShellView) {
            *ppv = static_cast<IShellView*>(this); AddRef(); return S_OK;
        }
        return E_NOINTERFACE;
    }
    IFACEMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&refs_); }
    IFACEMETHODIMP_(ULONG) Release() override {
        ULONG value = InterlockedDecrement(&refs_); if (!value) delete this; return value;
    }
    IFACEMETHODIMP GetWindow(HWND* phwnd) override { if (!phwnd) return E_POINTER; *phwnd = hwnd_; return hwnd_ ? S_OK : E_FAIL; }
    IFACEMETHODIMP ContextSensitiveHelp(BOOL) override { return E_NOTIMPL; }
    IFACEMETHODIMP TranslateAccelerator(MSG*) override { return S_FALSE; }
    IFACEMETHODIMP EnableModeless(BOOL) override { return S_OK; }
    IFACEMETHODIMP UIActivate(UINT) override { return S_OK; }
    IFACEMETHODIMP Refresh() override { RefreshCaches(); InvalidateRect(hwnd_, nullptr, TRUE); return S_OK; }

    IFACEMETHODIMP CreateViewWindow(IShellView*, LPCFOLDERSETTINGS pfs, IShellBrowser* browser, RECT* rect, HWND* phwnd) override {
        if (!browser || !rect || !phwnd) return E_INVALIDARG;
        HWND parent = nullptr;
        HRESULT hr = browser->GetWindow(&parent);
        if (FAILED(hr) || !parent) return FAILED(hr) ? hr : E_FAIL;
        WNDCLASSW wc{};
        wc.lpfnWndProc = StorageView::WndProc;
        wc.hInstance = g_instance;
        wc.lpszClassName = kStorageViewClass;
        wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        wc.hbrBackground = CreateSolidBrush(RGB(0, 0, 0));
        ATOM atom = RegisterClassW(&wc);
        if (!atom && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return HRESULT_FROM_WIN32(GetLastError());
        hwnd_ = CreateWindowExW(0, kStorageViewClass, L"986 Storage", WS_CHILD | WS_VISIBLE,
            rect->left, rect->top, rect->right - rect->left, rect->bottom - rect->top,
            parent, nullptr, g_instance, this);
        if (!hwnd_) return HRESULT_FROM_WIN32(GetLastError());
        CreateScanButtons();
        LayoutScanButtons();
        settings_ = pfs ? *pfs : FOLDERSETTINGS{};
        SetTimer(hwnd_, 986, 1000, nullptr);
        *phwnd = hwnd_;
        return S_OK;
    }
    IFACEMETHODIMP DestroyViewWindow() override {
        if (hwnd_) { KillTimer(hwnd_, 986); DestroyWindow(hwnd_); hwnd_ = nullptr; }
        return S_OK;
    }
    IFACEMETHODIMP GetCurrentInfo(LPFOLDERSETTINGS pfs) override { if (!pfs) return E_POINTER; *pfs = settings_; return S_OK; }
    IFACEMETHODIMP AddPropertySheetPages(DWORD, LPFNADDPROPSHEETPAGE, LPARAM) override { return E_NOTIMPL; }
    IFACEMETHODIMP SaveViewState() override { return S_OK; }
    IFACEMETHODIMP SelectItem(PCUITEMID_CHILD, SVSIF) override { return E_NOTIMPL; }
    IFACEMETHODIMP GetItemObject(UINT, REFIID, void**) override { return E_NOINTERFACE; }

private:
    void LoadBrandWatermark() {
        Gdiplus::GdiplusStartupInput input;
        if (Gdiplus::GdiplusStartup(&gdiplusToken_, &input, nullptr) != Gdiplus::Ok) { gdiplusToken_ = 0; return; }
        std::wstring path = ModuleDirectory() + L"\\..\\..\\assets\\AbeyyTechXy-logo.png";
        watermark_ = Gdiplus::Image::FromFile(path.c_str(), FALSE);
        if (!watermark_ || watermark_->GetLastStatus() != Gdiplus::Ok) { delete watermark_; watermark_ = nullptr; }
    }

    void DrawBrandWatermark(HDC dc, const RECT& client) {
        if (!watermark_) return;
        const UINT iw = watermark_->GetWidth(), ih = watermark_->GetHeight();
        if (!iw || !ih) return;
        const int cw = max(1, client.right - client.left), ch = max(1, client.bottom - client.top);
        const double scale = min((cw * 0.55) / static_cast<double>(iw), (ch * 0.55) / static_cast<double>(ih));
        const int w = max(1, static_cast<int>(iw * scale)), h = max(1, static_cast<int>(ih * scale));
        const int x = client.left + (cw - w) / 2, y = client.top + (ch - h) / 2;
        Gdiplus::ColorMatrix matrix = { 1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,0.50f,0, 0,0,0,0,1 };
        Gdiplus::ImageAttributes attrs;
        attrs.SetColorMatrix(&matrix, Gdiplus::ColorMatrixFlagsDefault, Gdiplus::ColorAdjustTypeBitmap);
        Gdiplus::Graphics graphics(dc);
        graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
        graphics.DrawImage(watermark_, Gdiplus::Rect(x, y, w, h), 0, 0, iw, ih, Gdiplus::UnitPixel, &attrs);
    }

    static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
        StorageView* self = reinterpret_cast<StorageView*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
        if (msg == WM_NCCREATE) {
            auto cs = reinterpret_cast<CREATESTRUCTW*>(lp);
            self = static_cast<StorageView*>(cs->lpCreateParams);
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        }
        if (!self) return DefWindowProcW(hwnd, msg, wp, lp);
        switch (msg) {
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
        return DefWindowProcW(hwnd, msg, wp, lp);
    }

    void EnumerateDrives() {
        DWORD mask = GetLogicalDrives();
        for (int i = 0; i < 26; ++i) {
            if (!(mask & (1u << i))) continue;
            wchar_t root[] = { static_cast<wchar_t>(L'A' + i), L':', L'\\', L'\0' };
            if (GetDriveTypeW(root) != DRIVE_FIXED) continue;
            DriveCard d; d.root = root; RefreshSpace(d); LoadCache(d); drives_.push_back(d);
        }
    }

    static void RefreshSpace(DriveCard& d) {
        ULARGE_INTEGER freeAvail{}, total{}, freeTotal{};
        if (GetDiskFreeSpaceExW(d.root.c_str(), &freeAvail, &total, &freeTotal)) {
            d.total = total.QuadPart; d.free = freeTotal.QuadPart;
        }
    }

    enum { kScanButtonBase = 2000 };

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
            CardLayout layout = BuildCardLayout(client, top, d.cacheLoaded);
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
        COLORREF fill = drive->scanning ? RGB(122, 65, 75) : RGB(255, 138, 0);
        if ((dis->itemState & ODS_SELECTED) && !drive->scanning) fill = RGB(200, 90, 0);
        HBRUSH brush = CreateSolidBrush(fill);
        FillRect(dis->hDC, &dis->rcItem, brush);
        DeleteObject(brush);
        SetBkMode(dis->hDC, TRANSPARENT);
        SetTextColor(dis->hDC, RGB(245, 241, 238));
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

    void RefreshCaches() {
        for (auto& d : drives_) {
            RefreshSpace(d);
            if (d.scanning) {
                if (LoadCache(d)) {
                    d.scanning = false;
                    if (d.scanButton) InvalidateRect(d.scanButton, nullptr, TRUE);
                }
            }
        }
    }

    bool StartScan(DriveCard& d) {
        const std::wstring moduleDir = ModuleDirectory();
        const std::wstring scanner = moduleDir + L"\\986StorageScanner.exe";
        if (GetFileAttributesW(scanner.c_str()) == INVALID_FILE_ATTRIBUTES) {
            d.scanError = GetLastError();
            return false;
        }
        std::wstring cache = CachePath(d.root);
        DeleteFileW(cache.c_str());
        std::wstring cmd = QuoteCommandLineArg(scanner) + L" " + QuoteCommandLineArg(d.root) + L" " + QuoteCommandLineArg(cache);
        std::vector<wchar_t> mutableCmd(cmd.begin(), cmd.end()); mutableCmd.push_back(L'\0');
        STARTUPINFOW si{}; si.cb = sizeof(si); si.dwFlags = STARTF_USESHOWWINDOW; si.wShowWindow = SW_HIDE;
        PROCESS_INFORMATION pi{};
        if (!CreateProcessW(scanner.c_str(), mutableCmd.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, moduleDir.c_str(), &si, &pi)) {
            d.scanError = GetLastError();
            return false;
        }
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        d.scanError = ERROR_SUCCESS;
        d.scanning = true; d.cacheLoaded = false; d.categories = CategoryBytes{};
        d.topFilesPreview.clear(); d.topFoldersPreview.clear(); d.recommendationPreview.clear();
        if (d.scanButton) InvalidateRect(d.scanButton, nullptr, TRUE);
        return true;
    }

    void Click(int x, int y) {
        POINT p{ x, y };
        RECT client{};
        GetClientRect(hwnd_, &client);
        int top = 88;
        for (auto& d : drives_) {
            CardLayout layout = BuildCardLayout(client, top, d.cacheLoaded);
            if (PtInRect(&layout.scanButton, p) && !d.scanning) {
                StartScan(d); InvalidateRect(hwnd_, nullptr, FALSE); break;
            }
            top += layout.cardHeight + 18;
        }
    }

    void Paint(HWND hwnd) {
        PAINTSTRUCT ps{}; HDC dc = BeginPaint(hwnd, &ps);
        RECT client{}; GetClientRect(hwnd, &client);
        HBRUSH bg = CreateSolidBrush(RGB(0, 0, 0)); FillRect(dc, &client, bg); DeleteObject(bg);
        DrawBrandWatermark(dc, client);
        SetBkMode(dc, TRANSPARENT); SetTextColor(dc, RGB(216, 160, 168));
        HFONT titleFont = CreateFontW(24, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HFONT textFont = CreateFontW(17, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HFONT old = static_cast<HFONT>(SelectObject(dc, titleFont));
        const wchar_t* title = L"986 Storage";
        TextOutW(dc, 28, 20, title, static_cast<int>(wcslen(title)));
        SelectObject(dc, textFont);
        const wchar_t* subtitle = L"Android-style storage breakdown inside File Explorer";
        TextOutW(dc, 28, 52, subtitle, static_cast<int>(wcslen(subtitle)));

        int top = 88;
        for (auto& d : drives_) {
            CardLayout layout = BuildCardLayout(client, top, d.cacheLoaded);
            const int left = layout.card.left;
            const int right = layout.card.right;
            const int contentWidth = layout.contentWidth;
            const int labelColumns = layout.labelColumns;
            const int labelY = layout.labelY;
            const int buttonTop = layout.buttonTop;
            const int cardH = layout.cardHeight;
            HBRUSH cardBrush = CreateSolidBrush(RGB(18, 14, 15)); FillRect(dc, &layout.card, cardBrush); DeleteObject(cardBrush);
            wchar_t header[128]{};
            std::wstring freeText = FormatGb(d.free), totalText = FormatGb(d.total);
            swprintf_s(header, L"%c:    %s free of %s", d.root[0], freeText.c_str(), totalText.c_str());
            SetTextColor(dc, RGB(245, 241, 238)); TextOutW(dc, left + 18, top + 16, header, static_cast<int>(wcslen(header)));

            RECT bar = layout.bar;
            HBRUSH usedBase = CreateSolidBrush(RGB(59, 39, 41)); FillRect(dc, &bar, usedBase); DeleteObject(usedBase);
            ULONGLONG used = d.total > d.free ? d.total - d.free : 0;
            ULONGLONG values[] = { d.categories.apps, d.categories.videos, d.categories.pictures, d.categories.documents,
                d.categories.audio, d.categories.system, d.categories.other };
            int x = bar.left;
            ULONGLONG known = 0;
            if (d.cacheLoaded && d.total) {
                for (size_t i = 0; i < ARRAYSIZE(values); ++i) {
                    known += values[i];
                    int w = static_cast<int>((static_cast<long double>(values[i]) / d.total) * (bar.right - bar.left));
                    if (w <= 0) continue;
                    RECT seg{ x, bar.top, min(x + w, bar.right), bar.bottom };
                    HBRUSH sb = CreateSolidBrush(SegmentColor(i)); FillRect(dc, &seg, sb); DeleteObject(sb); x = seg.right;
                }
            }
            ULONGLONG residual = used > known ? used - known : 0;
            if (d.total && residual) {
                int w = static_cast<int>((static_cast<long double>(residual) / d.total) * (bar.right - bar.left));
                RECT seg{ x, bar.top, min(x + w, bar.right), bar.bottom };
                HBRUSH rb = CreateSolidBrush(RGB(59, 39, 41)); FillRect(dc, &seg, rb); DeleteObject(rb);
            }
            if (d.total && d.free) {
                int w = static_cast<int>((static_cast<long double>(d.free) / d.total) * (bar.right - bar.left));
                RECT seg{ max(bar.left, bar.right - w), bar.top, bar.right, bar.bottom };
                HBRUSH fb = CreateSolidBrush(RGB(0, 0, 0)); FillRect(dc, &seg, fb); DeleteObject(fb);
            }

            SetTextColor(dc, RGB(175, 168, 163));
            const wchar_t* names[] = { L"Apps", L"Videos", L"Pictures", L"Documents", L"Audio", L"System", L"Other" };
            if (d.cacheLoaded) {
                const int columnWidth = max(1, contentWidth / labelColumns);
                for (int i = 0; i < 7; ++i) {
                    const int row = i / labelColumns;
                    const int col = i % labelColumns;
                    const int labelX = left + 18 + col * columnWidth;
                    std::wstring value = FormatGb(values[i]);
                    wchar_t line[96]{}; swprintf_s(line, L"%s %s", names[i], value.c_str());
                    TextOutW(dc, labelX, labelY + row * 25, line, static_cast<int>(wcslen(line)));
                }
            } else {
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

            if (d.cacheLoaded) {
                const int iy = layout.intelY;
                SetTextColor(dc, RGB(216, 160, 168));
                const wchar_t* intelTitle = L"Storage Intelligence";
                TextOutW(dc, left + 18, iy, intelTitle, static_cast<int>(wcslen(intelTitle)));
                SetTextColor(dc, RGB(245, 241, 238));
                if (contentWidth >= 520) {
                    const int gap = 18;
                    const int half = max(1, (contentWidth - gap) / 2);
                    const int rightX = left + 18 + half + gap;
                    const wchar_t* fileTitle = L"Largest files";
                    const wchar_t* folderTitle = L"Largest folders";
                    TextOutW(dc, left + 18, iy + 24, fileTitle, static_cast<int>(wcslen(fileTitle)));
                    TextOutW(dc, rightX, iy + 24, folderTitle, static_cast<int>(wcslen(folderTitle)));
                    SetTextColor(dc, RGB(175, 168, 163));
                    RECT filesRect{ left + 18, iy + 46, left + 18 + half, iy + 98 };
                    RECT foldersRect{ rightX, iy + 46, right - 18, iy + 98 };
                    DrawTextW(dc, (d.topFilesPreview.empty() ? L"No data" : d.topFilesPreview.c_str()), -1, &filesRect, DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
                    DrawTextW(dc, (d.topFoldersPreview.empty() ? L"No data" : d.topFoldersPreview.c_str()), -1, &foldersRect, DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
                    SetTextColor(dc, RGB(255, 138, 0));
                    const wchar_t* reviewTitle = L"986 Review";
                    TextOutW(dc, left + 18, iy + 104, reviewTitle, static_cast<int>(wcslen(reviewTitle)));
                    SetTextColor(dc, RGB(175, 168, 163));
                    RECT reviewRect{ left + 105, iy + 101, right - 18, iy + 140 };
                    DrawTextW(dc, (d.recommendationPreview.empty() ? L"Review only; 986 never auto-deletes." : d.recommendationPreview.c_str()), -1, &reviewRect, DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
                } else {
                    const wchar_t* fileTitle = L"Largest files";
                    TextOutW(dc, left + 18, iy + 24, fileTitle, static_cast<int>(wcslen(fileTitle)));
                    SetTextColor(dc, RGB(175, 168, 163));
                    RECT filesRect{ left + 18, iy + 46, right - 18, iy + 96 };
                    DrawTextW(dc, (d.topFilesPreview.empty() ? L"No data" : d.topFilesPreview.c_str()), -1, &filesRect, DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
                    SetTextColor(dc, RGB(245, 241, 238));
                    const wchar_t* folderTitle = L"Largest folders";
                    TextOutW(dc, left + 18, iy + 102, folderTitle, static_cast<int>(wcslen(folderTitle)));
                    SetTextColor(dc, RGB(175, 168, 163));
                    RECT foldersRect{ left + 18, iy + 124, right - 18, iy + 174 };
                    DrawTextW(dc, (d.topFoldersPreview.empty() ? L"No data" : d.topFoldersPreview.c_str()), -1, &foldersRect, DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
                    SetTextColor(dc, RGB(255, 138, 0));
                    const wchar_t* reviewTitle = L"986 Review";
                    TextOutW(dc, left + 18, iy + 180, reviewTitle, static_cast<int>(wcslen(reviewTitle)));
                    SetTextColor(dc, RGB(175, 168, 163));
                    RECT reviewRect{ left + 18, iy + 202, right - 18, iy + 230 };
                    DrawTextW(dc, (d.recommendationPreview.empty() ? L"Review only; 986 never auto-deletes." : d.recommendationPreview.c_str()), -1, &reviewRect, DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
                }
            }

            top += cardH + 18;
        }
        SelectObject(dc, old); DeleteObject(titleFont); DeleteObject(textFont); EndPaint(hwnd, &ps);
    }

    long refs_;
    HWND hwnd_;
    ULONG_PTR gdiplusToken_;
    Gdiplus::Image* watermark_;
    FOLDERSETTINGS settings_{};
    std::vector<DriveCard> drives_;
};

class StorageFolder final : public IShellFolder, public IPersistFolder2 {
public:
    StorageFolder() : refs_(1), pidl_(nullptr) { ModuleAddRef(); }
    ~StorageFolder() { if (pidl_) CoTaskMemFree(pidl_); ModuleRelease(); }
    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (!ppv) return E_POINTER; *ppv = nullptr;
        if (riid == IID_IUnknown || riid == IID_IShellFolder) *ppv = static_cast<IShellFolder*>(this);
        else if (riid == IID_IPersist || riid == IID_IPersistFolder || riid == IID_IPersistFolder2) *ppv = static_cast<IPersistFolder2*>(this);
        else return E_NOINTERFACE; AddRef(); return S_OK;
    }
    IFACEMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&refs_); }
    IFACEMETHODIMP_(ULONG) Release() override { ULONG value = InterlockedDecrement(&refs_); if (!value) delete this; return value; }
    IFACEMETHODIMP GetClassID(CLSID* clsid) override { if (!clsid) return E_POINTER; *clsid = CLSID_986Storage; return S_OK; }
    IFACEMETHODIMP Initialize(PCIDLIST_ABSOLUTE pidl) override { if (pidl_) CoTaskMemFree(pidl_); pidl_ = ILCloneFull(pidl); return pidl_ ? S_OK : E_OUTOFMEMORY; }
    IFACEMETHODIMP GetCurFolder(PIDLIST_ABSOLUTE* ppidl) override { if (!ppidl) return E_POINTER; *ppidl = pidl_ ? ILCloneFull(pidl_) : nullptr; return pidl_ && !*ppidl ? E_OUTOFMEMORY : S_OK; }
    IFACEMETHODIMP ParseDisplayName(HWND, IBindCtx*, LPWSTR, ULONG*, PIDLIST_RELATIVE*, ULONG*) override { return E_NOTIMPL; }
    IFACEMETHODIMP EnumObjects(HWND, SHCONTF, IEnumIDList** enumerator) override { if (!enumerator) return E_POINTER; *enumerator = nullptr; return S_FALSE; }
    IFACEMETHODIMP BindToObject(PCUIDLIST_RELATIVE, IBindCtx*, REFIID, void**) override { return E_NOTIMPL; }
    IFACEMETHODIMP BindToStorage(PCUIDLIST_RELATIVE, IBindCtx*, REFIID, void**) override { return E_NOTIMPL; }
    IFACEMETHODIMP CompareIDs(LPARAM, PCUIDLIST_RELATIVE, PCUIDLIST_RELATIVE) override { return MAKE_HRESULT(SEVERITY_SUCCESS, 0, 0); }
    IFACEMETHODIMP CreateViewObject(HWND, REFIID riid, void** ppv) override {
        if (!ppv) return E_POINTER; *ppv = nullptr; if (riid != IID_IShellView) return E_NOINTERFACE;
        StorageView* view = new (std::nothrow) StorageView(); if (!view) return E_OUTOFMEMORY; *ppv = static_cast<IShellView*>(view); return S_OK;
    }
    IFACEMETHODIMP GetAttributesOf(UINT, PCUITEMID_CHILD_ARRAY, SFGAOF* attrs) override { if (!attrs) return E_POINTER; *attrs &= (SFGAO_FOLDER | SFGAO_HASSUBFOLDER | SFGAO_BROWSABLE); return S_OK; }
    IFACEMETHODIMP GetUIObjectOf(HWND, UINT, PCUITEMID_CHILD_ARRAY, REFIID, UINT*, void**) override { return E_NOINTERFACE; }
    IFACEMETHODIMP GetDisplayNameOf(PCUITEMID_CHILD, SHGDNF, STRRET* name) override {
        if (!name) return E_POINTER; size_t chars = wcslen(k986StorageTitle) + 1; name->uType = STRRET_WSTR;
        name->pOleStr = static_cast<LPWSTR>(CoTaskMemAlloc(chars * sizeof(wchar_t))); if (!name->pOleStr) return E_OUTOFMEMORY;
        memcpy(name->pOleStr, k986StorageTitle, chars * sizeof(wchar_t)); return S_OK;
    }
    IFACEMETHODIMP SetNameOf(HWND, PCUITEMID_CHILD, LPCWSTR, SHGDNF, PITEMID_CHILD*) override { return E_NOTIMPL; }
private: long refs_; PIDLIST_ABSOLUTE pidl_;
};

class ClassFactory final : public IClassFactory {
public:
    ClassFactory() : refs_(1) { ModuleAddRef(); } ~ClassFactory() { ModuleRelease(); }
    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (!ppv) return E_POINTER; *ppv = nullptr;
        if (riid == IID_IUnknown || riid == IID_IClassFactory) { *ppv = static_cast<IClassFactory*>(this); AddRef(); return S_OK; }
        return E_NOINTERFACE;
    }
    IFACEMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&refs_); }
    IFACEMETHODIMP_(ULONG) Release() override { ULONG value = InterlockedDecrement(&refs_); if (!value) delete this; return value; }
    IFACEMETHODIMP CreateInstance(IUnknown* outer, REFIID riid, void** ppv) override {
        if (outer) return CLASS_E_NOAGGREGATION; StorageFolder* folder = new (std::nothrow) StorageFolder(); if (!folder) return E_OUTOFMEMORY;
        HRESULT hr = folder->QueryInterface(riid, ppv); folder->Release(); return hr;
    }
    IFACEMETHODIMP LockServer(BOOL lock) override { if (lock) ModuleAddRef(); else ModuleRelease(); return S_OK; }
private: long refs_;
};

BOOL APIENTRY DllMain(HINSTANCE instance, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) { g_instance = instance; DisableThreadLibraryCalls(instance); }
    return TRUE;
}
extern "C" HRESULT __stdcall DllCanUnloadNow() { return g_moduleRefs == 0 ? S_OK : S_FALSE; }
extern "C" HRESULT __stdcall DllGetClassObject(REFCLSID clsid, REFIID riid, void** ppv) {
    if (clsid != CLSID_986Storage) return CLASS_E_CLASSNOTAVAILABLE;
    ClassFactory* factory = new (std::nothrow) ClassFactory(); if (!factory) return E_OUTOFMEMORY;
    HRESULT hr = factory->QueryInterface(riid, ppv); factory->Release(); return hr;
}
