@echo off
chcp 65001 >nul
title Media File Explorer - 자동 설치

echo.
echo ===============================================
echo    Media File Explorer - 자동 설치 스크립트
echo ===============================================
echo.
echo 이 스크립트는 다음 프로그램들을 자동으로 설치합니다:
echo   1. Node.js (v20.18.0)
echo   2. Python (3.12.4)
echo   3. FFmpeg (비디오 처리용)
echo   4. 프로젝트 의존성 (npm 패키지)
echo.
echo 설치 과정에서 관리자 권한이 필요할 수 있습니다.
echo.

REM 관리자 권한 확인
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [관리자 권한] 확인됨
    goto :main
) else (
    echo [경고] 관리자 권한이 필요합니다.
    echo 관리자 권한으로 다시 시작합니다...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:main
echo.
echo 설치를 시작합니다...
echo.

REM PowerShell 스크립트 실행
if exist "%~dp0install_all_direct.ps1" (
    echo PowerShell 스크립트를 실행합니다...
    powershell -ExecutionPolicy Bypass -File "%~dp0install_all_direct.ps1" -AsAdmin
    if %errorlevel% neq 0 (
        echo.
        echo PowerShell 스크립트 실행 실패. 대체 설치 방법을 시도합니다...
        goto :fallback_install
    )
    goto :success
) else (
    echo install_all_direct.ps1 파일을 찾을 수 없습니다.
    goto :fallback_install
)

:fallback_install
echo.
echo ===============================================
echo      대체 설치 방법 (Winget 사용)
echo ===============================================
echo.

REM Winget 설치 확인
winget --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [오류] Winget을 찾을 수 없습니다.
    echo Windows 10/11의 최신 버전이 필요합니다.
    echo 수동으로 다음 프로그램들을 설치해주세요:
    echo   - Node.js: https://nodejs.org/
    echo   - Python: https://www.python.org/
    echo   - FFmpeg: https://ffmpeg.org/
    goto :manual_install
)

echo 1. Node.js 설치 중...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements
    if %errorlevel% neq 0 (
        echo Node.js 설치 실패
    ) else (
        echo Node.js 설치 완료
    )
) else (
    echo Node.js가 이미 설치되어 있습니다.
)

echo 2. Python 설치 중...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    winget install Python.Python.3.12 --silent --accept-source-agreements
    if %errorlevel% neq 0 (
        echo Python 설치 실패
    ) else (
        echo Python 설치 완료
    )
) else (
    echo Python이 이미 설치되어 있습니다.
)

echo 3. FFmpeg 설치 중...
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    winget install Gyan.FFmpeg --silent --accept-source-agreements
    if %errorlevel% neq 0 (
        echo FFmpeg 설치 실패
    ) else (
        echo FFmpeg 설치 완료
    )
) else (
    echo FFmpeg가 이미 설치되어 있습니다.
)

REM 환경변수 새로고침을 위해 새로운 명령 프롬프트 세션에서 확인
echo 4. 프로젝트 의존성 설치 중...
cd /d "%~dp0"
if exist package.json (
    if not exist node_modules (
        call npm install
        if %errorlevel% neq 0 (
            echo npm 설치 실패. 터미널을 새로 열고 수동으로 'npm install'을 실행해주세요.
        ) else (
            echo 프로젝트 의존성 설치 완료
        )
    ) else (
        echo 프로젝트 의존성이 이미 설치되어 있습니다.
    )
) else (
    echo package.json을 찾을 수 없습니다.
)

:success
echo.
echo ===============================================
echo          설치 완료!
echo ===============================================
echo.
echo 설치된 버전 확인:
cmd /c "node --version 2>nul && echo Node.js 설치됨 || echo Node.js 미설치"
cmd /c "python --version 2>nul && echo Python 설치됨 || echo Python 미설치"
cmd /c "ffmpeg -version 2>nul | findstr "ffmpeg version" && echo FFmpeg 설치됨 || echo FFmpeg 미설치"
echo.
echo 애플리케이션을 시작하려면:
echo   - 'MediaExplorer-Start.bat' 파일을 실행하거나
echo   - '🚀 CLICK HERE TO START.bat' 파일을 실행하세요
echo.
goto :end

:manual_install
echo.
echo ===============================================
echo         수동 설치 안내
echo ===============================================
echo.
echo 다음 웹사이트에서 프로그램들을 다운로드하여 설치하세요:
echo.
echo 1. Node.js v20.18.0:
echo    https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi
echo.
echo 2. Python 3.12.4:
echo    https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe
echo.
echo 3. FFmpeg:
echo    https://github.com/BtbN/FFmpeg-Builds/releases
echo.
echo 설치 후 터미널을 새로 열고 다음 명령을 실행하세요:
echo    npm install
echo.

:end
echo 아무 키나 눌러서 종료하세요...
pause >nul