@echo off
chcp 65001 >nul
title Media File Explorer - Quick Install
cls

echo ================================================
echo    Media File Explorer - 빠른 설치
echo ================================================
echo.
echo 이 스크립트는 필요한 모든 패키지를 자동으로 설치합니다.
echo.

:: Change to script directory
cd /d "%~dp0"

:: Node.js 확인
echo [1/4] Node.js 확인...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js가 설치되지 않았습니다!
    echo.
    echo Node.js를 먼저 설치해주세요:
    echo https://nodejs.org/
    echo.
    echo 또는 "원클릭 프로그램 설치.bat"를 실행하세요.
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('node --version') do echo ✅ Node.js %%i

:: npm 패키지 설치
echo.
echo [2/4] npm 패키지 설치...
if exist "node_modules" (
    echo 기존 node_modules 삭제 중...
    rmdir /s /q node_modules 2>nul
)

echo 패키지 설치 중 (1-2분 소요)...
call npm install
if %errorlevel% neq 0 (
    echo ❌ 패키지 설치 실패!
    echo 인터넷 연결을 확인하세요.
    pause
    exit /b 1
)
echo ✅ 패키지 설치 완료

:: PM2 설치
echo.
echo [3/4] PM2 설치...
pm2 --version >nul 2>&1
if %errorlevel% neq 0 (
    echo PM2 전역 설치 중...
    call npm install -g pm2
    if %errorlevel% neq 0 (
        echo ⚠️  PM2 설치 실패 (선택사항)
    ) else (
        echo ✅ PM2 설치 완료
    )
) else (
    for /f "tokens=*" %%i in ('pm2 --version 2^>nul') do echo ✅ PM2 %%i 이미 설치됨
)

:: FFmpeg 확인
echo.
echo [4/4] FFmpeg 확인...
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️  FFmpeg가 설치되지 않았습니다.
    echo    썸네일 생성 기능이 제한될 수 있습니다.
    echo    "썸네일 안만들어질 때 눌러주세요.bat"를 실행하세요.
) else (
    echo ✅ FFmpeg 설치됨
)

echo.
echo ================================================
echo    ✅ 설치 완료!
echo ================================================
echo.
echo 이제 "시작하기.bat"를 실행하여 프로그램을 시작할 수 있습니다.
echo.
echo 바로 시작하시겠습니까? (Y/N)
choice /c YN /n /m "> "
if %errorlevel% equ 1 (
    call "시작하기.bat"
)