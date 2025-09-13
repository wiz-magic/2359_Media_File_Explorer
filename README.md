
# 📂 2359 Media File Explorer

컴퓨터의 모든 미디어 파일을 쉽게 검색하고 미리보기할 수 있는 프로그램입니다.
콘텐츠 기획에서 다양한 소스의 활용도를 높이고자 개발되었습니다.
(현재는 윈도우만 지원하고 있습니다.)


### 📥 **1단계: 다운로드**
GitHub에서 **"Code" → "Download ZIP"** → 압축 해제

### 🎯 **2단계: 설치**
- **"원클릭 프로그램 설치"** 눌러 실행에 필요한 프로그램을 설치합니다.
   - Node.js, Python, ffmpeng


## ✅ **성공하면**
- **시작하기**를 누릅니다.
- 브라우저에서 `http://localhost:3000` 자동 열림
- 미디어 파일 검색 및 미리보기 사용 가능

## 💡 주요 기능
- 📸 이미지 썸네일 자동 생성
- 🔍 실시간 파일 검색
- 📁 모든 폴더 접근 가능
- 🎬 비디오, 음악, 문서 파일 지원


# Media File Explorer 

## 프로젝트 개요
- **이름**: Media File Explorer
- **목표**: 실제 파일 시스템의 미디어 파일을 검색하고 미리보기할 수 있는 웹 기반 시스템


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

## 배포
- **플랫폼**: Node.js Backend
- **상태**: ✅ 개발 완료 및 실행 중
- **마지막 업데이트**: 2025-08-14
