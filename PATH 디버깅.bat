@echo off

echo ================================================================
echo             PATH Debugging Tool
echo ================================================================
echo.
echo This tool shows detailed PATH information to debug the issue.
echo.
pause

echo Checking admin privileges...
net session >nul 2>&1
if errorlevel 1 (
  echo [INFO] User mode
  set USE_SYSTEM=0
) else (
  echo [OK] Admin mode
  set USE_SYSTEM=1
)

echo.
echo ================================================================
echo                    CURRENT SESSION PATH
echo ================================================================
echo.
echo Current PATH in this session:
echo %PATH%
echo.

echo ================================================================
echo                    SYSTEM ENVIRONMENT PATH
echo ================================================================
echo.
echo System PATH from registry:
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH

echo.
echo ================================================================
echo                    USER ENVIRONMENT PATH  
echo ================================================================
echo.
echo User PATH from registry:
reg query "HKCU\Environment" /v PATH 2>nul
if errorlevel 1 echo User PATH does not exist in registry

echo.
echo ================================================================
echo                    PROGRAM LOCATIONS
echo ================================================================
echo.

REM Check Node.js
if exist "%ProgramFiles%\nodejs\node.exe" (
  echo [FOUND] Node.js executable: %ProgramFiles%\nodejs\node.exe
  echo Node.js version:
  "%ProgramFiles%\nodejs\node.exe" --version
) else (
  echo [NOT FOUND] Node.js executable at %ProgramFiles%\nodejs\node.exe
)

echo.

REM Check Python
if exist "C:\Program Files\Python312\python.exe" (
  echo [FOUND] Python executable: C:\Program Files\Python312\python.exe
  echo Python version:
  "C:\Program Files\Python312\python.exe" --version
) else (
  echo [NOT FOUND] Python executable at C:\Program Files\Python312\python.exe
)

echo.

REM Check FFmpeg
if exist "C:\ffmpeg\bin\ffmpeg.exe" (
  echo [FOUND] FFmpeg executable: C:\ffmpeg\bin\ffmpeg.exe
  echo FFmpeg version:
  "C:\ffmpeg\bin\ffmpeg.exe" -version | findstr version
) else (
  echo [NOT FOUND] FFmpeg executable at C:\ffmpeg\bin\ffmpeg.exe
)

echo.
echo ================================================================
echo                    WHERE COMMAND TEST
echo ================================================================
echo.
echo Testing 'where' command to see if programs are in PATH:
echo.

echo Node.js:
where node 2>nul
if errorlevel 1 echo   NOT FOUND in PATH

echo.
echo Python:
where python 2>nul
if errorlevel 1 echo   NOT FOUND in PATH

echo.
echo FFmpeg:
where ffmpeg 2>nul  
if errorlevel 1 echo   NOT FOUND in PATH

echo.
echo ================================================================
echo                    PATH ANALYSIS
echo ================================================================
echo.

REM Check if Node.js path is in current PATH
echo Checking if Node.js path is in current session PATH...
echo %PATH% | findstr /i "nodejs" >nul
if errorlevel 1 (
  echo [ISSUE] Node.js path NOT found in current session PATH
) else (
  echo [OK] Node.js path found in current session PATH
)

REM Check if Python path is in current PATH
echo Checking if Python path is in current session PATH...
echo %PATH% | findstr /i "Python312" >nul
if errorlevel 1 (
  echo [ISSUE] Python path NOT found in current session PATH
) else (
  echo [OK] Python path found in current session PATH
)

REM Check if FFmpeg path is in current PATH
echo Checking if FFmpeg path is in current session PATH...
echo %PATH% | findstr /i "ffmpeg" >nul
if errorlevel 1 (
  echo [ISSUE] FFmpeg path NOT found in current session PATH
) else (
  echo [OK] FFmpeg path found in current session PATH
)

echo.
echo ================================================================
echo                    RECOMMENDATIONS
echo ================================================================
echo.

echo Based on the analysis above:
echo.
echo 1. If programs are FOUND but NOT in PATH:
echo    - The PATH was not updated correctly
echo    - Try running PATH solver again
echo.
echo 2. If programs are in registry PATH but not session PATH:
echo    - You need to restart your computer
echo    - Or logout and login again
echo.
echo 3. If 'where' command finds programs:
echo    - PATH is working, check program installation
echo.
echo 4. If session PATH shows the programs but commands don't work:
echo    - There might be PATH length limit (2048 characters)
echo    - Or conflicting installations
echo.

echo Current session PATH character count:
echo %PATH% > temp_path.txt
for %%A in (temp_path.txt) do echo PATH Length: %%~zA characters
del temp_path.txt

echo.
echo Press any key to close...
pause >nul