# Media File Explorer - Clean Installation Script
# No Korean characters to avoid encoding issues

param(
    [switch]$AsAdmin
)

# Check administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin -and -not $AsAdmin) {
    Write-Host "Administrator privileges required. Restarting with admin rights..." -ForegroundColor Yellow
    try {
        Start-Process PowerShell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -AsAdmin" -Verb RunAs -Wait
        exit 0
    } catch {
        Write-Host "Failed to get administrator privileges. Please run as administrator manually." -ForegroundColor Red
        Write-Host "Press any key to exit..."
        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
        exit 1
    }
}

# Set execution policy
try {
    Set-ExecutionPolicy Bypass -Scope Process -Force
} catch {
    Write-Host "Failed to set execution policy. Continuing..." -ForegroundColor Yellow
}

Write-Host "===============================================" -ForegroundColor Green
Write-Host "   Media File Explorer - Auto Setup Script" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installation order: Node.js -> Python -> FFmpeg" -ForegroundColor Cyan
Write-Host ""

# --- 1. Install Node.js ---
Write-Host "1. Installing Node.js..." -ForegroundColor Green
try {
    # Check if Node.js is already installed
    $nodeInstalled = $false
    try {
        $nodeVersion = cmd /c "node --version 2>nul"
        if ($nodeVersion -and $nodeVersion.StartsWith("v")) {
            Write-Host "    Node.js already installed: $nodeVersion" -ForegroundColor Yellow
            $nodeInstalled = $true
        }
    } catch {
        # Node.js not found, proceed with installation
    }
    
    if (-not $nodeInstalled) {
        $nodeUrl = "https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi"
        $nodeInstaller = "$env:TEMP\node-installer.msi"

        Write-Host "    Downloading Node.js v20.18.0..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeInstaller

        Write-Host "    Installing Node.js..." -ForegroundColor Yellow
        Start-Process msiexec.exe -ArgumentList "/i `"$nodeInstaller`" /qn" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "    Node.js v20.18.0 installation completed." -ForegroundColor Green
    }
} catch {
    Write-Host "    Node.js installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# --- 2. Install Python ---
Write-Host "`n2. Installing Python..." -ForegroundColor Green
try {
    # Check if Python is already installed
    $pythonInstalled = $false
    try {
        $pythonVersion = cmd /c "python --version 2>nul"
        if ($pythonVersion -and $pythonVersion.Contains("Python")) {
            Write-Host "    Python already installed: $pythonVersion" -ForegroundColor Yellow
            $pythonInstalled = $true
        }
    } catch {
        # Python not found, proceed with installation
    }
    
    if (-not $pythonInstalled) {
        $pythonUrl = "https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe"
        $pythonInstaller = "$env:TEMP\python-installer.exe"

        Write-Host "    Downloading Python 3.12.4..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller

        Write-Host "    Installing Python..." -ForegroundColor Yellow
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "    Python installation completed." -ForegroundColor Green
    }
} catch {
    Write-Host "    Python installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# --- 3. Install FFmpeg ---
Write-Host "`n3. Installing FFmpeg..." -ForegroundColor Green
try {
    # Check if FFmpeg is already installed
    $ffmpegInstalled = $false
    try {
        $ffmpegVersion = cmd /c "ffmpeg -version 2>nul"
        if ($ffmpegVersion -and $ffmpegVersion.Contains("ffmpeg version")) {
            Write-Host "    FFmpeg already installed" -ForegroundColor Yellow
            $ffmpegInstalled = $true
        }
    } catch {
        # FFmpeg not found, proceed with installation
    }
    
    if (-not $ffmpegInstalled) {
        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            Write-Host "    Installing FFmpeg using Winget..." -ForegroundColor Yellow
            winget install Gyan.FFmpeg --silent --accept-source-agreements --accept-package-agreements
            
            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            Write-Host "    FFmpeg installation completed." -ForegroundColor Green
        } else {
            Write-Host "    Winget not available. FFmpeg not installed automatically." -ForegroundColor Yellow
            Write-Host "    Please download from https://ffmpeg.org/ manually." -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "    FFmpeg installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# --- 4. Install project dependencies ---
Write-Host "`n4. Installing project dependencies..." -ForegroundColor Green
try {
    Set-Location $PSScriptRoot
    
    if (Test-Path "package.json") {
        if (-not (Test-Path "node_modules")) {
            Write-Host "    Installing npm packages..." -ForegroundColor Yellow
            # Try to use npm, if not available, skip with warning
            try {
                $npmVersion = cmd /c "npm --version 2>nul"
                if ($npmVersion) {
                    & npm install
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "    Project dependencies installation completed!" -ForegroundColor Green
                    } else {
                        Write-Host "    Some packages may not have installed correctly." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "    npm not found. Please restart terminal and run 'npm install' manually." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "    npm not available yet. Please restart terminal and run 'npm install' manually." -ForegroundColor Yellow
            }
        } else {
            Write-Host "    Dependencies already installed." -ForegroundColor Yellow
        }
    } else {
        Write-Host "    package.json file not found." -ForegroundColor Yellow
    }
} catch {
    Write-Host "    Project dependency installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# --- 5. Installation verification ---
Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host "           Installation Results" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Below versions should appear if installation was successful." -ForegroundColor White
Write-Host ""

# Verify installations using CMD to avoid PowerShell cmdlet errors
try {
    $nodeVer = cmd /c "node --version 2>nul"
    if ($nodeVer -and $nodeVer.StartsWith("v")) {
        Write-Host "Node.js: $nodeVer" -ForegroundColor Green
    } else {
        Write-Host "Node.js: NOT INSTALLED or PATH needs refresh" -ForegroundColor Red
    }
} catch {
    Write-Host "Node.js: Cannot verify" -ForegroundColor Red
}

try {
    $pythonVer = cmd /c "python --version 2>nul"
    if ($pythonVer -and $pythonVer.Contains("Python")) {
        Write-Host "Python: $pythonVer" -ForegroundColor Green
    } else {
        Write-Host "Python: NOT INSTALLED or PATH needs refresh" -ForegroundColor Red
    }
} catch {
    Write-Host "Python: Cannot verify" -ForegroundColor Red
}

try {
    $ffmpegVer = cmd /c "ffmpeg -version 2>nul"
    if ($ffmpegVer -and $ffmpegVer.Contains("ffmpeg version")) {
        Write-Host "FFmpeg: Installed" -ForegroundColor Green
    } else {
        Write-Host "FFmpeg: NOT INSTALLED or PATH needs refresh" -ForegroundColor Red
    }
} catch {
    Write-Host "FFmpeg: Cannot verify" -ForegroundColor Red
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "         Setup Script Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installation completed. Please restart your terminal and run the application." -ForegroundColor White
Write-Host ""
Write-Host "To start the application:" -ForegroundColor Cyan
Write-Host "  - Run MediaExplorer-Start.bat" -ForegroundColor White
Write-Host "  - Or run START-HERE-WINDOWS.bat" -ForegroundColor White
Write-Host ""

# Wait for user input
Write-Host "Press any key to exit..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null