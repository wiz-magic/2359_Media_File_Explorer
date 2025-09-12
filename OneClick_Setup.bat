@echo off
title Media File Explorer - One Click Setup

echo.
echo ===============================================
echo    Media File Explorer - One Click Setup
echo ===============================================
echo.

REM Check and request administrator privileges with better error handling
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Administrator privileges required.
    echo Attempting to restart with administrator privileges...
    echo.
    timeout /t 2 /nobreak >nul
    
    REM Try to restart with admin privileges
    powershell -Command "try { Start-Process '%~f0' -Verb RunAs -Wait } catch { Write-Host 'Failed to get admin privileges' }"
    
    REM If we reach here, either admin was granted or denied
    echo.
    echo If the script didn't continue, please:
    echo 1. Right-click on OneClick_Setup_Fixed.bat
    echo 2. Select 'Run as administrator'
    echo 3. Click 'Yes' when prompted
    echo.
    pause
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
echo                         ONE CLICK INSTALLER
echo ===============================================================================
echo.
echo This installer will automatically install everything needed for Media File Explorer:
echo.
echo   [+] Node.js (JavaScript Runtime)
echo   [+] Python (Script Environment)  
echo   [+] FFmpeg (Video/Audio Processing)
echo   [+] Required NPM Packages
echo.
echo Installation time: About 5-10 minutes (depends on internet speed)
echo Administrator privileges: CONFIRMED
echo.
echo ===============================================================================

set /p confirm="Do you want to proceed with installation? (Y/N): "
if /i "%confirm%" neq "Y" (
    echo.
    echo Installation cancelled by user.
    echo.
    pause
    exit /b 0
)

echo.
echo [PROGRESS] Starting installation process...
echo.

REM Check system compatibility
echo [1/5] Checking system compatibility...
winget --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Windows Package Manager (winget) not found.
    echo.
    echo SYSTEM REQUIREMENTS:
    echo - Windows 10 version 1709 or later
    echo - Windows 11 (any version)
    echo - App Installer from Microsoft Store
    echo.
    echo SOLUTIONS:
    echo 1. Update Windows to the latest version
    echo 2. Install 'App Installer' from Microsoft Store
    echo 3. Use 'install_all.bat' for alternative installation
    echo.
    pause
    exit /b 1
)
echo [COMPLETE] System is compatible with winget.

REM Install Node.js
echo.
echo [2/5] Checking and installing Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Node.js... (This may take several minutes)
    winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [ERROR] Node.js installation failed.
        echo Please try running 'install_all.bat' instead.
        pause
        exit /b 1
    ) else (
        echo [COMPLETE] Node.js installed successfully.
    )
) else (
    for /f "tokens=*" %%i in ('node --version 2^>nul') do set nodeversion=%%i
    echo [COMPLETE] Node.js already installed: %nodeversion%
)

REM Install Python
echo.
echo [3/5] Checking and installing Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Python... (This may take several minutes)
    winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [ERROR] Python installation failed.
        echo Please try running 'install_all.bat' instead.
        pause
        exit /b 1
    ) else (
        echo [COMPLETE] Python installed successfully.
    )
) else (
    for /f "tokens=*" %%i in ('python --version 2^>nul') do set pythonversion=%%i
    echo [COMPLETE] Python already installed: %pythonversion%
)

REM Install FFmpeg
echo.
echo [4/5] Checking and installing FFmpeg...
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing FFmpeg... (This may take several minutes)
    winget install Gyan.FFmpeg --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [WARNING] FFmpeg installation failed.
        echo Video thumbnail features may be limited.
        echo You can manually install FFmpeg later from https://ffmpeg.org/
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
set "PATH=%PATH%;%ProgramFiles%\nodejs;%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts"

if exist package.json (
    if not exist node_modules (
        echo Installing npm packages...
        call npm install 2>nul
        if %errorlevel% neq 0 (
            echo [WARNING] Some npm packages may have failed to install.
            echo Please run 'npm install' manually in this folder later.
        ) else (
            echo [COMPLETE] All dependencies installed successfully.
        )
    ) else (
        echo [COMPLETE] Dependencies already installed.
    )
) else (
    echo [WARNING] package.json not found in current directory.
)

echo.
echo ===============================================================================
echo                        INSTALLATION COMPLETE!
echo ===============================================================================
echo.
echo Checking installed components:
echo.

REM Verify installations with better error handling
call node --version >nul 2>&1 && (
    for /f "tokens=*" %%i in ('node --version 2^>nul') do echo   [✓] Node.js %%i
) || echo   [!] Node.js - Please restart terminal to update PATH

call python --version >nul 2>&1 && (
    for /f "tokens=*" %%i in ('python --version 2^>nul') do echo   [✓] Python %%i  
) || echo   [!] Python - Please restart terminal to update PATH

call ffmpeg -version >nul 2>&1 && (
    echo   [✓] FFmpeg installed
) || echo   [!] FFmpeg - Please restart terminal to update PATH

if exist node_modules (
    echo   [✓] Project dependencies installed
) else (
    echo   [!] Project dependencies - Run 'npm install' manually
)

echo.
echo ===============================================================================
echo                        READY TO START!
echo ===============================================================================
echo.
echo Next steps:
echo.
echo 1. IMPORTANT: Close this window and open a NEW terminal/command prompt
echo    (This ensures all PATH changes take effect)
echo.
echo 2. Navigate back to this folder and run one of these:
echo    - START-HERE-WINDOWS.bat
echo    - MediaExplorer-Start.bat
echo.
echo 3. The application will open at http://localhost:3000
echo.

set /p start="Would you like to try starting it now? (Y/N): "
if /i "%start%"=="Y" (
    if exist "START-HERE-WINDOWS.bat" (
        echo.
        echo Starting Media File Explorer...
        echo If it fails, please restart your terminal first.
        echo.
        timeout /t 2 /nobreak >nul
        call "START-HERE-WINDOWS.bat"
    ) else if exist "MediaExplorer-Start.bat" (
        echo.
        echo Starting Media File Explorer...
        echo If it fails, please restart your terminal first.
        echo.
        timeout /t 2 /nobreak >nul
        call "MediaExplorer-Start.bat"
    ) else (
        echo Start file not found. Please run manually after restarting terminal.
    )
)

echo.
echo Installation process completed.
echo Thank you for using Media File Explorer!
echo.
pause