@echo off
echo ========================================
echo  Media File Explorer - Windows Installer
echo ========================================
echo.

:: Node.js 확인
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed!
    echo Please download and install Node.js from:
    echo https://nodejs.org/
    pause
    exit /b 1
)

echo [1/4] Installing dependencies...
call npm install

echo.
echo [2/4] Creating shortcuts...

:: 바탕화면 바로가기 생성
powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\Media File Explorer.lnk'); $Shortcut.TargetPath = '%CD%\start.bat'; $Shortcut.IconLocation = '%CD%\icon.ico'; $Shortcut.Save()"

echo [3/4] Checking for FFmpeg (for video thumbnails)...
where ffmpeg >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [WARNING] FFmpeg not found!
    echo Video thumbnails will not be available.
    echo.
    echo To enable video thumbnails, install FFmpeg:
    echo 1. Download from: https://ffmpeg.org/download.html
    echo 2. Extract and add to PATH
    echo.
)

echo [4/4] Installation complete!
echo.
echo ========================================
echo  Installation successful!
echo ========================================
echo.
echo Double-click "start.bat" or the desktop shortcut to run
echo.
pause
