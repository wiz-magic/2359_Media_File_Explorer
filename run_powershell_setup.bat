@echo off
chcp 65001 >nul
title Media File Explorer - PowerShell 설치 스크립트 실행기

echo.
echo ===============================================
echo   Media File Explorer - PowerShell 스크립트 실행
echo ===============================================
echo.
echo 이 스크립트는 PowerShell 설치 스크립트를 안전하게 실행합니다.
echo.

REM 관리자 권한으로 실행
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 관리자 권한이 필요합니다. 관리자 권한으로 다시 시작합니다...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [권한 확인] 관리자 권한으로 실행 중입니다.
echo.

REM 실행할 PowerShell 스크립트 선택
echo 실행할 PowerShell 스크립트를 선택하세요:
echo.
echo 1. install_all_direct.ps1 (직접 설치 스크립트)
echo 2. install_all.ps1 (래퍼 스크립트)
echo 3. MediaExplorer-Setup.ps1 (고급 설치 스크립트)
echo 4. 취소
echo.

set /p choice="선택 (1-4): "

if "%choice%"=="1" (
    set script=install_all_direct.ps1
) else if "%choice%"=="2" (
    set script=install_all.ps1  
) else if "%choice%"=="3" (
    set script=MediaExplorer-Setup.ps1
) else if "%choice%"=="4" (
    echo 취소되었습니다.
    pause
    exit /b
) else (
    echo 잘못된 선택입니다.
    pause
    exit /b
)

if not exist "%~dp0%script%" (
    echo [오류] %script% 파일을 찾을 수 없습니다.
    echo.
    echo 대신 다음 중 하나를 사용해보세요:
    echo   - install_all.bat (권장)
    echo   - 🚀 원클릭 설치.bat
    echo.
    pause
    exit /b
)

echo.
echo [실행] %script%를 실행합니다...
echo.

REM PowerShell 실행 정책을 우회하여 스크립트 실행
powershell -ExecutionPolicy Bypass -Command "& '%~dp0%script%' -AsAdmin"

if %errorlevel% neq 0 (
    echo.
    echo [오류] PowerShell 스크립트 실행에 실패했습니다.
    echo.
    echo 대안:
    echo   1. 'install_all.bat' 파일을 사용해보세요 (권장)
    echo   2. 또는 '🚀 원클릭 설치.bat' 파일을 사용해보세요
    echo.
) else (
    echo.
    echo [완료] PowerShell 스크립트가 성공적으로 실행되었습니다.
)

echo.
echo 아무 키나 눌러서 종료하세요...
pause >nul