@echo off

echo ================================================================
echo             PATH Problem Solver
echo ================================================================
echo.
echo This tool fixes PATH issues after reboot.
echo.
pause

echo Checking admin privileges...
net session >nul 2>&1
if errorlevel 1 (
  echo [INFO] User mode - will modify user PATH
  set USE_SYSTEM=0
) else (
  echo [OK] Admin mode - will modify system PATH
  set USE_SYSTEM=1
)

echo.
echo Searching for programs...
echo.

REM Find Node.js
set NODEJS_PATH=
if exist "%ProgramFiles%\nodejs\node.exe" (
  set NODEJS_PATH=%ProgramFiles%\nodejs
  echo [FOUND] Node.js at: %ProgramFiles%\nodejs
) else (
  echo [NOT FOUND] Node.js
)

REM Find Python
set PYTHON_PATH=
if exist "C:\Program Files\Python312\python.exe" (
  set PYTHON_PATH=C:\Program Files\Python312
  echo [FOUND] Python at: C:\Program Files\Python312
) else if exist "C:\Program Files\Python311\python.exe" (
  set PYTHON_PATH=C:\Program Files\Python311
  echo [FOUND] Python at: C:\Program Files\Python311
) else if exist "C:\Program Files\Python310\python.exe" (
  set PYTHON_PATH=C:\Program Files\Python310
  echo [FOUND] Python at: C:\Program Files\Python310
) else (
  echo [NOT FOUND] Python
)

REM Find FFmpeg
set FFMPEG_PATH=
if exist "C:\ffmpeg\bin\ffmpeg.exe" (
  set FFMPEG_PATH=C:\ffmpeg\bin
  echo [FOUND] FFmpeg at: C:\ffmpeg\bin
) else (
  echo [NOT FOUND] FFmpeg
)

echo.
echo Adding to PATH...
echo.

REM Add Node.js to PATH
if defined NODEJS_PATH (
  echo Adding Node.js to PATH...
  if %USE_SYSTEM%==1 (
    setx PATH "%PATH%;%NODEJS_PATH%" /M
  ) else (
    setx PATH "%PATH%;%NODEJS_PATH%"
  )
)

REM Add Python to PATH
if defined PYTHON_PATH (
  echo Adding Python to PATH...
  if %USE_SYSTEM%==1 (
    setx PATH "%PATH%;%PYTHON_PATH%;%PYTHON_PATH%\Scripts" /M
  ) else (
    setx PATH "%PATH%;%PYTHON_PATH%;%PYTHON_PATH%\Scripts"
  )
)

REM Add FFmpeg to PATH
if defined FFMPEG_PATH (
  echo Adding FFmpeg to PATH...
  if %USE_SYSTEM%==1 (
    setx PATH "%PATH%;%FFMPEG_PATH%" /M
  ) else (
    setx PATH "%PATH%;%FFMPEG_PATH%"
  )
)

echo.
echo ================================================================
echo                    COMPLETED!
echo ================================================================
echo.
echo IMPORTANT: Close ALL command windows and open a NEW one
echo.
echo Then test these commands:
if defined NODEJS_PATH echo   node --version
if defined PYTHON_PATH echo   python --version
if defined FFMPEG_PATH echo   ffmpeg -version
echo.
echo If still not working, restart your computer.
echo ================================================================
echo.
echo Press any key to close...
pause >nul