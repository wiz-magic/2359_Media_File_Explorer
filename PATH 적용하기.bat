@echo off

echo ================================================================
echo             PATH Complete Fix Tool
echo ================================================================
echo.
echo This tool will PROPERLY fix the PATH by reading current system PATH
echo and adding missing Node.js and Python paths correctly.
echo.
pause

echo Checking admin privileges...
net session >nul 2>&1
if errorlevel 1 (
  echo [ERROR] This tool requires administrator privileges!
  echo Please right-click and "Run as Administrator"
  pause
  exit /b 1
)

echo [OK] Admin mode confirmed

echo.
echo Reading current system PATH from registry...

REM Get current system PATH from registry
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH ^| find "REG_"') do set CURRENT_SYSTEM_PATH=%%b

echo Current system PATH: %CURRENT_SYSTEM_PATH%
echo.

REM Check what needs to be added
set NODEJS_PATH=C:\Program Files\nodejs
set PYTHON_PATH=C:\Program Files\Python312
set PYTHON_SCRIPTS=C:\Program Files\Python312\Scripts

set NEED_NODEJS=0
set NEED_PYTHON=0
set NEED_SCRIPTS=0

echo Checking what needs to be added...

REM Check if Node.js path exists
if exist "%NODEJS_PATH%\node.exe" (
  echo %CURRENT_SYSTEM_PATH% | findstr /i "nodejs" >nul
  if errorlevel 1 (
    echo [NEEDED] Node.js path: %NODEJS_PATH%
    set NEED_NODEJS=1
  ) else (
    echo [OK] Node.js already in PATH
  )
) else (
  echo [SKIP] Node.js not installed at %NODEJS_PATH%
)

REM Check if Python path exists  
if exist "%PYTHON_PATH%\python.exe" (
  echo %CURRENT_SYSTEM_PATH% | findstr /i "Python312" >nul
  if errorlevel 1 (
    echo [NEEDED] Python path: %PYTHON_PATH%
    set NEED_PYTHON=1
  ) else (
    echo [OK] Python already in PATH
  )
) else (
  echo [SKIP] Python not installed at %PYTHON_PATH%
)

REM Check if Python Scripts path exists
if exist "%PYTHON_SCRIPTS%\pip.exe" (
  echo %CURRENT_SYSTEM_PATH% | findstr /i "Python312\Scripts" >nul
  if errorlevel 1 (
    echo [NEEDED] Python Scripts path: %PYTHON_SCRIPTS%
    set NEED_SCRIPTS=1
  ) else (
    echo [OK] Python Scripts already in PATH
  )
) else (
  echo [SKIP] Python Scripts not found at %PYTHON_SCRIPTS%
)

REM Build new PATH
set NEW_PATH=%CURRENT_SYSTEM_PATH%

if %NEED_NODEJS%==1 set NEW_PATH=%NEW_PATH%;%NODEJS_PATH%
if %NEED_PYTHON%==1 set NEW_PATH=%NEW_PATH%;%PYTHON_PATH%
if %NEED_SCRIPTS%==1 set NEW_PATH=%NEW_PATH%;%PYTHON_SCRIPTS%

echo.
echo ================================================================
echo                    UPDATING SYSTEM PATH
echo ================================================================
echo.

if %NEED_NODEJS%==0 if %NEED_PYTHON%==0 if %NEED_SCRIPTS%==0 (
  echo All paths are already correctly set!
  echo No changes needed.
  goto :end
)

echo Old PATH: %CURRENT_SYSTEM_PATH%
echo.
echo New PATH: %NEW_PATH%
echo.

echo Updating system PATH in registry...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH /t REG_EXPAND_SZ /d "%NEW_PATH%" /f

if errorlevel 1 (
  echo [ERROR] Failed to update system PATH
  pause
  exit /b 1
) else (
  echo [SUCCESS] System PATH updated successfully!
)

echo.
echo ================================================================
echo                    VERIFICATION
echo ================================================================
echo.

echo Testing updated PATH...
echo.

if %NEED_NODEJS%==1 (
  echo Testing Node.js:
  "%NODEJS_PATH%\node.exe" --version
  if errorlevel 1 (
    echo [ERROR] Node.js test failed
  ) else (
    echo [OK] Node.js working
  )
)

if %NEED_PYTHON%==1 (
  echo Testing Python:
  "%PYTHON_PATH%\python.exe" --version
  if errorlevel 1 (
    echo [ERROR] Python test failed
  ) else (
    echo [OK] Python working
  )
)

echo.
echo ================================================================
echo                    COMPLETE!
echo ================================================================
echo.
echo PATH has been properly updated!
echo.
echo *** CRITICAL: You MUST restart your computer now! ***
echo.
echo After restart, open a new command prompt and test:
if %NEED_NODEJS%==1 echo   node --version
if %NEED_PYTHON%==1 echo   python --version
echo   ffmpeg -version
echo.
echo The restart is required for PATH changes to take effect system-wide.
echo ================================================================

:end
echo.
echo Press any key to close...
pause >nul