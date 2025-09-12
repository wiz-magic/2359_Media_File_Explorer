# One-Click Installer (Wrapper)
# Purpose: Run the main setup script with proper execution policy in a single click

param(
    [switch]$AsAdmin
)

# Allow running this script
Set-ExecutionPolicy Bypass -Scope Process -Force

# Re-run as Admin if needed (delegates elevation to the main script afterward too)
$scriptPath = Join-Path $PSScriptRoot "MediaExplorer-Setup.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Host "MediaExplorer-Setup.ps1 not found next to this file." -ForegroundColor Red
    exit 1
}

# Invoke the main setup script
& powershell -ExecutionPolicy Bypass -File "$scriptPath" @PSBoundParameters
