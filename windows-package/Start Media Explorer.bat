@echo off
title Media File Explorer
cd /d "%~dp0app"

echo ========================================
echo     Media File Explorer
echo ========================================
echo.
echo Starting application...
echo The browser will open automatically.
echo.
echo Press Ctrl+C to stop the server.
echo ========================================
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed!
    echo.
    echo Please install Node.js from https://nodejs.org
    echo Download the LTS version for Windows.
    echo.
    pause
    exit /b 1
)

REM Install dependencies if needed
if not exist "node_modules" (
    echo Installing dependencies...
    call npm install --production
    echo.
)

REM Start the application
node local-server.cjs

pause