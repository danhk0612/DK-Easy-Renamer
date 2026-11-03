// T01 Windows 11 native IExplorerCommand. No file renaming operations.
#include <windows.h>
#include <shobjidl.h>
#include <shlwapi.h>
#include <cstdint>
#include <new>
#include <string>
#include <vector>

namespace
{
    constexpr CLSID CommandClsid =
        {0x73f9a0e1, 0x982d, 0x4c4e, {0xab, 0x20, 0x98, 0x7d, 0xca, 0x14, 0xe9, 0x30}};
    volatile LONG objectCount = 0;
    volatile LONG lockCount = 0;

    HRESULT ReadSetting(const wchar_t* name, std::wstring& value)
    {
        DWORD bytes = 0;
        LONG rc = RegGetValueW(HKEY_CURRENT_USER, L"Software\\DKEasyRenamer", name,
                               RRF_RT_REG_SZ, nullptr, nullptr, &bytes);
        if (rc != ERROR_SUCCESS) return HRESULT_FROM_WIN32(rc);
        if (bytes < sizeof(wchar_t) || bytes > 65536) return E_INVALIDARG;
        std::vector<wchar_t> chars(bytes / sizeof(wchar_t));
        rc = RegGetValueW(HKEY_CURRENT_USER, L"Software\\DKEasyRenamer", name,
                          RRF_RT_REG_SZ, nullptr, chars.data(), &bytes);
        if (rc != ERROR_SUCCESS) return HRESULT_FROM_WIN32(rc);
        value.assign(chars.data());
        return value.empty() ? E_INVALIDARG : S_OK;
    }

    bool WriteExact(HANDLE file, const void* bytes, DWORD count)
    {
        DWORD written = 0;
        return WriteFile(file, bytes, count, &written, nullptr) && written == count;
    }

    HRESULT LaunchWithSelection(const std::vector<std::wstring>& paths)
    {
        if (paths.empty() || paths.size() > 10000) return E_INVALIDARG;
        std::wstring app;
        HRESULT hr = ReadSetting(L"ExecutablePath", app);
        if (FAILED(hr)) return hr;

        wchar_t folder[MAX_PATH] = {};
        DWORD used = GetTempPathW(MAX_PATH, folder);
        if (used == 0 || used >= MAX_PATH)
            return HRESULT_FROM_WIN32(used ? ERROR_BUFFER_OVERFLOW : GetLastError());

        wchar_t packet[MAX_PATH] = {};
        if (!GetTempFileNameW(folder, L"DKR", 0, packet))
            return HRESULT_FROM_WIN32(GetLastError());
        HANDLE handle = CreateFileW(packet, GENERIC_WRITE, 0, nullptr, TRUNCATE_EXISTING,
                                    FILE_ATTRIBUTE_TEMPORARY, nullptr);
        if (handle == INVALID_HANDLE_VALUE)
        {
            DWORD error = GetLastError();
            DeleteFileW(packet);
            return HRESULT_FROM_WIN32(error);
        }

        const char magic[] = {'D', 'K', 'R', '1'};
        const uint32_t count = static_cast<uint32_t>(paths.size());
        bool ok = WriteExact(handle, magic, sizeof(magic)) &&
                  WriteExact(handle, &count, sizeof(count));
        for (const auto& path : paths)
        {
            if (path.empty() || path.size() > 32767)
            {
                ok = false;
                break;
            }
            const uint32_t len = static_cast<uint32_t>(path.size());
            ok = ok && WriteExact(handle, &len, sizeof(len)) &&
                 WriteExact(handle, path.data(), len * sizeof(wchar_t));
            if (!ok) break;
        }
        DWORD error = ok ? ERROR_SUCCESS : GetLastError();
        CloseHandle(handle);
        if (!ok)
        {
            DeleteFileW(packet);
            return HRESULT_FROM_WIN32(error ? error : ERROR_WRITE_FAULT);
        }

        // Explicit lpApplicationName avoids parsing ambiguities with spaces.
        std::wstring cmd = L"\"" + app + L"\" --selection-file \"" + packet + L"\"";
        std::vector<wchar_t> command(cmd.begin(), cmd.end());
        command.push_back(L'\0');
        STARTUPINFOW startup = {};
        startup.cb = sizeof(startup);
        PROCESS_INFORMATION process = {};
        if (!CreateProcessW(app.c_str(), command.data(), nullptr, nullptr,
                            FALSE, 0, nullptr, nullptr, &startup, &process))
        {
            error = GetLastError();
            DeleteFileW(packet);
            return HRESULT_FROM_WIN32(error);
        }
        CloseHandle(process.hThread);
        CloseHandle(process.hProcess);
        return S_OK;
    }

    class ExplorerCommand final : public IExplorerCommand
    {
        volatile LONG refs_ = 1;
    public:
        ExplorerCommand() { InterlockedIncrement(&objectCount); }
        ~ExplorerCommand() { InterlockedDecrement(&objectCount); }

        HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** output) override
        {
            if (!output) return E_POINTER;
            *output = nullptr;
            if (IsEqualIID(iid, IID_IUnknown) || IsEqualIID(iid, IID_IExplorerCommand))
            {
                *output = static_cast<IExplorerCommand*>(this);
                AddRef();
                return S_OK;
            }
            return E_NOINTERFACE;
        }
        ULONG STDMETHODCALLTYPE AddRef() override
        {
            return static_cast<ULONG>(InterlockedIncrement(&refs_));
        }
        ULONG STDMETHODCALLTYPE Release() override
        {
            LONG remaining = InterlockedDecrement(&refs_);
            if (!remaining) delete this;
            return static_cast<ULONG>(remaining);
        }
        HRESULT STDMETHODCALLTYPE GetTitle(IShellItemArray*, LPWSTR* title) override
        {
            if (!title) return E_POINTER;
            return SHStrDupW(L"DK Easy Renamer로 이름 변경", title);
        }
        HRESULT STDMETHODCALLTYPE GetIcon(IShellItemArray*, LPWSTR* icon) override
        {
            if (!icon) return E_POINTER;
            *icon = nullptr;
            std::wstring path;
            HRESULT hr = ReadSetting(L"IconPath", path);
            return SUCCEEDED(hr) ? SHStrDupW(path.c_str(), icon) : E_NOTIMPL;
        }
        HRESULT STDMETHODCALLTYPE GetToolTip(IShellItemArray*, LPWSTR* tip) override
        {
            if (!tip) return E_POINTER;
            *tip = nullptr;
            return E_NOTIMPL;
        }
        HRESULT STDMETHODCALLTYPE GetCanonicalName(GUID* value) override
        {
            if (!value) return E_POINTER;
            *value = CommandClsid;
            return S_OK;
        }
        HRESULT STDMETHODCALLTYPE GetState(IShellItemArray* items, BOOL, EXPCMDSTATE* state) override
        {
            if (!state) return E_POINTER;
            DWORD count = 0;
            *state = items && SUCCEEDED(items->GetCount(&count)) && count > 0
                ? ECS_ENABLED : ECS_DISABLED;
            return S_OK;
        }
        HRESULT STDMETHODCALLTYPE Invoke(IShellItemArray* items, IBindCtx*) override
        {
            if (!items) return E_INVALIDARG;
            DWORD count = 0;
            HRESULT hr = items->GetCount(&count);
            if (FAILED(hr)) return hr;
            if (count == 0 || count > 10000) return E_INVALIDARG;
            std::vector<std::wstring> paths;
            paths.reserve(count);
            for (DWORD i = 0; i < count; ++i)
            {
                IShellItem* item = nullptr;
                hr = items->GetItemAt(i, &item);
                if (FAILED(hr)) return hr;
                PWSTR text = nullptr;
                hr = item->GetDisplayName(SIGDN_FILESYSPATH, &text);
                item->Release();
                if (FAILED(hr)) return hr;
                paths.emplace_back(text);
                CoTaskMemFree(text);
            }
            return LaunchWithSelection(paths);
        }
        HRESULT STDMETHODCALLTYPE GetFlags(EXPCMDFLAGS* value) override
        {
            if (!value) return E_POINTER;
            *value = ECF_DEFAULT;
            return S_OK;
        }
        HRESULT STDMETHODCALLTYPE EnumSubCommands(IEnumExplorerCommand** commands) override
        {
            if (!commands) return E_POINTER;
            *commands = nullptr;
            return E_NOTIMPL;
        }
    };

    class CommandFactory final : public IClassFactory
    {
        volatile LONG refs_ = 1;
    public:
        CommandFactory() { InterlockedIncrement(&objectCount); }
        ~CommandFactory() { InterlockedDecrement(&objectCount); }
        HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** output) override
        {
            if (!output) return E_POINTER;
            *output = nullptr;
            if (IsEqualIID(iid, IID_IUnknown) || IsEqualIID(iid, IID_IClassFactory))
            {
                *output = static_cast<IClassFactory*>(this);
                AddRef();
                return S_OK;
            }
            return E_NOINTERFACE;
        }
        ULONG STDMETHODCALLTYPE AddRef() override
        {
            return static_cast<ULONG>(InterlockedIncrement(&refs_));
        }
        ULONG STDMETHODCALLTYPE Release() override
        {
            LONG remaining = InterlockedDecrement(&refs_);
            if (!remaining) delete this;
            return static_cast<ULONG>(remaining);
        }
        HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, REFIID iid, void** output) override
        {
            if (outer) return CLASS_E_NOAGGREGATION;
            auto* command = new (std::nothrow) ExplorerCommand;
            if (!command) return E_OUTOFMEMORY;
            HRESULT hr = command->QueryInterface(iid, output);
            command->Release();
            return hr;
        }
        HRESULT STDMETHODCALLTYPE LockServer(BOOL lock) override
        {
            if (lock) InterlockedIncrement(&lockCount);
            else InterlockedDecrement(&lockCount);
            return S_OK;
        }
    };
}

extern "C" BOOL WINAPI DllMain(HINSTANCE module, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH) DisableThreadLibraryCalls(module);
    return TRUE;
}
extern "C" HRESULT __stdcall ModuleCanUnload()
{
    return objectCount == 0 && lockCount == 0 ? S_OK : S_FALSE;
}
extern "C" HRESULT __stdcall ModuleGetClassObject(
    REFCLSID clsid, REFIID iid, void** output)
{
    if (!IsEqualCLSID(clsid, CommandClsid)) return CLASS_E_CLASSNOTAVAILABLE;
    auto* factory = new (std::nothrow) CommandFactory;
    if (!factory) return E_OUTOFMEMORY;
    HRESULT hr = factory->QueryInterface(iid, output);
    factory->Release();
    return hr;
}
