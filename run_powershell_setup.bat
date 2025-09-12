@echo off
title Media File Explorer - PowerShell Script Runner

echo.
echo ===============================================
echo   Media File Explorer - PowerShell Script Runner
echo ===============================================
echo.
echo This script safely runs PowerShell installation scripts.
echo.

REM Check and request administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Administrator privileges required. Restarting with admin rights...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [Permission Check] Running with administrator privileges.
echo.

REM Choose PowerShell script to run
echo Choose which PowerShell script to run:
echo.
echo 1. install_all_direct.ps1 (Direct installation script)
echo 2. install_all.ps1 (Wrapper script)
echo 3. MediaExplorer-Setup.ps1 (Advanced installation script)
echo 4. Cancel
echo.

set /p choice="Choice (1-4): "

if "%choice%"=="1" (
    set script=install_all_direct.ps1
) else if "%choice%"=="2" (
    set script=install_all.ps1  
) else if "%choice%"=="3" (
    set script=MediaExplorer-Setup.ps1
) else if "%choice%"=="4" (
    echo Cancelled.
    pause
    exit /b
) else (
    echo Invalid choice.
    pause
    exit /b
)

if not exist "%~dp0%script%" (
    echo [ERROR] %script% file not found.
    echo.
    echo Please try one of the following instead:
    echo   - install_all.bat (recommended)
    echo   - OneClick_Setup.bat
    echo.
    pause
    exit /b
)

echo.
echo [RUNNING] Executing %script%...
echo.

REM Run PowerShell script with bypassed execution policy
powershell -ExecutionPolicy Bypass -Command "& '%~dp0%script%' -AsAdmin"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] PowerShell script execution failed.
    echo.
    echo Alternatives:
    echo   1. Try 'install_all.bat' file (recommended)
    echo   2. Or try 'OneClick_Setup.bat' file
    echo.
) else (
    echo.
    echo [COMPLETE] PowerShell script executed successfully.
)

echo.
echo Press any key to exit...
pause >nul