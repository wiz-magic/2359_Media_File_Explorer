@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ================================================================
::      Media Explorer - Enhanced Local Installer
::      Improved PATH management and environment refresh
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
set "POWERSHELL=%SR%\System32\WindowsPowerShell\v1.0\powershell.exe"

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

:: Refresh environment variables function
:refresh_env
echo   Refreshing environment variables...
if exist "%POWERSHELL%" (
  "%POWERSHELL%" -Command "foreach($level in 'Machine','User') { [Environment]::GetEnvironmentVariables($level).GetEnumerator() | ForEach-Object { Set-Item \"Env:$($_.Name)\" $_.Value } }"
) else (
  :: Fallback: Manual registry read for PATH
  call :read_system_path
  call :read_user_path
)
exit /b 0

:: Read system PATH from registry
:read_system_path
for /f "tokens=2*" %%a in ('"%REGEXE%" query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul ^| find "REG_"') do set "SYS_PATH=%%b"
exit /b 0

:: Read user PATH from registry
:read_user_path
for /f "tokens=2*" %%a in ('"%REGEXE%" query "HKCU\Environment" /v PATH 2^>nul ^| find "REG_"') do set "USER_PATH=%%b"
exit /b 0

:: Add path to system environment
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

:: Add path to user environment
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
echo        Media Explorer - Enhanced Local Installer
echo ================================================================
echo.
echo This will install using local files in:
echo   %RUNTIME%
echo Required files/folders:
echo   - node-v20.18.0-x64.msi (or any node*.msi)
echo   - python-3.12.4-amd64.exe (or any python*.exe)  
echo   - ffmpeg\bin\ffmpeg.exe  (or any ffmpeg* folder containing bin\ffmpeg.exe)
echo.
echo Features:
echo   + Enhanced PATH management
echo   + Environment variable refresh
echo   + Better verification system
echo   + Persistent PATH settings
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
  echo [OK] Administrator access available - will use system PATH.
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
echo.
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
    echo   Installing Node.js (this may take a few minutes)...
    "%MSIEXEC%" /i "%NODE_LOCAL%" /quiet /norestart ADDLOCAL=ALL
    call :sleep 10
    
    :: Add Node.js to PATH if not automatically added
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
    ) else (
      echo   [WARN] Node.js installation path not found - PATH may not be updated.
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
echo.
echo [2/3] Installing Python from local installer...
set "PY_LOCAL="
for %%F in ("%RUNTIME%\python-3.12.4-amd64.exe") do if exist "%%~fF" set "PY_LOCAL=%%~fF"
if not defined PY_LOCAL (
  for %%F in ("%RUNTIME%\python*.exe") do if exist "%%~fF" set "PY_LOCAL=%%~fF" & goto :py_found
)
:py_found

if defined PY_LOCAL (
  echo   Using: "%PY_LOCAL%"
  echo   Installing Python (this may take a few minutes)...
  
  if "%NO_ADMIN%"=="1" (
    :: User installation with explicit PATH setting
    "%PY_LOCAL%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0 Include_doc=0 Include_dev=0 Include_debug=0 Include_launcher=1 InstallLauncherAllUsers=0
  ) else (
    :: System-wide installation
    "%PY_LOCAL%" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_doc=0 Include_dev=0 Include_debug=0 Include_launcher=1 InstallLauncherAllUsers=1
  )
  
  call :sleep 15
  
  :: Verify Python installation and add to PATH if needed
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
  
  :: Check user AppData path
  if exist "%USERPROFILE%\AppData\Local\Programs\Python\" (
    for /d %%D in ("%USERPROFILE%\AppData\Local\Programs\Python\Python*") do (
      if exist "%%D\python.exe" (
        set "PYTHON_PATH=%%D"
        set "PYTHON_SCRIPTS_PATH=%%D\Scripts"
        goto :python_path_found
      )
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
  ) else (
    echo   [WARN] Python installation path not found - PATH may not be updated.
  )
) else (
  echo   [WARN] No python*.exe found in runtime. Skipping Python.
)

:: -----------------------------------------------------------------
:: 3) FFmpeg local setup (no download)
:: -----------------------------------------------------------------
echo.
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
    rem Admin: copy to C:\ffmpeg and add to system PATH
    if not exist "C:\ffmpeg" mkdir "C:\ffmpeg" >nul 2>&1
    echo   Copying FFmpeg to C:\ffmpeg...
    xcopy "%FFBIN%\..\*" "C:\ffmpeg\" /E /I /Y >nul 2>&1
    call :add_to_system_path "C:\ffmpeg\bin"
  )
) else (
  echo   [WARN] No ffmpeg folder found in runtime. Skipping FFmpeg.
)

:: -----------------------------------------------------------------
:: Environment Refresh
:: -----------------------------------------------------------------
echo.
echo [4/4] Refreshing environment variables...
call :refresh_env
call :sleep 3

:: Update current session PATH
call :read_system_path
call :read_user_path
if defined SYS_PATH set "PATH=%SYS_PATH%"
if defined USER_PATH set "PATH=%PATH%;%USER_PATH%"

:: -----------------------------------------------------------------
:: Enhanced Verification
:: -----------------------------------------------------------------
echo.
echo ================================================================
echo                    VERIFICATION RESULTS
echo ================================================================

:: Node.js verification
echo.
echo --- Node.js ---
where node >nul 2>&1
if errorlevel 1 (
  echo   Status: NOT FOUND in PATH
  if exist "%ProgramFiles%\nodejs\node.exe" (
    echo   Found at: %ProgramFiles%\nodejs\node.exe
    "%ProgramFiles%\nodejs\node.exe" --version 2>nul
  ) else (
    echo   Not installed or not accessible
  )
) else (
  for /f "tokens=*" %%p in ('where node 2^>nul') do echo   Path: %%p
  node --version 2>nul
  npm --version 2>nul
)

:: Python verification  
echo.
echo --- Python ---
where python >nul 2>&1
if errorlevel 1 (
  echo   Status: NOT FOUND in PATH
  :: Check common locations
  for %%V in (312 311 310 39 38) do (
    if exist "C:\Program Files\Python%%V\python.exe" (
      echo   Found at: C:\Program Files\Python%%V\python.exe
      "C:\Program Files\Python%%V\python.exe" --version 2>nul
      goto :python_ver_done
    )
  )
  echo   Not installed or not accessible
  :python_ver_done
) else (
  for /f "tokens=*" %%p in ('where python 2^>nul') do echo   Path: %%p
  python --version 2>nul
  pip --version 2>nul
)

:: FFmpeg verification
echo.
echo --- FFmpeg ---
where ffmpeg >nul 2>&1
if errorlevel 1 (
  echo   Status: NOT FOUND in PATH
  if exist "C:\ffmpeg\bin\ffmpeg.exe" (
    echo   Found at: C:\ffmpeg\bin\ffmpeg.exe
    "C:\ffmpeg\bin\ffmpeg.exe" -version 2>nul | findstr "version"
  ) else if defined FFBIN (
    echo   Found at: %FFBIN%\ffmpeg.exe
    "%FFBIN%\ffmpeg.exe" -version 2>nul | findstr "version"
  ) else (
    echo   Not installed or not accessible
  )
) else (
  for /f "tokens=*" %%p in ('where ffmpeg 2^>nul') do echo   Path: %%p
  ffmpeg -version 2>nul | findstr "version"
)

echo.
echo ================================================================
echo                    INSTALLATION SUMMARY
echo ================================================================
echo.
echo Installation completed successfully!
echo.
echo IMPORTANT: If any tools are not recognized:
echo   1. Close ALL command prompts and terminals
echo   2. Open a NEW command prompt/PowerShell
echo   3. Test the commands: node --version, python --version, ffmpeg -version
echo.
echo If still not working after opening new terminal:
echo   1. Restart your computer (recommended)
echo   2. Or manually logout and login again
echo.
echo This ensures all PATH changes take effect properly.
echo ================================================================

:end
echo.
echo Press any key to close this window.
pause >nul
endlocal
