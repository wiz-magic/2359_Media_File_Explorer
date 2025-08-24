@echo off
title Media File Explorer - Debug Mode
cls

echo ===============================================
echo     Media File Explorer - Debug Mode
echo ===============================================
echo.
echo This will show detailed information about what's happening.
echo.

:: Change to script directory
set "SCRIPT_DIR=%~dp0"
echo Script location: %SCRIPT_DIR%
cd /d "%SCRIPT_DIR%"
echo Current directory: %CD%
echo.

:: Check if package.json exists
echo Checking for package.json...
if exist "package.json" (
    echo ✓ package.json found
) else (
    echo ✗ package.json NOT found!
    echo This means you're in the wrong directory.
    echo Please make sure you extracted the ZIP file properly.
    echo.
    echo Contents of current directory:
    dir
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

:: Check Node.js
echo.
echo Checking Node.js...
node --version 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('node --version 2^>nul') do echo ✓ Node.js found: %%i
) else (
    echo ✗ Node.js NOT found!
    echo.
    echo Attempting to install Node.js...
    
    :: Check if we have admin rights
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        echo Need administrator privileges to install Node.js.
        echo Right-click this file and select "Run as administrator"
        echo.
        pause
        exit /b 1
    )
    
    echo Downloading Node.js installer...
    powershell -Command "try { Write-Host 'Downloading...'; Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.17.0/node-v20.17.0-x64.msi' -OutFile 'node-installer.msi'; Write-Host 'Download complete' } catch { Write-Host 'Download failed:' $_.Exception.Message }"
    
    if exist "node-installer.msi" (
        echo Installing Node.js (this takes a few minutes)...
        start /wait msiexec /i "node-installer.msi" /quiet /norestart
        del "node-installer.msi"
        
        echo Refreshing environment variables...
        :: Refresh PATH
        for /f "tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "SYSTEM_PATH=%%j"
        for /f "tokens=2*" %%i in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%j"
        set "PATH=%SYSTEM_PATH%;%USER_PATH%;C:\Program Files\nodejs"
        
        echo Checking Node.js installation...
        node --version 2>nul
        if %errorlevel% equ 0 (
            echo ✓ Node.js installed successfully!
        ) else (
            echo ✗ Node.js installation failed or needs computer restart
            echo Please restart your computer and try again.
            pause
            exit /b 1
        )
    ) else (
        echo ✗ Failed to download Node.js installer
        echo Please check your internet connection.
        pause
        exit /b 1
    )
)

:: Check npm
echo.
echo Checking npm...
npm --version 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('npm --version 2^>nul') do echo ✓ npm found: %%i
) else (
    echo ✗ npm NOT found (this shouldn't happen if Node.js is installed)
    pause
    exit /b 1
)

:: Check dependencies
echo.
echo Checking dependencies...
if exist "node_modules" (
    echo ✓ node_modules folder exists
) else (
    echo ✗ node_modules folder missing
    echo Installing dependencies...
    
    echo Running: npm install
    call npm install
    if %errorlevel% equ 0 (
        echo ✓ Dependencies installed successfully
    ) else (
        echo ✗ npm install failed
        echo Trying to fix with cache clean...
        call npm cache clean --force
        call npm install
        if %errorlevel% equ 0 (
            echo ✓ Dependencies installed after cache clean
        ) else (
            echo ✗ npm install still failing
            echo Manual intervention required.
            pause
            exit /b 1
        )
    )
)

:: Test server startup
echo.
echo Testing server startup...
echo Running: node local-server.cjs (test)
timeout /t 1 /nobreak >nul
start /B node local-server.cjs
timeout /t 3 /nobreak >nul

:: Check if server is running
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe" >nul
if %errorlevel% equ 0 (
    echo ✓ Server started successfully
    
    :: Kill test server
    taskkill /F /IM node.exe >nul 2>&1
    
    :: Start proper server
    echo.
    echo Starting Media File Explorer...
    start /B npm start
    
    timeout /t 3 /nobreak >nul
    
    :: Open browser
    echo Opening browser...
    start http://localhost:3000
    
    echo.
    echo ===============================================
    echo   Media File Explorer is now running!
    echo   
    echo   URL: http://localhost:3000
    echo   Keep this window open to keep the server running.
    echo ===============================================
    echo.
    
    :: Monitor loop
    :monitor
    timeout /t 10 /nobreak >nul
    tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe" >nul
    if %errorlevel% neq 0 (
        echo Server stopped. Restarting...
        start /B npm start
        timeout /t 3 /nobreak >nul
    )
    goto monitor
    
) else (
    echo ✗ Server failed to start
    echo.
    echo Let's check what's wrong...
    echo Trying to run the server directly to see errors:
    echo.
    node local-server.cjs
    echo.
    echo If you see error messages above, that's the problem.
    pause
)

echo.
echo Debug session ended.
pause