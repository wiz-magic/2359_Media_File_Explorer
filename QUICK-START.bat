@echo off
title Media File Explorer - Quick Start

:: Go to script directory
cd /d "%~dp0"

echo Media File Explorer - Quick Start
echo =================================
echo.

:: Check basics
if not exist package.json (
    echo ERROR: package.json not found!
    echo Are you in the right folder?
    echo.
    pause
    exit /b 1
)

:: Simple Node.js check
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Node.js not found!
    echo.
    echo Please install Node.js first:
    echo 1. Go to https://nodejs.org
    echo 2. Download and install LTS version
    echo 3. Restart computer
    echo 4. Run this script again
    echo.
    pause
    exit /b 1
)

echo Node.js: OK
echo.

:: Install dependencies if needed
if not exist node_modules (
    echo Installing dependencies...
    npm install
    if %errorlevel% neq 0 (
        echo.
        echo Failed to install dependencies!
        echo Try running this as administrator.
        pause
        exit /b 1
    )
)

echo Dependencies: OK
echo.

:: Kill existing processes
taskkill /F /IM node.exe >nul 2>&1

:: Start server
echo Starting server...
start /B npm start

:: Wait and open browser
timeout /t 3 /nobreak >nul
start http://localhost:3000

echo.
echo Server started!
echo Browser should open automatically.
echo If not, go to: http://localhost:3000
echo.
echo Keep this window open while using the app.
echo Close this window to stop the server.
echo.

:: Simple monitoring
:wait
timeout /t 30 /nobreak >nul
goto wait