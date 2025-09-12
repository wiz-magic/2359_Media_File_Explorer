@echo off
title Media File Explorer - One Click Setup

REM Check and request administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cls
echo.
echo  ███╗   ███╗███████╗██████╗ ██╗ █████╗     ███████╗██╗██╗     ███████╗
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
echo                         ONE CLICK INSTALLER
echo ===============================================================================
echo.
echo This installer will automatically install everything needed for Media File Explorer:
echo.
echo   [✓] Node.js (JavaScript Runtime)
echo   [✓] Python (Script Environment)  
echo   [✓] FFmpeg (Video/Audio Processing)
echo   [✓] Required NPM Packages
echo.
echo Installation time: About 5-10 minutes (depends on internet speed)
echo.
echo ===============================================================================

set /p confirm="Do you want to proceed with installation? (Y/N): "
if /i "%confirm%" neq "Y" (
    echo Installation cancelled.
    pause
    exit /b
)

echo.
echo [PROGRESS] Starting installation...
echo.

REM Check system compatibility
echo [1/5] Checking system compatibility...
winget --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Windows Package Manager (winget) not found.
    echo Windows 10 version 1709+ or Windows 11 required.
    echo.
    echo Alternative: Install "App Installer" from Microsoft Store and try again.
    echo Or run 'install_all_fixed.bat' for manual installation.
    pause
    exit /b 1
)
echo [COMPLETE] System is compatible.

REM Install Node.js
echo.
echo [2/5] Checking and installing Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Node.js... (This may take a while)
    winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [ERROR] Node.js installation failed.
    ) else (
        echo [COMPLETE] Node.js installed successfully.
    )
) else (
    for /f "tokens=*" %%i in ('node --version') do set nodeversion=%%i
    echo [COMPLETE] Node.js already installed (Version: %nodeversion%)
)

REM Install Python
echo.
echo [3/5] Checking and installing Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Python... (This may take a while)
    winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [ERROR] Python installation failed.
    ) else (
        echo [COMPLETE] Python installed successfully.
    )
) else (
    for /f "tokens=*" %%i in ('python --version') do set pythonversion=%%i
    echo [COMPLETE] Python already installed (Version: %pythonversion%)
)

REM Install FFmpeg
echo.
echo [4/5] Checking and installing FFmpeg...
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing FFmpeg... (This may take a while)
    winget install Gyan.FFmpeg --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [WARNING] FFmpeg installation failed. Video thumbnail features may be limited.
    ) else (
        echo [COMPLETE] FFmpeg installed successfully.
    )
) else (
    echo [COMPLETE] FFmpeg already installed.
)

REM Install project dependencies
echo.
echo [5/5] Installing project dependencies...
cd /d "%~dp0"

REM Refresh PATH environment variables
call refreshenv >nul 2>&1

if exist package.json (
    if not exist node_modules (
        echo Installing npm packages...
        call npm install --silent
        if %errorlevel% neq 0 (
            echo [WARNING] Some npm packages may have failed to install.
            echo Please run 'npm install' manually.
        ) else (
            echo [COMPLETE] All dependencies installed successfully.
        )
    ) else (
        echo [COMPLETE] Dependencies already installed.
    )
) else (
    echo [WARNING] package.json not found.
)

echo.
echo ===============================================================================
echo                        INSTALLATION COMPLETE!
echo ===============================================================================
echo.
echo Installed components:
echo.

REM Verify installations
call node --version >nul 2>&1 && (
    for /f "tokens=*" %%i in ('node --version') do echo   [✓] Node.js %%i
) || echo   [✗] Node.js installation failed

call python --version >nul 2>&1 && (
    for /f "tokens=*" %%i in ('python --version') do echo   [✓] Python %%i  
) || echo   [✗] Python installation failed

call ffmpeg -version >nul 2>&1 && (
    echo   [✓] FFmpeg installed
) || echo   [✗] FFmpeg installation failed

if exist node_modules (
    echo   [✓] Project dependencies installed
) else (
    echo   [✗] Project dependencies installation failed
)

echo.
echo ===============================================================================
echo                        READY TO START!
echo ===============================================================================
echo.
echo Choose one of the following to start Media File Explorer:
echo.
echo   1. Double-click 'START-HERE-WINDOWS.bat'
echo   2. Double-click 'MediaExplorer-Start.bat'
echo   3. Double-click any file that starts with a rocket emoji
echo.
echo The application will open in your web browser at http://localhost:3000
echo.

set /p start="Would you like to start it now? (Y/N): "
if /i "%start%"=="Y" (
    if exist "START-HERE-WINDOWS.bat" (
        echo Starting Media File Explorer...
        start "" "START-HERE-WINDOWS.bat"
    ) else if exist "MediaExplorer-Start.bat" (
        echo Starting Media File Explorer...
        start "" "MediaExplorer-Start.bat"
    ) else (
        echo Start file not found.
    )
)

echo.
echo Installation completed. You can close this window.
pause