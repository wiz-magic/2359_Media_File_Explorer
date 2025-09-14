@echo off
setlocal EnableDelayedExpansion

:: ================================================================
::      PATH 문제 해결 도구 (재부팅 후 인식 안됨 해결)
::      Node.js, Python, FFmpeg PATH 자동 추가
:: ================================================================

echo ================================================================
echo             PATH 문제 해결 도구
echo ================================================================
echo.
echo 재부팅 후 node, python, ffmpeg 명령어가 인식되지 않는 문제를
echo 자동으로 진단하고 수정합니다.
echo.
echo 원클릭 설치 후 이 도구를 실행하세요.
echo.
pause

:: 관리자 권한 확인
net session >nul 2>&1
if errorlevel 1 (
  echo [알림] 사용자 권한으로 실행 - 사용자 PATH만 수정됩니다.
  echo        더 나은 결과를 위해 "관리자 권한으로 실행"을 권장합니다.
  set "USE_SYSTEM=0"
) else (
  echo [확인] 관리자 권한으로 실행 - 시스템 PATH를 수정합니다.
  set "USE_SYSTEM=1"
)

echo.
echo ================================================================
echo                   설치된 프로그램 검색 중...
echo ================================================================

:: Node.js 찾기
set "NODEJS_PATH="
if exist "%ProgramFiles%\nodejs\node.exe" (
  set "NODEJS_PATH=%ProgramFiles%\nodejs"
  echo [발견] Node.js: %ProgramFiles%\nodejs\
) else if exist "%ProgramFiles(x86)%\nodejs\node.exe" (
  set "NODEJS_PATH=%ProgramFiles(x86)%\nodejs"
  echo [발견] Node.js: %ProgramFiles(x86)%\nodejs\
) else (
  echo [없음] Node.js가 설치되지 않았거나 찾을 수 없습니다.
)

:: Python 찾기
set "PYTHON_PATH="
set "PYTHON_SCRIPTS="
for %%V in (313 312 311 310 39 38 37) do (
  if exist "C:\Program Files\Python%%V\python.exe" (
    set "PYTHON_PATH=C:\Program Files\Python%%V"
    set "PYTHON_SCRIPTS=C:\Program Files\Python%%V\Scripts"
    echo [발견] Python: C:\Program Files\Python%%V\
    goto :python_found
  )
  if exist "C:\Python%%V\python.exe" (
    set "PYTHON_PATH=C:\Python%%V"
    set "PYTHON_SCRIPTS=C:\Python%%V\Scripts"
    echo [발견] Python: C:\Python%%V\
    goto :python_found
  )
)

:: 사용자 폴더에서 Python 찾기
if exist "%USERPROFILE%\AppData\Local\Programs\Python\" (
  for /d %%D in ("%USERPROFILE%\AppData\Local\Programs\Python\Python*") do (
    if exist "%%D\python.exe" (
      set "PYTHON_PATH=%%D"
      set "PYTHON_SCRIPTS=%%D\Scripts"
      echo [발견] Python: %%D
      goto :python_found
    )
  )
)

echo [없음] Python이 설치되지 않았거나 찾을 수 없습니다.
:python_found

:: FFmpeg 찾기
set "FFMPEG_PATH="
if exist "C:\ffmpeg\bin\ffmpeg.exe" (
  set "FFMPEG_PATH=C:\ffmpeg\bin"
  echo [발견] FFmpeg: C:\ffmpeg\bin\
) else (
  echo [없음] FFmpeg가 설치되지 않았거나 찾을 수 없습니다.
)

:: PATH에 추가할 항목이 있는지 확인
if not defined NODEJS_PATH if not defined PYTHON_PATH if not defined FFMPEG_PATH (
  echo.
  echo ================================================================
  echo                    결과: 수정할 것이 없습니다
  echo ================================================================
  echo.
  echo Node.js, Python, FFmpeg가 모두 설치되지 않았습니다.
  echo 먼저 "원클릭 프로그램 설치.bat"를 실행하세요.
  goto :end
)

echo.
echo ================================================================
echo                    PATH 자동 수정 중...
echo ================================================================

:: Node.js PATH 추가
if defined NODEJS_PATH (
  echo.
  echo [처리 중] Node.js PATH 추가...
  if "%USE_SYSTEM%"=="1" (
    setx PATH "%PATH%;%NODEJS_PATH%" /M >nul 2>&1
    if errorlevel 1 (
      echo [실패] 시스템 PATH 수정 실패
    ) else (
      echo [완료] 시스템 PATH에 Node.js 추가됨: %NODEJS_PATH%
    )
  ) else (
    setx PATH "%PATH%;%NODEJS_PATH%" >nul 2>&1
    if errorlevel 1 (
      echo [실패] 사용자 PATH 수정 실패
    ) else (
      echo [완료] 사용자 PATH에 Node.js 추가됨: %NODEJS_PATH%
    )
  )
)

:: Python PATH 추가
if defined PYTHON_PATH (
  echo.
  echo [처리 중] Python PATH 추가...
  if "%USE_SYSTEM%"=="1" (
    setx PATH "%PATH%;%PYTHON_PATH%;%PYTHON_SCRIPTS%" /M >nul 2>&1
    if errorlevel 1 (
      echo [실패] 시스템 PATH 수정 실패
    ) else (
      echo [완료] 시스템 PATH에 Python 추가됨: %PYTHON_PATH%
      echo [완료] 시스템 PATH에 Python Scripts 추가됨: %PYTHON_SCRIPTS%
    )
  ) else (
    setx PATH "%PATH%;%PYTHON_PATH%;%PYTHON_SCRIPTS%" >nul 2>&1
    if errorlevel 1 (
      echo [실패] 사용자 PATH 수정 실패
    ) else (
      echo [완료] 사용자 PATH에 Python 추가됨: %PYTHON_PATH%
      echo [완료] 사용자 PATH에 Python Scripts 추가됨: %PYTHON_SCRIPTS%
    )
  )
)

:: FFmpeg PATH 추가
if defined FFMPEG_PATH (
  echo.
  echo [처리 중] FFmpeg PATH 추가...
  if "%USE_SYSTEM%"=="1" (
    setx PATH "%PATH%;%FFMPEG_PATH%" /M >nul 2>&1
    if errorlevel 1 (
      echo [실패] 시스템 PATH 수정 실패
    ) else (
      echo [완료] 시스템 PATH에 FFmpeg 추가됨: %FFMPEG_PATH%
    )
  ) else (
    setx PATH "%PATH%;%FFMPEG_PATH%" >nul 2>&1
    if errorlevel 1 (
      echo [실패] 사용자 PATH 수정 실패  
    ) else (
      echo [완료] 사용자 PATH에 FFmpeg 추가됨: %FFMPEG_PATH%
    )
  )
)

echo.
echo ================================================================
echo                    PATH 수정 완료!
echo ================================================================
echo.
echo *** 중요: PATH 변경사항을 적용하려면 ***
echo.
echo 1. 이 창을 포함한 모든 명령프롬프트/PowerShell 창을 닫으세요
echo 2. 새로운 명령프롬프트 또는 PowerShell을 여세요  
echo 3. 다음 명령어로 테스트하세요:
echo.
if defined NODEJS_PATH echo    node --version
if defined PYTHON_PATH echo    python --version
if defined FFMPEG_PATH echo    ffmpeg -version
echo.
echo *** 여전히 인식되지 않는다면 ***
echo.
echo 1. 컴퓨터를 재시작하세요 (권장)
echo 2. 또는 로그아웃 후 다시 로그인하세요
echo.
echo PATH 변경은 새로운 터미널 세션에서만 적용됩니다!
echo ================================================================

:end
echo.
echo 아무 키나 누르면 창이 닫힙니다.
pause >nul