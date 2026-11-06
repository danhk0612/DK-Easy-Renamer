// CI-only native COM runtime probe: file and folder menu roots and labels.
// Does not register COM, invoke the app, or modify files.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shobjidl.h>
#include <array>
#include <cstdio>
#include <string>

namespace
{
    constexpr CLSID FileRootClsid =
        {0x73f9a0e1, 0x982d, 0x4c4e, {0xab, 0x20, 0x98, 0x7d, 0xca, 0x14, 0xe9, 0x30}};
    constexpr CLSID FolderRootClsid =
        {0xf7be1b68, 0x314c, 0x4f75, {0x9f, 0x3e, 0x7c, 0x35, 0x97, 0xb4, 0x2a, 0xd1}};
    using GetClassObjectFn = HRESULT(STDAPICALLTYPE*)(REFCLSID, REFIID, void**);

    bool HasTitle(IExplorerCommand* command, const wchar_t* expected)
    {
        PWSTR title = nullptr;
        HRESULT hr = command->GetTitle(nullptr, &title);
        bool matches = SUCCEEDED(hr) && title && std::wstring(title) == expected;
        CoTaskMemFree(title);
        return matches;
    }

    int Fail(const char* message)
    {
        std::fprintf(stderr, "Explorer context-sensitive flyout FAILED: %s\n", message);
        return 1;
    }

    int CheckFlyout(GetClassObjectFn getClass, REFCLSID rootClsid,
                    const std::array<const wchar_t*, 3>& titles)
    {
        IClassFactory* factory = nullptr;
        HRESULT hr = getClass(rootClsid, IID_IClassFactory, reinterpret_cast<void**>(&factory));
        if (FAILED(hr) || !factory) return Fail("creating registered root factory");
        IExplorerCommand* root = nullptr;
        hr = factory->CreateInstance(nullptr, IID_IExplorerCommand, reinterpret_cast<void**>(&root));
        factory->Release();
        if (FAILED(hr) || !root) return Fail("creating registered root command");

        EXPCMDFLAGS flags{};
        hr = root->GetFlags(&flags);
        if (FAILED(hr) || !(flags & ECF_HASSUBCOMMANDS) || !(flags & ECF_ISDROPDOWN))
            return Fail("missing root flyout flags");
        GUID canonical{};
        if (FAILED(root->GetCanonicalName(&canonical)) || !IsEqualGUID(canonical, rootClsid))
            return Fail("root returned wrong file/folder canonical name");
        if (!HasTitle(root, L"DK Easy Renamer")) return Fail("root title mismatch");

        IEnumExplorerCommand* enumerator = nullptr;
        hr = root->EnumSubCommands(&enumerator);
        if (FAILED(hr) || !enumerator) return Fail("root did not return child enumerator");

        std::array<GUID, 3> canonicalNames{};
        for (size_t i = 0; i < titles.size(); ++i)
        {
            IExplorerCommand* child = nullptr;
            ULONG fetched = 0;
            hr = enumerator->Next(1, &child, &fetched);
            if (hr != S_OK || fetched != 1 || !child) return Fail("missing child command");
            if (!HasTitle(child, titles[i])) return Fail("wrong context-specific child label/order");
            EXPCMDSTATE state{};
            if (FAILED(child->GetState(nullptr, FALSE, &state)) || state != ECS_ENABLED)
                return Fail("context child disabled without selection metadata");
            EXPCMDFLAGS childFlags{};
            if (FAILED(child->GetFlags(&childFlags)) || (childFlags & ECF_HASSUBCOMMANDS))
                return Fail("child unexpectedly advertises another flyout");
            if (FAILED(child->GetCanonicalName(&canonicalNames[i])) ||
                IsEqualGUID(canonicalNames[i], rootClsid))
                return Fail("child canonical name is invalid");
            for (size_t previous = 0; previous < i; ++previous)
                if (IsEqualGUID(canonicalNames[i], canonicalNames[previous]))
                    return Fail("duplicate child canonical names");
            child->Release();
        }

        IExplorerCommand* extra = nullptr;
        ULONG fetched = 0;
        hr = enumerator->Next(1, &extra, &fetched);
        if (hr != S_FALSE || fetched != 0 || extra) return Fail("unexpected fourth child");
        enumerator->Release();
        root->Release();
        return 0;
    }
}

int wmain(int argc, wchar_t** argv)
{
    if (argc != 2) return Fail("expected one Explorer DLL path");
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr)) return Fail("COM apartment initialization");
    HMODULE module = LoadLibraryW(argv[1]);
    if (!module) return Fail("loading Explorer DLL");
    auto getClass = reinterpret_cast<GetClassObjectFn>(GetProcAddress(module, "DllGetClassObject"));
    if (!getClass) return Fail("DllGetClassObject export missing");

    const std::array<const wchar_t*, 3> fileTitles = {
        L"\uD30C\uC77C \uC774\uB984 \uBCC0\uACBD...",
        L"\uD30C\uC77C \uBE60\uB978 \uC21C\uBC88 \uBCC0\uACBD...",
        L"\uD30C\uC77C \uBE60\uB978 \uCC3E\uAE30\u00B7\uBC14\uAFB8\uAE30..."
    };
    const std::array<const wchar_t*, 3> folderTitles = {
        L"\uD3F4\uB354 \uC774\uB984 \uBCC0\uACBD...",
        L"\uD3F4\uB354 \uBE60\uB978 \uC21C\uBC88 \uBCC0\uACBD...",
        L"\uD3F4\uB354 \uBE60\uB978 \uCC3E\uAE30\u00B7\uBC14\uAFB8\uAE30..."
    };

    if (CheckFlyout(getClass, FileRootClsid, fileTitles) != 0) return 1;
    if (CheckFlyout(getClass, FolderRootClsid, folderTitles) != 0) return 1;
    FreeLibrary(module);
    CoUninitialize();
    std::puts("Explorer context-sensitive COM PASS: file and folder roots with 3 correctly labeled actions each.");
    return 0;
}
