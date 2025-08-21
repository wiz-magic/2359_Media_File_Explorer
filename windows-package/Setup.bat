@echo off
title Media File Explorer - Setup
echo ========================================
echo    Media File Explorer - Setup
echo ========================================
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo Node.js is not installed. Installing Node.js...
    echo.
    echo Please wait while we download Node.js installer...
    
    REM Download Node.js installer
    powershell -Command "Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi' -OutFile 'node-installer.msi'"
    
    echo Installing Node.js...
    msiexec /i node-installer.msi /quiet /norestart
    
    echo Node.js installed successfully!
    del node-installer.msi
    echo.
) else (
    echo Node.js is already installed.
    echo.
)

cd /d "%~dp0app"

echo Installing application dependencies...
call npm install --production

echo.
echo ========================================
echo    Setup Complete!
echo ========================================
echo.
echo You can now run "Start Media Explorer.bat"
echo.
pause