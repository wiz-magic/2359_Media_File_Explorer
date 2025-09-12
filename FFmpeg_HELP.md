# 🎬 FFmpeg PATH 문제 해결 가이드

MediaExplorer-OneClick-Install.bat으로 설치가 완료되었지만 FFmpeg 명령어를 찾을 수 없는 경우의 해결 방법입니다.

## 🚨 현재 상황
```cmd
C:\Users\사용자명>ffmpeg -version
'ffmpeg'은(는) 내부 또는 외부 명령, 실행할 수 있는 프로그램, 또는
배치 파일이 아닙니다.
```

## ⚡ 즉시 해결 방법

### 방법 1: 빠른 임시 해결 (권장)
```cmd
Quick_FFmpeg_Fix.bat 더블클릭
```
- 가장 빠른 방법
- 현재 터미널 세션에서 즉시 FFmpeg 사용 가능
- 임시적 해결 (터미널 재시작 시 다시 실행 필요)

### 방법 2: 완전한 영구 해결
```cmd
Fix_FFmpeg_PATH.bat 더블클릭 (관리자 권한으로)
```
- 시스템 PATH에 영구적으로 추가
- 모든 터미널에서 FFmpeg 사용 가능
- 컴퓨터 재시작 후에도 유지됨

## 🔧 수동 해결 방법

FFmpeg가 다음 위치에 설치되어 있는지 확인하세요:

1. **C:\ffmpeg\bin\ffmpeg.exe** (가장 일반적)
2. **C:\Program Files\ffmpeg\bin\ffmpeg.exe**
3. **%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg*\ffmpeg-*\bin\ffmpeg.exe**

### 수동 PATH 추가 (Windows 11/10)

1. **Windows키 + R** → `sysdm.cpl` 입력 → 확인
2. **고급** 탭 → **환경 변수** 클릭
3. **시스템 변수**에서 **Path** 선택 → **편집**
4. **새로 만들기** → `C:\ffmpeg\bin` 입력
5. **확인** → **확인** → **확인**
6. **모든 터미널 창 닫기**
7. **새 터미널 열어서 테스트**: `ffmpeg -version`

## ✅ 해결 확인

다음 명령어로 FFmpeg가 제대로 작동하는지 확인:

```cmd
ffmpeg -version
```

성공적으로 설치된 경우 다음과 같은 출력이 나타납니다:
```
ffmpeg version x.x.x-xxx Copyright (c) 2000-2024 the FFmpeg developers
built with gcc x.x.x ...
```

## 🆘 여전히 문제가 있다면

1. **컴퓨터 완전 재시작**
2. **새 명령 프롬프트/PowerShell 창에서 재시도**
3. **관리자 권한으로 Fix_FFmpeg_PATH.bat 실행**

## 📱 Media File Explorer 사용

FFmpeg가 설정되면 Media File Explorer에서 다음 기능들이 정상 작동합니다:

- 🎥 비디오 썸네일 생성
- 🎵 오디오 파일 미리보기  
- 📹 비디오 메타데이터 읽기
- 🔄 미디어 파일 형식 변환

FFmpeg 없이도 기본 파일 탐색기 기능은 모두 사용 가능합니다!