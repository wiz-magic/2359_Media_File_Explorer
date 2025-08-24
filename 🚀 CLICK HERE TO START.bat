@echo off
chcp 65001 > nul
title 🚀 Media File Explorer - Quick Start

echo.
echo ================================================================
echo          📂 Media File Explorer - Quick Start Guide
echo ================================================================
echo.
echo 👋 Welcome! First time user?
echo.
echo 🎯 Goal: Create standalone Windows EXE file
echo     (No Python installation needed!)
echo.
echo ================================================================
echo                    🚀 QUICK START
echo ================================================================
echo.
echo 1️⃣  Find this file in the same folder:
echo     📄 build-electron-auto.bat
echo.
echo 2️⃣  Double-click that file!
echo.
echo 3️⃣  Everything will be automatic:
echo     ✅ Auto-install Node.js (if needed)
echo     ✅ Install required packages
echo     ✅ Generate EXE files
echo.
echo 4️⃣  Check results in electron\dist folder:
echo     📦 Media File Explorer Setup 1.0.0.exe (installer)
echo     📦 MediaExplorer-Portable-1.0.0.exe (portable)
echo.
echo ================================================================
echo.
echo 💡 Notes:
echo   - First run may take 10-20 minutes
echo   - Administrator permission may be required
echo   - Generated EXE runs on any Windows without Python!
echo.
echo ================================================================
echo                      🆘 Having Issues?
echo ================================================================
echo.
echo 📞 Troubleshooting files:
echo   - check-nodejs.bat (Check Node.js status)
echo   - WINDOWS_SETUP_GUIDE.md (Detailed guide)
echo.
echo 🔍 Common solutions:
echo   1. Temporarily disable antivirus
echo   2. Run as administrator
echo   3. Check internet connection
echo.
echo ================================================================
echo.
set /p START_NOW=Run build-electron-auto.bat now? (Y/N): 
if /i "%START_NOW%"=="Y" (
    echo.
    echo 🚀 Starting build-electron-auto.bat...
    call build-electron-auto.bat
) else (
    echo.
    echo 💡 Please double-click build-electron-auto.bat later to start!
)

echo.
echo 🎉 Thank you for using Media File Explorer!
pause