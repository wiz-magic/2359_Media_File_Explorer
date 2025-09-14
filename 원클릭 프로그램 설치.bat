@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ================================================================
::      Media Explorer - Install Dependencies From runtime Only
::      (No Internet. Use local installers inside /runtime)
:: ================================================================

:: Base and tools (absolute paths, no PATH dependency)
set "BASE=%~dp0"
set "RUNTIME=%BASE%runtime"
set "SR=%SystemRoot%"
if "%SR%"=="" set "SR=C:\Windows"
set "MSIEXEC=%SR%\System32\msiexec.exe"
set "REGEXE=%SR%\System32\reg.exe"
set "NET_EXE=%SR%\System32\net.exe"
set "TIMEOUT_EXE=%SR%\System32\timeout.exe"
set "TASKKILL_EXE=%SR%\System32\taskkill.exe"
set "TASKLIST_EXE=%SR%\System32\tasklist.exe"
set "CMD=%SR%\System32\cmd.exe"

:: Jump over helper labels to main entry point
goto :main

:: Small sleep helper
:sleep
set "__SECS=%~1"
if not defined __SECS set "__SECS=5"
if exist "%TIMEOUT_EXE%" (
  "%TIMEOUT_EXE%" /t %__SECS% /nobreak >nul
) else (
  ping 127.0.0.1 -n %__SECS% >nul
)
exit /b 0

:: Add path to system environment (simple version)
:add_to_system_path
set "NEW_PATH=%~1"
if not defined NEW_PATH exit /b 1
for /f "tokens=2*" %%a in ('"%REGEXE%" query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul ^| find "REG_"') do set "CURSYS=%%b"
echo %CURSYS% | find /i "%NEW_PATH%" >nul
if errorlevel 1 (
  echo     Adding to system PATH: %NEW_PATH%
  "%REGEXE%" add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH /t REG_EXPAND_SZ /d "%CURSYS%;%NEW_PATH%" /f >nul 2>&1
)
exit /b 0

:: Add path to user environment (simple version)
:add_to_user_path
set "NEW_PATH=%~1"
if not defined NEW_PATH exit /b 1
"%REGEXE%" query "HKCU\Environment" /v PATH >nul 2>&1
if errorlevel 1 (
  echo     Creating user PATH: %NEW_PATH%
  "%REGEXE%" add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%NEW_PATH%" /f >nul 2>&1
) else (
  for /f "tokens=2*" %%a in ('"%REGEXE%" query "HKCU\Environment" /v PATH 2^>nul ^| find "REG_"') do set "CURUSERPATH=%%b"
  echo !CURUSERPATH! | find /i "%NEW_PATH%" >nul
  if errorlevel 1 (
    echo     Adding to user PATH: %NEW_PATH%
    "%REGEXE%" add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "!CURUSERPATH!;%NEW_PATH%" /f >nul 2>&1
  )
)
exit /b 0

:main
echo ================================================================
echo        Media Explorer - Local (Offline) Installer
echo ================================================================
echo.
echo This will install using local files in:
echo   %RUNTIME%
echo Required files/folders:
echo   - node-v20.18.0-x64.msi (or any node*.msi)
echo   - python-3.12.4-amd64.exe (or any python*.exe)
echo   - ffmpeg\bin\ffmpeg.exe  (or any ffmpeg* folder containing bin\ffmpeg.exe)
echo.
pause

:: Check admin privilege (affects system PATH updates)
echo Checking system permissions...
"%NET_EXE%" session >nul 2>&1
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo [INFO] Running without administrator privileges - install will use user PATH.
  set "NO_ADMIN=1"
) else (
  echo [OK] Administrator access available.
  set "NO_ADMIN=0"
)

if not exist "%RUNTIME%" (
  echo [ERROR] runtime folder not found: %RUNTIME%
  echo        Please create it and place the installers inside.
  goto end
)

:: -----------------------------------------------------------------
:: 1) Install Node.js from local MSI
:: -----------------------------------------------------------------
echo [1/3] Installing Node.js from local installer...
set "NODE_LOCAL="
for %%F in ("%RUNTIME%\node-v20.18.0-x64.msi") do if exist "%%~fF" set "NODE_LOCAL=%%~fF"
if not defined NODE_LOCAL (
  for %%F in ("%RUNTIME%\node*.msi") do if exist "%%~fF" set "NODE_LOCAL=%%~fF" & goto :node_found
)
:node_found
if defined NODE_LOCAL (
  echo   Using: "%NODE_LOCAL%"
  if exist "%MSIEXEC%" (
    "%MSIEXEC%" /i "%NODE_LOCAL%" /quiet /norestart
    call :sleep 8
    
    :: Add Node.js to PATH after installation
    set "NODEJS_PATH="
    if exist "%ProgramFiles%\nodejs\node.exe" set "NODEJS_PATH=%ProgramFiles%\nodejs"
    if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "NODEJS_PATH=%ProgramFiles(x86)%\nodejs"
    
    if defined NODEJS_PATH (
      echo   Node.js installed at: !NODEJS_PATH!
      if "%NO_ADMIN%"=="1" (
        call :add_to_user_path "!NODEJS_PATH!"
      ) else (
        call :add_to_system_path "!NODEJS_PATH!"
      )
    )
  ) else (
    echo   [WARN] msiexec.exe not found. Cannot install Node.js automatically.
  )
) else (
  echo   [WARN] No node*.msi found in runtime. Skipping Node.js.
)

:: -----------------------------------------------------------------
:: 2) Install Python from local EXE
:: -----------------------------------------------------------------
echo [2/3] Installing Python from local installer...
set "PY_LOCAL="
for %%F in ("%RUNTIME%\python-3.12.4-amd64.exe") do if exist "%%~fF" set "PY_LOCAL=%%~fF"
if not defined PY_LOCAL (
  for %%F in ("%RUNTIME%\python*.exe") do if exist "%%~fF" set "PY_LOCAL=%%~fF" & goto :py_found
)
:py_found
if defined PY_LOCAL (
  echo   Using: "%PY_LOCAL%"
  "%PY_LOCAL%" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
  call :sleep 10
  
  :: Add Python to PATH after installation (in case PrependPath=1 didn't work)
  set "PYTHON_PATH="
  set "PYTHON_SCRIPTS_PATH="
  
  :: Check common Python installation paths
  for %%V in (312 311 310 39 38) do (
    if exist "C:\Program Files\Python%%V\python.exe" (
      set "PYTHON_PATH=C:\Program Files\Python%%V"
      set "PYTHON_SCRIPTS_PATH=C:\Program Files\Python%%V\Scripts"
      goto :python_path_found
    )
    if exist "C:\Python%%V\python.exe" (
      set "PYTHON_PATH=C:\Python%%V"
      set "PYTHON_SCRIPTS_PATH=C:\Python%%V\Scripts"
      goto :python_path_found
    )
  )
  
  :python_path_found
  if defined PYTHON_PATH (
    echo   Python installed at: !PYTHON_PATH!
    if "%NO_ADMIN%"=="1" (
      call :add_to_user_path "!PYTHON_PATH!"
      if defined PYTHON_SCRIPTS_PATH call :add_to_user_path "!PYTHON_SCRIPTS_PATH!"
    ) else (
      call :add_to_system_path "!PYTHON_PATH!"
      if defined PYTHON_SCRIPTS_PATH call :add_to_system_path "!PYTHON_SCRIPTS_PATH!"
    )
  )
) else (
  echo   [WARN] No python*.exe found in runtime. Skipping Python.
)

:: -----------------------------------------------------------------
:: 3) FFmpeg local setup (no download)
:: -----------------------------------------------------------------
echo [3/3] Configuring FFmpeg from local folder...
set "FFBIN="
if exist "%RUNTIME%\ffmpeg\bin\ffmpeg.exe" set "FFBIN=%RUNTIME%\ffmpeg\bin"

if not defined FFBIN (
  for /d %%D in ("%RUNTIME%\ffmpeg*") do (
    if exist "%%~fD\bin\ffmpeg.exe" set "FFBIN=%%~fD\bin" & goto :ff_found
  )
)
:ff_found
if defined FFBIN (
  echo   Found FFmpeg bin: "%FFBIN%"
  if "%NO_ADMIN%"=="1" (
    call :add_to_user_path "%FFBIN%"
  ) else (
    rem Admin: copy to C:\ffmpeg and add to system PATH - HKLM
    if not exist "C:\ffmpeg" mkdir "C:\ffmpeg" >nul 2>&1
    xcopy "%FFBIN%\..\*" "C:\ffmpeg\" /E /I /Y >nul 2>&1
    call :add_to_system_path "C:\ffmpeg\bin"
  )
) else (
  echo   [WARN] No ffmpeg folder found in runtime. Skipping FFmpeg.
)

:: -----------------------------------------------------------------
:: Verification (best effort)
:: -----------------------------------------------------------------
echo.
echo --- Verification ---
for %%P in ("%ProgramFiles%\nodejs\node.exe") do if exist "%%~fP" ( "%%~fP" --version ) else ( echo Node.js: not detected in default path )
for %%P in ("C:\Program Files\Python312\python.exe") do if exist "%%~fP" ( "%%~fP" --version ) else ( echo Python: not detected in default path )
if defined FFBIN ( "%FFBIN%\ffmpeg.exe" -version | findstr version ) else ( echo FFmpeg: not detected )

echo.
echo ------------------------------------------------
echo Local installation script completed.
echo If commands are still not recognized, please:
echo   - Open a NEW terminal (PATH refresh), or
echo   - Reboot once for PATH changes to apply.
echo ------------------------------------------------

:end
echo.
echo Press any key to close this window.
pause >nul
endlocal