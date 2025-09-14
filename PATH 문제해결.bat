@echo off
setlocal EnableDelayedExpansion

:: ================================================================
::      환경변수 문제 해결 도구
::      Node.js, Python 재부팅 후 인식 안되는 문제 진단 및 수정
:: ================================================================

echo ================================================================
echo             환경변수 문제 해결 도구
echo ================================================================
echo.
echo 이 도구는 재부팅 후 Node.js, Python이 인식되지 않는 문제를 
echo 진단하고 수정합니다.
echo.
pause

:: 관리자 권한 확인
net session >nul 2>&1
if errorlevel 1 (
  echo [정보] 사용자 권한으로 실행 중 - 사용자 환경변수만 수정 가능
  set "ADMIN_MODE=0"
) else (
  echo [확인] 관리자 권한으로 실행 중 - 시스템 환경변수 수정 가능
  set "ADMIN_MODE=1"
)

echo.
echo ================================================================
echo                    현재 상태 진단
echo ================================================================

:: 1. 현재 PATH 확인
echo.
echo --- 현재 세션 PATH ---
echo %PATH%

:: 2. 시스템 환경변수 PATH 확인
echo.
echo --- 시스템 환경변수 PATH ---
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul ^| find "REG_"') do echo %%b

:: 3. 사용자 환경변수 PATH 확인
echo.
echo --- 사용자 환경변수 PATH ---
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul ^| find "REG_"') do echo %%b

:: 4. 프로그램 설치 상태 확인
echo.
echo --- 프로그램 설치 상태 확인 ---

echo.
echo [Node.js 확인]
set "NODE_FOUND=0"
if exist "%ProgramFiles%\nodejs\node.exe" (
  echo   위치: %ProgramFiles%\nodejs\
  "%ProgramFiles%\nodejs\node.exe" --version
  set "NODE_PATH=%ProgramFiles%\nodejs"
  set "NODE_FOUND=1"
) else if exist "%ProgramFiles(x86)%\nodejs\node.exe" (
  echo   위치: %ProgramFiles(x86)%\nodejs\
  "%ProgramFiles(x86)%\nodejs\node.exe" --version  
  set "NODE_PATH=%ProgramFiles(x86)%\nodejs"
  set "NODE_FOUND=1"
) else (
  echo   상태: 설치되지 않음
)

echo.
echo [Python 확인]  
set "PYTHON_FOUND=0"
set "PYTHON_PATH="
set "PYTHON_SCRIPTS="

:: Python 설치 경로 검색
for %%V in (312 311 310 39 38) do (
  if exist "C:\Program Files\Python%%V\python.exe" (
    echo   위치: C:\Program Files\Python%%V\
    "C:\Program Files\Python%%V\python.exe" --version
    set "PYTHON_PATH=C:\Program Files\Python%%V"
    set "PYTHON_SCRIPTS=C:\Program Files\Python%%V\Scripts"
    set "PYTHON_FOUND=1"
    goto :python_found
  )
  if exist "C:\Python%%V\python.exe" (
    echo   위치: C:\Python%%V\
    "C:\Python%%V\python.exe" --version
    set "PYTHON_PATH=C:\Python%%V"
    set "PYTHON_SCRIPTS=C:\Python%%V\Scripts"
    set "PYTHON_FOUND=1"
    goto :python_found
  )
)

:: 사용자 설치 경로 확인
if exist "%USERPROFILE%\AppData\Local\Programs\Python\" (
  for /d %%D in ("%USERPROFILE%\AppData\Local\Programs\Python\Python*") do (
    if exist "%%D\python.exe" (
      echo   위치: %%D
      "%%D\python.exe" --version
      set "PYTHON_PATH=%%D"
      set "PYTHON_SCRIPTS=%%D\Scripts"  
      set "PYTHON_FOUND=1"
      goto :python_found
    )
  )
)

:python_found
if "%PYTHON_FOUND%"=="0" echo   상태: 설치되지 않음

echo.
echo [FFmpeg 확인]
set "FFMPEG_FOUND=0"
if exist "C:\ffmpeg\bin\ffmpeg.exe" (
  echo   위치: C:\ffmpeg\bin\
  "C:\ffmpeg\bin\ffmpeg.exe" -version | findstr "version"
  set "FFMPEG_PATH=C:\ffmpeg\bin"
  set "FFMPEG_FOUND=1"
) else (
  echo   상태: 설치되지 않음 또는 경로 문제
)

:: 5. PATH에서 누락된 경로 확인
echo.
echo ================================================================
echo                    문제 진단 결과
echo ================================================================

set "NEED_FIX=0"

echo.
echo PATH에서 누락된 항목:
if "%NODE_FOUND%"=="1" (
  echo %PATH% | find /i "%NODE_PATH%" >nul
  if errorlevel 1 (
    echo   - Node.js PATH 누락: %NODE_PATH%
    set "NEED_FIX=1"
  )
)

if "%PYTHON_FOUND%"=="1" (
  echo %PATH% | find /i "%PYTHON_PATH%" >nul
  if errorlevel 1 (
    echo   - Python PATH 누락: %PYTHON_PATH%
    set "NEED_FIX=1"
  )
  if defined PYTHON_SCRIPTS (
    echo %PATH% | find /i "%PYTHON_SCRIPTS%" >nul
    if errorlevel 1 (
      echo   - Python Scripts PATH 누락: %PYTHON_SCRIPTS%
      set "NEED_FIX=1"
    )
  )
)

if "%FFMPEG_FOUND%"=="1" (
  echo %PATH% | find /i "%FFMPEG_PATH%" >nul
  if errorlevel 1 (
    echo   - FFmpeg PATH 누락: %FFMPEG_PATH%
    set "NEED_FIX=1"
  )
)

if "%NEED_FIX%"=="0" (
  echo   모든 PATH가 올바르게 설정되어 있습니다.
  echo.
  echo   만약 여전히 명령어가 인식되지 않는다면:
  echo   1. 모든 명령프롬프트/PowerShell 창을 닫으세요
  echo   2. 새로운 명령프롬프트를 열어 테스트하세요
  echo   3. 그래도 안 되면 재부팅하세요
  goto :end
)

echo.
echo ================================================================
echo                    PATH 자동 수정
echo ================================================================

echo.
echo 누락된 PATH를 자동으로 수정하시겠습니까?
echo 계속하려면 아무 키나 누르세요. 취소하려면 Ctrl+C를 누르세요.
pause >nul

:: NODE.js PATH 수정
if "%NODE_FOUND%"=="1" (
  echo %PATH% | find /i "%NODE_PATH%" >nul
  if errorlevel 1 (
    echo   Node.js PATH 추가 중...
    if "%ADMIN_MODE%"=="1" (
      call :add_system_path "%NODE_PATH%"
    ) else (
      call :add_user_path "%NODE_PATH%"
    )
  )
)

:: Python PATH 수정
if "%PYTHON_FOUND%"=="1" (
  echo %PATH% | find /i "%PYTHON_PATH%" >nul
  if errorlevel 1 (
    echo   Python PATH 추가 중...
    if "%ADMIN_MODE%"=="1" (
      call :add_system_path "%PYTHON_PATH%"
    ) else (
      call :add_user_path "%PYTHON_PATH%"
    )
  )
  
  if defined PYTHON_SCRIPTS (
    echo %PATH% | find /i "%PYTHON_SCRIPTS%" >nul
    if errorlevel 1 (
      echo   Python Scripts PATH 추가 중...
      if "%ADMIN_MODE%"=="1" (
        call :add_system_path "%PYTHON_SCRIPTS%"
      ) else (
        call :add_user_path "%PYTHON_SCRIPTS%"
      )
    )
  )
)

:: FFmpeg PATH 수정
if "%FFMPEG_FOUND%"=="1" (
  echo %PATH% | find /i "%FFMPEG_PATH%" >nul
  if errorlevel 1 (
    echo   FFmpeg PATH 추가 중...
    if "%ADMIN_MODE%"=="1" (
      call :add_system_path "%FFMPEG_PATH%"
    ) else (
      call :add_user_path "%FFMPEG_PATH%"
    )
  )
)

echo.
echo PATH 수정이 완료되었습니다!
echo.
echo 변경사항을 적용하려면:
echo   1. 현재 명령프롬프트를 닫으세요
echo   2. 새로운 명령프롬프트를 열어서 테스트하세요
echo   3. node --version, python --version, ffmpeg -version 명령어를 실행해보세요
echo.
echo 만약 여전히 인식되지 않는다면 재부팅 후 다시 시도해주세요.

goto :end

:: 시스템 PATH에 경로 추가
:add_system_path
set "NEW_PATH=%~1"
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul ^| find "REG_"') do set "CURRENT_PATH=%%b"
echo %CURRENT_PATH% | find /i "%NEW_PATH%" >nul
if errorlevel 1 (
  reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH /t REG_EXPAND_SZ /d "%CURRENT_PATH%;%NEW_PATH%" /f >nul
  echo     시스템 PATH에 추가됨: %NEW_PATH%
)
exit /b

:: 사용자 PATH에 경로 추가  
:add_user_path
set "NEW_PATH=%~1"
reg query "HKCU\Environment" /v PATH >nul 2>&1
if errorlevel 1 (
  reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%NEW_PATH%" /f >nul
  echo     사용자 PATH 생성 및 추가됨: %NEW_PATH%
) else (
  for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul ^| find "REG_"') do set "CURRENT_PATH=%%b"
  echo !CURRENT_PATH! | find /i "%NEW_PATH%" >nul
  if errorlevel 1 (
    reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "!CURRENT_PATH!;%NEW_PATH%" /f >nul
    echo     사용자 PATH에 추가됨: %NEW_PATH%
  )
)
exit /b

:end
echo.
echo 작업이 완료되었습니다. 아무 키나 누르면 종료됩니다.
pause >nul