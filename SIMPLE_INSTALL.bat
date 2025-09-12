@echo off
title Media File Explorer - Simple Install

echo.
echo ================================================
echo    Media File Explorer - Simple Installer
echo ================================================
echo.
echo This is the most basic installation method.
echo No fancy graphics, just reliable installation.
echo.

REM Request admin rights if not already running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [ADMIN] Running with administrator privileges.
echo.

REM Check for Winget
echo [STEP 1] Checking system compatibility...
winget --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This installer requires Windows Package Manager (winget).
    echo.
    echo Please install 'App Installer' from Microsoft Store first.
    echo Or use manual installation instructions.
    pause
    exit /b 1
)
echo [OK] Windows Package Manager is available.

REM Install Node.js
echo.
echo [STEP 2] Installing Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [ERROR] Node.js installation failed.
    ) else (
        echo [OK] Node.js installed.
    )
) else (
    echo [OK] Node.js already installed.
)

REM Install Python
echo.
echo [STEP 3] Installing Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    winget install Python.Python.3.12 --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [ERROR] Python installation failed.
    ) else (
        echo [OK] Python installed.
    )
) else (
    echo [OK] Python already installed.
)

REM Install FFmpeg
echo.
echo [STEP 4] Installing FFmpeg...
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    winget install Gyan.FFmpeg --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [WARNING] FFmpeg installation failed. Video features may be limited.
    ) else (
        echo [OK] FFmpeg installed.
    )
) else (
    echo [OK] FFmpeg already installed.
)

REM Install npm packages
echo.
echo [STEP 5] Installing project dependencies...
cd /d "%~dp0"
if exist package.json (
    if not exist node_modules (
        npm install
        if %errorlevel% neq 0 (
            echo [ERROR] npm install failed. Please run 'npm install' manually.
        ) else (
            echo [OK] Project dependencies installed.
        )
    ) else (
        echo [OK] Project dependencies already installed.
    )
) else (
    echo [WARNING] package.json not found.
)

echo.
echo ================================================
echo              Installation Complete
echo ================================================
echo.
echo Results:
call node --version >nul 2>&1 && echo [✓] Node.js: OK || echo [✗] Node.js: Failed
call python --version >nul 2>&1 && echo [✓] Python: OK || echo [✗] Python: Failed
call ffmpeg -version >nul 2>&1 && echo [✓] FFmpeg: OK || echo [✗] FFmpeg: Failed
if exist node_modules echo [✓] Dependencies: OK
if not exist node_modules echo [✗] Dependencies: Failed
echo.
echo To start the application:
echo 1. Close this window
echo 2. Run START-HERE-WINDOWS.bat or MediaExplorer-Start.bat
echo.
pause