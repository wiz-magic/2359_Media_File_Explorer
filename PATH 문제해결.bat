@echo off
setlocal EnableDelayedExpansion

:: ================================================================
::      PATH Problem Solver (Simple Version)
::      Auto-add Node.js, Python, FFmpeg to PATH
:: ================================================================

echo ================================================================
echo             PATH Problem Solver
echo ================================================================
echo.
echo This tool fixes PATH issues after reboot.
echo.
pause

:: Check admin privileges - simplified
net session >nul 2>&1
if errorlevel 1 (
  echo [INFO] User mode - will modify user PATH
  set "USE_SYSTEM=0"
) else (
  echo [OK] Admin mode - will modify system PATH
  set "USE_SYSTEM=1"
)

echo.
echo Searching for programs...
echo.

:: Find Node.js - simplified
set "NODEJS_PATH="
if exist "%ProgramFiles%\nodejs\node.exe" (
  set "NODEJS_PATH=%ProgramFiles%\nodejs"
  echo [FOUND] Node.js at: %ProgramFiles%\nodejs
)
if exist "%ProgramFiles(x86)%\nodejs\node.exe" (
  set "NODEJS_PATH=%ProgramFiles(x86)%\nodejs" 
  echo [FOUND] Node.js at: %ProgramFiles(x86)%\nodejs
)
if not defined NODEJS_PATH echo [NOT FOUND] Node.js

:: Find Python - simplified
set "PYTHON_PATH="
if exist "C:\Program Files\Python312\python.exe" (
  set "PYTHON_PATH=C:\Program Files\Python312"
  echo [FOUND] Python at: C:\Program Files\Python312
)
if exist "C:\Program Files\Python311\python.exe" (
  set "PYTHON_PATH=C:\Program Files\Python311"
  echo [FOUND] Python at: C:\Program Files\Python311
)
if exist "C:\Program Files\Python310\python.exe" (
  set "PYTHON_PATH=C:\Program Files\Python310"
  echo [FOUND] Python at: C:\Program Files\Python310
)
if not defined PYTHON_PATH echo [NOT FOUND] Python

:: Find FFmpeg - simplified
set "FFMPEG_PATH="
if exist "C:\ffmpeg\bin\ffmpeg.exe" (
  set "FFMPEG_PATH=C:\ffmpeg\bin"
  echo [FOUND] FFmpeg at: C:\ffmpeg\bin
)
if not defined FFMPEG_PATH echo [NOT FOUND] FFmpeg

:: Check if anything was found
if not defined NODEJS_PATH if not defined PYTHON_PATH if not defined FFMPEG_PATH (
  echo.
  echo ERROR: No programs found to add to PATH
  echo Please run the one-click installer first
  echo.
  pause
  goto :end
)

echo.
echo Adding to PATH...
echo.

:: Add Node.js to PATH
if defined NODEJS_PATH (
  echo Adding Node.js to PATH...
  if "%USE_SYSTEM%"=="1" (
    setx PATH "%PATH%;%NODEJS_PATH%" /M
    echo Node.js added to system PATH
  ) else (
    setx PATH "%PATH%;%NODEJS_PATH%"
    echo Node.js added to user PATH
  )
)

:: Add Python to PATH
if defined PYTHON_PATH (
  echo Adding Python to PATH...
  if "%USE_SYSTEM%"=="1" (
    setx PATH "%PATH%;%PYTHON_PATH%;%PYTHON_PATH%\Scripts" /M
    echo Python added to system PATH
  ) else (
    setx PATH "%PATH%;%PYTHON_PATH%;%PYTHON_PATH%\Scripts"
    echo Python added to user PATH
  )
)

:: Add FFmpeg to PATH
if defined FFMPEG_PATH (
  echo Adding FFmpeg to PATH...
  if "%USE_SYSTEM%"=="1" (
    setx PATH "%PATH%;%FFMPEG_PATH%" /M
    echo FFmpeg added to system PATH
  ) else (
    setx PATH "%PATH%;%FFMPEG_PATH%"
    echo FFmpeg added to user PATH
  )
)

echo.
echo ================================================================
echo                    COMPLETED!
echo ================================================================
echo.
echo IMPORTANT: Close ALL command windows and open a NEW one
echo.
echo Then test these commands:
if defined NODEJS_PATH echo   node --version
if defined PYTHON_PATH echo   python --version
if defined FFMPEG_PATH echo   ffmpeg -version
echo.
echo If still not working, restart your computer.
echo ================================================================

:end
echo.
echo Press any key to close...
pause >nul