# DK Easy Renamer — 정식 배포 준비 점검 (2026-11-06)

> 범위: 코드·문서·GitHub Actions·기존 사용자 확인 기록을 대조한 **read-only release readiness audit**. 본 문서는 정식 Release, 공개 코드 서명, 설치/인증서 변경, 자동 업데이트 활성화를 승인하지 않는다.

## 기준과 판정

- 기준 커밋: `78fd0ffbfcfd15581bfc1e370263420767e2e848` (`main` / PR #47 병합).
- 현재 앱 및 테스트 설치본 버전: **0.1.2**. CI에서 0.1.2→0.1.3은 임시 업그레이드 시험일 뿐, 0.1.3 정식 버전은 아니다.
- [PR 전체 CI #42170126651](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/42170126651): .NET·C++·COM 메뉴, 임시 인증서로 서명한 패키지, Windows Server 2025 설치·제거·업그레이드·옵션 메뉴 자동 검사 **성공**.
- [병합된 main CI #42170723126](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/42170723126): 빌드·패키징 **성공**. **PR 전용 Windows Server 2025 설치·제거·업그레이드 후속 job은 skipped**. Main 빌드만 보고 실제 설치 자동검사가 새로 실행됐다고 주장하지 않는다.
- Windows 11 사용자가 이전 GUI 기능과 단일 Explorer 메뉴의 세 명령 실행을 확인했다. 가장 최신 **파일·폴더별 메뉴 구분 PR #47**은 사용자 요청에 따라 **추가 수동 기능 테스트를 생략**했고, COM 빌드/런타임 자동검사만 완료했다. [T04 이슈 #7](https://github.com/danhk0612/DK-Easy-Renamer/issues/7) 참고.
- 확인 당시 [GitHub Releases](https://github.com/danhk0612/DK-Easy-Renamer/releases)에 **정식 Release가 0건**이며, 생성된 빌드는 모두 TEST-ONLY 아티팩트다.

**종합 판정: 개발 기능은 테스트 배포 가능한 수준이지만, 일반 사용자 대상 정식 설치본 및 앱 내 자동 업데이트는 아직 차단(BLOCKED) 상태.**

## 확보된 기능·검증

| 범위 | 확보한 근거 | 한계 |
|---|---|---|
| WPF 앱 기능 | 파일/폴더 선택, 범위별 폴더 추가, 정렬, 미리보기, 실제 이름 변경·Undo, UI/규칙 목록 내부 우클릭에 대한 사용자 확인 | 최근 UI 변경마다 전체 수동 회귀를 수행한 것은 아님 |
| 탐색기 메뉴 | 단일 flyout으로 일반/순번/찾기·바꾸기 실행 사용자 확인; PR #47은 파일/폴더 각각 전용 COM 루트 및 3개 명령 런타임 검사 성공 | PR #47 최신 문구의 Win11 수동 재확인은 사용자 요청으로 생략 |
| 테스트 패키징 | 0.1.2 테스트 APP-ONLY EXE 및 개발용 서명 Explorer EXE+MSIX 생성; 해시·서명·패키지 정합성 검사 | CI 자체 서명은 공인 서명/SmartScreen 신뢰가 아님 |
| 설치 수명주기 | Windows Server 2025 disposable runner에서 서명 설치·제거, 선택적 Explorer 등록, 0.1.2→임시 0.1.3 업그레이드 성공 | 실제 공개 서명자, 첫 공개 설치 및 Windows 11 게시자 전환은 미검증 |
| 업데이트 확인 (UX-07a) | 사용자가 **업데이트 확인** 버튼을 눌러야 공식 `/releases/latest` 조회; 정식 버전·릴리스 노트 표시·링크 열기 | 아직 공개 Release가 없어 실제 최신 공개 버전 양성 시나리오 미확인 |
| 검증된 설치 인계 (UX-07b 기초) | 공식 asset/해시, 다운로드 저장, Authenticode 공개 게시자 검증, 실행 직전 재확인, 승인 후 인계·정리 코드는 존재하고 CI fixture 테스트 통과 | `PublicUpdatePolicy.ApprovedSubject/ApprovedThumbprint`는 **빈 문자열**이므로 공개 업데이트 설치 경로는 현재 의도적으로 비활성 |

## 정식 배포 차단 항목 — 우선순위

| 우선순위 | 항목 | 실제 상태 | 해제 조건 |
|---|---|---|---|
| **P0** | 공인 배포 서명자 | 공개 서명 서비스/인증서 **미선정**. 현재 CI는 단기 개발용 자체 서명만 사용 | 공식 배포 신뢰 체인/게시자 선택, 정확한 Subject·지문 관리 및 EXE·DLL·MSIX·Setup 서명 일치 확인. 개인 키를 저장소에 커밋하거나 대화로 공유하지 않음 |
| **P0** | 기존 테스트 MSIX → 공개 게시자 | 현재 MSIX Publisher는 `CN=DK Easy Renamer Development`. 공개 Publisher가 바뀌면 package family/COM 소유권이 바뀌며 이전 등록을 일반 업그레이드로 교체할 수 없음 | 새 사용자 설치와 기존 개발용 테스트 설치 사용자의 **안전한 제거/이전**을 분리해 정책 승인. 필요 시 이전 서명 설치본·MSIX 보관, AppData 백업, 소유권 검증 및 실패 복구를 Win11에서 확인; 무단 자동 이전 금지 |
| **P0** | 실제 공개 서명 설치 수용 | 유효한 *공개* 서명 설치본으로 Windows 11 최초 설치·탐색기 3개 메뉴·등록 및 완전 제거·설치 경로 유지 검증 없음 | 공개 인증서로 만든 RC를 격리된 Win11에서 설치/업그레이드/제거(사용자 데이터 보존 포함)해 확인 |
| **P0** | 정식 Release 자산 계약 | 현재 공식 Release가 없고, `.github/workflows/`에는 CI 워크플로만 있음. 테스트용 `SIGNED-PROBE`를 공식 릴리스로 간주할 수 없음 | 버전 결정, `DK-Easy-Renamer-X.Y.Z-x64-RELEASE.exe` 명명, 공식 HTTPS Release 자산·SHA-256·릴리스 노트 확인, 이력을 재현할 수 있는 공개 배포 절차 확정 |
| **P1** | UX-07b 공개 업데이트 실제 양성 검증 | 해시·서명·게시자 검증 로직과 CI fixture 존재, 하지만 공개 승인 signer·Release 없는 상태라 앱에서 설치 기능 차단 | P0 해제 후 pinned public publisher 정책 활성화에 대한 별도 코드 리뷰, 새 버전 다운로드·승인·인계·업그레이드/실패 복구 Win11 점검 |
| **P1** | 제3자 재배포 라이선스 | `THIRD_PARTY_LICENSES.md`에 WPF-UI MIT와 Inno Setup 안내 있음. 문서에 종속 패키지 라이선스·Inno 라이선스 확인을 **공개 배포 전 과제**로 명시 | 실제 게시 아티팩트에 필요한 전이 의존성 고지 및 Inno Setup 배포 조건 확인 |
| **P1** | 사용자 문서/버전 정리 | `README.md`, `docs/TASKS.md`, `docs/INSTALLER.md` 일부는 0.1.1·옛날 2개 Explorer 메뉴·2026-11-05 기준을 서술 | 현재 버전 0.1.2/파일·폴더별 3개 메뉴/서명·업데이트 제한으로 현재 상태 갱신; 구버전 이력은 명시적으로 역사 기록으로만 유지 |
| **P2** | 반복 시험용 고정 개발 인증서 | 테스트 인증서는 기본 CI 실행마다 변경됨. 고정 PFX 및 `dev-signing` 환경 자동화 문서는 있으나 현 저장소 조회만으로 환경 secret 설치 여부 확인 불가 | 반복 Windows 테스트가 필요할 경우 사용자 소유 비공개 키로 별도 환경 구성·승인. 공개 배포 인증서와 혼동 금지 |

## 현재 단계에서 진행하면 안 되는 것

- TEST-ONLY/SELF-SIGNED `SIGNED-PROBE` 또는 `APP-ONLY`를 `RELEASE.exe`로 개명하거나 GitHub Release에 게시하지 않는다.
- `PublicUpdatePolicy`에 개발용 인증서를 채워 자동 설치를 활성화하지 않는다.
- 게시자 다른 기존 패키지를 자동 제거하거나 인증서를 자동 신뢰 등록하지 않는다.
- 서버 CI PASS를 실제 공개 신뢰·Windows 11 전체 배포 승인으로 대체하지 않는다.

## 실행 가능한 다음 작업

1. **즉시 가능 (기존 범위 내)**: README/TASKS/INSTALLER의 구버전 설명과 2026-11-06 변경 이력 정리, 첫 공개 Release 후보 체크리스트/릴리스 노트·SHA-256 산출물 형식 정의, 라이선스 점검. 정식 Release 발행은 하지 않는다.
2. **사용자 의사결정 필요**: 공개 인증서 또는 배포 서명 서비스 및 공식 Publisher identity 선택. 특히 **기존 개발용 설치 사용자에게 초기화 재설치를 허용할지, 설정 보존을 동반한 게시자 이전을 지원할지** 정책 확정.
3. **서명자 확보 이후**: 공개 서명 릴리스 후보 만들기 → Windows 11 신규·기존 설치/메뉴/제거/실패 복구 검증 → 공개 업데이트 정책 및 다운로드 설치 기능 활성화 검토 → 사용자 승인 후 첫 Release.

## 근거 파일 및 이슈

- [공개 signer 미설정](../src/DK.EasyRenamer.Core/PublicUpdatePolicy.cs) · [수동 업데이트 확인](../src/DK.EasyRenamer.App/MainWindow.Updates.cs) · [설치 인계](../src/DK.EasyRenamer.App/MainWindow.UpdateInstall.cs)
- [배포 스크립트](../tools/t05/Build-Distribution.ps1) · [Inno Setup 선택형 Explorer 메뉴](../installer/windows/DK-Easy-Renamer.iss) · [현재 MSIX identity](../installer/shell/AppxManifest.xml)
- [Windows 11 수용 조건](T04_ACCEPTANCE.md) · [공개 게시자 변경 준비](UX07_PUBLISHER_MIGRATION_READINESS.md) · [서명 이전 설치본 복구 자료](UX07_SIGNED_ROLLBACK_ARCHIVE.md)
- [T04 이슈 #7](https://github.com/danhk0612/DK-Easy-Renamer/issues/7) · [UX-07 이슈 #10](https://github.com/danhk0612/DK-Easy-Renamer/issues/10)

_이 보고서는 2026-11-06 시점의 저장소 증거를 정리하며, 현지 Windows 11 장치나 개인 인증서 저장소를 변경하지 않았다._
