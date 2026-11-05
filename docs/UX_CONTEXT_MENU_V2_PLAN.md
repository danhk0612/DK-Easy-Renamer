# DK Easy Renamer — 공개 배포 전 UX/속도 개선 계획

작성: 2026-11-04. 기준: main acb5d2bcaadcc750485a31ce0470b74edad25e25.
상태: **검토안. 기능 코드 변경/정식 배포 승인 아님.** 서명 공개 배포 준비는 별도 브랜치이며 이 계획에 포함하지 않는다.

## 1. 현재 구현 확인

- Explorer: src/DK.EasyRenamer.Shell/ExplorerCommand.cpp는 IExplorerCommand 한 개만 제공한다. GetTitle은 “DK Easy Renamer로 이름 변경”, GetState는 선택 개수, GetIcon은 HKCU 설치된 아이콘 경로를 사용한다. EnumSubCommands는 E_NOTIMPL. Invoke는 선택 경로를 DKR1 UTF-16LE 임시 패킷에 저장하고 독립 WPF 프로세스를 실행한다. 탐색기 안에서 파일명을 변경하지 않는 점은 유지한다.
- WPF: App.xaml.cs는 --selection-file 한 가지만 처리한다. MainWindow는 전체 규칙 편집 화면으로 열린다. 규칙 프리셋/최근 사용 규칙 저장, 빠른 작업 진입점, 파일/폴더 종류별 목록 필터는 없다.
- 미리보기: 규칙 입력마다 RefreshPreview → RenamePlanner.Build → 파일 상태 Capture를 전체 선택 목록에 대해 다시 수행한다. 10,000개/느린 네트워크 경로에서는 UI 정지 가능성이 있으나 **실측하지 않았으므로 성능 결함 확정은 아님**.
- 명확한 검토 포인트: RenamePlanner.Build의 선택 폴더 포함 검사 dirSources.Any는 목록·폴더 수가 커지면 반복 검색한다. RenameSelectionSorter.Sort는 내림차순에서 Reverse를 사용해 동률의 기존 순서를 뒤집을 수 있다(“안정 정렬” 주석과 불일치).
- 선행 테스트: Windows Server 2025에서 패키지 설치·제거, WPF 제목, 한글/일본어 선택 패킷의 GUI 수신 성공. 실제 Windows 11 작업표시줄/창 조작/메뉴 클릭/파일 변경 및 Undo는 issue #7에 남는다.

## 2. 우클릭 UX 권장안

### 목표 경험 (실제 Windows 11 위치/그룹 방식은 프로토타입 검증 필요)

기본 동작은 종전과 같아야 한다: “DK Easy Renamer로 이름 변경”을 누르면 선택 항목을 전체 편집기로 연다.

추가 작업은 **원칙적으로 하나의 앱 그룹/하위 메뉴에 모아** 메뉴를 불필요하게 늘리지 않는다.

- **전체 이름 변경:** 기존 규칙 편집 화면. 현재 동작을 유지한다.
- **빠른 순번 변경…:** 선택 항목을 받아 작은 편집/미리보기 창에서 시작 번호·증가값·자릿수·이름 앞/뒤·기존 이름 대체를 설정한다.
- **빠른 찾기·바꾸기…:** 찾을 문자·대체 문자·대소문자 무시를 표시하고 미리보기 후 변경한다.
- **저장한 규칙으로 열기…:** 앱에서 저장한 프리셋 선택 또는 마지막 사용 프리셋을 미리 적용한 미리보기로 연다. 프리셋이 없으면 정상 안내 화면으로 이동한다.

메뉴 구현 후보:
A. 기존 단일 최상위 명령은 그대로 두고, 별도 빠른 작업 명령/그룹을 추가한다.
B. 앱 단일 상위 명령의 IExplorerCommand::EnumSubCommands + ECF_HASSUBCOMMANDS로 위 동작을 묶는다.
Windows 11은 여러 앱 동작을 시스템이 플라이아웃에 묶기도 한다. **A/B 모두 실제 Windows 11 빌드에서 1회 클릭/추가 클릭 수·표시 순서·기존 첫 번째 메뉴 노출을 확인하고 선택한다.** 하위 메뉴의 하위 메뉴는 Explorer에서 지원되지 않으므로 설계 금지. Microsoft의 2026년 Insider 컨텍스트 메뉴 변경은 모든 Windows 11에 배포됐다고 전제하지 않는다.

**기본 정책:** 우클릭만으로 파일명을 자동 변경하지 않는다. 어떤 빠른 작업도 반드시 변경 전/후 미리보기, 변경 대상 수, 충돌·제외 상태와 최종 확인을 제공한다. 파일 확장자는 명시적 변경 규칙이 없으면 보존한다. 폴더 선택 자체만 변경하며 재귀 접근하지 않는다.

### COM ↔ WPF 전달

- 기존 설치 패키지 이름 DKEasyRenamer.Shell, COM CLSID, DKR1 선택 패킷, Explorer 메뉴 기본 동작과 한글 메뉴 제목을 유지한다.
- 새 빠른 작업의 식별자는 **고정된 enum/허용 목록**으로 앱에 전달한다. 경로나 규칙 JSON을 명령행 문자열로 전달하거나 쉘 프로세스에서 임의 사용자 프리셋 파일을 파싱하지 않는다.
- Shell 메서드 GetTitle/GetIcon/GetState/EnumSubCommands는 네트워크/파일 메타데이터 열거/규칙 검사/JSON 역직렬화를 하지 않는다. Invoke 이후에만 선택을 수집하고 앱을 실행한다.
- WPF가 명령 식별자와 선택 패킷을 검사하고, 전체 편집/빠른 편집/프리셋 화면으로 라우팅한다. 기존 --selection-file만 실행하는 호출은 변경하지 않는다.
- 선택이 없는 폴더 배경 메뉴는 후속 후보. 무심코 해당 폴더 내부 전체 파일을 자동 대상으로 지정하는 동작은 추가하지 않는다.

## 3. 프리셋과 빠른 편집

- 프리셋 저장 내용: 이름, 규칙 종류/값/사용 여부/순서, 정렬 기준/방향, 기본 빠른 작업 선택. *선택 파일 전체 경로나 변경 이력·개인 폴더 경로를 저장하지 않는다.*
- 로컬 사용자 AppData 내 JSON 설정 파일로 시작; 버전 필드와 마이그레이션·원본 보존 계약을 테스트한다. 클라우드/서비스/데이터 수집은 추가하지 않는다.
- 앱 안에서 저장/이름 변경/삭제/불러오기. 최근 사용 프리셋은 최소 표시(권장 1개), 사용자가 원치 않으면 표시하지 않는다.
- Quick 화면은 규칙 1개 + 큰 미리보기 + “상세 편집으로 이동” + 최종 확인. 복잡한 조합은 기존 화면에서 처리한다.
- 빠른 메뉴를 선택해도 사전에 이름을 변경하거나 우회 실행하지 않는다. 취소 시 원본 불변.

## 4. 속도/안정성 개선 계획

1. **먼저 기준값 측정:** 콜드/웜 실행, 오른쪽 클릭부터 메뉴 표시, 메뉴 선택부터 창 표시, 1/20/500/5000개 항목 미리보기와 정렬을 비교. 로컬 SSD와 사용자가 허용한 임시 네트워크 fixture를 구분. 동일 PC/Windows 빌드에서 5회 측정, 중앙값·p95 보고.
2. **Explorer 지연 방지:** GetState 등의 동기 호출에서 메타데이터/설정 파일 읽기 불허. 기존 GetIcon HKCU 레지스트리 접근은 측정한 뒤 필요 시 교체. COM에 WPF나 파일 내용 검사 로드 금지.
3. **GUI 편집 지연:** 입력 연속 변경에 대한 제한적 debounce, 이전 계산 무효화, 비동기 미리보기/메타데이터 조회 또는 캐시를 검토. 계산 결과가 최신 선택/규칙/정렬 revision에 해당할 때만 반영. 취소된 변경이 화면을 덮지 않도록 회귀 검사.
4. **코어 알고리즘:** 폴더-자식 관계 검사 반복 비용과 내림차순 안정 정렬 오류를 별도 테스트로 고친다. 파일 상태를 재사용하더라도 실제 Apply 직전 재검증은 절대로 제거하지 않는다.
5. **1000개 이상 UI:** DataGrid 가상화 유지 확인, 진행 안내와 반응성 점검. “취소”는 실제 파일 이동 중 안전한 중단 계약이 마련되기 전에는 추가하지 않는다.
6. **완성도:** 정렬 방향(오름/내림)을 명확히 표시, 변경 예정/충돌/제외 항목 필터, 최초 실행 빈 규칙 상태의 안내, 키보드 조작과 DPI/고대비 검증.

측정 지표 및 임시 목표 (성능 PASS는 실측에서만 판정):
- 우클릭 메뉴 표시 지연: baseline 대비 p95 **10% 이상 악화되지 않을 것** (반복 측정, Windows 빌드 동등 조건).
- 빠른 작업: 전체 규칙 편집을 반복하는 방식보다 입력/클릭 단계 감소. **예상 수치 아닌 테스트 기록으로 판정.**
- 파일 500/5000개: UI가 장시간 비응답 상태가 되지 않고 진행을 확인할 수 있어야 한다. 구체적 시간 기준은 baseline 측정 후 확정.
- 프리셋/빠른 작업 포함 실제 Rename/Undo의 데이터 무결성: 100% 테스트 PASS, 파일 내용 및 확장자 불변(명시적 확장자 편집 제외).

## 5. 태스크/PR 분리 (승인 후 구현)

| 순서 | Task | 변경 영역 | 완료 증거 |
|---|---|---|---|
| UX-00 | 기준 성능 측정 및 UI/메뉴 시나리오 확정 | test tools/docs만 | Windows 11 실제 메뉴/실행 baseline, A/B 결과, T04 issue #7 현황 |
| UX-01 | 메뉴 하위 명령 프로토타입 | Shell C++/MSIX manifest/test | 탐색기 첫 수준 노출·한글·단일/다중 파일·폴더·기존 메뉴 회귀, 앱 실행 인수 검증 |
| UX-02 | 프리셋 저장·불러오기 | Core-independent settings + WPF | JSON 보존/호환/불량 값 테스트, 사용자 경로 미저장 |
| UX-03 | 빠른 순번/치환/프리셋 미리보기 | WPF, handoff, existing Core | 입력→미리보기→최종 확인→Apply→Undo. 단일/다중 파일 회귀 |
| UX-04 | 병목 수정 및 성능 측정 | Planner/Sorter/WPF | 1/20/500/5000 fixture, 타이밍 비교 및 기존 규칙 회귀 |
| UX-05 | 정렬/필터/키보드 UX | WPF | 선택·번호·제외·정렬 방향 유지, 접근성·DPI 검증 |
| UX-06 | 설치/업그레이드/Windows 11 최종 승인 | Installer/CI/manual | 기본 메뉴/빠른 작업, shell crash 없는지, 원본 무결성, 기존 dev 인증서 업그레이드, issue #7 체크 |
| UX-07a | 사용자가 누르는 앱 업데이트 확인 | WPF/Core + 오프라인 단위 테스트 | 공식 GitHub 정식 Releases만 조회, 버전 비교, 공개 릴리스 페이지 연결; 배포 전에는 '업데이트 없음' 안내 |
| UX-07b | 다운로드·실행 가능한 업데이트 적용 | 공식 코드 서명 확보 후 후속 작업 | 신뢰된 게시자 서명과 SHA-256 확인, 설치 전 최종 승인, 기존 설치·Explorer COM 등록·사용자 데이터 보존 |

UX-00은 실제 Windows 11 화면에서 검증 가능한 사용자 실행 단계가 필요하다. 후속 작업은 각각 별도 branch/PR을 만들고 해당 Task만 구현·테스트한다. 자동 CI 통과와 실기기 Explorer PASS를 구별한다.

## 5-1. 사용자 요청 추가: 프로그램 업데이트 기능 (UX-07)

- **UX-07a 현재 구현 범위:** 사용자 버튼을 눌렀을 때만 `https://api.github.com/repos/danhk0612/DK-Easy-Renamer/releases/latest`에서 최신 비초안/비프리릴리스 버전을 조회한다. 앱 실제 버전과 비교하여 업데이트 없음/새 버전 출시/연결 실패를 표시하며 정식 GitHub 릴리스 페이지로 안내한다. 공개 Release가 없다면 없는 것으로 처리한다. 실행 시 자동 조회/백그라운드 상주/원격 임의 URL 실행 없음.
- **UX-07b 추후 범위:** 검증된 공식 release 설치 EXE와 해시/인증서 신뢰 확인 후 사용자 승인으로 실제 업데이트. 현 개발용 인증서는 공개 배포용 신뢰 체계가 아니므로 자동 업데이트 설치 경로에 포함하지 않는다. 이전 설치 경로 및 sparse MSIX 패키지 identity/Explorer 메뉴를 유지해야 하며 원본 데이터나 Undo 복구 능력을 훼손하면 안 된다.
- 버전 확인과 실제 업그레이드는 독립적으로 테스트. 참조: https://docs.github.com/en/rest/releases/releases#get-the-latest-release ; https://jrsoftware.org/isfaq.php
- 자세한 승인 조건: https://github.com/danhk0612/DK-Easy-Renamer/issues/10

## 6. 안전 및 배포 제외 항목

- 프로그램이 직접 원본 파일을 변경하는 단계에서 **전체 편집/빠른 편집을 가리지 않고 명시적 확인**을 유지.
- 파일명 충돌 시 기존과 같이 덮어쓰기 금지, Apply 시 파일 상태 재검증, Undo 안전성 유지.
- shell 안에서 이름 변경/파일 읽기/네트워크 호출·자동 관리자 권한 상승 금지.
- 임시 테스트용 자체 서명 설치본은 일반 사용자 공개 배포 금지. 기존 dev-signing 및 공개 서명 준비는 이 개선 단계와 독립적.
- **Release/tag 생성 금지.** T04 issue #7 실제 Windows 11 실기기 승인과 별도 서명·배포 심사 완료 후 다시 판단.

## 참고 문서

- Microsoft Windows 11 IExplorerCommand/sparse package: https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer
- Microsoft EnumSubCommands: https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-iexplorercommand-enumsubcommands
- Microsoft GetState fOkToBeSlow: https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-iexplorercommand-getstate
- Microsoft Windows Insider 2026 menu rollout (not all devices): https://blogs.windows.com/windows-insider/2026/08/17/improving-file-explorer-context-menu-faster-simpler-and-more-customizable/
- Microsoft PowerToys PowerRename UX baseline: https://learn.microsoft.com/en-us/windows/powertoys/powerrename
