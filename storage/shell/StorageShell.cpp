#define INITGUID
#include <windows.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <new>
#include "StorageGuids.h"

static HINSTANCE g_instance = nullptr;
static long g_moduleRefs = 0;

static void ModuleAddRef() { InterlockedIncrement(&g_moduleRefs); }
static void ModuleRelease() { InterlockedDecrement(&g_moduleRefs); }

class StorageView final : public IShellView {
public:
    StorageView() : refs_(1), hwnd_(nullptr) { ModuleAddRef(); }
    ~StorageView() { if (hwnd_) DestroyWindow(hwnd_); ModuleRelease(); }

    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (!ppv) return E_POINTER;
        *ppv = nullptr;
        if (riid == IID_IUnknown || riid == IID_IOleWindow || riid == IID_IShellView) {
            *ppv = static_cast<IShellView*>(this);
            AddRef();
            return S_OK;
        }
        return E_NOINTERFACE;
    }
    IFACEMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&refs_); }
    IFACEMETHODIMP_(ULONG) Release() override {
        ULONG value = InterlockedDecrement(&refs_);
        if (!value) delete this;
        return value;
    }

    IFACEMETHODIMP GetWindow(HWND* phwnd) override {
        if (!phwnd) return E_POINTER;
        *phwnd = hwnd_;
        return hwnd_ ? S_OK : E_FAIL;
    }
    IFACEMETHODIMP ContextSensitiveHelp(BOOL) override { return E_NOTIMPL; }
    IFACEMETHODIMP TranslateAccelerator(MSG*) override { return S_FALSE; }
    IFACEMETHODIMP EnableModeless(BOOL) override { return S_OK; }
    IFACEMETHODIMP UIActivate(UINT) override { return S_OK; }
    IFACEMETHODIMP Refresh() override { return S_OK; }
    IFACEMETHODIMP CreateViewWindow(IShellView*, LPCFOLDERSETTINGS pfs, IShellBrowser* browser, RECT* rect, HWND* phwnd) override {
        if (!browser || !rect || !phwnd) return E_INVALIDARG;
        HWND parent = nullptr;
        HRESULT hr = browser->GetWindow(&parent);
        if (FAILED(hr) || !parent) return FAILED(hr) ? hr : E_FAIL;
        hwnd_ = CreateWindowExW(0, L"STATIC",
            L"986 Storage\r\nStorage category view is initializing...",
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            rect->left, rect->top, rect->right - rect->left, rect->bottom - rect->top,
            parent, nullptr, g_instance, nullptr);
        if (!hwnd_) return HRESULT_FROM_WIN32(GetLastError());
        settings_ = pfs ? *pfs : FOLDERSETTINGS{};
        *phwnd = hwnd_;
        return S_OK;
    }
    IFACEMETHODIMP DestroyViewWindow() override {
        if (hwnd_) { DestroyWindow(hwnd_); hwnd_ = nullptr; }
        return S_OK;
    }
    IFACEMETHODIMP GetCurrentInfo(LPFOLDERSETTINGS pfs) override {
        if (!pfs) return E_POINTER;
        *pfs = settings_;
        return S_OK;
    }
    IFACEMETHODIMP AddPropertySheetPages(DWORD, LPFNADDPROPSHEETPAGE, LPARAM) override { return E_NOTIMPL; }
    IFACEMETHODIMP SaveViewState() override { return S_OK; }
    IFACEMETHODIMP SelectItem(PCUITEMID_CHILD, SVSIF) override { return E_NOTIMPL; }
    IFACEMETHODIMP GetItemObject(UINT, REFIID, void**) override { return E_NOINTERFACE; }

private:
    long refs_;
    HWND hwnd_;
    FOLDERSETTINGS settings_{};
};

class StorageFolder final : public IShellFolder, public IPersistFolder2 {
public:
    StorageFolder() : refs_(1), pidl_(nullptr) { ModuleAddRef(); }
    ~StorageFolder() { if (pidl_) CoTaskMemFree(pidl_); ModuleRelease(); }

    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (!ppv) return E_POINTER;
        *ppv = nullptr;
        if (riid == IID_IUnknown || riid == IID_IShellFolder) *ppv = static_cast<IShellFolder*>(this);
        else if (riid == IID_IPersist || riid == IID_IPersistFolder || riid == IID_IPersistFolder2) *ppv = static_cast<IPersistFolder2*>(this);
        else return E_NOINTERFACE;
        AddRef();
        return S_OK;
    }
    IFACEMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&refs_); }
    IFACEMETHODIMP_(ULONG) Release() override {
        ULONG value = InterlockedDecrement(&refs_);
        if (!value) delete this;
        return value;
    }

    IFACEMETHODIMP GetClassID(CLSID* clsid) override {
        if (!clsid) return E_POINTER;
        *clsid = CLSID_986Storage;
        return S_OK;
    }
    IFACEMETHODIMP Initialize(PCIDLIST_ABSOLUTE pidl) override {
        if (pidl_) { CoTaskMemFree(pidl_); pidl_ = nullptr; }
        pidl_ = ILCloneFull(pidl);
        return pidl_ ? S_OK : E_OUTOFMEMORY;
    }
    IFACEMETHODIMP GetCurFolder(PIDLIST_ABSOLUTE* ppidl) override {
        if (!ppidl) return E_POINTER;
        *ppidl = pidl_ ? ILCloneFull(pidl_) : nullptr;
        return pidl_ && !*ppidl ? E_OUTOFMEMORY : S_OK;
    }

    IFACEMETHODIMP ParseDisplayName(HWND, IBindCtx*, LPWSTR, ULONG*, PIDLIST_RELATIVE*, ULONG*) override { return E_NOTIMPL; }
    IFACEMETHODIMP EnumObjects(HWND, SHCONTF, IEnumIDList** enumerator) override {
        if (!enumerator) return E_POINTER;
        *enumerator = nullptr;
        return S_FALSE;
    }
    IFACEMETHODIMP BindToObject(PCUIDLIST_RELATIVE, IBindCtx*, REFIID, void**) override { return E_NOTIMPL; }
    IFACEMETHODIMP BindToStorage(PCUIDLIST_RELATIVE, IBindCtx*, REFIID, void**) override { return E_NOTIMPL; }
    IFACEMETHODIMP CompareIDs(LPARAM, PCUIDLIST_RELATIVE, PCUIDLIST_RELATIVE) override { return MAKE_HRESULT(SEVERITY_SUCCESS, 0, 0); }
    IFACEMETHODIMP CreateViewObject(HWND, REFIID riid, void** ppv) override {
        if (!ppv) return E_POINTER;
        *ppv = nullptr;
        if (riid != IID_IShellView) return E_NOINTERFACE;
        StorageView* view = new (std::nothrow) StorageView();
        if (!view) return E_OUTOFMEMORY;
        *ppv = static_cast<IShellView*>(view);
        return S_OK;
    }
    IFACEMETHODIMP GetAttributesOf(UINT, PCUITEMID_CHILD_ARRAY, SFGAOF* attrs) override {
        if (!attrs) return E_POINTER;
        *attrs &= (SFGAO_FOLDER | SFGAO_HASSUBFOLDER | SFGAO_BROWSABLE);
        return S_OK;
    }
    IFACEMETHODIMP GetUIObjectOf(HWND, UINT, PCUITEMID_CHILD_ARRAY, REFIID, UINT*, void**) override { return E_NOINTERFACE; }
    IFACEMETHODIMP GetDisplayNameOf(PCUITEMID_CHILD, SHGDNF, STRRET* name) override {
        if (!name) return E_POINTER;
        size_t chars = wcslen(k986StorageTitle) + 1;
        name->uType = STRRET_WSTR;
        name->pOleStr = static_cast<LPWSTR>(CoTaskMemAlloc(chars * sizeof(wchar_t)));
        if (!name->pOleStr) return E_OUTOFMEMORY;
        memcpy(name->pOleStr, k986StorageTitle, chars * sizeof(wchar_t));
        return S_OK;
    }
    IFACEMETHODIMP SetNameOf(HWND, PCUITEMID_CHILD, LPCWSTR, SHGDNF, PITEMID_CHILD*) override { return E_NOTIMPL; }

private:
    long refs_;
    PIDLIST_ABSOLUTE pidl_;
};

class ClassFactory final : public IClassFactory {
public:
    ClassFactory() : refs_(1) { ModuleAddRef(); }
    ~ClassFactory() { ModuleRelease(); }
    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (!ppv) return E_POINTER;
        *ppv = nullptr;
        if (riid == IID_IUnknown || riid == IID_IClassFactory) {
            *ppv = static_cast<IClassFactory*>(this);
            AddRef();
            return S_OK;
        }
        return E_NOINTERFACE;
    }
    IFACEMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&refs_); }
    IFACEMETHODIMP_(ULONG) Release() override {
        ULONG value = InterlockedDecrement(&refs_);
        if (!value) delete this;
        return value;
    }
    IFACEMETHODIMP CreateInstance(IUnknown* outer, REFIID riid, void** ppv) override {
        if (outer) return CLASS_E_NOAGGREGATION;
        StorageFolder* folder = new (std::nothrow) StorageFolder();
        if (!folder) return E_OUTOFMEMORY;
        HRESULT hr = folder->QueryInterface(riid, ppv);
        folder->Release();
        return hr;
    }
    IFACEMETHODIMP LockServer(BOOL lock) override {
        if (lock) ModuleAddRef(); else ModuleRelease();
        return S_OK;
    }
private:
    long refs_;
};

BOOL APIENTRY DllMain(HINSTANCE instance, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        g_instance = instance;
        DisableThreadLibraryCalls(instance);
    }
    return TRUE;
}

extern "C" HRESULT __stdcall DllCanUnloadNow() {
    return g_moduleRefs == 0 ? S_OK : S_FALSE;
}

extern "C" HRESULT __stdcall DllGetClassObject(REFCLSID clsid, REFIID riid, void** ppv) {
    if (clsid != CLSID_986Storage) return CLASS_E_CLASSNOTAVAILABLE;
    ClassFactory* factory = new (std::nothrow) ClassFactory();
    if (!factory) return E_OUTOFMEMORY;
    HRESULT hr = factory->QueryInterface(riid, ppv);
    factory->Release();
    return hr;
}
