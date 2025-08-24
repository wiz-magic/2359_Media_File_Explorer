@echo off
chcp 65001 > nul
title Media Explorer - Electron 독립 실행형 EXE 빌드

echo ================================================================
echo     Media File Explorer - 완전 독립형 EXE 빌드
echo ================================================================
echo.
echo 이 스크립트는 Python 설치 없이 실행 가능한 
echo 완전한 독립 실행형 설치 파일을 생성합니다!
echo.
echo 필요한 것:
echo   - Node.js (빌드 시에만 필요, 실행 시 불필요)
echo   - 인터넷 연결 (처음 실행 시)
echo.
echo 생성되는 파일:
echo   1. 설치 프로그램 (Setup.exe) - 일반 설치용
echo   2. 포터블 버전 (.exe) - USB 등에서 바로 실행
echo.
pause

:: Node.js 확인 (강화된 감지)
echo.
echo [1/5] Node.js 확인 중...

:: Node.js 버전 확인 시도
set "NODE_FOUND=false"
set "NODE_VERSION="

:: 방법 1: 직접 node 명령어
node --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('node --version 2^>nul') do set "NODE_VERSION=%%i"
    set "NODE_FOUND=true"
    echo ✅ Node.js 발견: %NODE_VERSION%
    goto node_check_done
)

:: 방법 2: where 명령어로 node.exe 찾기
where node.exe >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('node --version 2^>nul') do set "NODE_VERSION=%%i"
    set "NODE_FOUND=true"
    echo ✅ Node.js 발견: %NODE_VERSION%
    goto node_check_done
)

:: 방법 3: 일반적인 설치 경로 확인
for %%p in (
    "%ProgramFiles%\nodejs\node.exe"
    "%ProgramFiles(x86)%\nodejs\node.exe"
    "%LOCALAPPDATA%\Programs\nodejs\node.exe"
    "%APPDATA%\npm\node.exe"
) do (
    if exist "%%p" (
        for /f "tokens=*" %%i in ('"%%p" --version 2^>nul') do set "NODE_VERSION=%%i"
        set "NODE_FOUND=true"
        echo ✅ Node.js 발견: %NODE_VERSION% (경로: %%p)
        set "PATH=%%~dpp;%PATH%"
        goto node_check_done
    )
)

:node_check_done
if "%NODE_FOUND%"=="false" (
    echo.
    echo ❌ Node.js를 찾을 수 없습니다!
    echo.
    echo 💡 Node.js 설치 방법:
    echo    1. https://nodejs.org 접속
    echo    2. "20.17.0 LTS" 또는 최신 LTS 버전 다운로드
    echo    3. 설치 후 컴퓨터 재시작
    echo    4. 이 스크립트를 다시 실행
    echo.
    echo 🔍 디버깅 정보:
    echo    - PATH: %PATH%
    echo    - 현재 디렉토리: %CD%
    echo.
    echo "계속하려면 아무 키나 누르세요..."
    pause
    exit /b 1
)

:: npm 확인
echo.
echo    npm 확인 중...
npm --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ npm을 찾을 수 없습니다!
    echo    Node.js와 함께 설치되어야 합니다.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('npm --version 2^>nul') do echo ✅ npm 발견: v%%i

:: Electron 디렉토리로 이동
echo.
echo [2/5] 작업 디렉토리 설정 중...
cd electron
if %errorlevel% neq 0 (
    echo ❌ electron 폴더를 찾을 수 없습니다!
    pause
    exit /b 1
)
echo ✅ 작업 디렉토리 설정 완료

:: npm 패키지 설치
echo.
echo [3/5] 필요한 패키지 설치 중...
echo       (처음 실행 시 시간이 걸릴 수 있습니다)
call npm install
if %errorlevel% neq 0 (
    echo ❌ 패키지 설치 실패!
    pause
    exit /b 1
)
echo ✅ 패키지 설치 완료

:: 빌드 스크립트 실행
echo.
echo [4/5] 빌드 시작...
echo       (약 2-5분 소요됩니다)
node build-standalone.js
if %errorlevel% neq 0 (
    echo ❌ 빌드 실패!
    pause
    exit /b 1
)

:: 결과 확인
echo.
echo [5/5] 빌드 결과 확인 중...

if exist "dist\Media File Explorer Setup 1.0.0.exe" (
    echo.
    echo ================================================================
    echo     ✅ 빌드 성공!
    echo ================================================================
    echo.
    echo 📦 생성된 파일:
    echo.
    
    :: 파일 크기 표시
    for %%F in ("dist\Media File Explorer Setup 1.0.0.exe") do (
        set /a size=%%~zF/1048576
        echo   1. 설치 프로그램: %%~nxF
        echo      경로: %cd%\dist\%%~nxF
    )
    
    if exist "dist\MediaExplorer-Portable-1.0.0.exe" (
        for %%F in ("dist\MediaExplorer-Portable-1.0.0.exe") do (
            set /a size=%%~zF/1048576
            echo.
            echo   2. 포터블 버전: %%~nxF  
            echo      경로: %cd%\dist\%%~nxF
        )
    )
    
    echo.
    echo ================================================================
    echo.
    echo 🎉 이제 생성된 EXE 파일을 배포할 수 있습니다!
    echo.
    echo 💡 사용 방법:
    echo    - 설치 프로그램: 일반적인 Windows 프로그램처럼 설치
    echo    - 포터블 버전: USB에 넣고 어디서든 실행 가능
    echo.
    echo 📌 참고: 생성된 EXE는 Python/Node.js 설치 없이 실행됩니다!
    echo ================================================================
    
    :: 폴더 열기 옵션
    echo.
    set /p OPEN_FOLDER=생성된 파일이 있는 폴더를 여시겠습니까? (Y/N): 
    if /i "%OPEN_FOLDER%"=="Y" (
        explorer "%cd%\dist"
    )
) else (
    echo.
    echo ❌ 빌드 파일을 찾을 수 없습니다!
    echo    electron\dist 폴더를 확인하세요.
)

echo.
pause