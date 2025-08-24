@echo off
title Media Explorer Auto Build
cls

echo ================================================================
echo     Media File Explorer - Auto Build System
echo ================================================================
echo.
echo This script will automatically handle everything:
echo   * Check Node.js installation status
echo   * Auto download and install Node.js if needed
echo   * Auto build Electron app
echo   * Generate standalone exe files
echo.
echo Press any key to continue...
pause >nul

:: 관리자 권한 확인
echo.
echo [0/6] 관리자 권한 확인 중...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo WARNING: Administrator privileges required!
    echo.
    echo Solution:
    echo   1. Right-click this file
    echo   2. Select "Run as administrator"
    echo   3. Click "Yes" in UAC dialog
    echo.
    pause
    exit /b 1
)
echo [OK] Administrator privileges confirmed

:: 임시 다운로드 폴더 생성
set "TEMP_DIR=%TEMP%\media-explorer-build"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

:: Node.js 확인 및 설치
echo.
echo [1/6] Checking Node.js...

node --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('node --version 2^>nul') do (
        echo ✅ Node.js 이미 설치됨: %%i
        goto nodejs_ready
    )
)

echo ❌ Node.js가 설치되지 않았습니다.
echo 📥 Node.js 자동 다운로드 및 설치를 시작합니다...
echo.

:: Node.js 다운로드
set "NODE_URL=https://nodejs.org/dist/v20.17.0/node-v20.17.0-x64.msi"
set "NODE_INSTALLER=%TEMP_DIR%\nodejs-installer.msi"

echo    다운로드 중... (약 30MB)
powershell -Command "(New-Object System.Net.WebClient).DownloadFile('%NODE_URL%', '%NODE_INSTALLER%')"

if not exist "%NODE_INSTALLER%" (
    echo ❌ Node.js 다운로드 실패!
    echo    인터넷 연결을 확인하고 다시 시도하세요.
    pause
    exit /b 1
)

echo ✅ 다운로드 완료
echo.

:: Node.js 설치
echo    설치 중... (자동으로 진행됩니다)
msiexec /i "%NODE_INSTALLER%" /quiet /norestart

:: PATH 새로고침
echo    환경 변수 새로고침...
for /f "tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH') do set "SYSTEM_PATH=%%j"
for /f "tokens=2*" %%i in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%j"
set "PATH=%SYSTEM_PATH%;%USER_PATH%"

:: 설치 확인
timeout /t 3 /nobreak >nul
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js 설치 후에도 인식되지 않습니다.
    echo    컴퓨터를 재시작한 후 다시 시도하세요.
    pause
    exit /b 1
)

echo ✅ Node.js 설치 완료!

:nodejs_ready

:: 버전 확인 및 표시
for /f "tokens=*" %%i in ('node --version 2^>nul') do set "NODE_VER=%%i"
for /f "tokens=*" %%i in ('npm --version 2^>nul') do set "NPM_VER=%%i"
echo    Node.js: %NODE_VER%
echo    npm: v%NPM_VER%

:: Electron 디렉토리 확인
echo.
echo [2/6] 프로젝트 구조 확인 중...
if not exist "electron" (
    echo ❌ electron 폴더를 찾을 수 없습니다!
    echo    올바른 프로젝트 디렉토리에서 실행하세요.
    pause
    exit /b 1
)
echo ✅ electron 폴더 확인됨

:: Electron 디렉토리로 이동
cd electron
if %errorlevel% neq 0 (
    echo ❌ electron 폴더로 이동 실패!
    pause
    exit /b 1
)

:: package.json 확인
if not exist "package.json" (
    echo ❌ electron/package.json 파일이 없습니다!
    echo    프로젝트 구조를 확인하세요.
    pause
    exit /b 1
)
echo ✅ package.json 확인됨

:: npm 패키지 설치
echo.
echo [3/6] 필요한 패키지 설치 중...
echo       (처음 실행 시 5-10분 소요될 수 있습니다)
call npm install
if %errorlevel% neq 0 (
    echo ❌ npm install 실패!
    echo.
    echo 해결 방법:
    echo   1. 인터넷 연결 확인
    echo   2. npm cache clean --force
    echo   3. 다시 실행
    pause
    exit /b 1
)
echo ✅ 패키지 설치 완료

:: 빌드 실행
echo.
echo [4/6] Electron 앱 빌드 중...
echo       (약 3-5분 소요됩니다)

:: 빌드 환경 설정
set "CSC_IDENTITY_AUTO_DISCOVERY=false"
set "DEBUG=electron-builder"

call npm run build-win
if %errorlevel% neq 0 (
    echo ❌ 빌드 실패!
    echo.
    echo 일반적인 원인:
    echo   1. 디스크 공간 부족 (최소 2GB 필요)
    echo   2. 백신 프로그램 간섭
    echo   3. 권한 문제
    echo.
    echo 해결 시도:
    echo   - 백신 프로그램 일시 중지
    echo   - 디스크 공간 확보
    echo   - 관리자 권한으로 재실행
    pause
    exit /b 1
)

:: 빌드 결과 확인
echo.
echo [5/6] 빌드 결과 확인 중...

set "SETUP_FILE=dist\Media File Explorer Setup 1.0.0.exe"
set "PORTABLE_FILE=dist\MediaExplorer-Portable-1.0.0.exe"

if exist "%SETUP_FILE%" (
    echo ✅ 설치 프로그램 생성 성공!
) else (
    echo ❌ 설치 프로그램 생성 실패!
)

if exist "%PORTABLE_FILE%" (
    echo ✅ 포터블 버전 생성 성공!
) else (
    echo ❌ 포터블 버전 생성 실패!
)

:: 결과 보고
echo.
echo [6/6] 최종 결과
echo.

if exist "%SETUP_FILE%" (
    echo ================================================================
    echo                    🎉 빌드 성공! 🎉
    echo ================================================================
    echo.
    echo 📦 생성된 파일:
    echo.
    
    for %%F in ("%SETUP_FILE%") do (
        set /a size=%%~zF/1048576
        echo    1. 설치 프로그램: %%~nxF
        echo       크기: !size! MB
        echo       위치: %cd%\%%~nxF
    )
    
    if exist "%PORTABLE_FILE%" (
        echo.
        for %%F in ("%PORTABLE_FILE%") do (
            set /a size=%%~zF/1048576
            echo    2. 포터블 버전: %%~nxF
            echo       크기: !size! MB  
            echo       위치: %cd%\%%~nxF
        )
    )
    
    echo.
    echo ================================================================
    echo.
    echo 🚀 이제 생성된 EXE 파일을 배포할 수 있습니다!
    echo.
    echo 💡 사용 방법:
    echo    👥 최종 사용자는 Python/Node.js 설치 없이 바로 실행 가능
    echo    📱 설치 프로그램: 일반적인 Windows 프로그램처럼 설치
    echo    💾 포터블 버전: USB에 넣고 어디서든 실행
    echo.
    echo ================================================================
    
    :: 폴더 열기
    echo.
    set /p OPEN_FOLDER=생성된 파일 폴더를 여시겠습니까? (Y/N): 
    if /i "%OPEN_FOLDER%"=="Y" (
        explorer "%cd%\dist"
    )
) else (
    echo ================================================================
    echo                    ❌ 빌드 실패
    echo ================================================================
    echo.
    echo 문제 해결:
    echo   1. check-nodejs.bat 실행하여 Node.js 상태 확인
    echo   2. 백신 프로그램 일시 중지 후 재시도  
    echo   3. 디스크 공간 확보 (최소 2GB)
    echo   4. 관리자 권한으로 재실행
    echo.
)

:: 정리
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"

echo.
pause