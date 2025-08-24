@echo off
title Media File Explorer - All-in-One
cls

:: Change to script directory
cd /d "%~dp0"

echo ===============================================
echo     Media File Explorer - All-in-One
echo ===============================================
echo.
echo This script will:
echo  1. Check Node.js installation
echo  2. Install dependencies if needed
echo  3. Start the application
echo.

:: Check if we're in the right directory
if not exist "package.json" (
    echo ERROR: package.json not found!
    echo Make sure you're running this from the project folder.
    echo Current location: %CD%
    echo.
    pause
    exit /b 1
)

:: Check Node.js
echo [1/3] Checking Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Node.js not found. Attempting to install...
    
    :: Request admin privileges
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        echo Requesting administrator privileges for Node.js installation...
        powershell -Command "Start-Process '%~f0' -Verb RunAs -WorkingDirectory '%CD%'"
        exit /b
    )
    
    :: Download and install Node.js
    echo Downloading Node.js...
    powershell -Command "try { Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.17.0/node-v20.17.0-x64.msi' -OutFile 'node-installer.msi' } catch { Write-Host 'Download failed' }"
    
    if exist "node-installer.msi" (
        echo Installing Node.js... (this may take a few minutes)
        msiexec /i "node-installer.msi" /quiet /norestart
        echo Waiting for installation to complete...
        timeout /t 20 /nobreak >nul
        del "node-installer.msi"
        
        :: Refresh PATH
        for /f "tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH') do set "PATH=%%j"
        set "PATH=%PATH%;C:\Program Files\nodejs"
        
        :: Verify installation
        node --version >nul 2>&1
        if %errorlevel% neq 0 (
            echo Node.js installation may not be complete.
            echo Please restart your computer and try again.
            echo Or manually install Node.js from: https://nodejs.org
            pause
            exit /b 1
        )
        echo Node.js installed successfully!
    ) else (
        echo Failed to download Node.js installer.
        echo Please manually install Node.js from: https://nodejs.org
        pause
        exit /b 1
    )
) else (
    echo Node.js found!
)

:: Install dependencies
echo.
echo [2/3] Checking dependencies...
if not exist "node_modules" (
    echo Installing npm packages... (this may take several minutes)
    call npm install
    if %errorlevel% neq 0 (
        echo npm install failed. Trying to fix...
        call npm cache clean --force
        call npm install
        if %errorlevel% neq 0 (
            echo Failed to install dependencies.
            echo Try running: npm install
            pause
            exit /b 1
        )
    )
    echo Dependencies installed!
) else (
    echo Dependencies already installed!
)

:: Start the application
echo.
echo [3/3] Starting Media File Explorer...

:: Kill any existing processes
taskkill /F /IM node.exe >nul 2>&1

:: Start the server
start /B npm start

:: Wait for server to start
echo Waiting for server to start...
timeout /t 5 /nobreak >nul

:: Verify server is running
timeout /t 2 /nobreak >nul
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe" >nul
if errorlevel 1 (
    echo Server failed to start. Checking for errors...
    timeout /t 3 /nobreak >nul
    tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe" >nul
    if errorlevel 1 (
        echo.
        echo ERROR: Server is not running.
        echo Please check the error messages above.
        echo.
        pause
        exit /b 1
    )
)

:: Open browser
echo Opening browser...
timeout /t 2 /nobreak >nul
start http://localhost:3000

:: Create desktop shortcut
echo Creating desktop shortcut...
set "DESKTOP=%USERPROFILE%\Desktop"
set "SHORTCUT=%DESKTOP%\Media File Explorer.lnk"
set "TARGET=%~f0"

powershell -Command "try { $WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%SHORTCUT%'); $Shortcut.TargetPath = '%TARGET%'; $Shortcut.WorkingDirectory = '%CD%'; $Shortcut.Save() } catch { }"

echo.
echo ===============================================
echo      Media File Explorer is now running!
echo ===============================================
echo.
echo * Browser opened to: http://localhost:3000
echo * Desktop shortcut created (if possible)
echo * Keep this window open while using the app
echo.
echo To stop the server, close this window.
echo ===============================================
echo.

:: Monitor server
:monitor
timeout /t 10 /nobreak >nul
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe" >nul
if errorlevel 1 (
    echo Server stopped. Attempting restart...
    start /B npm start
    timeout /t 3 /nobreak >nul
)
goto monitor