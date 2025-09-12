@echo off
title FFmpeg PATH Fix

echo ================================================================
echo                FFmpeg PATH Configuration Fix
echo ================================================================
echo.
echo This script will fix FFmpeg PATH issues after installation.
echo.

REM Request admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Administrator privileges required for PATH modification...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [ADMIN] Running with administrator privileges.
echo.

echo [STEP 1] Checking FFmpeg installation locations...

REM Check common FFmpeg installation paths
set "FFMPEG_PATH="
if exist "C:\ffmpeg\bin\ffmpeg.exe" (
    set "FFMPEG_PATH=C:\ffmpeg\bin"
    echo [FOUND] FFmpeg found at: C:\ffmpeg\bin\ffmpeg.exe
) else if exist "C:\Program Files\ffmpeg\bin\ffmpeg.exe" (
    set "FFMPEG_PATH=C:\Program Files\ffmpeg\bin"
    echo [FOUND] FFmpeg found at: C:\Program Files\ffmpeg\bin\ffmpeg.exe
) else if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg*\ffmpeg-*\bin\ffmpeg.exe" (
    for /d %%i in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg*") do (
        for /d %%j in ("%%i\ffmpeg-*\bin") do (
            if exist "%%j\ffmpeg.exe" (
                set "FFMPEG_PATH=%%j"
                echo [FOUND] FFmpeg found at: %%j\ffmpeg.exe
                goto found_ffmpeg
            )
        )
    )
) else (
    echo [NOT FOUND] FFmpeg not found in standard locations.
    echo.
    echo Searching entire system for ffmpeg.exe...
    
    REM Search for ffmpeg.exe on C: drive
    for /f "tokens=*" %%i in ('dir C:\ffmpeg.exe /s /b 2^>nul ^| findstr /i bin') do (
        set "FFMPEG_PATH=%%~dpi"
        echo [FOUND] FFmpeg found at: %%i
        goto found_ffmpeg
    )
    
    echo [ERROR] FFmpeg not found on this system.
    echo Please install FFmpeg first using one of the installation scripts.
    pause
    exit /b 1
)

:found_ffmpeg
if "%FFMPEG_PATH%"=="" (
    echo [ERROR] Could not determine FFmpeg path.
    pause
    exit /b 1
)

REM Remove trailing backslash if present
if "%FFMPEG_PATH:~-1%"=="\" set "FFMPEG_PATH=%FFMPEG_PATH:~0,-1%"

echo.
echo [STEP 2] Checking current PATH configuration...

REM Check if FFmpeg is already in system PATH
for /f "tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do (
    echo %%j | findstr /i /c:"%FFMPEG_PATH%" >nul
    if not errorlevel 1 (
        echo [OK] FFmpeg path already in system PATH: %FFMPEG_PATH%
        goto check_user_path
    )
)

echo [FIXING] Adding FFmpeg to system PATH...
for /f "tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH') do (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH /t REG_EXPAND_SZ /d "%%j;%FFMPEG_PATH%" /f >nul
    if not errorlevel 1 (
        echo [SUCCESS] Added to system PATH: %FFMPEG_PATH%
    ) else (
        echo [ERROR] Failed to add to system PATH.
    )
)

:check_user_path
REM Also add to user PATH as backup
echo [STEP 3] Checking user PATH configuration...
for /f "tokens=2*" %%i in ('reg query "HKCU\Environment" /v PATH 2^>nul') do (
    echo %%j | findstr /i /c:"%FFMPEG_PATH%" >nul
    if not errorlevel 1 (
        echo [OK] FFmpeg path already in user PATH: %FFMPEG_PATH%
        goto test_ffmpeg
    )
)

echo [FIXING] Adding FFmpeg to user PATH...
reg query "HKCU\Environment" /v PATH >nul 2>&1
if errorlevel 1 (
    REM PATH doesn't exist for user, create it
    reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%FFMPEG_PATH%" /f >nul
) else (
    REM PATH exists, append to it
    for /f "tokens=2*" %%i in ('reg query "HKCU\Environment" /v PATH') do (
        reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%%j;%FFMPEG_PATH%" /f >nul
    )
)

if not errorlevel 1 (
    echo [SUCCESS] Added to user PATH: %FFMPEG_PATH%
) else (
    echo [ERROR] Failed to add to user PATH.
)

:test_ffmpeg
echo.
echo [STEP 4] Broadcasting PATH changes...
REM Broadcast WM_SETTINGCHANGE to notify all applications of environment change
powershell -Command "[Environment]::SetEnvironmentVariable('TEMP_REFRESH', [Environment]::GetEnvironmentVariable('TEMP_REFRESH', 'User'), 'User')" >nul 2>&1

echo.
echo [STEP 5] Testing FFmpeg access...

REM Test FFmpeg in new process (simulates new terminal)
powershell -Command "& { $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User'); ffmpeg -version }" >nul 2>&1
if not errorlevel 1 (
    echo [SUCCESS] FFmpeg is now accessible!
    echo.
    powershell -Command "& { $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User'); ffmpeg -version | Select-Object -First 1 }"
) else (
    echo [WARNING] FFmpeg may still not be accessible.
    echo You may need to restart your computer or log out and log back in.
)

echo.
echo ================================================================
echo                      Fix Complete!
echo ================================================================
echo.
echo Actions taken:
echo 1. Found FFmpeg at: %FFMPEG_PATH%
echo 2. Added to system PATH registry
echo 3. Added to user PATH registry  
echo 4. Broadcasted environment changes
echo.
echo IMPORTANT: To use FFmpeg immediately:
echo 1. Close ALL command prompt/PowerShell windows
echo 2. Open a NEW command prompt/PowerShell window
echo 3. Test with: ffmpeg -version
echo.
echo If it still doesn't work, restart your computer.
echo.
pause