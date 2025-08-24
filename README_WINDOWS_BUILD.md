# 📦 Media File Explorer - Windows EXE 빌드 가이드

## 🎯 개요
이 가이드는 Media File Explorer를 Windows용 단일 실행 파일(.exe)로 빌드하는 방법을 설명합니다.
생성된 설치 프로그램은 다음을 포함합니다:
- ✅ Node.js 포터블 버전 (설치 불필요)
- ✅ FFmpeg 바이너리 (비디오 썸네일용)
- ✅ 모든 필요한 의존성
- ✅ 자동 설치 프로그램

## 📋 사전 요구사항

### 필수 설치
1. **Python 3.8 이상**
   - 다운로드: https://www.python.org/downloads/
   - 설치 시 "Add Python to PATH" 체크 필수

2. **Git** (선택사항)
   - 다운로드: https://git-scm.com/download/win

### 선택사항 (고급 빌드용)
- **7-Zip**: 원파일 설치 프로그램 생성용
  - 다운로드: https://www.7-zip.org/
- **NSIS**: 전문적인 설치 프로그램 생성용
  - 다운로드: https://nsis.sourceforge.io/

## 🚀 빠른 빌드 (추천)

### 방법 1: 배치 파일 사용 (가장 쉬움)
```batch
# 1. 프로젝트 폴더에서
build_windows_exe.bat

# 2. 완료 후 생성된 파일
builder\MediaExplorer_Windows_Setup_v1.0.0.zip
```

### 방법 2: 직접 Python 스크립트 실행
```batch
# 1. builder 폴더로 이동
cd builder

# 2. 필요한 패키지 설치
pip install -r requirements.txt

# 3. 빌드 실행
python build_windows.py
```

## 📦 빌드 결과물

빌드가 완료되면 다음 파일들이 생성됩니다:

```
builder/
├── MediaExplorer_Windows_Setup_v1.0.0.zip  # 📦 최종 배포 파일
├── output/
│   ├── MediaExplorer.exe                   # 🚀 런처 실행 파일
│   ├── node/                                # 📁 Node.js 포터블
│   ├── ffmpeg/                              # 🎬 FFmpeg 바이너리
│   └── app/                                 # 💾 애플리케이션 파일
└── install.bat                              # 🔧 설치 스크립트
```

## 🔧 설치 방법

### 최종 사용자 설치 과정
1. `MediaExplorer_Windows_Setup_v1.0.0.zip` 다운로드
2. 원하는 위치에 압축 해제
3. `install.bat`를 **관리자 권한**으로 실행
4. 설치 완료 후 바탕화면 아이콘 클릭

## 🎨 커스터마이징

### 버전 변경
`builder/build_windows.py` 파일에서:
```python
package_name = f"MediaExplorer_Windows_Setup_v2.0.0.zip"  # 버전 변경
```

### 아이콘 추가
1. `icon.ico` 파일을 `builder/` 폴더에 추가
2. `build_windows.py`의 PyInstaller 설정에서:
```python
icon='builder/icon.ico'  # 아이콘 경로 추가
```

### Node.js 버전 변경
`builder/build_windows.py` 파일에서:
```python
self.nodejs_url = "https://nodejs.org/dist/v20.11.0/node-v20.11.0-win-x64.zip"
# 원하는 버전으로 URL 변경
```

## 🏗️ 고급 빌드 옵션

### 원파일 설치 프로그램 생성 (7-Zip 필요)
```powershell
# PowerShell에서 실행
.\builder\create_onefile_installer.ps1
# 결과: MediaExplorer_Setup.exe (단일 실행 파일)
```

### NSIS 설치 프로그램 (NSIS 필요)
```batch
# 1. 먼저 기본 빌드 실행
python builder\build_windows.py

# 2. NSIS 컴파일
"C:\Program Files (x86)\NSIS\makensis.exe" builder\installer.nsi
```

## 🐛 문제 해결

### "Python이 설치되지 않았습니다" 오류
- Python 설치 후 명령 프롬프트 재시작
- 시스템 환경 변수 PATH에 Python 경로 확인

### "PyInstaller를 찾을 수 없습니다" 오류
```batch
pip install --upgrade pip
pip install PyInstaller
```

### 빌드 중 "Access Denied" 오류
- 백신 프로그램 일시 중지
- 관리자 권한으로 명령 프롬프트 실행

### FFmpeg 다운로드 실패
- 수동 다운로드: https://www.gyan.dev/ffmpeg/builds/
- `ffmpeg-release-essentials.zip` 다운로드 후 `builder/build/` 폴더에 저장

## 📊 빌드 세부 정보

### 포함되는 구성 요소
| 구성 요소 | 버전 | 크기 | 용도 |
|---------|------|------|-----|
| Node.js | 20.11.0 | ~30MB | JavaScript 런타임 |
| FFmpeg | 7.0.2 | ~80MB | 비디오 처리 |
| App Files | Latest | ~5MB | 애플리케이션 코드 |
| **총 크기** | - | **~120MB** | 압축 시 ~50MB |

### 빌드 시간
- 첫 빌드: 10-20분 (다운로드 포함)
- 재빌드: 2-3분 (캐시 사용)

## 🔐 보안 고려사항

### 코드 서명 (선택사항)
Windows Defender 경고를 방지하려면 코드 서명 인증서 사용:
```batch
signtool sign /a /t http://timestamp.digicert.com MediaExplorer.exe
```

### 바이러스 검사 제외
일부 백신이 PyInstaller 실행 파일을 오탐지할 수 있음:
- Windows Defender 제외 목록에 추가
- 또는 VirusTotal에서 검사 후 사용

## 📝 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.
포함된 제3자 소프트웨어:
- Node.js: MIT License
- FFmpeg: LGPL/GPL License
- PyInstaller: GPL License

## 🆘 지원

문제가 있으신가요?
- GitHub Issues: [프로젝트 저장소]/issues
- 이메일: support@mediaexplorer.com

## 🎉 완료!

이제 Windows 사용자들이 쉽게 설치하고 사용할 수 있는 
Media File Explorer 설치 프로그램을 만들 수 있습니다!

---
*마지막 업데이트: 2024-08-21*