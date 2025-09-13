@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ===============================================
echo         Media File Explorer
echo ===============================================
echo.

:: Node.js 설치 확인
echo Checking Node.js installation...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js is not installed!
    echo Please run "원클릭 프로그램 설치.bat" first.
    pause
    exit /b 1
)
echo ✅ Node.js is installed

:: npm 패키지 설치 확인
echo.
echo Checking npm packages...
if not exist "node_modules" (
    echo 📦 Installing npm packages for the first time...
    echo This may take a few minutes...
    call npm install
    if !errorlevel! neq 0 (
        echo ❌ Failed to install packages!
        echo Please check your internet connection and try again.
        pause
        exit /b 1
    )
    echo ✅ Packages installed successfully!
) else (
    :: express 모듈 확인
    if not exist "node_modules\express" (
        echo ⚠️  Some packages are missing. Reinstalling...
        call npm install
    ) else (
        echo ✅ Packages are already installed
    )
)

:: PM2 설치 확인
echo.
echo Checking PM2...
pm2 --version >nul 2>&1
if %errorlevel% neq 0 (
    echo 📦 Installing PM2 globally...
    call npm install -g pm2
    if !errorlevel! neq 0 (
        echo ⚠️  PM2 installation failed. Starting without PM2...
        goto :START_DIRECT
    )
)
echo ✅ PM2 is installed

:: PM2로 서버 시작
echo.
echo Starting server with PM2...
pm2 stop all >nul 2>&1
pm2 delete all >nul 2>&1
pm2 start ecosystem.config.cjs

if %errorlevel% equ 0 (
    echo ✅ Server started successfully!
    echo.
    
    :: 서버 준비 대기
    echo Waiting for server to initialize...
    ping 127.0.0.1 -n 3 >nul
    
    :: 브라우저 열기
    echo Opening browser...
    start http://localhost:3000
    
    echo.
    echo ===============================================
    echo   Media File Explorer is now running!
    echo   URL: http://localhost:3000
    echo ===============================================
    echo.
    echo   📊 View logs: pm2 logs
    echo   🔄 Restart: pm2 restart all
    echo   🛑 Stop: pm2 stop all
    echo.
    echo   Press any key to view server status...
    pause >nul
    
    :: 서버 상태 표시
    pm2 status
    
    echo.
    echo Keep this window open or press Ctrl+C to stop.
    pause >nul
    
    goto :END
)

:START_DIRECT
:: PM2 없이 직접 실행
echo.
echo Starting server directly (without PM2)...
echo.
echo ===============================================
echo   Media File Explorer is now running!
echo   URL: http://localhost:3000
echo   Close this window to stop the server.
echo ===============================================
echo.

:: 브라우저 열기 (백그라운드)
start http://localhost:3000

:: 서버 직접 실행
node local-server.cjs

:END
echo.
echo Server stopped.
pause