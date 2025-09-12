@echo off
title Quick FFmpeg Fix

echo ========================================
echo        Quick FFmpeg PATH Fix
echo ========================================
echo.

REM Check if FFmpeg exists in common locations
if exist "C:\ffmpeg\bin\ffmpeg.exe" (
    echo [FOUND] FFmpeg at: C:\ffmpeg\bin\ffmpeg.exe
    set "FFMPEG_BIN=C:\ffmpeg\bin"
    goto fix_path
)

if exist "C:\Program Files\ffmpeg\bin\ffmpeg.exe" (
    echo [FOUND] FFmpeg at: C:\Program Files\ffmpeg\bin\ffmpeg.exe
    set "FFMPEG_BIN=C:\Program Files\ffmpeg\bin"
    goto fix_path
)

REM Search in WinGet installation directory
for /d %%i in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg*") do (
    for /d %%j in ("%%i\ffmpeg-*\bin") do (
        if exist "%%j\ffmpeg.exe" (
            echo [FOUND] FFmpeg at: %%j\ffmpeg.exe
            set "FFMPEG_BIN=%%j"
            goto fix_path
        )
    )
)

echo [ERROR] FFmpeg not found!
echo Please run one of the installation scripts first.
pause
exit /b

:fix_path
echo [FIXING] Setting up FFmpeg for current session...

REM Add to current session PATH
set "PATH=%PATH%;%FFMPEG_BIN%"

REM Test if it works now
"%FFMPEG_BIN%\ffmpeg.exe" -version >nul 2>&1
if not errorlevel 1 (
    echo [SUCCESS] FFmpeg is now working!
    echo.
    echo Testing FFmpeg:
    "%FFMPEG_BIN%\ffmpeg.exe" -version | findstr "ffmpeg version"
    echo.
    echo [IMPORTANT] This fix is temporary for this command window only.
    echo To make it permanent, run: Fix_FFmpeg_PATH.bat (as administrator)
) else (
    echo [ERROR] FFmpeg still not working properly.
)

echo.
echo FFmpeg location: %FFMPEG_BIN%
echo Current PATH includes FFmpeg for this session.
echo.
pause