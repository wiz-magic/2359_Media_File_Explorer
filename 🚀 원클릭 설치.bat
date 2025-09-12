@echo off
chcp 65001 >nul
title Media File Explorer - 원클릭 설치

REM 관리자 권한으로 실행
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cls
echo.
echo  ██╗   ██╗███████╗██████╗ ██╗ █████╗     ███████╗██╗██╗     ███████╗
echo  ████╗ ████║██╔════╝██╔══██╗██║██╔══██╗    ██╔════╝██║██║     ██╔════╝
echo  ██╔████╔██║█████╗  ██║  ██║██║███████║    █████╗  ██║██║     █████╗  
echo  ██║╚██╔╝██║██╔══╝  ██║  ██║██║██╔══██║    ██╔══╝  ██║██║     ██╔══╝  
echo  ██║ ╚═╝ ██║███████╗██████╔╝██║██║  ██║    ██║     ██║███████╗███████╗
echo  ╚═╝     ╚═╝╚══════╝╚═════╝ ╚═╝╚═╝  ╚═╝    ╚═╝     ╚═╝╚══════╝╚══════╝
echo.
echo                     ███████╗██╗  ██╗██████╗ ██╗      ██████╗ ██████╗ ███████╗██████╗ 
echo                     ██╔════╝╚██╗██╔╝██╔══██╗██║     ██╔═══██╗██╔══██╗██╔════╝██╔══██╗
echo                     █████╗   ╚███╔╝ ██████╔╝██║     ██║   ██║██████╔╝█████╗  ██████╔╝
echo                     ██╔══╝   ██╔██╗ ██╔═══╝ ██║     ██║   ██║██╔══██╗██╔══╝  ██╔══██╗
echo                     ███████╗██╔╝ ██╗██║     ███████╗╚██████╔╝██║  ██║███████╗██║  ██║
echo                     ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
echo.
echo ===============================================================================
echo                         🚀 원클릭 자동 설치 🚀
echo ===============================================================================
echo.
echo 이 프로그램은 Media File Explorer 실행에 필요한 모든 것을 자동으로 설치합니다:
echo.
echo   ✅ Node.js (JavaScript 런타임)
echo   ✅ Python (스크립트 실행 환경)  
echo   ✅ FFmpeg (비디오/오디오 처리)
echo   ✅ 필요한 npm 패키지들
echo.
echo 설치 시간: 약 5-10분 (인터넷 속도에 따라 다름)
echo.
echo ===============================================================================

set /p confirm="설치를 진행하시겠습니까? (Y/N): "
if /i "%confirm%" neq "Y" (
    echo 설치가 취소되었습니다.
    pause
    exit /b
)

echo.
echo [진행중] 설치를 시작합니다...
echo.

REM Winget 확인
echo [1/5] 시스템 호환성 확인 중...
winget --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [오류] Windows Package Manager(winget)를 찾을 수 없습니다.
    echo Windows 10 버전 1709 이상 또는 Windows 11이 필요합니다.
    echo.
    echo 대안: Microsoft Store에서 "App Installer"를 설치한 후 다시 시도하세요.
    echo 또는 수동 설치를 위해 'install_all.bat'을 실행하세요.
    pause
    exit /b 1
)
echo [완료] 시스템이 호환됩니다.

REM Node.js 설치
echo.
echo [2/5] Node.js 확인 및 설치 중...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Node.js를 설치하고 있습니다... (시간이 걸릴 수 있습니다)
    winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [오류] Node.js 설치에 실패했습니다.
    ) else (
        echo [완료] Node.js가 설치되었습니다.
    )
) else (
    for /f "tokens=*" %%i in ('node --version') do set nodeversion=%%i
    echo [완료] Node.js가 이미 설치되어 있습니다. (버전: !nodeversion!)
)

REM Python 설치  
echo.
echo [3/5] Python 확인 및 설치 중...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Python을 설치하고 있습니다... (시간이 걸릴 수 있습니다)
    winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [오류] Python 설치에 실패했습니다.
    ) else (
        echo [완료] Python이 설치되었습니다.
    )
) else (
    for /f "tokens=*" %%i in ('python --version') do set pythonversion=%%i
    echo [완료] Python이 이미 설치되어 있습니다. (버전: !pythonversion!)
)

REM FFmpeg 설치
echo.
echo [4/5] FFmpeg 확인 및 설치 중...
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    echo FFmpeg를 설치하고 있습니다... (시간이 걸릴 수 있습니다)
    winget install Gyan.FFmpeg --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [경고] FFmpeg 설치에 실패했습니다. 비디오 썸네일 기능이 제한될 수 있습니다.
    ) else (
        echo [완료] FFmpeg가 설치되었습니다.
    )
) else (
    echo [완료] FFmpeg가 이미 설치되어 있습니다.
)

REM 프로젝트 의존성 설치
echo.
echo [5/5] 프로젝트 의존성 설치 중...
cd /d "%~dp0"

REM PATH 환경변수 새로고침
call refreshenv >nul 2>&1

if exist package.json (
    if not exist node_modules (
        echo npm 패키지들을 설치하고 있습니다...
        call npm install --silent
        if %errorlevel% neq 0 (
            echo [경고] 일부 npm 패키지 설치에 실패했을 수 있습니다.
            echo 수동으로 'npm install'을 실행해주세요.
        ) else (
            echo [완료] 모든 의존성이 설치되었습니다.
        )
    ) else (
        echo [완료] 의존성이 이미 설치되어 있습니다.
    )
) else (
    echo [경고] package.json을 찾을 수 없습니다.
)

echo.
echo ===============================================================================
echo                        🎉 설치 완료! 🎉
echo ===============================================================================
echo.
echo 설치된 항목들:
echo.

REM 설치 확인
call node --version >nul 2>&1 && (
    for /f "tokens=*" %%i in ('node --version') do echo   ✅ Node.js %%i
) || echo   ❌ Node.js 설치 실패

call python --version >nul 2>&1 && (
    for /f "tokens=*" %%i in ('python --version') do echo   ✅ Python %%i  
) || echo   ❌ Python 설치 실패

call ffmpeg -version >nul 2>&1 && (
    echo   ✅ FFmpeg 설치됨
) || echo   ❌ FFmpeg 설치 실패

if exist node_modules (
    echo   ✅ 프로젝트 의존성 설치됨
) else (
    echo   ❌ 프로젝트 의존성 설치 실패
)

echo.
echo ===============================================================================
echo                        🚀 이제 시작할 수 있습니다! 🚀
echo ===============================================================================
echo.
echo 다음 중 하나를 선택하여 Media File Explorer를 시작하세요:
echo.
echo   1. '🚀 CLICK HERE TO START.bat' 더블클릭
echo   2. 'MediaExplorer-Start.bat' 더블클릭  
echo   3. 'START-HERE-WINDOWS.bat' 더블클릭
echo.
echo 웹브라우저에서 http://localhost:3000 주소로 접속됩니다.
echo.

set /p start="지금 바로 실행하시겠습니까? (Y/N): "
if /i "%start%"=="Y" (
    if exist "🚀 CLICK HERE TO START.bat" (
        echo Media File Explorer를 시작합니다...
        start "" "🚀 CLICK HERE TO START.bat"
    ) else if exist "MediaExplorer-Start.bat" (
        echo Media File Explorer를 시작합니다...
        start "" "MediaExplorer-Start.bat"
    ) else (
        echo 시작 파일을 찾을 수 없습니다.
    )
)

echo.
echo 설치가 완료되었습니다. 창을 닫으셔도 됩니다.
pause