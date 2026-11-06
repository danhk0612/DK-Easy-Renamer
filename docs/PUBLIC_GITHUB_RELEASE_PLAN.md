# DK Easy Renamer — 한국 개인 개발자 / GitHub Releases 공개 배포 계획

작성 기준: 2026-11-06. **계획·준비 문서이며 실제 공개 Release, 인증서 결제, 서명 활성화가 아니다.**

## 결정된 조건

- 배포: **GitHub Releases 직접 다운로드**, Windows 11 x64, Inno Setup 설치 EXE + 선택형 Windows 11 Explorer 우클릭 통합 sparse MSIX.
- 법적 게시자: **한국 거주 개인 개발자**(사업자·법인 아님). 인증서 주체는 실제 CA 신원 검증 결과와 정확히 일치해야 한다. 가상의 개인 이름/조직명 사용 금지.
- 기존 GitHub 테스트 빌드의 자체 서명 MSIX는 일반 사용자용이 아니며 공개 배포 금지.
- 결제·개인정보 제출·인증서 생성·게시자 변경·정식 Release 발행에는 별도 사용자 조치/승인이 필요.

## 서명 정책과 발급 순서

**개인 명의 공인 코드 서명 인증서를 발급받기 위해 먼저 서명 없는 실행 파일을 GitHub Release로 배포할 필요는 없다.**
CA에는 개발자 신원 확인, 배포 프로젝트 URL, 추가 증빙이 필요할 수 있다. GitHub 원본 코드 공개 및 MIT 라이선스는 이미 충족하는 조건이다.

1. **1차 발급 경로: 개인 신청이 가능한 CA 코드 서명 인증서.** Sectigo는 OV(non-EV) 코드 서명에 *individual* 신청을 공식적으로 허용한다. 최종 주문은 한국 거주자 수용, 최소 비용, 원격 HSM/USB 토큰 제공 방식, SignTool과 Inno Setup 호환성 및 환불 조건을 확인한 뒤 진행한다. 아직 CA/상품·구독료는 **구매 확정하지 않았다**.
2. **비영리 OSS 대안: Certum Open Source Code Signing.** 발급 대상은 개인이며 공개 저장소 소유자·신원·주소 증빙이 필요하고, *상업적 배포*에 사용할 수 없다. 현재 공식 Certum Cloud 상품 페이지는 **€49부터, 품절**로 표시되고 있고, 자체 카드 소지자용 코드 상품도 품절 표기가 있으므로 지금 발급 가능하다고 가정하지 않는다. 개인 명의이긴 하지만 인증서 CN에는 'Open Source Developer' 접두어가 붙는다. **무료 다운로드·비상업적 운영 여부를 사용자에게 확인한 뒤** 이용 가능 시 검토한다.
3. **무료 서명 대안: SignPath Foundation.** 오픈소스 프로젝트 무료 인증서 지원, EXE/MSIX 서명 지원. 그러나 인증서 게시자가 *SignPath Foundation*이 되므로 **개인 명의 서명이라는 현재 선택에는 일치하지 않는다**. 발급 전 이미 공개 릴리스가 있어야 한다는 별도 조건도 있다. 따라서 개인 명의 고수 시 기본 경로로 선택하지 않는다.
4. **현재 사용 불가:** Azure Artifact Signing Public Trust 개인 개발자 신청은 공식 문서상 미국·캐나다 거주자로 제한된다. 한국 개인 개발자 계정에 적용할 수 있다고 가정하지 않는다.
5. 자체 서명 테스트 인증서 또는 unsigned APP-ONLY EXE는 공인 인증서를 대체하지 않는다. 공인 CA 인증서로 서명해도 SmartScreen 평판이 즉시 확보되는 것은 아니다.

참고:
- [Microsoft — Windows code signing options](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options)
- [Microsoft — MSIX signing and Publisher match](https://learn.microsoft.com/en-us/windows/msix/package/sign-msix-package-guide)
- [Sectigo — Individual OV identity validation](https://www.sectigo.com/knowledge-base/detail/OV-Code-Signing-Validation-for-Organizations-and-Individuals)
- [Certum — Open Source identity verification](https://support.certum.eu/en/code-signing-required-documents/)
- [Certum — Open Source cloud product](https://shop.certum.eu/open-source-code-signing-on-simplysign.html)
- [SignPath Foundation terms](https://signpath.org/terms)

## 패키징 / 공개 서명 연계

- 서명 대상: 게시용 앱 EXE, 네이티브 Explorer COM DLL, **해당 Subject와 MSIX manifest Identity.Publisher가 일치하는 MSIX**, Inno Setup 설치 EXE 및 제거 프로그램. 하나의 공개 게시자 정체성을 기준으로 검증한다.
- 현재 [Build-Distribution.ps1](../tools/t05/Build-Distribution.ps1)은 `Cert:\CurrentUser\My`의 개인 키 보유 인증서와 SignTool을 전제로 한다. **USB 토큰/클라우드 HSM이 발급된 후 실제 SignTool 접근 방식·타임스탬프·Inno Setup 자동 서명을 시험하기 전까지** 기존 옵션만으로 외부 서명 서비스 통합이 끝났다고 주장하지 않는다.
- CA 인증서의 개인 키는 Git 커밋, GitHub Release, Actions artifact, 일반 issue/comment, 채팅에 업로드하지 않는다. 초기 공개 서명은 **보호된 사용자 로컬 Windows 환경에서 수동 승인·서명**하고, GitHub Actions는 신뢰 가능한 원본 빌드와 테스트 근거만 제공하는 방식을 우선 검토한다. CI 자동 서명은 별도 공급자/API 확인 후 검토한다.
- 기존 테스트 Publisher `CN=DK Easy Renamer Development`와 실제 CA의 개인 Subject는 다르다. 기존 개발용 MSIX를 설치한 테스트 사용자에 대한 Publisher 변경/제거는 **안전한 수동 전환 절차**로 별도 확인한다. 패키지 소유권을 무시한 자동 제거는 금지한다.
- [PublicUpdatePolicy.cs](../src/DK.EasyRenamer.Core/PublicUpdatePolicy.cs)의 승인 Subject와 Thumbprint는 **여전히 공란**이다. 공개 인증서 발급 및 첫 서명된 업데이트 회귀 테스트 전에는 값을 채우지 않는다.

## GitHub Releases 최초 공개 계약 (미발행)

첫 공개 릴리스에는 다음이 필요하다.

- **버전·태그는 인증서 수령 후 확정.** 현재 코드/테스트는 0.1.2이며 CI의 0.1.3은 업그레이드 테스트 픽스처일 뿐 실제 배포본이 아니다.
- 자산: `DK-Easy-Renamer-X.Y.Z-x64-RELEASE.exe` (**개인 CA로 검증된 정식 서명만**), `SHA256SUMS.txt`, 라이선스·변경 로그·설치/제거 설명. MSIX는 설치 프로그램 내부에서 처리; 별도 공개 자산 여부는 확정 전 확인.
- 공식 릴리스 태그와 앱 Assembly.Version, MSIX Identity Version, 설치 프로그램 버전의 일치 확인. 기존 [릴리스 파서](../src/DK.EasyRenamer.Core/StableReleaseParser.cs) 및 [asset 검증](../src/DK.EasyRenamer.Core/OfficialInstallerAssetVerifier.cs)의 계약을 맞춘다.
- CI 빌드/단위 테스트/COM 런타임 검사, 서명 파일 검증(Signtool/Authenticode + timestamp), ZIP/EXE/MSIX Publisher 정합성, SHA-256, 실제 Windows 11 첫 설치·Explorer 메뉴·제거·업그레이드/Undo/데이터 보존을 검증한다.
- 개인 CA로 이름을 드러내는 **서명자 Subject가 최종 사용자에게 표시될 수 있음**을 확인한다. Github 계정 표시 이름과 인증서의 법적 이름은 다를 수 있다.
- 공개 버전은 사용자의 별도 최종 승인 전 **Release/tag를 생성하지 않는다**.
- unsigned APP-ONLY를 굳이 공개해 CA 신청에 활용할 이유는 없다. **SignPath Foundation을 신청하는 경우에만** '기존에 릴리스된 형태' 요건을 먼저 확인하고, unsigned 사전 공개를 제안할 때 사용자의 동의를 받는다.

## 배포 전 체크리스트

- [x] 공개 GitHub 소스 저장소 및 MIT 라이선스
- [x] Windows 빌드/단위 테스트/COM 등록/개발 인증서 설치·제거·업그레이드에 관한 CI 근거
- [x] 기존 Windows 11 앱 기능·Explorer 통합 사용자 확인 기록 (단, 가장 최근 파일/폴더 문구 변경은 자동 검사만 수행)
- [ ] 개인 CA 인증서 공급자/비용/발급 요건 **실제 승인 및 주문**
- [ ] 실제 공개 인증서 Subject, thumbprint, 개인키 저장/접근 방법 및 서명 절차 검증
- [ ] EXE/DLL/MSIX/Inno setup/uninstaller 전체 서명 및 게시자 일치
- [ ] 개발용 Publisher → 공인 Publisher 전환/롤백 및 새 사용자 설치 검증
- [ ] 제3자 라이선스/번들 고지 및 README 최종 정확성 확인
- [ ] 공식 Release 후보 해시/버전/문서/SmartScreen 고지 검증
- [ ] 첫 공개 Release/tag 발행 **최종 사용자 승인**

## 다음 결정

**상업적 사용/유료 배포 예정 여부**, **연간 인증서 비용 예산**, **실명이 Windows 게시자로 노출되어도 되는지**를 사용자에게 확인해야 발급 방식을 최종 잠글 수 있다. 답변 전까지는 개인 명의 유료 CA를 *기준 경로*로 유지하고, 발급 주문·공개 출시는 실행하지 않는다.
