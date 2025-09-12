# 📥 Media File Explorer 설치 안내

Media File Explorer 사용을 위해 필요한 프로그램들을 자동으로 설치하는 방법을 안내합니다.

## 🚀 추천 설치 방법 (가장 쉬움)

### 방법 1: 원클릭 설치 (권장) ⭐
```
🚀 원클릭 설치.bat 더블클릭
```
- **가장 사용하기 쉬운 방법**
- 모든 필요한 프로그램을 자동으로 설치
- 예쁜 UI와 상세한 진행 상황 표시
- 설치 완료 후 바로 실행 가능

### 방법 2: 일반 설치
```
install_all.bat 더블클릭
```
- 전통적인 설치 방식
- 문제 발생 시 대체 설치 방법 제공
- PowerShell 스크립트 실행 실패 시 자동으로 Winget 사용

## 🔧 고급 사용자용

### PowerShell 스크립트 직접 실행
PowerShell 스크립트를 직접 실행하고 싶다면:

```
run_powershell_setup.bat 더블클릭
```
- PowerShell 스크립트를 안전하게 실행
- 실행 정책 문제 자동 해결
- 여러 PowerShell 스크립트 중 선택 가능

### 수동 실행 (PowerShell)
```powershell
# 관리자 권한으로 PowerShell 열기
# 다음 중 하나 실행:
.\install_all_direct.ps1
.\install_all.ps1  
.\MediaExplorer-Setup.ps1
```

## 📋 설치되는 프로그램들

설치 순서: **Node.js → Python → FFmpeg**

1. **Node.js v20.18.0** - JavaScript 런타임
2. **Python 3.12.4** - 스크립트 실행 환경  
3. **FFmpeg** - 비디오/오디오 처리 도구
4. **npm 패키지들** - 프로젝트 의존성

## ❗ 문제 해결

### PowerShell 스크립트가 실행되지 않을 때
- **해결책**: BAT 파일 사용 (`install_all.bat` 또는 `🚀 원클릭 설치.bat`)
- **원인**: Windows 실행 정책 또는 권한 문제

### "winget을 찾을 수 없습니다" 오류
- **해결책**: Microsoft Store에서 "App Installer" 설치
- **또는**: Windows 10 1709+ 또는 Windows 11로 업데이트

### 관리자 권한 요청
- **정상적인 동작입니다** - 프로그램 설치를 위해 필요
- **"예"를 클릭**하여 계속 진행

### 설치 후 명령을 찾을 수 없는 경우
```cmd
# 터미널을 새로 열고 다시 시도
# 또는 컴퓨터 재시작 후 시도
```

## 🔍 설치 확인

설치가 완료되면 다음 명령으로 확인할 수 있습니다:

```cmd
node --version
python --version  
ffmpeg -version
```

## 🏃‍♂️ 설치 후 실행

설치 완료 후 다음 중 하나로 실행:

1. `🚀 CLICK HERE TO START.bat` 더블클릭
2. `MediaExplorer-Start.bat` 더블클릭
3. `START-HERE-WINDOWS.bat` 더블클릭

웹브라우저에서 `http://localhost:3000`으로 접속됩니다.

## 📞 지원

문제가 발생하면:
1. 먼저 BAT 파일 방식 시도
2. 그래도 안 되면 수동 설치 진행
3. GitHub Issues에 문제 보고

---

**🎯 권장사항**: 대부분의 사용자에게는 `🚀 원클릭 설치.bat`을 권장합니다!