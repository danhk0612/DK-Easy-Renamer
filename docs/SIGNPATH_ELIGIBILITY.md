# SignPath Foundation 무료 OSS 서명 신청 — 사전 자격 점검

기준: 2026-11-06. **사용자는 Windows 서명 게시자 `SignPath Foundation` 표시를 허용했다.** 이는 **신청·서명 요청·GitHub 공개 배포 승인과 다르다**. 이 문서는 실제 발급 가능 여부를 보장하지 않는다.

## 공식 요건 대비 프로젝트 상태

| SignPath 공식 요건 | 현재 확인 | 추가 조치 |
|---|---|---|
| OSI 승인 오픈소스 라이선스 | **PASS** — [MIT](../LICENSE), 공개 GitHub 저장소 | 배포된 외부 파일 라이선스까지 확인 |
| 소스/빌드 파이프라인의 관리 주체 | **PASS(저장소 내 근거)** — [danhk0612/DK-Easy-Renamer](https://github.com/danhk0612/DK-Easy-Renamer), GitHub-hosted Windows Actions | SignPath 프로젝트 소유권·GitHub origin 감사로 최종 심사 |
| 최근 유지관리·설명서·제거 기능 | **코드 근거 있음** — README/CI/Windows 설치·제거 | 실제 사용자 공개 다운로드 안내와 배포기록 보강 |
| **서명하려는 형식으로 기존 공개 릴리스** | **BLOCKED** — GitHub Releases 0건 | 공식 기관에 **서명 없는 APP-ONLY 공개만으로 이후 EXE+DLL+MSIX+Inno 서명 심사를 충족하는지** 먼저 질의. 확답 없이 공개를 승인받은 것으로 간주하지 않음 |
| 재단 서명 게시자 수용 | **사용자 승인 완료** | 실제 인증서 Subject는 **SignPath 발급/승인 이후** 확인 |
| 개인·팀 MFA 및 roles | **미검증** — [Code signing policy](CODE_SIGNING_POLICY.md)에 maintainer/approver 기재 | GitHub 및 SignPath 계정 MFA/권한을 사용자 직접 확인 |
| 개인정보 및 시스템 변경 고지 | **초안 있음** — 네트워크는 사용자가 업데이트 확인을 누를 때만 GitHub 접근; 설치 메뉴 선택형 | 실제 릴리스 다운로드 페이지에 한글 공지·개인정보 관련 범위 기재 |
| 공용/외부 바이너리 라이선스 | **일부 확인** — [WPF-UI MIT 및 Inno 고지](../THIRD_PARTY_LICENSES.md) | self-contained publish 산출물의 제3자/이진 파일 출처 및 SignPath의 upstream 서명 제한 확인 |
| 제품명/제품 버전 메타데이터 | **미검증** | 실제 PE EXE/DLL, MSIX, Inno Setup VersionInfo에 `DK Easy Renamer`와 동일 제품 버전을 반영하고 SignPath artifact metadata constraints 검증 |
| 동일 게시자 EXE·DLL·MSIX·Setup | **BLOCKED** — 현재 모든 signed 실행은 개발자 인증서 사용 | 승인된 SignPath 인증서 Subject/서명 정책 확정 후 패키지 Publisher를 정확히 맞춤 |
| 승인된 CI origin + signing requests | **미설정** | SignPath 계정, GitHub App, 승인 정책·API credentials 확보 후 별도 보안 설계; 외부 서비스와 GitHub 연결은 사용자 직접 승인 |
| 사용자 공개 배포 승인 | **아직 없음** | 게시할 파일·버전·서명 유무·제한 안내를 따로 확인 |

공식 요건: [SignPath Foundation Terms](https://signpath.org/terms.html), [신청 페이지](https://signpath.org/apply.html), [GitHub Trusted Build](https://docs.signpath.io/trusted-build-systems/github), [지원 파일 형식](https://docs.signpath.io/artifact-configuration/reference), [MSIX Publisher/서명](https://learn.microsoft.com/en-us/windows/msix/package/sign-msix-package-guide).

## 기술적으로 중요한 미해결 항목

1. **Inno Setup 중첩 서명 순서:** SignPath의 서명 서비스는 EXE·DLL·MSIX 형식을 지원하지만, `Inno Setup` 설치 프로그램 내부의 앱/임시 실행 파일과 **제거 실행 파일**을 서명하는 단계가 자동 해결되는 것은 아니다. 기존 로컬 키 기반 Inno `SignTool` 방식은 SignPath 원격 HSM 인증서와 바로 호환되지 않는다.
2. **개발 Publisher 변경:** 테스트 MSIX의 `CN=DK Easy Renamer Development`를 실제 재단 인증서 Subject로 변경하면 package family가 바뀌므로 기존 사용자의 자동 MSIX 교체를 강제하면 안 된다. [이전 안전 점검](UX07_PUBLISHER_MIGRATION_READINESS.md) 참고.
3. **서명 없는 APP-ONLY 공개 제한:** 출시 시 파일 탐색기 우클릭 통합 제공 불가, SmartScreen 경고 가능. [릴리스 검토 계획](PUBLIC_GITHUB_RELEASE_PLAN.md)에 따라 서명 전 임시 공개 릴리스를 실제 만들지 않았으며, SignPath에 **이미 릴리스된 형태** 요건을 먼저 확인해야 한다.
4. **인증서 정책 검토:** [PublicUpdatePolicy](../src/DK.EasyRenamer.Core/PublicUpdatePolicy.cs)의 approved Subject/Thumbprint는 공란이다. 서명 승인·Windows 실기기 설치/업데이트 전 검증까지 그대로 유지한다.
5. **신규 프로젝트 승인 불확실성:** 저장소가 새롭고 공개 Release·다운로드 기록이 없으므로, SignPath가 요구하는 프로젝트 평판·실제 사용자 신뢰를 충분히 갖췄다고 주장하지 않는다.

## 비공개 초기 후보 아티팩트

GitHub Actions의 검증된 APP-ONLY 테스트 설치본을 **재컴파일·파일명 변경 없이** 복사하고 파일 해시/서명 부재를 재검증하는 [Prepare-UnsignedAppOnlyPreview.ps1](../tools/release/Prepare-UnsignedAppOnlyPreview.ps1)를 사용한다.

```powershell
# windows-2022: 기존 CI에서 APP-ONLY 설치본 생성/검증 후 실행
pwsh -NoProfile -File .\tools\release\Prepare-UnsignedAppOnlyPreview.ps1
```

산출물 (**GitHub Actions 보관 아티팩트**이며 GitHub Release가 아님. 공개 저장소의 Actions 아티팩트는 접근 권한이 있는 사용자에게 다운로드될 수 있으므로 비밀 자료로 취급하지 않는다):

- `DK-Easy-Renamer-0.1.2-x64-APP-ONLY.exe` — 서명 없는 독립 실행형 설치본. 파일 이름 변경·UI 사용 가능, Explorer 통합 없음
- `SHA256SUMS.txt` — 설치 파일 단독 SHA-256
- `PREVIEW_MANIFEST.json` — 커밋·해시·버전·서명 여부·공개 여부
- `RELEASE_NOTES_DRAFT.md` — 사용자에게 표시할 한계·출처·해시·미공개 상태

**아티팩트를 GitHub Release에 공개하거나 `RELEASE.exe`로 이름만 변경해 배포하지 않는다.** Actions 아티팩트 이름의 `NOT-PUBLISHED`는 GitHub Release 미발행을 뜻하며 외부 다운로드가 절대 불가능하다는 의미는 아니다.

## SignPath에 확인할 질의 초안 (실제 전송 전 검토)

> Our project is DK Easy Renamer, a free MIT-licensed Windows 11 file/folder renamer built on public GitHub Actions. We intend to distribute on GitHub Releases, and accept the SignPath Foundation publisher identity. The final installer is built using Inno Setup and offers an optional native IExplorerCommand + sparse MSIX extension. We currently have no public GitHub Release.
>
> Would an initial **unsigned APP-ONLY Inno Setup release without the MSIX Explorer extension** meet your requirement that the software has already been released *in the form to be signed*, if our eventual SignPath-signed package will include the optional MSIX integration? If not, what initial release evidence or packaging would you require? Can your program support a staged signing workflow that signs our own EXE/DLL/MSIX and Inno Setup installer/uninstaller while ensuring the MSIX Publisher exactly matches the Foundation certificate Subject?
>
> We have documented roles, privacy, GitHub-hosted CI and a proposed code signing policy. No signing request has been submitted.

**다음 승인 경계**: 재단의 답변 없이 공개 릴리스를 생성하지 않음. 사용자 계정 MFA와 SignPath 가입·외부 문의 전송 및 Release 공개는 각각 별도 승인 필요.
