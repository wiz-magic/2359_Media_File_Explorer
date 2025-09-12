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
    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip' -OutFile '%INSTALL_DIR%\ffmpeg.zip' } catch { Write-Host 'FFmpeg download failed' }}"
    
    if exist "%INSTALL_DIR%\ffmpeg.zip" (
        echo   Extracting FFmpeg...
        powershell -Command "Expand-Archive -Path '%INSTALL_DIR%\ffmpeg.zip' -DestinationPath '%INSTALL_DIR%' -Force"
        
        :: Move to C:\ffmpeg
        if not exist "C:\ffmpeg" mkdir "C:\ffmpeg"
        for /d %%i in ("%INSTALL_DIR%\ffmpeg-*") do (
            xcopy "%%i\*" "C:\ffmpeg\" /E /I /Y >nul
        )
        
        :: Configure FFmpeg PATH properly
        echo   Configuring FFmpeg PATH...
        
        :: Add to system PATH permanently
        for /f "skip=2 tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do (
            echo %%j | find /i "C:\ffmpeg\bin" >nul || (
                reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH /t REG_EXPAND_SZ /d "%%j;C:\ffmpeg\bin" /f >nul 2>&1
            )
        )
        
        :: Add to user PATH as well for immediate availability
        reg query "HKCU\Environment" /v PATH >nul 2>&1
        if errorlevel 1 (
            reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "C:\ffmpeg\bin" /f >nul 2>&1
        ) else (
            for /f "skip=2 tokens=2*" %%i in ('reg query "HKCU\Environment" /v PATH') do (
                echo %%j | find /i "C:\ffmpeg\bin" >nul || (
                    reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%%j;C:\ffmpeg\bin" /f >nul 2>&1
                )
            )
        )
        
        :: Update current session PATH immediately
        set "PATH=%PATH%;C:\ffmpeg\bin"
        
        :: Force environment refresh using multiple methods
        echo   Refreshing environment variables...
        setx FFMPEG_REFRESH "1" >nul 2>&1
        setx FFMPEG_REFRESH "" >nul 2>&1
        
        :: Test FFmpeg immediately
        echo   Testing FFmpeg installation...
        "C:\ffmpeg\bin\ffmpeg.exe" -version >nul 2>&1
        if not errorlevel 1 (
            echo   [SUCCESS] FFmpeg is working correctly!
        ) else (
            echo   [WARNING] FFmpeg may need system restart to work properly
        )
    ) else (
        echo   FFmpeg download failed, skipping...
    )
) else (
    echo   FFmpeg already installed
)

:: Final environment refresh before npm install
echo [4/4] Installing project dependencies...
cd /d "%~dp0"

:: Update PATH for current session from registry
echo   Refreshing PATH from registry...
for /f "skip=2 tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "SYSTEM_PATH=%%j"
for /f "skip=2 tokens=2*" %%i in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%j"
if defined USER_PATH (
    set "PATH=%SYSTEM_PATH%;%USER_PATH%"
) else (
    set "PATH=%SYSTEM_PATH%;C:\ffmpeg\bin"
)

:: Install npm packages
if not exist "node_modules" (
    echo   Installing npm packages...
    call npm install
)

:: Final verification with detailed status
echo.
echo ================================================================
echo                   Installation Verification
echo ================================================================
echo.

:: Test Node.js
echo Testing Node.js...
node --version >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=*" %%i in ('node --version') do echo   [✓] Node.js %%i - Ready
) else (
    echo   [!] Node.js - May need new terminal to work
)

:: Test Python  
echo Testing Python...
python --version >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=*" %%i in ('python --version') do echo   [✓] Python %%i - Ready
) else (
    echo   [!] Python - May need new terminal to work
)

:: Test FFmpeg with direct path and PATH
echo Testing FFmpeg...
"C:\ffmpeg\bin\ffmpeg.exe" -version >nul 2>&1
if not errorlevel 1 (
    echo   [✓] FFmpeg - Ready (Direct Path)
    ffmpeg -version >nul 2>&1
    if not errorlevel 1 (
        echo   [✓] FFmpeg - Ready (PATH)
    ) else (
        echo   [!] FFmpeg - Working but PATH may need restart
    )
) else (
    echo   [✗] FFmpeg - Installation may have failed
)

echo.
echo [INFO] If any component shows warnings, restart your computer
echo       and the components will work in new terminals.

:: Mark as installed
echo Installation completed successfully > "%~dp0\.installed"

:start_app
echo.
echo ================================================================
echo                 Starting Media File Explorer
echo ================================================================
echo.

:: Quick FFmpeg availability check before starting
if exist "C:\ffmpeg\bin\ffmpeg.exe" (
    echo FFmpeg Status: Available
) else (
    echo FFmpeg Status: Not found - Video features may be limited
)

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