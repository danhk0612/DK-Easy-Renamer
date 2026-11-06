# Third-party license register

DK Easy Renamer's own source code is MIT licensed. This register records externally distributed packages and their licenses.

## WPF UI
- Package: WPF-UI, version 4.3.0
- Purpose: Fluent controls, icons, light/dark theme resources for the Windows 11 WPF application.
- License: MIT.
- Package: https://www.nuget.org/packages/WPF-UI/4.3.0
- Source: https://github.com/lepoco/wpfui
- License text: https://github.com/lepoco/wpfui/blob/main/LICENSE
- Runtime dependency: WPF-UI.Abstractions, version 4.3.0
- Runtime dependency license: MIT, as listed by NuGet.
- Dependency package: https://www.nuget.org/packages/WPF-UI.Abstractions/4.3.0

The license notices inside the actual self-contained published app still require verification before a public release. Windows Segoe fonts are installed by Windows; this repository does not redistribute font files. The application logo and generated ICO are original project artwork.

## Inno Setup 6
- Tool: Inno Setup 6 (CI verified with 6.7.1) to generate the Windows setup program.
- The installer runtime is distributed according to the Inno Setup license, which is distinct from the MIT license for DK Easy Renamer's source.
- Official project/license: https://jrsoftware.org/isinfo.php
- Retain the original Inno Setup license and review its terms before distributing the signed installer. No compiler binaries or private signing keys are committed to this repository.
- Official commercial-use guidance (reviewed 2026-11-06): https://jrsoftware.org/isorder.php — Inno Setup **requests** a commercial license for qualifying commercial users; the publisher says purchasing is **not strictly required**. Whether that request applies depends on the actual for-profit use/revenue; personal free/open-source use must not be mislabeled commercial without confirmation.
- Release gate: re-check the upstream Inno Setup license text and the published installer binary's redistributed notices before first public Release.
