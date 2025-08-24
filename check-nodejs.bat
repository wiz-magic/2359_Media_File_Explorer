@echo off
chcp 65001 > nul
title Node.js 설치 상태 진단 도구

echo ================================================================
echo           Node.js 설치 상태 진단 도구
echo ================================================================
echo.

:: 시스템 정보
echo 🖥️  시스템 정보:
echo    - OS: %OS%
echo    - 아키텍처: %PROCESSOR_ARCHITECTURE%
echo    - 사용자: %USERNAME%
echo    - 현재 디렉토리: %CD%
echo.

:: PATH 변수 확인
echo 🛤️  PATH 환경 변수 확인:
echo %PATH% | findstr /i "nodejs" >nul
if %errorlevel% equ 0 (
    echo ✅ PATH에 Node.js 관련 경로가 있습니다
    echo %PATH% | findstr /i "nodejs"
) else (
    echo ❌ PATH에 Node.js 관련 경로가 없습니다
)
echo.

:: Node.js 명령어 테스트
echo 🧪 Node.js 명령어 테스트:
echo.

echo 1. node --version 테스트:
node --version 2>nul
if %errorlevel% equ 0 (
    echo ✅ node 명령어 작동함
) else (
    echo ❌ node 명령어 실패 (에러코드: %errorlevel%)
)
echo.

echo 2. where node 테스트:
where node 2>nul
if %errorlevel% equ 0 (
    echo ✅ node.exe 위치 발견
) else (
    echo ❌ node.exe를 찾을 수 없음
)
echo.

echo 3. npm --version 테스트:
npm --version 2>nul
if %errorlevel% equ 0 (
    echo ✅ npm 명령어 작동함
) else (
    echo ❌ npm 명령어 실패 (에러코드: %errorlevel%)
)
echo.

:: 일반적인 설치 경로 확인
echo 📁 일반적인 Node.js 설치 경로 확인:
echo.

set "NODEJS_PATHS=%ProgramFiles%\nodejs;%ProgramFiles(x86)%\nodejs;%LOCALAPPDATA%\Programs\nodejs;%APPDATA%\npm"

for %%p in (%NODEJS_PATHS%) do (
    echo 확인 중: %%p
    if exist "%%p\node.exe" (
        echo ✅ 발견: %%p\node.exe
        for /f "tokens=*" %%v in ('"%%p\node.exe" --version 2^>nul') do echo    버전: %%v
    ) else (
        echo ❌ 없음: %%p\node.exe
    )
    echo.
)

:: 레지스트리 확인 (설치 정보)
echo 📋 레지스트리에서 설치 정보 확인:
reg query "HKLM\SOFTWARE\Node.js" /v InstallPath 2>nul
if %errorlevel% equ 0 (
    echo ✅ 레지스트리에 Node.js 설치 정보 있음
) else (
    echo ❌ 레지스트리에 Node.js 설치 정보 없음
)
echo.

:: 환경 변수 확인
echo 🌍 환경 변수 확인:
echo    NODE_PATH: %NODE_PATH%
echo    NPM_CONFIG_PREFIX: %NPM_CONFIG_PREFIX%
echo.

:: 권장 해결방법
echo ================================================================
echo                     💡 권장 해결방법
echo ================================================================
echo.

node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js가 제대로 설치되지 않은 것 같습니다.
    echo.
    echo 🔧 해결 방법:
    echo.
    echo 1. Node.js 재설치:
    echo    - https://nodejs.org 접속
    echo    - "20.17.0 LTS" 다운로드
    echo    - 기존 Node.js 완전 제거 후 재설치
    echo    - 설치 시 "Add to PATH" 옵션 체크
    echo.
    echo 2. 수동 PATH 추가:
    echo    - 제어판 → 시스템 → 고급 시스템 설정
    echo    - 환경 변수 → PATH 편집
    echo    - Node.js 설치 경로 추가 (예: C:\Program Files\nodejs)
    echo.
    echo 3. 컴퓨터 재시작:
    echo    - 환경 변수 변경 후 재시작 필요
    echo.
    echo 4. PowerShell에서 테스트:
    echo    - PowerShell 관리자 모드로 실행
    echo    - node --version 입력하여 확인
) else (
    echo ✅ Node.js가 정상적으로 설치되어 있습니다!
    for /f "tokens=*" %%i in ('node --version 2^>nul') do echo    버전: %%i
    for /f "tokens=*" %%i in ('npm --version 2^>nul') do echo    npm 버전: v%%i
    echo.
    echo 🎉 Media Explorer 빌드를 진행할 수 있습니다!
)

echo.
echo ================================================================
pause