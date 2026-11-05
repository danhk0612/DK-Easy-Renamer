# UX-07g — 이전 서명 설치본·MSIX 복구 자료 보관 및 무결성 확인

이 단계는 **수동 실행되는 오프라인 보관 도구**입니다. MSIX 패키지 등록, 설치본 실행, 인증서 신뢰 설정, 기존 사용자 데이터 복원을 수행하지 않습니다. 이전 공개 서명자 미확정 상태를 유지합니다.

## 준비물

- **기존 버전의 원본 서명 설치 파일**: `DK-Easy-Renamer-X.Y.Z-x64-SIGNED-PROBE.exe` (테스트용) 또는 `DK-Easy-Renamer-X.Y.Z-x64-RELEASE.exe` (승인된 공개 배포용)
- **동일 버전의 원본 서명 MSIX**: `DKEasyRenamer.Shell.msix`. 앱 설치 폴더에 보관된 MSIX가 있다면 원본과 서명을 확인한 뒤 사용해야 합니다.
- 기존에 **독립적으로 확인한** 이전 서명 인증서의 정확한 Subject와 SHA-1 Thumbprint. 아카이브 내부의 값만 믿지 않고 실행자에게 별도로 요구합니다.
- 실행하는 컴퓨터가 해당 이전 서명 인증서를 신뢰하고 있어야 합니다. 신뢰되지 않는/서명이 유효하지 않은 파일은 도구가 거부합니다. 사용자 컴퓨터에 개발용 테스트 인증서를 자동 설치하지 마세요.

**설치된 앱 실행 파일과 MSIX만으로 원본 Inno Setup 설치 파일을 재생성할 수는 없습니다.** 이전 설치본을 분실했다면 이 도구는 복구용 설치본을 새로 만들지 않습니다.

## 사용 예제

아래 경로·게시자·지문은 예시입니다. 실제 인증서 Subject 및 Thumbprint를 먼저 검증해 대체하세요.

```powershell
$tool = '.\tools\ux07\Invoke-SignedRollbackArchive.ps1'
$setup = 'D:\Originals\DK-Easy-Renamer-0.1.2-x64-SIGNED-PROBE.exe'
$msix = 'D:\Originals\DKEasyRenamer.Shell.msix'
$archive = 'D:\RollbackArchives\DK-Easy-Renamer-0.1.2'
$subject = 'CN=DK Easy Renamer Development'
$thumbprint = '0123456789ABCDEF0123456789ABCDEF01234567'  # 실제 기존 인증서 값으로 교체

# 원본을 지우지 않고 새 복구 보관 폴더를 만듭니다.
& $tool -Mode Capture -ArchiveDirectory $archive -InstallerPath $setup -MsixPath $msix -ExpectedSignerSubject $subject -ExpectedSignerThumbprint $thumbprint

# 재검증: 파일 크기, SHA-256, Windows Authenticode, MSIX 버전/게시자
& $tool -Mode Verify -ArchiveDirectory $archive -ExpectedSignerSubject $subject -ExpectedSignerThumbprint $thumbprint

# 실제 설치하지 않고 빈 새 폴더에 설치본·MSIX의 정확한 바이트를 재구성
& $tool -Mode StageToNewDirectory -ArchiveDirectory $archive -StageDirectory 'D:\RollbackArchives\Staged-0.1.2' -ExpectedSignerSubject $subject -ExpectedSignerThumbprint $thumbprint
```

새 아카이브는 `RollbackManifest.json`, `payload/원래-설치파일.exe`, `payload/DKEasyRenamer.Shell.msix`로 구성됩니다. 매니페스트에는 원본 이름·버전·서명자 Subject/Thumbprint·파일별 길이·SHA-256이 저장됩니다. 서명된 EXE와 MSIX의 게시자 Subject·Thumbprint가 서로 같고, MSIX의 패키지 이름이 `DKEasyRenamer.Shell`이며 설치본의 버전과 일치해야 합니다.

도구는 입력 파일·아카이브·새 대상 폴더의 **기존 경로 구성 요소 전체**에서 symlink/junction/reparse point를 거부합니다. 이는 파일 자체가 일반 파일이어도 상위 폴더가 링크인 경우를 포함합니다. Windows CI에서는 서명 설치 파일의 상위 폴더와 신규 복구 대상 상위 폴더를 각각 junction으로 만드는 부정 시나리오를 테스트합니다.

도구는 목적지 기존 폴더를 덮어쓰지 않고, 새 폴더에만 복사합니다. 예상치 못한 파일, 일치하지 않는 해시·서명·버전, 대상 충돌은 거부합니다. 원본 EXE/MSIX는 변경하지 않습니다. 보관 파일에 별도 매니페스트 전자서명은 없지만, 매 실행마다 **외부에서 지정한 서명 지문**과 파일 서명을 다시 확인합니다.

## 보관과 실제 롤백의 차이

- **이 도구의 완료 범위:** 기존 설치본/패키지를 별도 폴더에 복사하여 서명과 해시를 검증하고, 새 임시 폴더에 동일한 파일을 다시 준비할 수 있다는 것.
- **미구현:** 기존 Windows 탐색기 MSIX 등록을 제거하거나 되돌리는 기능, 앱 설치 파일 실행, 사용자 데이터를 원래 위치에 복원, 공개 서명자 이전 및 실패 시 자동 롤백.
- 기존 개발용 MSIX는 신뢰할 수 있는 테스트 환경에서만 사용해야 합니다. 보관에 성공했다고 테스트용 인증서를 공개 배포하거나 일반 사용자 Windows 인증서 저장소에 등록해서는 안 됩니다.
- **일회성 CI의 `SIGNED-PROBE` 인증서는 테스트가 끝나면 폐기됩니다.** 해당 서명본을 저장하는 것만으로 별도 PC에서 신뢰된 복구가 가능해지는 것은 아닙니다. 실제 사용자 Windows 11에서 재설치/복원하려면 이전 인증서 신뢰와 사용자 데이터의 독립적 백업이 필요합니다.

## 자동화 검증 범위

`tools/t04/Smoke-SignedRollbackArchive.ps1`은 기존 Windows Server 2025의 임시 인증서로 서명한 0.1.2/0.1.3 시험 파일을 사용합니다. 0.1.2 서명 설치본 및 MSIX의 보관·무결성 확인·새 폴더 준비, 원본 파일 보존, 잘못된 인증서 지문, 0.1.3 MSIX 혼용, 위변조·추가 파일·목적지 충돌·미서명 파일을 거부하는지 검증합니다.

서명과 무결성 확인은 **게시자 이전 성공이나 Windows 11의 실제 대화형 Explorer 등록·롤백을 입증하지 않습니다.** 공개 Release/tag는 생성하지 않습니다.

연관 문서: [이전 사전 점검](UX07_PUBLISHER_MIGRATION_READINESS.md), [앱 로컬 데이터 스냅샷](UX07_USER_DATA_SNAPSHOT.md).
