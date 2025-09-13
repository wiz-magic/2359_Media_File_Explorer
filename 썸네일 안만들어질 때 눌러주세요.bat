@echo off
title FFmpeg Fix Tool - Thumbnail Generation

echo ================================================================
echo           FFmpeg Fix Tool for Thumbnail Generation
echo ================================================================
echo.
echo This tool will fix FFmpeg configuration issues.
echo.

:: Set paths
set "BASE=%~dp0"
set "RUNTIME=%BASE%runtime"

:: Test basic functionality
echo Checking basic setup...
echo - Script location: %BASE%
echo - Runtime folder: %RUNTIME%
echo.

:: Check if runtime exists
if not exist "%RUNTIME%" (
    echo [ERROR] Runtime folder not found!
    echo Make sure you are running this from the deployed version.
    echo.
    pause
    goto :end
)

echo [OK] Runtime folder found.
echo.

:: Look for FFmpeg
echo Searching for FFmpeg...
set "FFMPEG_PATH="

:: Check different possible locations
if exist "%RUNTIME%\ffmpeg\bin\ffmpeg.exe" (
    set "FFMPEG_PATH=%RUNTIME%\ffmpeg\bin"
    echo [FOUND] FFmpeg at: %FFMPEG_PATH%
    goto :setup_path
)

if exist "%RUNTIME%\ffmpeg.exe" (
    set "FFMPEG_PATH=%RUNTIME%"
    echo [FOUND] FFmpeg at: %FFMPEG_PATH%
    goto :setup_path
)

:: Search in ffmpeg* folders
for /d %%D in ("%RUNTIME%\ffmpeg*") do (
    if exist "%%D\bin\ffmpeg.exe" (
        set "FFMPEG_PATH=%%D\bin"
        echo [FOUND] FFmpeg at: %%D\bin
        goto :setup_path
    )
)

echo [ERROR] FFmpeg not found in runtime folder!
echo.
echo Please make sure FFmpeg is included in the deployment package.
echo Expected locations:
echo - runtime\ffmpeg\bin\ffmpeg.exe
echo - runtime\ffmpeg.exe
echo.
pause
goto :end

:setup_path
echo.
echo Setting up FFmpeg in PATH...

:: Test if already working
ffmpeg -version >nul 2>&1
if "%ERRORLEVEL%"=="0" (
    echo [OK] FFmpeg is already working!
    ffmpeg -version | findstr "ffmpeg version"
    echo.
    echo Your FFmpeg is properly configured.
    echo If thumbnails still don't work, the issue might be elsewhere.
    pause
    goto :end
)

:: Add to current session PATH
set "PATH=%PATH%;%FFMPEG_PATH%"
echo [INFO] Added to current session PATH.

:: Add to user PATH permanently
echo [INFO] Adding to user PATH permanently...

reg query "HKCU\Environment" /v PATH >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    :: No PATH exists, create it
    reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%FFMPEG_PATH%" /f >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [OK] User PATH created and FFmpeg added.
    ) else (
        echo [WARN] Failed to create user PATH.
    )
) else (
    :: PATH exists, check and append
    for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul ^| find "REG_"') do set "CURRENT_PATH=%%b"
    
    echo !CURRENT_PATH! | find /i "%FFMPEG_PATH%" >nul
    if %ERRORLEVEL% EQU 0 (
        echo [OK] FFmpeg path already in user PATH.
    ) else (
        reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "!CURRENT_PATH!;%FFMPEG_PATH%" /f >nul 2>&1
        if %ERRORLEVEL% EQU 0 (
            echo [OK] FFmpeg added to user PATH.
        ) else (
            echo [WARN] Failed to update user PATH.
        )
    )
)

echo.
echo Testing FFmpeg after setup...
timeout /t 2 /nobreak >nul

ffmpeg -version >nul 2>&1
if "%ERRORLEVEL%"=="0" (
    echo [SUCCESS] FFmpeg is now working!
    ffmpeg -version | findstr "ffmpeg version"
    echo.
    echo ================================================================
    echo                       SUCCESS!
    echo ================================================================
    echo FFmpeg has been properly configured.
    echo Thumbnail generation should now work.
    echo.
    echo If problems persist:
    echo 1. Restart your browser/application
    echo 2. Try opening a new command prompt
    echo 3. Restart your computer if needed
) else (
    echo [ERROR] FFmpeg still not working after setup.
    echo.
    echo Try these solutions:
    echo 1. Run this script as Administrator
    echo 2. Restart your computer
    echo 3. Check Windows PATH manually:
    echo    - Right-click This PC ^> Properties
    echo    - Advanced System Settings ^> Environment Variables
    echo    - Add FFmpeg path to PATH variable
)

echo.
echo ================================================================
pause

:end