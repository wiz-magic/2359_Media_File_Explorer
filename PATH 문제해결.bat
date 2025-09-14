@echo off
setlocal EnableDelayedExpansion

:: ================================================================
::      PATH Problem Solver (Reboot Recognition Issue Fix)
::      Auto-add Node.js, Python, FFmpeg to PATH
:: ================================================================

echo ================================================================
echo             PATH Problem Solver
echo ================================================================
echo.
echo This tool automatically diagnoses and fixes the issue where
echo node, python, ffmpeg commands are not recognized after reboot.
echo.
echo Run this tool after using the one-click installer.
echo.
pause

:: Check admin privileges
net session >nul 2>&1
if errorlevel 1 (
  echo [INFO] Running with user privileges - will modify user PATH only.
  echo        For better results, recommend "Run as Administrator".
  set "USE_SYSTEM=0"
) else (
  echo [OK] Running with administrator privileges - will modify system PATH.
  set "USE_SYSTEM=1"
)

echo.
echo ================================================================
echo                   Searching for installed programs...
echo ================================================================

:: Find Node.js
set "NODEJS_PATH="
if exist "%ProgramFiles%\nodejs\node.exe" (
  set "NODEJS_PATH=%ProgramFiles%\nodejs"
  echo [FOUND] Node.js: %ProgramFiles%\nodejs\
) else if exist "%ProgramFiles(x86)%\nodejs\node.exe" (
  set "NODEJS_PATH=%ProgramFiles(x86)%\nodejs"
  echo [FOUND] Node.js: %ProgramFiles(x86)%\nodejs\
) else (
  echo [NOT FOUND] Node.js is not installed or cannot be found.
)

:: Find Python
set "PYTHON_PATH="
set "PYTHON_SCRIPTS="
for %%V in (313 312 311 310 39 38 37) do (
  if exist "C:\Program Files\Python%%V\python.exe" (
    set "PYTHON_PATH=C:\Program Files\Python%%V"
    set "PYTHON_SCRIPTS=C:\Program Files\Python%%V\Scripts"
    echo [FOUND] Python: C:\Program Files\Python%%V\
    goto :python_found
  )
  if exist "C:\Python%%V\python.exe" (
    set "PYTHON_PATH=C:\Python%%V"
    set "PYTHON_SCRIPTS=C:\Python%%V\Scripts"
    echo [FOUND] Python: C:\Python%%V\
    goto :python_found
  )
)

:: Search Python in user folder
if exist "%USERPROFILE%\AppData\Local\Programs\Python\" (
  for /d %%D in ("%USERPROFILE%\AppData\Local\Programs\Python\Python*") do (
    if exist "%%D\python.exe" (
      set "PYTHON_PATH=%%D"
      set "PYTHON_SCRIPTS=%%D\Scripts"
      echo [FOUND] Python: %%D
      goto :python_found
    )
  )
)

echo [NOT FOUND] Python is not installed or cannot be found.
:python_found

:: Find FFmpeg
set "FFMPEG_PATH="
if exist "C:\ffmpeg\bin\ffmpeg.exe" (
  set "FFMPEG_PATH=C:\ffmpeg\bin"
  echo [FOUND] FFmpeg: C:\ffmpeg\bin\
) else (
  echo [NOT FOUND] FFmpeg is not installed or cannot be found.
)

:: Check if there are items to add to PATH
if not defined NODEJS_PATH if not defined PYTHON_PATH if not defined FFMPEG_PATH (
  echo.
  echo ================================================================
  echo                    RESULT: Nothing to fix
  echo ================================================================
  echo.
  echo Node.js, Python, and FFmpeg are all not installed.
  echo Please run "One-Click Installer.bat" first.
  goto :end
)

echo.
echo ================================================================
echo                    Auto-fixing PATH...
echo ================================================================

:: Add Node.js PATH
if defined NODEJS_PATH (
  echo.
  echo [PROCESSING] Adding Node.js to PATH...
  if "%USE_SYSTEM%"=="1" (
    setx PATH "%PATH%;%NODEJS_PATH%" /M >nul 2>&1
    if errorlevel 1 (
      echo [FAILED] System PATH modification failed
    ) else (
      echo [DONE] Node.js added to system PATH: %NODEJS_PATH%
    )
  ) else (
    setx PATH "%PATH%;%NODEJS_PATH%" >nul 2>&1
    if errorlevel 1 (
      echo [FAILED] User PATH modification failed
    ) else (
      echo [DONE] Node.js added to user PATH: %NODEJS_PATH%
    )
  )
)

:: Add Python PATH
if defined PYTHON_PATH (
  echo.
  echo [PROCESSING] Adding Python to PATH...
  if "%USE_SYSTEM%"=="1" (
    setx PATH "%PATH%;%PYTHON_PATH%;%PYTHON_SCRIPTS%" /M >nul 2>&1
    if errorlevel 1 (
      echo [FAILED] System PATH modification failed
    ) else (
      echo [DONE] Python added to system PATH: %PYTHON_PATH%
      echo [DONE] Python Scripts added to system PATH: %PYTHON_SCRIPTS%
    )
  ) else (
    setx PATH "%PATH%;%PYTHON_PATH%;%PYTHON_SCRIPTS%" >nul 2>&1
    if errorlevel 1 (
      echo [FAILED] User PATH modification failed
    ) else (
      echo [DONE] Python added to user PATH: %PYTHON_PATH%
      echo [DONE] Python Scripts added to user PATH: %PYTHON_SCRIPTS%
    )
  )
)

:: Add FFmpeg PATH
if defined FFMPEG_PATH (
  echo.
  echo [PROCESSING] Adding FFmpeg to PATH...
  if "%USE_SYSTEM%"=="1" (
    setx PATH "%PATH%;%FFMPEG_PATH%" /M >nul 2>&1
    if errorlevel 1 (
      echo [FAILED] System PATH modification failed
    ) else (
      echo [DONE] FFmpeg added to system PATH: %FFMPEG_PATH%
    )
  ) else (
    setx PATH "%PATH%;%FFMPEG_PATH%" >nul 2>&1
    if errorlevel 1 (
      echo [FAILED] User PATH modification failed  
    ) else (
      echo [DONE] FFmpeg added to user PATH: %FFMPEG_PATH%
    )
  )
)

echo.
echo ================================================================
echo                    PATH Modification Complete!
echo ================================================================
echo.
echo *** IMPORTANT: To apply PATH changes ***
echo.
echo 1. Close ALL command prompt/PowerShell windows (including this one)
echo 2. Open a NEW command prompt or PowerShell
echo 3. Test with these commands:
echo.
if defined NODEJS_PATH echo    node --version
if defined PYTHON_PATH echo    python --version
if defined FFMPEG_PATH echo    ffmpeg -version
echo.
echo *** If still not recognized ***
echo.
echo 1. Restart your computer (recommended)
echo 2. Or log out and log back in
echo.
echo PATH changes only take effect in new terminal sessions!
echo ================================================================

:end
echo.
echo Press any key to close this window.
pause >nul