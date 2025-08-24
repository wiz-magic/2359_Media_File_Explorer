@echo off
title Media File Explorer - Simple Setup
cls

echo ===============================================
echo     Media File Explorer - Simple Setup
echo ===============================================
echo.
echo This will install everything needed and start the app.
echo.
pause

:: Get the directory where this script is located
set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"

echo Current directory: %CD%
echo.

:: Check if package.json exists
if not exist "package.json" (
    echo ERROR: package.json not found!
    echo Make sure you're running this from the project folder.
    echo Current location: %CD%
    pause
    exit /b 1
)

:: Request admin if not already
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs -WorkingDirectory '%PROJECT_DIR%'"
    exit /b
)

echo [Step 1] Checking Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Node.js...
    :: Download and install Node.js
    powershell -Command "Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.17.0/node-v20.17.0-x64.msi' -OutFile 'node-installer.msi'"
    if exist "node-installer.msi" (
        msiexec /i "node-installer.msi" /quiet /norestart
        echo Waiting for Node.js installation...
        timeout /t 15 /nobreak >nul
        del "node-installer.msi"
        
        :: Refresh PATH
        for /f "tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH') do set "PATH=%%j"
        set "PATH=%PATH%;C:\Program Files\nodejs"
    )
) else (
    echo Node.js already installed
)

echo.
echo [Step 2] Installing project packages...
if not exist "node_modules" (
    call npm install
    if %errorlevel% neq 0 (
        echo npm install failed! Trying to fix...
        call npm cache clean --force
        call npm install
    )
) else (
    echo Packages already installed
)

echo.
echo [Step 3] Creating startup script...
(
echo @echo off
echo title Media File Explorer
echo cd /d "%PROJECT_DIR%"
echo start /B npm start
echo timeout /t 3 /nobreak ^>nul
echo start http://localhost:3000
echo echo.
echo echo Media File Explorer is running at http://localhost:3000
echo echo Close this window to stop the server.
echo echo.
echo pause
) > "Start-MediaExplorer.bat"

:: Create desktop shortcut
echo [Step 4] Creating desktop shortcut...
set "DESKTOP=%USERPROFILE%\Desktop"
set "SHORTCUT=%DESKTOP%\Media File Explorer.lnk"
set "TARGET=%PROJECT_DIR%Start-MediaExplorer.bat"

powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%SHORTCUT%'); $Shortcut.TargetPath = '%TARGET%'; $Shortcut.WorkingDirectory = '%PROJECT_DIR%'; $Shortcut.Save()"

echo.
echo ===============================================
echo          INSTALLATION COMPLETED!
echo ===============================================
echo.
echo To start Media File Explorer:
echo   1. Double-click "Media File Explorer" on desktop
echo   2. Or run "Start-MediaExplorer.bat" in this folder
echo.
echo The app will open at: http://localhost:3000
echo.

set /p START=Start Media File Explorer now? (Y/N): 
if /i "%START%"=="Y" (
    echo Starting...
    call "Start-MediaExplorer.bat"
)

echo.
pause