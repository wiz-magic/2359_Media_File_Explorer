# 📂 2359 Media File Explorer

컴퓨터의 모든 미디어 파일을 쉽게 검색하고 미리보기할 수 있는 프로그램입니다.
콘텐츠 기획에서 다양한 소스의 활용도를 높이고자 개발되었습니다.

## ✨ 주요 기능

- 🔍 **빠른 검색**: 모든 미디어 파일 즉시 검색
- 🖼️ **썸네일 생성**: 이미지/비디오 자동 썸네일 생성
- 🎬 **비디오 미리보기**: 내장 비디오 플레이어
- 📁 **다중 폴더 지원**: 여러 디렉토리 동시 스캔
- 🔖 **북마크**: 즐겨찾기 파일 저장
- 🌏 **한글 지원**: 한글 검색 및 파일명 완벽 지원
- 🚀 **GPU 가속**: GPU 하드웨어 자동 감지 및 활용
- ⚡ **최적화 성능**: 스마트 캐싱, LRU 캐시, 멀티스레딩

## 🎮 GPU 가속 지원

시스템이 자동으로 GPU를 감지하여 최적의 성능을 제공합니다:

| GPU 종류 | 예상 성능 | 속도 향상 |
|---------|----------|-----------|
| NVIDIA RTX | 10-30ms | 100배 빠름 |
| Intel Iris Xe | 30-80ms | 5배 빠름 |
| AMD Radeon | 40-100ms | 4배 빠름 |
| Apple Silicon | 20-60ms | 10배 빠름 |
| CPU Only | 150-200ms | 기본 속도 |

## 📥 설치 방법

### 🚀 빠른 시작 (Windows)

1. **GitHub에서 다운로드**
   - "Code" → "Download ZIP" → 압축 해제

2. **필수 프로그램이 없다면**
   ```
   원클릭 프로그램 설치.bat
   ```
   Node.js, Python, FFmpeg를 자동 설치합니다.

3. **패키지 설치**
   ```
   빠른설치.bat
   ```
   
4. **프로그램 실행**
   ```
   시작하기.bat
   ```

### 🛠️ 수동 설치

1. **필수 프로그램 설치**
   - Node.js: https://nodejs.org/
   - FFmpeg: https://ffmpeg.org/

2. **npm 패키지 설치**
   ```cmd
   npm install
   ```

3. **PM2 설치 (선택)**
   ```cmd
   npm install -g pm2
   ```

4. **실행**
   ```cmd
   npm start
   # 또는
   node local-server.cjs
   ```

## 🔧 문제 해결

### 썸네일이 안 만들어질 때
```
썸네일 안만들어질 때 눌러주세요.bat
```

### Intel GPU 가속 설정
```
Intel GPU 가속 설정.bat
```

### 패키지 재설치
```cmd
rmdir /s /q node_modules
npm install
```

## 📊 성능

- **썸네일 생성**: 20-200ms (GPU 가속)
- **검색**: 즉시 (10,000개 파일 < 50ms)
- **캐싱**: 5GB 제한 스마트 LRU 캐시
- **동시 처리**: 모든 CPU 코어 활용
- **설정 불필요**: GPU 자동 감지 및 폴백

## 🖥️ 시스템 요구사항

- **OS**: Windows 10/11 (Mac/Linux 추후 지원)
- **RAM**: 4GB 이상 권장
- **저장공간**: 500MB 이상
- **Node.js**: v16 이상

## 📝 라이선스

MIT License - 자유롭게 사용 가능

## 🤝 기여

Pull Request와 Issue 제보를 환영합니다!

---

**문제가 있나요?** Issue를 열어주세요: [GitHub Issues](https://github.com/wiz-magic/2359_Media_File_Explorer/issues)