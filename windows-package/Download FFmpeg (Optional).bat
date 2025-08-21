@echo off
title Download FFmpeg (Optional)
echo ========================================
echo    FFmpeg Downloader (Optional)
echo ========================================
echo.
echo FFmpeg enables video thumbnail generation.
echo This is optional but recommended.
echo.
echo Download size: ~100MB
echo.
set /p confirm="Do you want to download FFmpeg? (y/n): "
if /i "%confirm%" neq "y" exit /b

echo.
echo Downloading FFmpeg...
powershell -Command "Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile 'ffmpeg.zip'"

echo Extracting FFmpeg...
powershell -Command "Expand-Archive -Path 'ffmpeg.zip' -DestinationPath '.'"

echo Setting up FFmpeg...
for /d %%i in (ffmpeg-*-essentials_build) do (
    move "%%i\bin\ffmpeg.exe" "app\"
    move "%%i\bin\ffprobe.exe" "app\"
    rmdir /s /q "%%i"
)

del ffmpeg.zip

echo.
echo FFmpeg installed successfully!
echo.
pause