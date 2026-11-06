# DK Easy Renamer — 무료 GitHub Releases 배포 및 서명 계획

기준: 2026-11-06. 사용자 확정 조건은 **완전 무료 프로그램**, **GitHub Releases 직접 배포**, **서명 비용 0원**, 실명 표시 허용이다. 이 문서는 정책·준비 자료이며 실제 공개 Release·태그·서명 요청·비밀정보 변경은 승인하지 않는다.

## 최종 선택과 제약

**1순위: [SignPath Foundation](https://signpath.org/) 무료 오픈소스 코드 서명 심사 신청**. SignPath.io의 서명 서비스를 통해 승인된 OSS 프로젝트의 EXE·DLL·MSIX 등을 서명한다. 인증서 소유자와 Windows에 표시되는 **게시자 명의는 SignPath Foundation**이며 개인 명의 인증서가 아니다. **사용자는 2026-11-06에 해당 게시자 명의 사용을 승인했다.** GitHub 프로젝트 소유권과 이름은 변경되지 않는다.

- [공식 가입 및 자격 요건](https://signpath.org/terms.html): OSI 승인 오픈소스 라이선스, 자체 프로젝트·자체 소스, 지속 관리, 기능 문서화, **서명하려는 형태로 기존 공개 릴리스가 존재할 것**, 기여자 MFA, 코드 서명 정책, 수동 서명 승인 등이 요구된다. OSS와 제3자 재배포 파일에 대한 정책 심사는 공급자 재량이며 **승인 보장 없음**.
- [SignPath 공식 서명 파일 형식](https://docs.signpath.io/artifact-configuration/reference): .exe/.dll (PE) 및 .msix 지원. **파일 형식 지원**과 **이 프로젝트의 Inno Setup + 외부 위치 sparse MSIX 일괄 서명이 가능한 승인된 구성**은 별개다. 정확한 artifact configuration·SignPath 인증서 Subject·설치 및 서명 순서는 승인 이후 결정한다.
- [GitHub Actions 공식 연결](https://docs.signpath.io/trusted-build-systems/github): 공개 저장소에서 GitHub-hosted runner로 구축·업로드한 아티팩트, SignPath GitHub App 및 origin 검증, 승인된 API 토큰·프로젝트 설정을 필요로 한다. 실제 구성값/토큰을 임의로 만들지 않는다.
- **한국 개인 명의 공인 CA 인증서 무료 발급은 현재 확인된 경로가 없음.** Microsoft의 [코드 서명 비교](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options)는 개인/일반 OV CA를 유료로 분류하고, Azure Artifact Signing 개인 신청을 미국·캐나다에 한정한다. **무료 + 개인 실명 서명 + GitHub 직접 배포** 세 조건을 동시에 제공한다고 주장하지 않는다.
- 예비 대안: SignPath 거절/미승인 시 **서명 없는 APP-ONLY** GitHub 설치본만 사용자 명시 승인 후 배포할 수 있다. Windows 탐색기 MSIX 메뉴 통합과 공인 게시자 표시는 제공하지 못하고 SmartScreen 경고가 나올 수 있다. 기존 테스트용 자체 서명을 일반 사용자에게 신뢰 등록하도록 안내하지 않는다.
- 다른 무료 서명 제공자 [OSSign](https://ossign.org/)은 확인 당시 **신청 중단**을 공지했다. [Necessary Code Signing](https://sign.necessary.nu/)은 이미 널리 이용되는 프로젝트를 대상으로 한 제한적 프로그램이다. 현재 확실한 대안으로 보지 않는다.

## 초기 공개 릴리스와 신청 순서

SignPath 자격 요건에는 이미 **서명할 형태의 공개 릴리스**가 필요하다. GitHub Actions의 임시 다운로드 아티팩트는 GitHub Release로 인정된다고 보장할 수 없고, 현재 공식 GitHub Release는 **0건**이다.

1. **공개 전 내부 준비**: README 최신 안내, 실제 배포 파일 내 오픈소스 라이선스 고지, 서명 없는 APP-ONLY 후보를 **비공개 준비 아티팩트**로 분리해 설치·제거·SHA-256·변경 내역을 확인. [SignPath 자격 점검](SIGNPATH_ELIGIBILITY.md)과 [준비 스크립트](../tools/release/Prepare-UnsignedAppOnlyPreview.ps1)를 사용한다. 사용자 별도 승인 없이 릴리스·태그를 만들지 않는다.
2. **서명 없는 초기 공개 검토**: **APP-ONLY Inno Setup EXE**만 공개하는 경우 탐색기 메뉴가 없고 SmartScreen 경고가 발생할 수 있음을 명시한다. 현재 TEST-ONLY 파일을 이름만 바꿔 공개하거나, 서명 검증을 우회하거나, 개발 자체 서명을 공식 인증서로 표시하지 않는다. *APP-ONLY만 공개한 이력이 전체 EXE+MSIX 패키지를 서명하려는 형태의 공개 릴리스 요건에 충분한지 SignPath에 문의해야 한다.* 사용자 승인 전 어떤 공개 배포도 금지한다.
3. **공식 심사 신청**: [신청 페이지](https://signpath.org/apply.html)를 통해 공개 프로젝트·릴리스·[코드 서명 정책](CODE_SIGNING_POLICY.md), 공개 빌드 내역을 제시한다. 계정 등록/서약/MFA/신청 제출은 사용자가 수행해야 한다. 외부 기관 승인 전 서명 성공을 가정하지 않는다.
4. **승인 후 서명 통합**: 실제 발급 인증서의 정확한 Subject와 정책·토큰을 확인한 뒤, MSIX manifest + embedded app manifest publisher 일치, 앱 EXE, 네이티브 DLL, MSIX, Inno Setup 및 uninstaller 서명 순서 확정. 현재 [Build-Distribution.ps1](../tools/t05/Build-Distribution.ps1)은 로컬 `Cert:\CurrentUser\My`의 **개인키 보유 인증서**로 SignTool/Inno Setup을 실행하는 방식이므로 SignPath 원격 서명에 **그대로 연결되지 않는다**. GitHub Actions 경유 signed artifact를 재패키징하는 적절한 단계 구성이 별도로 필요하다.
5. **인증서 게시자 변경 처리**: 기존 `CN=DK Easy Renamer Development` MSIX에서 SignPath Foundation의 정확한 Publisher로 변경할 경우 **패키지 패밀리가 달라져** 일반 업그레이드가 아니다. [사전 진단](UX07_PUBLISHER_MIGRATION_READINESS.md), 구 설치본 백업, 소유권 확인, 명시적 동의 및 복구 경로 확인 전 기존 등록을 자동 제거하지 않는다.
6. **최초 서명 Release**: 보안 검증된 실제 Windows 11 설치·탐색기 메뉴·앱 적용/Undo·업그레이드·제거, GitHub 아티팩트 해시 및 Signature 상태 확인, 앱의 공개 업데이트 정책을 별도 검토한 뒤 사용자 명시 승인으로 발행한다.

## 코드 서명 정책 및 개인정보

- 신청 전 [Code signing policy](CODE_SIGNING_POLICY.md) 초안을 유지한다. 아직 SignPath 승인이 없어 인증서 게시자를 실제 적용했다고 표시하지 않는다.
- 서명 권한 역할은 프로젝트 GitHub 관리자 `danhk0612`를 기준으로 작성했다. 실제 Signing Approver, 정책 및 MFA 활성화는 서비스 이용 시작 전에 사용자가 직접 확인해야 한다.
- 애플리케이션은 로컬에서 이름 변경을 수행하며 사용자가 **업데이트 확인**을 눌렀을 때만 GitHub의 공개 Releases API에 접속한다. 별도 상시 모니터링 서비스·백엔드는 없다. 공개 개인정보 고지에는 실제 종속 라이브러리/네트워크 작동도 검증해야 한다.
- SignPath 인증서의 개인키는 SignPath HSM에서 관리하며 GitHub/개발자 PC로 내보내지 않는다. 비밀 토큰을 PR·로그·릴리스 자산에 기록하지 않는다.

## 출시 안전 조건

- 앱 원본 기능·버전/설치본 검증을 유지하고 `PublicUpdatePolicy.ApprovedSubject`/`ApprovedThumbprint`를 **빈 값**으로 유지한다. 공개 서명자 승인 및 업데이트 실제 시험 전 자동 설치는 차단된다.
- SignPath 심사에 제출하는 저장소는 오픈소스 코드·빌드 흐름을 정확히 반영해야 한다. Inno Setup runtime·WPF-UI 등 서드파티 고지, 상용 코드 포함 여부, OSI 기준 적합성은 제출 전 확인한다.
- 설치 프로그램과 MSIX에 표시되는 Publisher는 별개의 임의 값일 수 없다. **서명 인증서 Subject와 매니페스트 Publisher의 정확한 동일성**이 필요하다.
- 서명 없는 초기 릴리스를 정식 서명본으로 속이거나 강제 신뢰 등록 안내를 하지 않는다.
- **서명 비용 0원 조건을 바꾸지 않는다.** 유료 CA, Microsoft 유료 서비스, 유료 Store 등록·상업 라이선스 구매는 제안할 수 있으나 사용자 새로운 결정 전 실행하지 않는다.

## 확인/승인 필요

- **재단 명의 게시자**: **사용자 승인 완료 (2026-11-06)**. 정확한 서명 인증서 Subject·신뢰 체인은 SignPath 승인 이후 확인.
- **서명 없는 APP-ONLY 초기 릴리스 승인 여부**: 실제 공개 범위, 버전, SmartScreen/메뉴 제한을 이해한 뒤 별도 결정. APP-ONLY 공개가 '서명하려는 형태' 조건을 충족하는지 재단의 확인을 먼저 받아야 한다.
- **SignPath 가입·MFA·심사**: 외부 서비스 계정은 사용자 직접 연결·승인 필요.
