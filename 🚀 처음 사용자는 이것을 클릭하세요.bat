@echo off
title Media File Explorer - Korean Guide

echo.
echo ================================================================
echo          📂 Media File Explorer 처음 사용자 가이드
echo ================================================================
echo.
echo 👋 안녕하세요! 처음 사용하시는군요.
echo.
echo 🎯 목표: Windows용 독립 실행형 EXE 파일 만들기
echo     (Python 설치 없이도 실행 가능!)
echo.
echo ================================================================
echo                    🚀 빠른 시작 가이드
echo ================================================================
echo.
echo 1️⃣  이 파일이 있는 폴더에서 찾으세요:
echo     📄 build-electron-auto.bat
echo.
echo 2️⃣  그 파일을 더블클릭하세요!
echo.
echo 3️⃣  자동으로 처리됩니다:
echo     ✅ Node.js 자동 설치 (필요시)
echo     ✅ 필요한 패키지 설치
echo     ✅ EXE 파일 생성
echo.
echo 4️⃣  완료되면 electron\dist 폴더에서 확인하세요:
echo     📦 Media File Explorer Setup 1.0.0.exe (설치 프로그램)
echo     📦 MediaExplorer-Portable-1.0.0.exe (포터블 버전)
echo.
echo ================================================================
echo.
echo 💡 참고:
echo   - 첫 실행 시 10-20분 정도 걸릴 수 있습니다
echo   - 관리자 권한이 필요할 수 있습니다 (UAC 창에서 "예" 클릭)
echo   - 생성된 EXE는 다른 컴퓨터에서 Python 없이도 실행됩니다!
echo.
echo ================================================================
echo                      🆘 문제가 있나요?
echo ================================================================
echo.
echo 📞 문제 해결 파일들:
echo   - check-nodejs.bat (Node.js 상태 확인)
echo   - WINDOWS_SETUP_GUIDE.md (상세 가이드)
echo.
echo 🔍 일반적인 해결방법:
echo   1. 백신 프로그램 일시 중지
echo   2. 관리자 권한으로 실행
echo   3. 인터넷 연결 확인
echo.
echo ================================================================
echo.
set /p START_NOW=지금 build-electron-auto.bat를 실행하시겠습니까? (Y/N): 
if /i "%START_NOW%"=="Y" (
    echo.
    echo 🚀 build-electron-auto.bat를 실행합니다...
    call build-electron-auto.bat
) else (
    echo.
    echo 💡 나중에 build-electron-auto.bat 파일을 더블클릭하여 시작하세요!
)

echo.
echo 🎉 Media File Explorer를 이용해 주셔서 감사합니다!
pause