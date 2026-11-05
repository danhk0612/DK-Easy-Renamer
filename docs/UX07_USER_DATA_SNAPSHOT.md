# UX-07f — 로컬 앱 데이터 스냅샷 및 신규 폴더 복원 시험

## 현재 실제 저장 범위

2026-11-05 기준 저장소의 WPF 화면은 규칙 및 되돌리기(Undo)를 메모리에 유지합니다. **프리셋 저장, 영속 설정 파일, 세션 Undo 복원 기능은 아직 구현되어 있지 않습니다.** 해당 항목을 백업할 파일이 존재한다고 가정하지 마세요.

독립적인 앱 데이터 디렉터리는 `%LOCALAPPDATA%\DK Easy Renamer`이며 현재 주로 설치·탐색기 통합의 진단 로그와 업데이트 임시 파일 등을 담습니다. 이 디렉터리 전체를 백업하면 **로그 안의 로컬 경로와 진단 정보가 함께 복사될 수 있습니다.** 개인 정보가 포함된 백업을 GitHub 공개 이슈나 Actions 산출물로 업로드하지 마세요.

탐색기 등록 소유권은 별도 HKCU 레지스트리에 저장됩니다. 아래 스냅샷은 **HKCU, 설치 폴더, 설치 실행 파일, MSIX 등록, 원본 서명 설치본을 백업하지 않습니다.** PR #25의 읽기 전용 진단 결과도 복구 가능한 파일 백업이 아닙니다.

## 수동 로컬 실행 (자동 실행되지 않음)

저장소 소스 폴더에서 PowerShell을 실행하고, 명령의 실제 경로를 선택해 사용합니다.

```powershell
$src = Join-Path $env:LOCALAPPDATA 'DK Easy Renamer'
$backup = 'D:\DK-Easy-Renamer-Backup-20261105'
$tool = '.\tools\ux07\Invoke-MigrationDataSnapshot.ps1'

# 1. 신규 스냅샷 디렉터리만 생성, 원본 파일 읽기 전용
& $tool -Mode Backup -SourceDirectory $src -SnapshotDirectory $backup

# 2. 복사된 파일별 SHA-256·크기·디렉터리 목록 검사
& $tool -Mode Verify -SnapshotDirectory $backup

# 3. 운영 AppData를 건드리지 않고 별도의 빈 경로에서 복원 시험
& $tool -Mode RestoreToNewDirectory -SnapshotDirectory $backup -RestoreDirectory 'D:\DK-Easy-Renamer-Restore-Test'
```

백업·복원 대상 경로가 이미 존재하면 **거부**하며 덮어쓰지 않습니다. 복원은 반드시 **새 디렉터리**를 지정해야 합니다. 원본 데이터가 없을 때는 임의로 파일을 만들지 않고 중단합니다.

스냅샷은 새 폴더의 `data/` 아래에 로컬 파일을 복사하고 `SnapshotManifest.json`에 상대 경로·크기·SHA-256을 기록합니다. 파일 이름은 Unicode를 지원합니다. 원본 해시를 복사 전후로 비교하며 심볼릭 링크·junction이 포함된 데이터는 거부합니다. 검사 시 상대 경로 이탈, 중복 항목, 추가 파일, 변경된 크기나 해시를 거부합니다. 스냅샷의 매니페스트 자체는 **전자서명되지 않았으므로 악의적 변경에 대한 독립적인 신뢰 증명은 아닙니다.**

이 도구는 스크립트를 수동 호출할 때만 실행되며 앱의 설치·자동업데이트 경로에 연결되지 않았습니다. **실제 사용자 AppData에 덮어써서 복구하는 기능은 제공하지 않습니다.**

## CI 검증 범위

`tools/t04/Smoke-MigrationDataSnapshot.ps1`은 폐기 가능한 Windows CI 폴더에서 한글/일본어 이름, 이진 파일, 빈 디렉터리, 정상 백업·복원·해시 비교, 기존 경로 덮어쓰기 거부, 해시 변조, 경로 이탈, 중복 매니페스트, 예기치 않은 파일과 빈 데이터 폴더를 테스트합니다. 실제 사용자의 LocalAppData나 MSIX/인증서 등록은 건드리지 않습니다.

## 실제 게시자 이전까지 여전히 필요한 사항

- 원본 공개/개발용 서명 설치 실행 파일 및 MSIX의 **독립적이고 검증된 보관**(이 도구로는 백업하지 않음)
- 사용자의 백업 파일을 안전하게 보관하고 실제 Windows 11 환경에서 수동으로 내용·복원 가능성 확인
- 승인된 공개 코드 서명 방식, MSIX 패키지 패밀리 변경 및 실패/롤백 절차
- 해당 이전·롤백의 Windows 11 실기기 승인

본 단계에서 공개 서명자 선택·자동 이전·실제 운영 데이터 복원·Release/tag 발행은 진행하지 않습니다.
