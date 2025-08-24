
# 📂 Media File Explorer

컴퓨터의 모든 미디어 파일을 쉽게 검색하고 미리보기할 수 있는 프로그램입니다.

## 🚀 **Windows 사용자 - 원클릭 설치!**

### 📥 **1단계: 다운로드**
1. GitHub에서 **"Code" → "Download ZIP"** 클릭
2. ZIP 파일 압축 해제

### 🎯 **2단계: 자동 설치 및 실행**
압축 해제한 폴더에서 **하나만** 더블클릭:

#### **방법 1: PowerShell (권장)**
**`MediaExplorer-Setup.ps1`** 우클릭 → **"PowerShell로 실행"**

#### **방법 2: 배치 파일**  
**`MediaExplorer-OneClick-Install.bat`** 더블클릭

### ✨ **자동으로 처리되는 모든 것:**
- ✅ **Node.js 자동 설치** (필요시)
- ✅ **Python 자동 설치** (필요시)  
- ✅ **FFmpeg 자동 설치** (비디오 썸네일용)
- ✅ **모든 패키지 자동 설치**
- ✅ **바탕화면 바로가기 생성**
- ✅ **브라우저에서 자동 실행** (http://localhost:3000)

### 🎉 **완료!**
설치 후 **바탕화면의 "Media File Explorer"** 아이콘을 클릭하면 바로 실행됩니다!

---

## 🎮 **개발자/Mac/Linux 사용자**

### Mac/Linux  
```bash
./install-mac.sh
./start.sh
```

### 수동 설치
```bash
npm install
npm start
```


VIDEO THUMBNAILS (Optional):
To enable video thumbnails, install FFmpeg:
1. Download from: https://ffmpeg.org/download.html
2. Choose "Windows builds from gyan.dev"
3. Download the "full" version
4. Extract to C:\ffmpeg
5. Add C:\ffmpeg\bin to your PATH:
   - Right-click "This PC" → Properties
   - Advanced system settings
   - Environment Variables
   - Edit PATH → Add C:\ffmpeg\bin

## 💡 주요 기능
- 📸 이미지 썸네일 자동 생성
- 🔍 실시간 파일 검색
- 📁 모든 폴더 접근 가능
- 🎬 비디오, 음악, 문서 파일 지원

## 📋 시스템 요구사항
- Node.js 16.0 이상
- Windows 10/11, macOS 10.15+, Linux

## 🆘 문제 해결

### "Node.js가 설치되어 있지 않습니다" 오류
→ https://nodejs.org 에서 LTS 버전 다운로드 후 설치

### "포트 3000이 사용 중입니다" 오류
→ 다른 프로그램이 포트를 사용 중. start.bat 편집하여 포트 변경

## 📧 문의
문제가 있으시면 Issues 탭에 남겨주세요.



# Media File Explorer - Real File System Edition

## 프로젝트 개요
- **이름**: Media File Explorer
- **목표**: 실제 파일 시스템의 미디어 파일을 검색하고 미리보기할 수 있는 웹 기반 시스템
- **주요 기능**: 
  - ✅ **실제 파일 시스템 접근** - Node.js 백엔드로 실제 파일 스캔
  - ✅ **동적 폴더 경로 지정** - 모든 접근 가능한 경로 스캔
  - ✅ **실시간 파일 인덱싱** - 재귀적 폴더 스캔 (깊이 설정 가능)
  - ✅ **파일명 기반 빠른 검색** - 실시간 필터링
  - ✅ **이미지 썸네일 생성** - Sharp 라이브러리로 자동 생성
  - ✅ **원본 파일 서빙** - 직접 파일 열기 지원
  - ✅ **최근 경로 자동 저장**

## 🚀 실행 중인 서비스

### 서비스 URL
- **프론트엔드 (Mock)**: https://3000-i51luexms0t8qbiy65hut-6532622b.e2b.dev/
- **프론트엔드 (Real)**: https://3000-i51luexms0t8qbiy65hut-6532622b.e2b.dev/real
- **백엔드 API**: http://localhost:3001

### 서비스 상태
- ✅ **Frontend Server**: 포트 3000에서 실행 중 (Cloudflare Pages Dev)
- ✅ **Backend Server**: 포트 3001에서 실행 중 (Node.js Express)
- ✅ **File System Access**: 정상 작동
- ✅ **Thumbnail Generation**: Sharp 라이브러리 활성화

## 구현된 기능

### 1. 실제 파일 시스템 접근
- ✅ 모든 로컬 경로 접근 가능
- ✅ 권한 검증 및 에러 처리
- ✅ 재귀적 폴더 스캔 (최대 10레벨)
- ✅ 숨김 파일 자동 제외

### 2. 미디어 파일 인덱싱
- ✅ 이미지: jpg, png, gif, webp, svg, bmp, ico, tiff
- ✅ 비디오: mp4, avi, mov, wmv, flv, mkv, webm
- ✅ 오디오: mp3, wav, flac, aac, ogg, m4a
- ✅ 문서: pdf, doc, docx, ppt, pptx, xls, xlsx

### 3. 썸네일 생성 및 캐싱
- ✅ 이미지 파일 자동 썸네일 생성 (300x300)
- ✅ 캐시 디렉토리에 저장
- ✅ MD5 해시 기반 캐싱

### 4. 고급 검색 기능
- ✅ 파일명 검색
- ✅ 경로 포함 검색
- ✅ 실시간 하이라이팅
- ✅ Debounce 최적화

### 5. UI/UX 기능
- ✅ 반응형 그리드 레이아웃
- ✅ 파일 타입별 아이콘
- ✅ 파일 크기/날짜 표시
- ✅ 원본 파일 열기
- ✅ 상태 표시 (Ready/Scanning/Error)

## API 엔드포인트

### Node.js Backend (포트 3001)
- `POST /api/validate-path` - 경로 유효성 검증
- `POST /api/scan` - 폴더 스캔 및 인덱싱
- `POST /api/search` - 파일 검색
- `GET /api/recent-paths` - 최근 경로 목록
- `GET /api/preview/:sessionId/:fileIndex` - 파일 미리보기
- `GET /api/serve-thumbnail/:filename` - 썸네일 서빙
- `GET /api/serve-file?path=` - 원본 파일 서빙
- `GET /api/system-info` - 시스템 정보

### Cloudflare Pages (포트 3000)
- `/` - Mock 데이터 버전
- `/real` - 실제 파일 시스템 버전

## 사용자 가이드

### 실제 파일 시스템 사용법

1. **페이지 접속**
   - https://3000-i51luexms0t8qbiy65hut-6532622b.e2b.dev/real 접속

2. **폴더 경로 입력**
   - Linux/Mac: `/home/user` 또는 `/home/user/sample-media`
   - Windows: `C:\Users\YourName\Documents`
   - 네트워크: `\\NAS\shared\media`

3. **스캔 옵션 설정**
   - 하위 폴더 포함 체크
   - 깊이 레벨 선택 (1-10)

4. **폴더 스캔**
   - "확인" 버튼으로 경로 검증
   - "스캔" 버튼으로 파일 인덱싱 시작

5. **파일 검색**
   - 검색창에 파일명 입력
   - 실시간 필터링 및 하이라이팅

6. **파일 미리보기**
   - 파일 카드 클릭
   - 이미지는 썸네일 표시
   - "원본 보기" 버튼으로 원본 파일 열기

### 샘플 미디어 경로
- `/home/user/sample-media` - 테스트용 샘플 파일들
- `/home/user/sample-media/images` - 이미지 파일
- `/home/user/sample-media/videos` - 비디오 파일
- `/home/user/sample-media/documents` - 문서 파일

## 기술 스택

### Frontend
- **Hono Framework** - 경량 웹 프레임워크
- **Cloudflare Pages** - 엣지 배포
- **TailwindCSS** - UI 스타일링
- **Axios** - HTTP 클라이언트

### Backend
- **Node.js + Express** - 파일 시스템 접근
- **Sharp** - 이미지 처리 및 썸네일 생성
- **Mime-types** - 파일 타입 감지
- **PM2** - 프로세스 관리

## 개발 명령어

```bash
# 서버 상태 확인
pm2 list

# 로그 확인
pm2 logs media-explorer-frontend --nostream
pm2 logs media-explorer-backend --nostream

# 서버 재시작
pm2 restart all

# 서버 중지
pm2 stop all

# 서버 삭제
pm2 delete all

# 프로젝트 빌드
npm run build

# Git 커밋
git add . && git commit -m "메시지"
```

## 프로젝트 구조
```
webapp/
├── src/
│   └── index.tsx         # Hono 메인 서버
├── public/
│   ├── real.html        # 실제 파일 시스템 HTML
│   └── static/
│       ├── app.js       # Mock 버전 JS
│       ├── app-real.js  # 실제 파일 시스템 JS
│       └── styles.css   # 공통 스타일
├── server.cjs           # Node.js 백엔드 서버
├── media-cache/         # 썸네일 캐시 디렉토리
│   └── thumbnails/
├── ecosystem.config.cjs # PM2 설정
└── package.json
```

## 보안 및 제한사항

### 보안 고려사항
- 파일 시스템 접근은 서버 권한에 따름
- 숨김 파일 및 시스템 디렉토리 자동 제외
- 읽기 권한이 있는 파일만 접근 가능

### 제한사항
- Cloudflare Workers 환경에서는 Mock 데이터만 사용
- 실제 파일 시스템은 Node.js 백엔드 필요
- 대용량 파일 썸네일 생성 시 시간 소요
- 브라우저 보안 정책으로 일부 파일 직접 열기 제한

## 추후 개선 계획

1. **성능 최적화**
   - WebSocket 실시간 스캔 진행률
   - Virtual scrolling for large lists
   - Worker threads for scanning

2. **기능 확장**
   - 비디오 썸네일 생성
   - 오디오 파형 시각화
   - ZIP 파일 내부 탐색
   - 파일 메타데이터 추출

3. **UI/UX 개선**
   - 드래그 앤 드롭 폴더 선택
   - 다크 모드 지원
   - 파일 정렬 옵션
   - 북마크 기능

## 배포
- **플랫폼**: Cloudflare Pages + Node.js Backend
- **상태**: ✅ 개발 완료 및 실행 중
- **마지막 업데이트**: 2024-08-14
