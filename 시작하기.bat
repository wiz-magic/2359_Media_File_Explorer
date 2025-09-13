@echo off
title Media File Explorer
cls

echo ===============================================
echo         Media File Explorer
echo ===============================================
echo.
echo Starting server...

:: Change to script directory
cd /d "%~dp0"

:: Kill any existing processes
taskkill /F /IM node.exe >nul 2>&1

:: Start the server in background
start /B npm start

:: Wait for server to start
echo Waiting for server to initialize...
timeout /t 5 /nobreak >nul

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

:: Keep server running
:loop
timeout /t 10 /nobreak >nul
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe" >nul
if errorlevel 1 (
    echo Server stopped unexpectedly. Restarting...
    start /B npm start
    timeout /t 3 /nobreak >nul
)
goto loop