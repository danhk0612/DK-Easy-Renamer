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
    constexpr CLSID QuickGroupClsid =
        {0xa01d3977, 0x7390, 0x4e7a, {0xab, 0x4e, 0x14, 0x6a, 0x28, 0xb7, 0x1f, 0x9c}};
    constexpr CLSID QuickSequenceGuid =
        {0xa01d3978, 0x7390, 0x4e7a, {0xab, 0x4e, 0x14, 0x6a, 0x28, 0xb7, 0x1f, 0x9c}};
    constexpr CLSID QuickReplaceGuid =
        {0xa01d3979, 0x7390, 0x4e7a, {0xab, 0x4e, 0x14, 0x6a, 0x28, 0xb7, 0x1f, 0x9c}};
    enum class CommandKind { Editor, QuickGroup, Sequence, Replace };
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

    HRESULT LaunchWithSelection(const std::vector<std::wstring>& paths, CommandKind kind)
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
        if (kind == CommandKind::Sequence) cmd += L" --quick-mode sequence";
        if (kind == CommandKind::Replace) cmd += L" --quick-mode replace";
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
        CommandKind kind_;
    public:
        explicit ExplorerCommand(CommandKind kind) : kind_(kind) { InterlockedIncrement(&objectCount); }
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
            const wchar_t* label = nullptr;
            switch (kind_)
            {
            case CommandKind::Editor:
                label = L"\uC77C\uBC18 \uC774\uB984 \uBCC0\uACBD...";
                break;
            case CommandKind::QuickGroup:
                label = L"DK Easy Renamer";
                break;
            case CommandKind::Sequence:
                label = L"\uBE60\uB978 \uC21C\uBC88 \uBCC0\uACBD...";
                break;
            case CommandKind::Replace:
                label = L"\uBE60\uB978 \uCC3E\uAE30\u00B7\uBC14\uAFB8\uAE30...";
                break;
            }
            return SHStrDupW(label, title);
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
            switch (kind_)
            {
            case CommandKind::Editor: *value = QuickGroupClsid; break;
            case CommandKind::QuickGroup: *value = CommandClsid; break;
            case CommandKind::Sequence: *value = QuickSequenceGuid; break;
            case CommandKind::Replace: *value = QuickReplaceGuid; break;
            }
            return S_OK;
        }
        HRESULT STDMETHODCALLTYPE GetState(IShellItemArray* items, BOOL, EXPCMDSTATE* state) override
        {
            if (!state) return E_POINTER;
            // Explorer can query flyout children before passing a selection.
            // Their actual Invoke still requires a nonempty IShellItemArray.
            if (!items)
            {
                *state = ECS_ENABLED;
                return S_OK;
            }
            DWORD count = 0;
            *state = SUCCEEDED(items->GetCount(&count)) && count > 0
                ? ECS_ENABLED : ECS_DISABLED;
            return S_OK;
        }
        HRESULT STDMETHODCALLTYPE Invoke(IShellItemArray* items, IBindCtx*) override
        {
            if (kind_ == CommandKind::QuickGroup) return E_NOTIMPL;
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
            return LaunchWithSelection(paths, kind_);
        }
        HRESULT STDMETHODCALLTYPE GetFlags(EXPCMDFLAGS* value) override
        {
            if (!value) return E_POINTER;
            *value = kind_ == CommandKind::QuickGroup
                ? static_cast<EXPCMDFLAGS>(ECF_HASSUBCOMMANDS | ECF_ISDROPDOWN)
                : ECF_DEFAULT;
            return S_OK;
        }
        HRESULT STDMETHODCALLTYPE EnumSubCommands(IEnumExplorerCommand** commands) override;
    };

    // Windows 11 may display only one top-level verb per package/item type.
    // Keep the original registered CLSID as one flyout with the editor
    // and both quick actions, without loading WPF until a child is invoked.
    class QuickCommandsEnumerator final : public IEnumExplorerCommand
    {
        volatile LONG refs_ = 1;
        ULONG index_;
    public:
        explicit QuickCommandsEnumerator(ULONG index = 0) : index_(index) { InterlockedIncrement(&objectCount); }
        ~QuickCommandsEnumerator() { InterlockedDecrement(&objectCount); }
        HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** output) override
        {
            if (!output) return E_POINTER;
            *output = nullptr;
            if (IsEqualIID(iid, IID_IUnknown) || IsEqualIID(iid, IID_IEnumExplorerCommand))
            {
                *output = static_cast<IEnumExplorerCommand*>(this);
                AddRef();
                return S_OK;
            }
            return E_NOINTERFACE;
        }
        ULONG STDMETHODCALLTYPE AddRef() override { return static_cast<ULONG>(InterlockedIncrement(&refs_)); }
        ULONG STDMETHODCALLTYPE Release() override
        {
            LONG remaining = InterlockedDecrement(&refs_);
            if (!remaining) delete this;
            return static_cast<ULONG>(remaining);
        }
        HRESULT STDMETHODCALLTYPE Next(ULONG count, IExplorerCommand** output, ULONG* fetched) override
        {
            if (!output || (count > 1 && !fetched)) return E_POINTER;
            if (fetched) *fetched = 0;
            ULONG produced = 0;
            while (produced < count && index_ < 3)
            {
                CommandKind kind;
                switch (index_++)
                {
                case 0: kind = CommandKind::Editor; break;
                case 1: kind = CommandKind::Sequence; break;
                default: kind = CommandKind::Replace; break;
                }
                auto* command = new (std::nothrow) ExplorerCommand(kind);
                if (!command)
                {
                    while (produced > 0) output[--produced]->Release();
                    return E_OUTOFMEMORY;
                }
                output[produced++] = command;
            }
            if (fetched) *fetched = produced;
            return produced == count ? S_OK : S_FALSE;
        }
        HRESULT STDMETHODCALLTYPE Skip(ULONG count) override
        {
            ULONG remaining = 3 - index_;
            if (count > remaining)
            {
                index_ = 3;
                return S_FALSE;
            }
            index_ += count;
            return S_OK;
        }
        HRESULT STDMETHODCALLTYPE Reset() override { index_ = 0; return S_OK; }
        HRESULT STDMETHODCALLTYPE Clone(IEnumExplorerCommand** output) override
        {
            if (!output) return E_POINTER;
            *output = new (std::nothrow) QuickCommandsEnumerator(index_);
            return *output ? S_OK : E_OUTOFMEMORY;
        }
    };

    HRESULT ExplorerCommand::EnumSubCommands(IEnumExplorerCommand** commands)
    {
        if (!commands) return E_POINTER;
        *commands = nullptr;
        if (kind_ != CommandKind::QuickGroup) return E_NOTIMPL;
        *commands = new (std::nothrow) QuickCommandsEnumerator;
        return *commands ? S_OK : E_OUTOFMEMORY;
    }

    class CommandFactory final : public IClassFactory
    {
        volatile LONG refs_ = 1;
        CommandKind kind_;
    public:
        explicit CommandFactory(CommandKind kind) : kind_(kind) { InterlockedIncrement(&objectCount); }
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
            auto* command = new (std::nothrow) ExplorerCommand(kind_);
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
    if (!IsEqualCLSID(clsid, CommandClsid) && !IsEqualCLSID(clsid, QuickGroupClsid))
        return CLASS_E_CLASSNOTAVAILABLE;
    // Both CLSIDs can still be activated by existing cached registrations,
    // but new packages expose only the original, stable top-level CLSID.
    CommandKind kind = CommandKind::QuickGroup;
    auto* factory = new (std::nothrow) CommandFactory(kind);
    if (!factory) return E_OUTOFMEMORY;
    HRESULT hr = factory->QueryInterface(iid, output);
    factory->Release();
    return hr;
}
