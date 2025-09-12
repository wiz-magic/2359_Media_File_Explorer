# Media File Explorer - One Click Setup Script
# This script will install everything needed and start the application

param(
    [switch]$AsAdmin
)

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin -and -not $AsAdmin) {
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "   Media File Explorer - Setup Required" -ForegroundColor Cyan  
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script needs administrator privileges to install:" -ForegroundColor Yellow
    Write-Host "  - Node.js (if not installed)" -ForegroundColor White
    Write-Host "  - Python (if not installed)" -ForegroundColor White
    Write-Host "  - FFmpeg (for video thumbnails)" -ForegroundColor White
    Write-Host ""
    Write-Host "Restarting with administrator privileges..." -ForegroundColor Green
    
    Start-Process PowerShell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -AsAdmin" -Verb RunAs
    exit
}

Clear-Host
Write-Host "===============================================" -ForegroundColor Green
Write-Host "   Media File Explorer - Auto Setup" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""

$installDir = Join-Path $PSScriptRoot "runtime"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Function to download file with progress
function Download-File {
    param($url, $output)
    try {
        Write-Host "    Downloading $(Split-Path $output -Leaf)..." -ForegroundColor Yellow
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $output)
        Write-Host "    Download completed!" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    Download failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Install Node.js
Write-Host "[1/4] Checking Node.js..." -ForegroundColor Cyan
try {
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        Write-Host "    Node.js already installed: $nodeVersion" -ForegroundColor Green
    } else {
        throw "Not installed"
    }
} catch {
    Write-Host "    Installing Node.js (nvm-windows + Node v20.18.0)..." -ForegroundColor Yellow

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        try {
            winget install CoreyButler.NVM-Windows --silent --accept-source-agreements
            # Refresh environment variables for current session
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            $env:NVM_HOME = [System.Environment]::GetEnvironmentVariable("NVM_HOME", "Machine")
            $env:NVM_SYMLINK = [System.Environment]::GetEnvironmentVariable("NVM_SYMLINK", "Machine")

            nvm install 20.18.0
            nvm use 20.18.0

            # Refresh PATH again after nvm use
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

            Write-Host "    Node.js v20.18.0 installation via nvm completed!" -ForegroundColor Green
        } catch {
            Write-Host "    nvm install failed via winget, falling back to MSI installer..." -ForegroundColor Yellow
            $nodeUrl = "https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi"
            $nodeInstaller = Join-Path $installDir "node.msi"
            if (Download-File $nodeUrl $nodeInstaller) {
                Write-Host "    Running Node.js MSI installer..." -ForegroundColor Yellow
                Start-Process -FilePath "msiexec" -ArgumentList "/i `"$nodeInstaller`" /quiet /norestart" -Wait
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                Write-Host "    Node.js installation completed!" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "    Winget not found; using MSI installer..." -ForegroundColor Yellow
        $nodeUrl = "https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi"
        $nodeInstaller = Join-Path $installDir "node.msi"
        if (Download-File $nodeUrl $nodeInstaller) {
            Write-Host "    Running Node.js MSI installer..." -ForegroundColor Yellow
            Start-Process -FilePath "msiexec" -ArgumentList "/i `"$nodeInstaller`" /quiet /norestart" -Wait
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Host "    Node.js installation completed!" -ForegroundColor Green
        }
    }
}

# Install Python
Write-Host "[2/4] Checking Python..." -ForegroundColor Cyan
try {
    $pythonVersion = python --version 2>$null
    if ($pythonVersion) {
        Write-Host "    Python already installed: $pythonVersion" -ForegroundColor Green
    } else {
        throw "Not installed"
    }
} catch {
    Write-Host "    Installing Python..." -ForegroundColor Yellow
    $pythonUrl = "https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe"
    $pythonInstaller = Join-Path $installDir "python.exe"
    
    if (Download-File $pythonUrl $pythonInstaller) {
        Write-Host "    Running Python installer..." -ForegroundColor Yellow
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "    Python installation completed!" -ForegroundColor Green
    }
}

# Install FFmpeg
Write-Host "[3/4] Checking FFmpeg..." -ForegroundColor Cyan
$ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpegCmd -or (Test-Path "C:\ffmpeg\bin\ffmpeg.exe")) {
    Write-Host "    FFmpeg already installed" -ForegroundColor Green
} else {
    Write-Host "    Installing FFmpeg..." -ForegroundColor Yellow
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    $ffmpegInstalled = $false
    if ($winget) {
        try {
            winget install Gyan.FFmpeg --silent --accept-source-agreements
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
                Write-Host "    FFmpeg installation via winget completed!" -ForegroundColor Green
                $ffmpegInstalled = $true
            }
        } catch {
            Write-Host "    Winget FFmpeg install failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "    Winget not found; using manual zip install..." -ForegroundColor Yellow
    }

    if (-not $ffmpegInstalled) {
        $ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
        $ffmpegZip = Join-Path $installDir "ffmpeg.zip"
        if (Download-File $ffmpegUrl $ffmpegZip) {
            Write-Host "    Extracting FFmpeg..." -ForegroundColor Yellow
            Expand-Archive -Path $ffmpegZip -DestinationPath $installDir -Force

            $ffmpegFolder = Get-ChildItem -Path $installDir -Directory -Name "ffmpeg-*" | Select-Object -First 1
            if ($ffmpegFolder) {
                $sourcePath = Join-Path $installDir $ffmpegFolder
                if (-not (Test-Path "C:\ffmpeg")) {
                    New-Item -ItemType Directory -Path "C:\ffmpeg" -Force | Out-Null
                }
                Copy-Item -Path "$sourcePath\*" -Destination "C:\ffmpeg\" -Recurse -Force

                $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                if ($currentPath -notlike "*C:\ffmpeg\bin*") {
                    [Environment]::SetEnvironmentVariable("Path", "$currentPath;C:\ffmpeg\bin", "Machine")
                    $env:Path += ";C:\ffmpeg\bin"
                }
                Write-Host "    FFmpeg installation completed!" -ForegroundColor Green
            } else {
                Write-Host "    Could not find extracted FFmpeg folder." -ForegroundColor Red
            }
        } else {
            Write-Host "    FFmpeg download failed, skipping..." -ForegroundColor Yellow
        }
    }
}

# Install project dependencies
Write-Host "" 
Write-Host "Verification - Installed versions:" -ForegroundColor Cyan
try { Write-Host ("    Python: " + (python --version)) } catch { Write-Host "    Python not found." -ForegroundColor Yellow }
try { Write-Host ("    FFmpeg: " + ((ffmpeg -version | Select-Object -First 1))) } catch { Write-Host "    FFmpeg not found." -ForegroundColor Yellow }
try { Write-Host ("    Node.js: " + (node -v)) } catch { Write-Host "    Node.js not found." -ForegroundColor Yellow }
Write-Host ""
Write-Host "[4/4] Installing project dependencies..." -ForegroundColor Cyan
Set-Location $PSScriptRoot  # Ensure we're in the correct directory
if (-not (Test-Path "node_modules")) {
    Write-Host "    Installing npm packages..." -ForegroundColor Yellow
    & npm install
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    Dependencies installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "    Warning: Some dependencies may not have installed correctly" -ForegroundColor Yellow
    }
} else {
    Write-Host "    Dependencies already installed" -ForegroundColor Green
}

# Create desktop shortcut
Write-Host "Creating desktop shortcut..." -ForegroundColor Cyan
$shortcutPath = [Environment]::GetFolderPath("Desktop") + "\Media File Explorer.lnk"
$targetPath = Join-Path $PSScriptRoot "MediaExplorer-Start.bat"

# Create start script
$startScript = @"
@echo off
title Media File Explorer
cd /d "$PSScriptRoot"
start /B npm start
timeout /t 3 /nobreak >nul
start http://localhost:3000
echo Media File Explorer is running at http://localhost:3000
echo Close this window to stop the application.
pause
"@

$startScript | Out-File -FilePath $targetPath -Encoding ASCII

# Create shortcut
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $targetPath
$Shortcut.WorkingDirectory = $PSScriptRoot  
$Shortcut.IconLocation = "$targetPath,0"
$Shortcut.Save()

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "        INSTALLATION COMPLETED!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "✓ All dependencies installed" -ForegroundColor Green
Write-Host "✓ Desktop shortcut created" -ForegroundColor Green
Write-Host ""
Write-Host "To start Media File Explorer:" -ForegroundColor White
Write-Host "  1. Double-click 'Media File Explorer' on desktop, OR" -ForegroundColor Yellow
Write-Host "  2. Double-click 'MediaExplorer-Start.bat' in this folder" -ForegroundColor Yellow
Write-Host ""
Write-Host "The application will open in your browser at:" -ForegroundColor White
Write-Host "  http://localhost:3000" -ForegroundColor Cyan
Write-Host ""

$start = Read-Host "Start Media File Explorer now? (Y/N)"
if ($start -eq "Y" -or $start -eq "y") {
    Write-Host "Starting Media File Explorer..." -ForegroundColor Green
    & $targetPath
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")