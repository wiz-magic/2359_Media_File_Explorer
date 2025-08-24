@echo off
chcp 65001 > nul
title Media Explorer Windows 빌드

echo ===============================================
echo     Media Explorer Windows EXE 빌드
echo ===============================================
echo.
echo 이 스크립트는 다음을 자동으로 수행합니다:
echo   1. Python 환경 확인
echo   2. 필요한 패키지 설치
echo   3. Node.js 포터블 버전 다운로드
echo   4. FFmpeg 바이너리 다운로드
echo   5. EXE 파일 생성
echo   6. 설치 패키지 생성
echo.
echo 시간이 다소 걸릴 수 있습니다 (10-20분)
echo.
pause

:: Python 확인
echo Python 확인 중...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Python이 설치되지 않았습니다.
    echo    https://www.python.org 에서 Python 3.8+ 를 설치하세요.
    pause
    exit /b 1
)

:: 필요한 패키지 설치
echo.
echo 필요한 Python 패키지 설치 중...
cd builder
pip install -r requirements.txt

:: 빌드 실행
echo.
echo 빌드를 시작합니다...
python build_windows.py

echo.
echo ===============================================
echo 빌드가 완료되었습니다!
echo 생성된 파일: builder\MediaExplorer_Windows_Setup_v1.0.0.zip
echo.
echo 설치 방법:
echo   1. ZIP 파일 압축 해제
echo   2. install.bat 실행 (관리자 권한)
echo ===============================================
echo.
pause