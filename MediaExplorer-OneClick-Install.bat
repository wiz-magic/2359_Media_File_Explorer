@echo off
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
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [OK] Administrator access granted
echo.

:: Create installation directory
set "INSTALL_DIR=%~dp0runtime"
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: Download and install Node.js
echo [1/4] Installing Node.js...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo   Downloading Node.js...
    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.17.0/node-v20.17.0-x64.msi' -OutFile '%INSTALL_DIR%\node.msi'}"
    
    echo   Installing Node.js...
    msiexec /i "%INSTALL_DIR%\node.msi" /quiet /norestart
    
    echo   Waiting for installation to complete...
    timeout /t 10 /nobreak >nul
    
    :: Refresh PATH
    call refreshenv.cmd >nul 2>&1
    set "PATH=%PATH%;C:\Program Files\nodejs"
) else (
    echo   Node.js already installed
)

:: Download and install Python
echo [2/4] Installing Python...
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo   Downloading Python...
    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.0/python-3.11.0-amd64.exe' -OutFile '%INSTALL_DIR%\python.exe'}"
    
    echo   Installing Python...
    "%INSTALL_DIR%\python.exe" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    
    echo   Waiting for installation to complete...
    timeout /t 15 /nobreak >nul
    
    :: Refresh PATH
    set "PATH=%PATH%;C:\Program Files\Python311;C:\Program Files\Python311\Scripts"
) else (
    echo   Python already installed
)

:: Download and install FFmpeg
echo [3/4] Installing FFmpeg...
if not exist "C:\ffmpeg\bin\ffmpeg.exe" (
    echo   Downloading FFmpeg...
    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/packages/release/ffmpeg-7.0.2-essentials_build.zip' -OutFile '%INSTALL_DIR%\ffmpeg.zip'}"
    
    echo   Extracting FFmpeg...
    powershell -Command "Expand-Archive -Path '%INSTALL_DIR%\ffmpeg.zip' -DestinationPath '%INSTALL_DIR%' -Force"
    
    :: Move to C:\ffmpeg
    if not exist "C:\ffmpeg" mkdir "C:\ffmpeg"
    for /d %%i in ("%INSTALL_DIR%\ffmpeg-*") do (
        xcopy "%%i\*" "C:\ffmpeg\" /E /I /Y >nul
    )
    
    :: Add to PATH permanently (improved error handling)
    echo   Configuring FFmpeg PATH...
    for /f "tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "CURRENT_PATH=%%j"
    if defined CURRENT_PATH (
        echo %CURRENT_PATH% | find /i "C:\ffmpeg\bin" >nul
        if errorlevel 1 (
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH /t REG_EXPAND_SZ /d "%CURRENT_PATH%;C:\ffmpeg\bin" /f >nul 2>&1
        )
    )
    
    :: Also add to user PATH for immediate availability  
    reg query "HKCU\Environment" /v PATH >nul 2>&1
    if errorlevel 1 (
        reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "C:\ffmpeg\bin" /f >nul 2>&1
    ) else (
        for /f "tokens=2*" %%i in ('reg query "HKCU\Environment" /v PATH 2^>nul') do (
            if defined %%j (
                echo %%j | find /i "C:\ffmpeg\bin" >nul || (
                    reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%%j;C:\ffmpeg\bin" /f >nul 2>&1
                )
            )
        )
    )
    
    :: Set for current session
    set "PATH=%PATH%;C:\ffmpeg\bin"
    
    :: Test FFmpeg installation
    echo   Testing FFmpeg...
    "C:\ffmpeg\bin\ffmpeg.exe" -version >nul 2>&1
    if not errorlevel 1 (
        echo   [SUCCESS] FFmpeg is working!
    ) else (
        echo   [INFO] FFmpeg installed - may need terminal restart to work from command line
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

:: Verify installation
echo.
echo Verifying installation...
node --version >nul 2>&1 && echo   [OK] Node.js ready || echo   [!] Node.js may need new terminal
python --version >nul 2>&1 && echo   [OK] Python ready || echo   [!] Python may need new terminal  
if exist "C:\ffmpeg\bin\ffmpeg.exe" echo   [OK] FFmpeg installed
if exist "node_modules" echo   [OK] Dependencies installed

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