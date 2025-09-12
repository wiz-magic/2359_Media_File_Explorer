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

REM Try to run PowerShell script first
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
    echo PowerShell script not found. Using alternative installation...
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
    echo    Node.js not found. Installing...
    winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo    [ERROR] Node.js installation failed
    ) else (
        echo    [SUCCESS] Node.js installation completed
        REM Refresh PATH for current session
        call refreshenv >nul 2>&1
    )
) else (
    for /f "tokens=*" %%i in ('node --version 2^>nul') do echo    [OK] Node.js already installed: %%i
)

echo 2. Installing Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo    Python not found. Installing...
    winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo    [ERROR] Python installation failed
    ) else (
        echo    [SUCCESS] Python installation completed
        REM Refresh PATH for current session
        call refreshenv >nul 2>&1
    )
) else (
    for /f "tokens=*" %%i in ('python --version 2^>nul') do echo    [OK] Python already installed: %%i
)

echo 3. Installing FFmpeg...
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    echo    FFmpeg not found. Installing...
    winget install Gyan.FFmpeg --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo    [WARNING] FFmpeg installation failed. Video features may be limited.
    ) else (
        echo    [SUCCESS] FFmpeg installation completed
        REM Refresh PATH for current session
        call refreshenv >nul 2>&1
    )
) else (
    echo    [OK] FFmpeg already installed.
)

REM Install project dependencies
echo 4. Installing project dependencies...
cd /d "%~dp0"
if exist package.json (
    if not exist node_modules (
        echo    Installing npm packages...
        REM Try to refresh PATH and use npm
        call refreshenv >nul 2>&1
        npm --version >nul 2>&1
        if %errorlevel% neq 0 (
            echo    [WARNING] npm not available yet. Please restart terminal and run 'npm install' manually.
        ) else (
            call npm install
            if %errorlevel% neq 0 (
                echo    [ERROR] npm install failed. Please run 'npm install' manually after restarting terminal.
            ) else (
                echo    [SUCCESS] Project dependencies installed successfully
            )
        )
    ) else (
        echo    [OK] Project dependencies already installed.
    )
) else (
    echo    [WARNING] package.json not found.
)

:success
echo.
echo ===============================================
echo          Installation Complete!
echo ===============================================
echo.
echo Installation Results:
echo.
call node --version >nul 2>&1 && (
    for /f "tokens=*" %%i in ('node --version 2^>nul') do echo   [✓] Node.js %%i
) || echo   [✗] Node.js: NOT INSTALLED - Please restart terminal

call python --version >nul 2>&1 && (
    for /f "tokens=*" %%i in ('python --version 2^>nul') do echo   [✓] Python %%i
) || echo   [✗] Python: NOT INSTALLED - Please restart terminal

call ffmpeg -version >nul 2>&1 && (
    echo   [✓] FFmpeg: Installed
) || echo   [✗] FFmpeg: NOT INSTALLED - Please restart terminal

if exist node_modules (
    echo   [✓] Project dependencies: Installed
) else (
    echo   [!] Project dependencies: Run 'npm install' after restarting terminal
)
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