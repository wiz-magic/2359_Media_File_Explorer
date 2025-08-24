# 🚀 Media File Explorer - Electron 독립 실행형 EXE 빌드

## ✨ 특징
**Python 설치 불필요!** Electron 기반으로 완전히 독립적으로 실행되는 Windows 프로그램을 만듭니다.

### 장점
- ✅ **Python 불필요**: 최종 사용자는 Python을 설치할 필요 없음
- ✅ **Node.js 불필요**: 실행 시 Node.js 설치 불필요 (내장됨)
- ✅ **원클릭 설치**: 일반 Windows 프로그램처럼 설치
- ✅ **포터블 버전**: USB에서 바로 실행 가능
- ✅ **자동 업데이트**: (선택사항) 자동 업데이트 기능 지원
- ✅ **시스템 트레이**: 백그라운드 실행 지원
- ✅ **네이티브 메뉴**: Windows 네이티브 메뉴 지원

## 📦 빌드 방법 (매우 간단!)

### 1단계: Node.js 설치 (빌드 시에만 필요)
- https://nodejs.org 에서 LTS 버전 다운로드
- 설치 후 컴퓨터 재시작

### 2단계: 빌드 실행
```batch
# 프로젝트 폴더에서
build-electron-exe.bat 더블클릭
```

### 3단계: 완료!
`electron/dist/` 폴더에 생성된 파일:
- `Media File Explorer Setup 1.0.0.exe` - 설치 프로그램
- `MediaExplorer-Portable-1.0.0.exe` - 포터블 버전

## 🎯 생성되는 파일 종류

### 1. 설치 프로그램 (권장)
- **파일명**: `Media File Explorer Setup 1.0.0.exe`
- **크기**: 약 80-100MB
- **특징**:
  - Program Files에 설치
  - 시작 메뉴 등록
  - 바탕화면 바로가기
  - 제어판에서 제거 가능
  - 자동 업데이트 지원

### 2. 포터블 버전
- **파일명**: `MediaExplorer-Portable-1.0.0.exe`
- **크기**: 약 80-100MB
- **특징**:
  - 설치 불필요
  - USB에서 실행 가능
  - 레지스트리 변경 없음
  - 어디서든 실행 가능

## 🔧 고급 설정

### 아이콘 변경
1. `electron/icon.ico` 파일을 원하는 아이콘으로 교체
2. 최소 256x256 해상도 권장

### 버전 변경
`electron/package.json`에서:
```json
{
  "version": "2.0.0"  // 원하는 버전으로 변경
}
```

### FFmpeg 포함 옵션
```javascript
// electron/build-standalone.js에서
await this.downloadFFmpeg(); // 주석 해제하면 FFmpeg 포함
```

## 💻 최종 사용자 경험

### 설치 프로그램 사용
1. `Setup.exe` 다운로드
2. 더블클릭으로 설치 시작
3. 설치 위치 선택 (선택사항)
4. 설치 완료 후 바탕화면 아이콘 클릭

### 포터블 버전 사용
1. `.exe` 파일 다운로드
2. 원하는 위치에 저장
3. 더블클릭으로 실행

## 🛠️ 문제 해결

### "Windows Defender가 차단했습니다" 경고
- 정상적인 현상 (코드 서명이 없어서)
- "추가 정보" → "실행" 클릭
- 또는 코드 서명 인증서 구매 (연 $200-500)

### 빌드 실패 시
```batch
# electron 폴더에서 직접 실행
cd electron
npm install
npm run build-win
```

### 백신 프로그램 오탐지
- 빌드 중 백신 일시 중지
- 또는 예외 폴더 추가

## 📊 빌드 파일 구조

```
electron/
├── dist/                       # 빌드 결과물
│   ├── Media File Explorer Setup 1.0.0.exe
│   └── MediaExplorer-Portable-1.0.0.exe
├── main.js                     # Electron 메인 프로세스
├── preload.js                  # 보안 브리지
├── loading.html                # 로딩 화면
├── package.json                # 프로젝트 설정
└── build-standalone.js         # 빌드 스크립트
```

## 🎨 UI 기능

### 메인 창
- 반응형 웹 UI
- 다크/라이트 모드
- 전체화면 지원

### 시스템 트레이
- 최소화 시 트레이로
- 우클릭 메뉴
- 알림 지원

### 네이티브 메뉴
- 파일, 편집, 보기, 도움말
- 단축키 지원
- 컨텍스트 메뉴

## 🔐 보안

### 기본 보안 설정
- Context Isolation 활성화
- Node Integration 비활성화
- 보안 preload 스크립트

### 추가 보안 (선택사항)
- 코드 서명 ($200-500/년)
- Windows SmartScreen 등록
- 자동 업데이트 서버

## 📈 성능 최적화

### 빌드 크기 줄이기
```json
// electron-builder에서 불필요한 파일 제외
"files": [
  "!**/*.map",
  "!**/test/**"
]
```

### 시작 속도 개선
- Lazy loading 적용
- 캐시 활용
- 압축 최적화

## 🌟 추가 기능 아이디어

### 자동 업데이트
```javascript
// electron-updater 패키지 사용
const { autoUpdater } = require("electron-updater");
autoUpdater.checkForUpdatesAndNotify();
```

### 다국어 지원
```javascript
// i18n 패키지 사용
const i18n = require("i18n");
```

### 테마 시스템
- 사용자 정의 테마
- 시스템 테마 연동
- 색상 커스터마이징

## 📝 라이선스
- Electron: MIT License
- 프로젝트: MIT License
- FFmpeg: LGPL/GPL (선택사항)

## 🎉 완료!

이제 Python 설치 없이도 실행 가능한 완전한 Windows 프로그램을 만들 수 있습니다!

**한 번의 클릭으로 전문적인 Windows 프로그램 생성!**

---
*최종 업데이트: 2024-08-21*