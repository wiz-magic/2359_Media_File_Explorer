@echo off
title Media File Explorer - Windows Starter
cls

echo.
echo ================================================================
echo          Media File Explorer - Windows Quick Start
echo ================================================================
echo.
echo Welcome! This will help you create a standalone Windows EXE file.
echo.
echo What you'll get:
echo   * Installer EXE (like normal Windows software)  
echo   * Portable EXE (runs from USB, no installation)
echo   * No Python required for end users!
echo.
echo ================================================================
echo                    CHOOSE YOUR METHOD
echo ================================================================
echo.
echo [1] SIMPLE BUILD (Recommended)
echo     File: build-electron-simple.bat
echo     - Easy to understand
echo     - Step-by-step progress
echo     - Better error messages
echo.
echo [2] ADVANCED BUILD  
echo     File: build-electron-auto.bat
echo     - More features
echo     - Automatic everything
echo     - For experienced users
echo.
echo [3] DIAGNOSTIC MODE
echo     File: check-nodejs.bat  
echo     - Check system status
echo     - Troubleshoot problems
echo     - Get detailed info
echo.
echo ================================================================
echo.

:choice
set /p choice=Enter your choice (1, 2, or 3): 

if "%choice%"=="1" (
    echo.
    echo Starting SIMPLE BUILD...
    echo Press any key when ready...
    pause >nul
    call build-electron-simple.bat
    goto end
)

if "%choice%"=="2" (
    echo.
    echo Starting ADVANCED BUILD...  
    echo Press any key when ready...
    pause >nul
    call build-electron-auto.bat
    goto end
)

if "%choice%"=="3" (
    echo.
    echo Starting DIAGNOSTIC MODE...
    echo Press any key when ready...
    pause >nul
    call check-nodejs.bat
    goto end
)

echo Invalid choice. Please enter 1, 2, or 3.
echo.
goto choice

:end
echo.
echo ================================================================
echo Thanks for using Media File Explorer!
echo ================================================================
pause