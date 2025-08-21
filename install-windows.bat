@echo off
chcp 65001 > nul
title Media File Explorer - 설치

echo ================================================
echo    Media File Explorer - Windows 설치 프로그램
echo ================================================
echo.

:: Node.js 확인
echo [1/4] Node.js 확인 중...
node --version > nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ❌ Node.js가 설치되어 있지 않습니다!
    echo.
    echo Node.js를 먼저 설치해주세요:
    echo https://nodejs.org 에서 LTS 버전 다운로드
    echo.
    pause
    exit /b 1
)
echo ✅ Node.js 확인 완료

:: npm 패키지 설치
echo.
echo [2/4] 필요한 패키지 설치 중...
echo 잠시 기다려주세요...
call npm install --silent
if %errorlevel% neq 0 (
    echo ❌ 패키지 설치 실패
    pause
    exit /b 1
)
echo ✅ 패키지 설치 완료

:: 캐시 디렉토리 생성
echo.
echo [3/4] 캐시 폴더 생성 중...
if not exist "media-cache" mkdir media-cache
if not exist "media-cache\thumbnails" mkdir media-cache\thumbnails
echo ✅ 캐시 폴더 생성 완료

:: 바로가기 생성
echo.
echo [4/4] 바로가기 생성 중...
powershell -Command "$WS = New-Object -ComObject WScript.Shell; $SC = $WS.CreateShortcut('%USERPROFILE%\Desktop\Media File Explorer.lnk'); $SC.TargetPath = '%CD%\start.bat'; $SC.IconLocation = '%SystemRoot%\system32\imageres.dll,3'; $SC.Save()"
echo ✅ 바탕화면에 바로가기 생성 완료

echo.
echo ================================================
echo    ✅ 설치가 완료되었습니다!
echo ================================================
echo.
echo 실행 방법:
echo 1. 바탕화면의 'Media File Explorer' 아이콘 클릭
echo 2. 또는 start.bat 파일 실행
echo.
pause
