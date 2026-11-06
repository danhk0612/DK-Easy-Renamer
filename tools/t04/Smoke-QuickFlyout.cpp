// Test-only native runtime probe for the Explorer DLL's COM command factory.
// Does not register COM, invoke the app or modify user files.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shobjidl.h>
#include <array>
#include <cstdio>
#include <string>

namespace
{
    constexpr CLSID RootCommandClsid =
        {0x73f9a0e1, 0x982d, 0x4c4e, {0xab, 0x20, 0x98, 0x7d, 0xca, 0x14, 0xe9, 0x30}};
    using GetClassObjectFn = HRESULT(STDAPICALLTYPE*)(REFCLSID, REFIID, void**);

    bool HasTitle(IExplorerCommand* command, const wchar_t* expected)
    {
        PWSTR title = nullptr;
        HRESULT hr = command->GetTitle(nullptr, &title);
        const bool match = SUCCEEDED(hr) && title && std::wstring(title) == expected;
        CoTaskMemFree(title);
        return match;
    }

    int Fail(const char* message)
    {
        std::fprintf(stderr, "Explorer flyout runtime smoke FAILED: %s\n", message);
        return 1;
    }
}

int wmain(int argc, wchar_t** argv)
{
    if (argc != 2) return Fail("expected one DLL path");
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr)) return Fail("COM apartment initialization");
    HMODULE module = LoadLibraryW(argv[1]);
    if (!module) return Fail("loading native Explorer command DLL");
    auto getClass = reinterpret_cast<GetClassObjectFn>(GetProcAddress(module, "DllGetClassObject"));
    if (!getClass) return Fail("DllGetClassObject export missing");

    IClassFactory* factory = nullptr;
    hr = getClass(RootCommandClsid, IID_IClassFactory, reinterpret_cast<void**>(&factory));
    if (FAILED(hr) || !factory) return Fail("creating original registered COM root factory");
    IExplorerCommand* root = nullptr;
    hr = factory->CreateInstance(nullptr, IID_IExplorerCommand, reinterpret_cast<void**>(&root));
    factory->Release();
    if (FAILED(hr) || !root) return Fail("creating original Explorer COM root");

    EXPCMDFLAGS flags{};
    hr = root->GetFlags(&flags);
    if (FAILED(hr) || !(flags & ECF_HASSUBCOMMANDS) || !(flags & ECF_ISDROPDOWN))
        return Fail("root did not advertise flyout flags");
    if (!HasTitle(root, L"DK Easy Renamer")) return Fail("root display name mismatch");

    IEnumExplorerCommand* enumerator = nullptr;
    hr = root->EnumSubCommands(&enumerator);
    if (FAILED(hr) || !enumerator) return Fail("root did not return child enumerator");

    const std::array<const wchar_t*, 3> titles = {
        L"\uC77C\uBC18 \uC774\uB984 \uBCC0\uACBD...",
        L"\uBE60\uB978 \uC21C\uBC88 \uBCC0\uACBD...",
        L"\uBE60\uB978 \uCC3E\uAE30\u00B7\uBC14\uAFB8\uAE30..."
    };
    for (size_t i = 0; i < titles.size(); ++i)
    {
        IExplorerCommand* child = nullptr;
        ULONG fetched = 0;
        hr = enumerator->Next(1, &child, &fetched);
        if (hr != S_OK || fetched != 1 || !child) return Fail("missing child command");
        if (!HasTitle(child, titles[i])) return Fail("child command label/order mismatch");
        EXPCMDSTATE state{};
        hr = child->GetState(nullptr, FALSE, &state);
        if (FAILED(hr) || state != ECS_ENABLED) return Fail("child disabled without selection metadata");
        EXPCMDFLAGS childFlags{};
        hr = child->GetFlags(&childFlags);
        if (FAILED(hr) || (childFlags & ECF_HASSUBCOMMANDS))
            return Fail("nested subcommands must not be registered");
        child->Release();
    }
    IExplorerCommand* extra = nullptr;
    ULONG fetched = 0;
    hr = enumerator->Next(1, &extra, &fetched);
    if (hr != S_FALSE || fetched != 0 || extra) return Fail("unexpected fourth menu command");

    enumerator->Release();
    root->Release();
    FreeLibrary(module);
    CoUninitialize();
    std::puts("Explorer flyout native runtime PASS: stable root CLSID, flags, and 3 ordered child commands.");
    return 0;
}
