@echo off
title Media File Explorer - Smart Start
cls

:: Change to script directory
cd /d "%~dp0"

echo ===============================================
echo         Media File Explorer
echo ===============================================
echo.

:: Check if dependencies are installed
if not exist "node_modules" (
    echo Dependencies not found. Installing automatically...
    echo This will take a few minutes...
    echo.
    
    :: Check if Node.js is available
    node --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo ERROR: Node.js is not installed!
        echo.
        echo Please run SIMPLE-INSTALL.bat first to install Node.js
        echo and all dependencies automatically.
        echo.
        pause
        exit /b 1
    )
    
    call npm install
    if %errorlevel% neq 0 (
        echo.
        echo ERROR: Failed to install dependencies!
        echo.
        echo Please run SIMPLE-INSTALL.bat for automatic setup
        echo.
        pause
        exit /b 1
    )
    echo.
    echo Dependencies installed successfully!
    echo.
)

echo Starting server...

:: Kill any existing processes
taskkill /F /IM node.exe >nul 2>&1

:: Start the server in background
start /B npm start

:: Wait for server to start
echo Waiting for server to initialize...
timeout /t 5 /nobreak >nul

:: Check if server actually started
timeout /t 2 /nobreak >nul
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe" >nul
if errorlevel 1 (
    echo.
    echo ERROR: Server failed to start!
    echo.
    echo This usually means missing dependencies.
    echo Please run SIMPLE-INSTALL.bat for complete setup.
    echo.
    pause
    exit /b 1
)

:: Open browser
echo Opening browser...
start http://localhost:3000

echo.
echo ===============================================
echo   Media File Explorer is now running!
echo   
echo   Browser opened to: http://localhost:3000
echo   
echo   Keep this window open while using the app.
echo   Close this window to stop the server.
echo ===============================================
echo.

:: Keep server running and monitor
:loop
timeout /t 10 /nobreak >nul
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe" >nul
if errorlevel 1 (
    echo Server stopped unexpectedly. Restarting...
    start /B npm start
    timeout /t 3 /nobreak >nul
)
goto loop