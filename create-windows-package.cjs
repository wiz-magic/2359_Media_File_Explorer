#!/usr/bin/env node
/**
 * Complete Windows Package Creator for Media File Explorer
 * Creates a ready-to-use Windows package with all dependencies
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('🚀 Media File Explorer - Windows Package Creator');
console.log('='.repeat(50));

const projectRoot = __dirname;
const packageDir = path.join(projectRoot, 'windows-package');
const outputDir = path.join(projectRoot, 'windows-output');

// Step 1: Clean and create directories
console.log('📁 Creating package directories...');
if (fs.existsSync(packageDir)) {
    fs.rmSync(packageDir, { recursive: true, force: true });
}
if (fs.existsSync(outputDir)) {
    fs.rmSync(outputDir, { recursive: true, force: true });
}
fs.mkdirSync(packageDir, { recursive: true });
fs.mkdirSync(outputDir, { recursive: true });
fs.mkdirSync(path.join(packageDir, 'app'), { recursive: true });

// Step 2: Copy project files
console.log('📋 Copying project files...');
const filesToCopy = [
    'package.json',
    'server.cjs',
    'local-server.cjs',
    'ecosystem.config.cjs'
];

const dirsToCopy = ['public', 'src'];

// Copy files
filesToCopy.forEach(file => {
    const src = path.join(projectRoot, file);
    const dest = path.join(packageDir, 'app', file);
    if (fs.existsSync(src)) {
        fs.copyFileSync(src, dest);
        console.log(`  ✅ Copied ${file}`);
    }
});

// Copy directories
function copyDir(src, dest) {
    fs.mkdirSync(dest, { recursive: true });
    const entries = fs.readdirSync(src, { withFileTypes: true });
    
    entries.forEach(entry => {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);
        
        if (entry.isDirectory()) {
            copyDir(srcPath, destPath);
        } else {
            fs.copyFileSync(srcPath, destPath);
        }
    });
}

dirsToCopy.forEach(dir => {
    const src = path.join(projectRoot, dir);
    const dest = path.join(packageDir, 'app', dir);
    if (fs.existsSync(src)) {
        copyDir(src, dest);
        console.log(`  ✅ Copied ${dir}/`);
    }
});

// Step 3: Create Windows launcher script
console.log('🔧 Creating launcher script...');
const launcherContent = `@echo off
title Media File Explorer
cd /d "%~dp0app"

echo ========================================
echo     Media File Explorer
echo ========================================
echo.
echo Starting application...
echo The browser will open automatically.
echo.
echo Press Ctrl+C to stop the server.
echo ========================================
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed!
    echo.
    echo Please install Node.js from https://nodejs.org
    echo Download the LTS version for Windows.
    echo.
    pause
    exit /b 1
)

REM Install dependencies if needed
if not exist "node_modules" (
    echo Installing dependencies...
    call npm install --production
    echo.
)

REM Start the application
node local-server.cjs

pause`;

fs.writeFileSync(path.join(packageDir, 'Start Media Explorer.bat'), launcherContent);

// Step 4: Create setup script
console.log('📝 Creating setup script...');
const setupContent = `@echo off
title Media File Explorer - Setup
echo ========================================
echo    Media File Explorer - Setup
echo ========================================
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo Node.js is not installed. Installing Node.js...
    echo.
    echo Please wait while we download Node.js installer...
    
    REM Download Node.js installer
    powershell -Command "Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi' -OutFile 'node-installer.msi'"
    
    echo Installing Node.js...
    msiexec /i node-installer.msi /quiet /norestart
    
    echo Node.js installed successfully!
    del node-installer.msi
    echo.
) else (
    echo Node.js is already installed.
    echo.
)

cd /d "%~dp0app"

echo Installing application dependencies...
call npm install --production

echo.
echo ========================================
echo    Setup Complete!
echo ========================================
echo.
echo You can now run "Start Media Explorer.bat"
echo.
pause`;

fs.writeFileSync(path.join(packageDir, 'Setup.bat'), setupContent);

// Step 5: Create FFmpeg downloader
console.log('📥 Creating FFmpeg downloader...');
const ffmpegDownloaderContent = `@echo off
title Download FFmpeg (Optional)
echo ========================================
echo    FFmpeg Downloader (Optional)
echo ========================================
echo.
echo FFmpeg enables video thumbnail generation.
echo This is optional but recommended.
echo.
echo Download size: ~100MB
echo.
set /p confirm="Do you want to download FFmpeg? (y/n): "
if /i "%confirm%" neq "y" exit /b

echo.
echo Downloading FFmpeg...
powershell -Command "Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile 'ffmpeg.zip'"

echo Extracting FFmpeg...
powershell -Command "Expand-Archive -Path 'ffmpeg.zip' -DestinationPath '.'"

echo Setting up FFmpeg...
for /d %%i in (ffmpeg-*-essentials_build) do (
    move "%%i\\bin\\ffmpeg.exe" "app\\"
    move "%%i\\bin\\ffprobe.exe" "app\\"
    rmdir /s /q "%%i"
)

del ffmpeg.zip

echo.
echo FFmpeg installed successfully!
echo.
pause`;

fs.writeFileSync(path.join(packageDir, 'Download FFmpeg (Optional).bat'), ffmpegDownloaderContent);

// Step 6: Create README
console.log('📄 Creating README...');
const readmeContent = `Media File Explorer - Windows Package
======================================

QUICK START:
1. Run "Setup.bat" (first time only)
2. Run "Start Media Explorer.bat"
3. Your browser will open automatically

OPTIONAL:
- Run "Download FFmpeg (Optional).bat" for video thumbnail support

FEATURES:
✅ Browse all media files on your computer
✅ Fast file search
✅ Image thumbnail generation  
✅ Support for images, videos, audio, and documents
✅ No installation required (portable)

REQUIREMENTS:
- Windows 10 or Windows 11
- Node.js (will be installed by Setup.bat if missing)

TROUBLESHOOTING:

Problem: "Port already in use" error
Solution: Close other applications using port 3000/3001

Problem: Application won't start
Solution: 
1. Run Setup.bat again
2. Make sure antivirus isn't blocking the app
3. Try running as Administrator

UNINSTALL:
Simply delete this folder. No registry entries are created.

SUPPORT:
https://github.com/wiz-magic/2359_Media_File_Explorer

Version 1.0.0
`;

fs.writeFileSync(path.join(packageDir, 'README.txt'), readmeContent);

// Step 7: Create package.json for production
console.log('🔧 Optimizing package.json...');
const packageJson = JSON.parse(fs.readFileSync(path.join(packageDir, 'app', 'package.json'), 'utf-8'));
// Remove dev dependencies and scripts not needed for production
delete packageJson.devDependencies;
delete packageJson.scripts.build;
delete packageJson.scripts.dev;
delete packageJson.scripts.preview;
delete packageJson.scripts.deploy;
packageJson.scripts.start = 'node local-server.cjs';

fs.writeFileSync(
    path.join(packageDir, 'app', 'package.json'),
    JSON.stringify(packageJson, null, 2)
);

// Step 8: Create ZIP package
console.log('📦 Creating ZIP package...');
const AdmZip = require('adm-zip');
const zip = new AdmZip();

// Add all files from package directory
function addToZip(dir, zipPath = '') {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    
    entries.forEach(entry => {
        const fullPath = path.join(dir, entry.name);
        const zipEntryPath = path.join(zipPath, entry.name);
        
        if (entry.isDirectory()) {
            addToZip(fullPath, zipEntryPath);
        } else {
            zip.addLocalFile(fullPath, path.dirname(zipEntryPath) || '');
        }
    });
}

addToZip(packageDir);

const zipOutputPath = path.join(outputDir, 'MediaFileExplorer-Windows-v1.0.0.zip');
zip.writeZip(zipOutputPath);

// Step 9: Create installer script
console.log('📋 Creating PowerShell installer...');
const psInstallerContent = `# Media File Explorer - PowerShell Installer
$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host " Media File Explorer Installer" -ForegroundColor Cyan  
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-File", $MyInvocation.MyCommand.Path
    exit
}

# Default installation path
$installPath = "$env:ProgramFiles\\MediaFileExplorer"

# Ask for installation path
$customPath = Read-Host "Installation path (press Enter for default: $installPath)"
if ($customPath) {
    $installPath = $customPath
}

Write-Host "Installing to: $installPath" -ForegroundColor Green
Write-Host ""

# Create installation directory
New-Item -ItemType Directory -Force -Path $installPath | Out-Null

# Copy files
Write-Host "Copying files..." -ForegroundColor Yellow
Copy-Item -Path ".\\*" -Destination $installPath -Recurse -Force

# Create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\\Desktop\\Media File Explorer.lnk")
$Shortcut.TargetPath = "$installPath\\Start Media Explorer.bat"
$Shortcut.WorkingDirectory = $installPath
$Shortcut.IconLocation = "shell32.dll,3"
$Shortcut.Save()

# Create Start Menu shortcut
$startMenuPath = "$env:APPDATA\\Microsoft\\Windows\\Start Menu\\Programs"
$Shortcut = $WshShell.CreateShortcut("$startMenuPath\\Media File Explorer.lnk")
$Shortcut.TargetPath = "$installPath\\Start Media Explorer.bat"
$Shortcut.WorkingDirectory = $installPath
$Shortcut.IconLocation = "shell32.dll,3"
$Shortcut.Save()

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host " Installation Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Desktop shortcut created" -ForegroundColor Cyan
Write-Host "Start Menu shortcut created" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run Setup.bat in the installation folder to complete setup" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")`;

fs.writeFileSync(path.join(packageDir, 'Install.ps1'), psInstallerContent);

// Step 10: Final summary
console.log('='.repeat(50));
console.log('✅ Windows package created successfully!');
console.log('');
console.log('📦 Package location:');
console.log(`   ${packageDir}`);
console.log('');
console.log('📦 ZIP file:');
console.log(`   ${zipOutputPath}`);
console.log('');
console.log('📋 Distribution instructions:');
console.log('1. Share the ZIP file with Windows users');
console.log('2. Users extract the ZIP to any location');
console.log('3. Users run "Setup.bat" (first time only)');
console.log('4. Users run "Start Media Explorer.bat" to launch');
console.log('');
console.log('📌 Optional features:');
console.log('- Run "Download FFmpeg (Optional).bat" for video thumbnails');
console.log('- Run "Install.ps1" for system-wide installation');
console.log('');
console.log('🎉 Package is ready for distribution!');