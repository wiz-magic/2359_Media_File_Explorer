@echo off
title Media Explorer - Simple Build
cls

echo ================================================================
echo     Media File Explorer - Simple Auto Builder
echo ================================================================
echo.
echo This will create a standalone Windows EXE file
echo No Python installation required for end users!
echo.
echo What this script does:
echo   [1] Check Node.js installation
echo   [2] Auto install Node.js if needed  
echo   [3] Install required packages
echo   [4] Build standalone EXE files
echo.
echo Generated files will be in: electron\dist\
echo   - Setup.exe (installer version)
echo   - Portable.exe (portable version)
echo.
pause

:: Check administrator privileges
echo.
echo [Step 1] Checking administrator privileges...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Administrator privileges required!
    echo.
    echo How to fix:
    echo   1. Right-click this file
    echo   2. Select "Run as administrator" 
    echo   3. Click "Yes" when Windows asks
    echo.
    pause
    exit /b 1
)
echo [OK] Administrator access confirmed

:: Check Node.js
echo.
echo [Step 2] Checking Node.js installation...
node --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('node --version 2^>nul') do (
        echo [OK] Node.js found: %%i
        goto nodejs_ready
    )
)

echo [INFO] Node.js not found, installing automatically...
echo.

:: Create temp directory
set "TEMP_DIR=%TEMP%\media-explorer-build"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

:: Download Node.js
echo    Downloading Node.js v20.17.0... (about 30MB)
set "NODE_URL=https://nodejs.org/dist/v20.17.0/node-v20.17.0-x64.msi"
set "NODE_INSTALLER=%TEMP_DIR%\nodejs-installer.msi"

powershell -Command "(New-Object System.Net.WebClient).DownloadFile('%NODE_URL%', '%NODE_INSTALLER%')" 2>nul

if not exist "%NODE_INSTALLER%" (
    echo [ERROR] Failed to download Node.js!
    echo         Please check your internet connection
    pause
    exit /b 1
)

echo    Installing Node.js...
msiexec /i "%NODE_INSTALLER%" /quiet /norestart

:: Refresh PATH
echo    Refreshing environment variables...
for /f "tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH') do set "SYSTEM_PATH=%%j"
for /f "tokens=2*" %%i in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%j"
set "PATH=%SYSTEM_PATH%;%USER_PATH%"

:: Wait and verify installation
timeout /t 5 /nobreak >nul
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js installation failed!
    echo         Please restart computer and try again
    pause
    exit /b 1
)

echo [OK] Node.js installed successfully!

:nodejs_ready

:: Show versions
for /f "tokens=*" %%i in ('node --version 2^>nul') do set "NODE_VER=%%i"
for /f "tokens=*" %%i in ('npm --version 2^>nul') do set "NPM_VER=%%i"
echo    Node.js: %NODE_VER%
echo    npm: v%NPM_VER%

:: Check project structure
echo.
echo [Step 3] Checking project structure...
if not exist "electron" (
    echo [ERROR] 'electron' folder not found!
    echo         Make sure you're running this in the correct directory
    pause
    exit /b 1
)
echo [OK] Project structure verified

:: Move to electron directory
cd electron
if %errorlevel% neq 0 (
    echo [ERROR] Cannot access electron directory!
    pause
    exit /b 1
)

if not exist "package.json" (
    echo [ERROR] electron/package.json not found!
    echo         Project structure may be corrupted
    pause
    exit /b 1
)

:: Install packages
echo.
echo [Step 4] Installing required packages...
echo          This may take 5-10 minutes on first run...

call npm install >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] npm install failed!
    echo.
    echo Common solutions:
    echo   1. Check internet connection
    echo   2. Clear npm cache: npm cache clean --force
    echo   3. Try again
    pause
    exit /b 1
)
echo [OK] Packages installed successfully

:: Build application
echo.
echo [Step 5] Building Electron application...
echo          This may take 3-5 minutes...

set "CSC_IDENTITY_AUTO_DISCOVERY=false"
call npm run build-win >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Build failed!
    echo.
    echo Common causes:
    echo   1. Insufficient disk space (need 2GB+)
    echo   2. Antivirus interference
    echo   3. Permission issues
    echo.
    echo Try:
    echo   - Temporarily disable antivirus
    echo   - Free up disk space
    echo   - Run as administrator
    pause
    exit /b 1
)

:: Check results
echo.
echo [Step 6] Checking build results...

set "SETUP_FILE=dist\Media File Explorer Setup 1.0.0.exe"
set "PORTABLE_FILE=dist\MediaExplorer-Portable-1.0.0.exe"

if exist "%SETUP_FILE%" (
    echo.
    echo ================================================================
    echo                   BUILD SUCCESSFUL!
    echo ================================================================
    echo.
    echo Generated files:
    echo.
    
    for %%F in ("%SETUP_FILE%") do (
        set /a size=%%~zF/1048576
        echo    [1] Installer: %%~nxF
        echo        Size: !size! MB
        echo        Path: %cd%\%%~nxF
    )
    
    if exist "%PORTABLE_FILE%" (
        echo.
        for %%F in ("%PORTABLE_FILE%") do (
            set /a size=%%~zF/1048576
            echo    [2] Portable: %%~nxF
            echo        Size: !size! MB  
            echo        Path: %cd%\%%~nxF
        )
    )
    
    echo.
    echo ================================================================
    echo.
    echo SUCCESS! You can now distribute these EXE files.
    echo End users don't need Python or Node.js installed!
    echo.
    echo Usage:
    echo   - Installer: Install like normal Windows software
    echo   - Portable: Run directly from USB or any folder
    echo.
    echo ================================================================
    
    echo.
    set /p OPEN_FOLDER=Open the folder with generated files? (Y/N): 
    if /i "%OPEN_FOLDER%"=="Y" (
        explorer "%cd%\dist"
    )
) else (
    echo [ERROR] Build files not found!
    echo         Check electron\dist folder manually
)

:: Cleanup
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" 2>nul

echo.
echo Press any key to exit...
pause >nul