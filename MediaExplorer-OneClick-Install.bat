@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Media Explorer - One Click Install and Run
cls

echo ================================================================
echo            Media File Explorer - One Click Setup
echo ================================================================
echo.
echo This will automatically:
echo  1. Install Node.js (if needed)
echo  2. Install Python (if needed) 
echo  3. Install FFmpeg (if needed)
echo  4. Install all dependencies
echo  5. Start the application on localhost
echo.
echo Just wait and it will open in your browser automatically!
echo.
pause

:: Check if already installed marker exists
if exist "%~dp0\.installed" (
    echo Previous installation found. Starting application...
    goto start_app
)

:: Request admin privileges
echo Requesting administrator privileges...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This requires administrator access to install software.
    echo A UAC elevation window will appear. Please accept it.
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList 'elevated' -Verb RunAs -Wait"
    echo.
    echo Installation finished. Press any key to close this window...
    pause >nul
    exit /b
)
if /i "%1"=="elevated" shift

echo [OK] Administrator access granted
echo.

:: Create installation directory
set "INSTALL_DIR=%~dp0runtime"
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: Download and install Node.js (nvm-windows + Node v20.18.0)
echo [1/4] Installing Node.js (nvm-windows + Node v20.18.0)...
where node >nul 2>&1
if %errorlevel% neq 0 (
    where winget >nul 2>&1
    if %errorlevel%==0 (
        echo   Installing nvm-windows via winget...
        winget install CoreyButler.NVM-Windows --silent --accept-package-agreements --accept-source-agreements
    ) else (
        echo   winget not found. Will use Node MSI fallback if nvm is unavailable.
    )

    rem Load NVM environment to current session
    for /f "tokens=2,*" %%A in ('reg query "HKCU\Environment" /v NVM_HOME 2^>nul ^| find "NVM_HOME"') do set "NVM_HOME=%%B"
    if not defined NVM_HOME for /f "tokens=2,*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v NVM_HOME 2^>nul ^| find "NVM_HOME"') do set "NVM_HOME=%%B"
    for /f "tokens=2,*" %%A in ('reg query "HKCU\Environment" /v NVM_SYMLINK 2^>nul ^| find "NVM_SYMLINK"') do set "NVM_SYMLINK=%%B"
    if not defined NVM_SYMLINK for /f "tokens=2,*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v NVM_SYMLINK 2^>nul ^| find "NVM_SYMLINK"') do set "NVM_SYMLINK=%%B"

    if defined NVM_HOME set "PATH=%NVM_HOME%;%PATH%"
    if defined NVM_SYMLINK set "PATH=%NVM_SYMLINK%;%PATH%"

    if defined NVM_HOME (
        echo   Installing Node 20.18.0 via nvm...
        "%NVM_HOME%\nvm.exe" install 20.18.0
        "%NVM_HOME%\nvm.exe" use 20.18.0
    ) else (
        echo   nvm unavailable, falling back to Node MSI installer...
        powershell -NoProfile -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi' -OutFile '%INSTALL_DIR%\node.msi'}"
        msiexec /i "%INSTALL_DIR%\node.msi" /quiet /norestart
        set "PATH=%PATH%;C:\Program Files\nodejs"
    )
) else (
    echo   Node.js already installed
)

:: Download and install Python
echo [2/4] Installing Python...
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo   Downloading Python...
    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe' -OutFile '%INSTALL_DIR%\python.exe'}"
    
    echo   Installing Python...
    "%INSTALL_DIR%\python.exe" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    
    echo   Waiting for installation to complete...
    timeout /t 15 /nobreak >nul
    
    :: Refresh PATH
    set "PATH=%PATH%;C:\Program Files\Python312;C:\Program Files\Python312\Scripts"
) else (
    echo   Python already installed
)

:: Download and install FFmpeg
echo [3/4] Installing FFmpeg...
where ffmpeg >nul 2>&1
if %errorlevel% neq 0 (
    where winget >nul 2>&1
    if %errorlevel%==0 (
        echo   Installing FFmpeg via winget...
        winget install Gyan.FFmpeg --silent --accept-package-agreements --accept-source-agreements
    ) else (
        echo   winget not found. Using zip fallback.
    )

    where ffmpeg >nul 2>&1
    if %errorlevel% neq 0 (
        echo   Downloading FFmpeg (zip fallback)...
        powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip' -OutFile '%INSTALL_DIR%\ffmpeg.zip' } catch { Write-Host 'FFmpeg download failed' }}"
        if exist "%INSTALL_DIR%\ffmpeg.zip" (
            echo   Extracting FFmpeg...
            powershell -Command "Expand-Archive -Path '%INSTALL_DIR%\ffmpeg.zip' -DestinationPath '%INSTALL_DIR%' -Force"
            if not exist "C:\ffmpeg" mkdir "C:\ffmpeg"
            for /d %%i in ("%INSTALL_DIR%\ffmpeg-*") do (
                xcopy "%%i\*" "C:\ffmpeg\" /E /I /Y >nul
            )
            for /f "tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH') do set "CURRENT_PATH=%%j"
            echo %CURRENT_PATH% | find "C:\ffmpeg\bin" >nul
            if errorlevel 1 (
                reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH /t REG_EXPAND_SZ /d "%CURRENT_PATH%;C:\ffmpeg\bin" /f >nul
            )
            set "PATH=%PATH%;C:\ffmpeg\bin"
        ) else (
            echo   FFmpeg download failed, skipping...
        )
    ) else (
        echo   FFmpeg installed successfully via winget
    )
) else (
    echo   FFmpeg already installed
)

:: Install project dependencies
echo [4/4] Installing project dependencies...
cd /d "%~dp0"
if not exist "node_modules" (
    echo   Installing npm packages...
    call npm install
)

:: Verification
echo.
echo Verification - Installed versions:
for /f "usebackq tokens=*" %%i in (`python --version 2^>^&1`) do echo   Python: %%i
for /f "usebackq tokens=*" %%i in (`node -v 2^>^&1`) do echo   Node.js: %%i
for /f "usebackq tokens=*" %%i in (`ffmpeg -version 2^>^&1`) do ( echo   FFmpeg: %%i & goto :ffmpeg_done )
:ffmpeg_done

:: Mark as installed
echo Installation completed successfully > "%~dp0\.installed"

:start_app
echo.
echo ================================================================
echo                 Starting Media File Explorer
echo ================================================================
echo.

:: Kill any existing processes
taskkill /F /IM node.exe >nul 2>&1

:: Start the application
echo Starting server...
start /B npm start

:: Wait for server to start
echo Waiting for server to start...
timeout /t 5 /nobreak >nul

:: Open browser
echo Opening browser...
start http://localhost:3000

echo.
echo ================================================================
echo     Media File Explorer is now running!
echo     
echo     Browser should open automatically to:
echo     http://localhost:3000
echo     
echo     Close this window to stop the application.
echo ================================================================
echo.

:: Keep the window open and monitor
:monitor
timeout /t 5 /nobreak >nul
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe" >nul
if "%ERRORLEVEL%"=="0" (
    goto monitor
) else (
    echo Server stopped. Restarting...
    start /B npm start
    timeout /t 3 /nobreak >nul
    goto monitor
)

pause