# Media File Explorer - PowerShell Installer
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
$installPath = "$env:ProgramFiles\MediaFileExplorer"

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
Copy-Item -Path ".\*" -Destination $installPath -Recurse -Force

# Create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Media File Explorer.lnk")
$Shortcut.TargetPath = "$installPath\Start Media Explorer.bat"
$Shortcut.WorkingDirectory = $installPath
$Shortcut.IconLocation = "shell32.dll,3"
$Shortcut.Save()

# Create Start Menu shortcut
$startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$Shortcut = $WshShell.CreateShortcut("$startMenuPath\Media File Explorer.lnk")
$Shortcut.TargetPath = "$installPath\Start Media Explorer.bat"
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
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")