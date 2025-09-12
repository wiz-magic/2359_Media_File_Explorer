@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ================================================================
::            Media File Explorer - One Click Setup
:: ================================================================

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

:: Jump to main start to avoid falling into helper labels
goto :start

:: Resolve absolute paths for system tools (no PATH dependency)
set "SR=%SystemRoot%"
if "%SR%"=="" set "SR=C:\Windows"
set "PWSH=%SR%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "PWSH7=%ProgramFiles%\PowerShell\7\pwsh.exe"
set "CURL=%SR%\System32\curl.exe"
set "BITS=%SR%\System32\bitsadmin.exe"
set "CERTUTIL=%SR%\System32\certutil.exe"
set "MSIEXEC=%SR%\System32\msiexec.exe"
set "TIMEOUT_EXE=%SR%\System32\timeout.exe"
set "REGEXE=%SR%\System32\reg.exe"
set "TAR=%SR%\System32\tar.exe"
set "CMD=%SR%\System32\cmd.exe"
set "WHERE_EXE=%SR%\System32\where.exe"
set "TASKLIST_EXE=%SR%\System32\tasklist.exe"
set "TASKKILL_EXE=%SR%\System32\taskkill.exe"
set "NET_EXE=%SR%\System32\net.exe"

:: Helper: sleep %1 seconds (timeout fallback)
:sleep_def
if "%~1"=="" (set "__SECS=5") else (set "__SECS=%~1")
if exist "%TIMEOUT_EXE%" (
    "%TIMEOUT_EXE%" /t %__SECS% /nobreak >nul
) else (
    ping 127.0.0.1 -n %__SECS% >nul
)
exit /b 0

:: Helper: download %1=url %2=outfile
:download
setlocal
set "__URL=%~1"
set "__OUT=%~2"
set "__OK=0"
if exist "%PWSH%" (
    "%PWSH%" -Command "& {[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%__URL%' -OutFile '%__OUT%'}" && set "__OK=1"
)
if %__OK%==0 if exist "%PWSH7%" (
    "%PWSH7%" -NoLogo -NoProfile -Command "Invoke-WebRequest -Uri '%__URL%' -OutFile '%__OUT%'" && set "__OK=1"
)
if %__OK%==0 if exist "%CURL%" (
    "%CURL%" -L -o "%__OUT%" "%__URL%" && set "__OK=1"
)
if %__OK%==0 if exist "%BITS%" (
    "%BITS%" /transfer ME_DLD /priority FOREGROUND "%__URL%" "%__OUT%" && set "__OK=1"
)
if %__OK%==0 if exist "%CERTUTIL%" (
    "%CERTUTIL%" -urlcache -split -f "%__URL%" "%__OUT%" >nul 2>&1 && set "__OK=1"
)
endlocal & (if %__OK%==1 (exit /b 0) else (exit /b 1))

:: Helper: extract zip %1=zip %2=dest
:extract_zip
setlocal
set "__ZIP=%~1"
set "__DST=%~2"
set "__OK=0"
if exist "%PWSH%" (
    "%PWSH%" -Command "Expand-Archive -Path '%__ZIP%' -DestinationPath '%__DST%' -Force" && set "__OK=1"
)
if %__OK%==0 if exist "%TAR%" (
    "%TAR%" -xf "%__ZIP%" -C "%__DST%" && set "__OK=1"
)
endlocal & (if %__OK%==1 (exit /b 0) else (exit /b 1))

:start
:: Check for admin privileges (affects FFmpeg system PATH)
echo Checking system permissions...
"%NET_EXE%" session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Running without administrator privileges.
    set "NO_ADMIN=1"
) else (
    echo [OK] Administrator access available.
    set "NO_ADMIN=0"
)

:: Create installation directory
set "INSTALL_DIR=%~dp0runtime"
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%" >nul 2>&1

:: URLs
set "NODE_URL=https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi"
set "PY_URL=https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe"
set "FFMPEG_ZIP_URL=https://www.gyan.dev/ffmpeg/builds/packages/release/ffmpeg-7.0.2-essentials_build.zip"

:: Local installer cache support
set "NODE_LOCAL1=%INSTALL_DIR%\node.msi"
set "NODE_LOCAL2=%INSTALL_DIR%\node-v20.18.0-x64.msi"
set "PY_LOCAL1=%INSTALL_DIR%\python.exe"
set "PY_LOCAL2=%INSTALL_DIR%\python-3.12.4-amd64.exe"

:: ------------------------------------------------------------
:: 1) Node.js (v20.18.0)
:: ------------------------------------------------------------
echo [1/4] Installing Node.js...
"%WHERE_EXE%" node >nul 2>&1
if %errorlevel% neq 0 (
    rem Use local installer if available, otherwise download
    if exist "%NODE_LOCAL2%" (
        set "NODE_LOCAL=%NODE_LOCAL2%"
    ) else if exist "%NODE_LOCAL1%" (
        set "NODE_LOCAL=%NODE_LOCAL1%"
    ) else (
        echo   Downloading Node.js v20.18.0...
        call :download "%NODE_URL%" "%NODE_LOCAL1%"
    )
    if not defined NODE_LOCAL if exist "%NODE_LOCAL1%" set "NODE_LOCAL=%NODE_LOCAL1%"
    if defined NODE_LOCAL (
        echo   Installing Node.js from "%NODE_LOCAL%"...
        if exist "%MSIEXEC%" (
            "%MSIEXEC%" /i "%NODE_LOCAL%" /quiet /norestart
        ) else (
            echo   [WARN] msiexec not found. Skipping Node.js installation.
        )
        echo   Finalizing Node.js install...
        call :sleep_def 10
        set "PATH=%PATH%;C:\Program Files\nodejs"
    ) else (
        echo   [ERROR] Failed to obtain Node.js installer.
        echo   [HINT] Place node-v20.18.0-x64.msi OR node.msi under "%INSTALL_DIR%" and rerun.
    )
) else (
    echo   Node.js already installed
)

:: Determine npm path
set "NPM=%ProgramFiles%\nodejs\npm.cmd"
if not exist "%NPM%" set "NPM=npm"

:: ------------------------------------------------------------
:: 2) Python (3.12.4)
:: ------------------------------------------------------------
echo [2/4] Installing Python...
"%WHERE_EXE%" python >nul 2>&1
if %errorlevel% neq 0 (
    rem Use local installer if available, otherwise download
    if exist "%PY_LOCAL2%" (
        set "PY_LOCAL=%PY_LOCAL2%"
    ) else if exist "%PY_LOCAL1%" (
        set "PY_LOCAL=%PY_LOCAL1%"
    ) else (
        echo   Downloading Python 3.12.4...
        call :download "%PY_URL%" "%PY_LOCAL1%"
    )
    if not defined PY_LOCAL if exist "%PY_LOCAL1%" set "PY_LOCAL=%PY_LOCAL1%"
    if defined PY_LOCAL (
        echo   Installing Python from "%PY_LOCAL%"...
        "%PY_LOCAL%" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
        echo   Finalizing Python install...
        call :sleep_def 15
        set "PATH=%PATH%;C:\Program Files\Python312;C:\Program Files\Python312\Scripts"
    ) else (
        echo   [ERROR] Failed to obtain Python installer.
        echo   [HINT] Place python-3.12.4-amd64.exe OR python.exe under "%INSTALL_DIR%" and rerun.
    )
) else (
    echo   Python already installed
)

:: ------------------------------------------------------------
:: 3) FFmpeg (prefer Winget, fallback to portable)
:: ------------------------------------------------------------
echo [3/4] Installing FFmpeg...
"%WHERE_EXE%" ffmpeg >nul 2>&1
if %errorlevel%==0 (
    echo   FFmpeg already installed
) else (
    set "WINGET=%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe"
    if not exist "%WINGET%" set "WINGET=%SR%\System32\winget.exe"
    if exist "%WINGET%" (
        echo   Installing FFmpeg via Winget...
        "%WINGET%" install Gyan.FFmpeg --silent --accept-source-agreements --accept-package-agreements
        ffmpeg -version >nul 2>&1
        if %errorlevel%==0 (
            echo   [SUCCESS] FFmpeg installed via Winget
            goto ffmpeg_done
        ) else (
            echo   Winget installation may require a restart. Falling back to portable install...
        )
    ) else (
        echo   Winget not available. Using portable install...
    )

    rem Prefer an already-present ffmpeg folder under runtime
    if exist "%INSTALL_DIR%\ffmpeg\bin\ffmpeg.exe" (
        echo   Using local FFmpeg folder: "%INSTALL_DIR%\ffmpeg"
        set "FFPORTABLE=%INSTALL_DIR%\ffmpeg"
    ) else (
        if not exist "%INSTALL_DIR%\ffmpeg.zip" (
            echo   Downloading FFmpeg (portable)...
            call :download "%FFMPEG_ZIP_URL%" "%INSTALL_DIR%\ffmpeg.zip"
        ) else (
            echo   Using cached FFmpeg archive: "%INSTALL_DIR%\ffmpeg.zip"
        )
        if exist "%INSTALL_DIR%\ffmpeg.zip" (
            echo   Extracting FFmpeg...
            call :extract_zip "%INSTALL_DIR%\ffmpeg.zip" "%INSTALL_DIR%" || echo   [WARN] Could not extract with preferred tool. Trying tar if available.
            set "FFEXTR="
            for /d %%i in ("%INSTALL_DIR%\ffmpeg-*") do (
                if not defined FFEXTR set "FFEXTR=%%i"
            )
            if defined FFEXTR (
                set "FFPORTABLE=%INSTALL_DIR%\ffmpeg_portable"
                if not exist "%FFPORTABLE%" mkdir "%FFPORTABLE%" >nul 2>&1
                xcopy "%FFEXTR%\*" "%FFPORTABLE%\" /E /I /Y >nul 2>&1
            )
        )
    )
        if exist "%FFPORTABLE%\bin" (
            if "%NO_ADMIN%"=="1" (
                set "PATH=%PATH%;%FFPORTABLE%\bin"
                if exist "%REGEXE%" (
                    for /f "tokens=2*" %%a in ('"%REGEXE%" query "HKCU\Environment" /v PATH 2^>nul ^| find "REG_"') do (
                        set "CURUSERPATH=%%b"
                    )
                    if not defined CURUSERPATH (
                        "%REGEXE%" add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%FFPORTABLE%\bin" /f >nul 2>&1
                    ) else (
                        echo !CURUSERPATH! | find /i "%FFPORTABLE%\bin" >nul || "%REGEXE%" add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "!CURUSERPATH!;%FFPORTABLE%\bin" /f >nul 2>&1
                    )
                )
            ) else (
                if not exist "C:\ffmpeg" mkdir "C:\ffmpeg" >nul 2>&1
                xcopy "%FFPORTABLE%\*" "C:\ffmpeg\" /E /I /Y >nul 2>&1
                set "PATH=%PATH%;C:\ffmpeg\bin"
                if exist "%REGEXE%" (
                    for /f "tokens=2*" %%a in ('"%REGEXE%" query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul ^| find "REG_"') do set "CURRENT_PATH=%%b"
                    if defined CURRENT_PATH (
                        echo %CURRENT_PATH% | find /i "C:\ffmpeg\bin" >nul || "%REGEXE%" add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH /t REG_EXPAND_SZ /d "%CURRENT_PATH%;C:\ffmpeg\bin" /f >nul 2>&1
                    )
                )
            )
        )
    )
)

:ffmpeg_done
echo   Testing FFmpeg...
ffmpeg -version >nul 2>&1 && echo   [SUCCESS] FFmpeg is working! || echo   [INFO] FFmpeg installed - may need terminal restart

:: ------------------------------------------------------------
:: 4) Project dependencies
:: ------------------------------------------------------------
echo [4/4] Installing project dependencies...
cd /d "%~dp0"
if not exist "node_modules" (
    echo   Installing npm packages...
    call "%NPM%" install
)

echo.
echo Verifying installation...
node --version >nul 2>&1 && echo   [OK] Node.js ready || echo   [!] Node.js may need new terminal
python --version >nul 2>&1 && echo   [OK] Python ready || echo   [!] Python may need new terminal
ffmpeg -version >nul 2>&1 && echo   [OK] FFmpeg installed || echo   [!] FFmpeg may need new terminal
if exist "node_modules" echo   [OK] Dependencies installed

:: Mark as installed
echo Installation completed successfully > "%~dp0\.installed"

echo.
echo ================================================================
echo                 Starting Media File Explorer
echo ================================================================
echo.

:: Kill any existing Node processes (best-effort)
"%TASKKILL_EXE%" /F /IM node.exe >nul 2>&1

echo Starting server...
:: Use npm path directly to avoid PATH issues
start "MediaExplorer" "%CMD%" /c ""%NPM%" run start"

echo Waiting for server to start...
call :sleep_def 5

echo Opening browser...
start "" http://localhost:3000

echo.
echo ================================================================
echo     Media File Explorer is now running!
echo     http://localhost:3000
echo ================================================================
echo.

:monitor
call :sleep_def 5
"%TASKLIST_EXE%" /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe" >nul
if "%ERRORLEVEL%"=="0" (
    goto monitor
) else (
    echo Server stopped. Restarting...
    start "MediaExplorer" "%CMD%" /c ""%NPM%" run start"
    call :sleep_def 3
    goto monitor
)

endlocal
