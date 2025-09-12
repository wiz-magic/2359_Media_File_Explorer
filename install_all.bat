@echo off
title Media File Explorer - Auto Setup

echo.
echo ===============================================
echo    Media File Explorer - Auto Setup Script
echo ===============================================
echo.
echo This script will install the following programs:
echo   1. Node.js (v20.18.0)
echo   2. Python (3.12.4)
echo   3. FFmpeg (for video processing)
echo   4. Project dependencies (npm packages)
echo.
echo Administrator privileges may be required during installation.
echo.

REM Check administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [Admin Rights] Confirmed
    goto :main
) else (
    echo [Warning] Administrator privileges required.
    echo Restarting with administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:main
echo.
echo Starting installation...
echo.

REM Run PowerShell script first
if exist "%~dp0install_all_direct.ps1" (
    echo Running PowerShell script...
    powershell -ExecutionPolicy Bypass -File "%~dp0install_all_direct.ps1" -AsAdmin
    if %errorlevel% neq 0 (
        echo.
        echo PowerShell script failed. Trying alternative installation...
        goto :fallback_install
    )
    goto :success
) else (
    echo install_all_direct.ps1 file not found.
    goto :fallback_install
)

:fallback_install
echo.
echo ===============================================
echo      Alternative Installation (Using Winget)
echo ===============================================
echo.

REM Check Winget availability
winget --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [Error] Winget not found.
    echo Windows 10/11 latest version required.
    echo Please manually install the following programs:
    echo   - Node.js: https://nodejs.org/
    echo   - Python: https://www.python.org/
    echo   - FFmpeg: https://ffmpeg.org/
    goto :manual_install
)

echo 1. Installing Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements
    if %errorlevel% neq 0 (
        echo Node.js installation failed
    ) else (
        echo Node.js installation completed
    )
) else (
    echo Node.js already installed.
)

echo 2. Installing Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    winget install Python.Python.3.12 --silent --accept-source-agreements
    if %errorlevel% neq 0 (
        echo Python installation failed
    ) else (
        echo Python installation completed
    )
) else (
    echo Python already installed.
)

echo 3. Installing FFmpeg...
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    winget install Gyan.FFmpeg --silent --accept-source-agreements
    if %errorlevel% neq 0 (
        echo FFmpeg installation failed
    ) else (
        echo FFmpeg installation completed
    )
) else (
    echo FFmpeg already installed.
)

REM Install project dependencies
echo 4. Installing project dependencies...
cd /d "%~dp0"
if exist package.json (
    if not exist node_modules (
        call npm install
        if %errorlevel% neq 0 (
            echo npm install failed. Please run 'npm install' manually.
        ) else (
            echo Project dependencies installed successfully
        )
    ) else (
        echo Project dependencies already installed.
    )
) else (
    echo package.json not found.
)

:success
echo.
echo ===============================================
echo          Installation Complete!
echo ===============================================
echo.
echo Installed versions:
call node --version 2>nul && echo Node.js: OK || echo Node.js: NOT INSTALLED
call python --version 2>nul && echo Python: OK || echo Python: NOT INSTALLED
call ffmpeg -version 2>nul | findstr "ffmpeg version" && echo FFmpeg: OK || echo FFmpeg: NOT INSTALLED
echo.
echo To start the application:
echo   - Run 'MediaExplorer-Start.bat' or
echo   - Run 'START-HERE-WINDOWS.bat'
echo.
goto :end

:manual_install
echo.
echo ===============================================
echo         Manual Installation Guide
echo ===============================================
echo.
echo Please download and install the following programs:
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
echo After installation, open a new terminal and run:
echo    npm install
echo.

:end
echo Press any key to exit...
pause >nul