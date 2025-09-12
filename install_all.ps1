# One-Click Installer (Wrapper)
# Purpose: Run the main setup script with proper execution policy in a single click
# 실행 방법: install_all.bat 파일을 더블클릭하여 실행하세요

param(
    [switch]$AsAdmin
)

# 관리자 권한 확인 및 요청
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin -and -not $AsAdmin) {
    Write-Host "관리자 권한이 필요합니다. 관리자 권한으로 다시 시작합니다..." -ForegroundColor Yellow
    try {
        Start-Process PowerShell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -AsAdmin" -Verb RunAs -Wait
        exit 0
    } catch {
        Write-Host "관리자 권한 획득에 실패했습니다. install_all.bat 파일을 사용해주세요." -ForegroundColor Red
        Write-Host "아무 키나 눌러서 종료..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

# Allow running this script
try {
    Set-ExecutionPolicy Bypass -Scope Process -Force
} catch {
    Write-Host "실행 정책 변경 실패. 계속 진행합니다..." -ForegroundColor Yellow
}

# Re-run as Admin if needed (delegates elevation to the main script afterward too)
$scriptPath = Join-Path $PSScriptRoot "MediaExplorer-Setup.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Host "MediaExplorer-Setup.ps1 not found next to this file." -ForegroundColor Red
    Write-Host "대신 install_all.bat 파일을 사용해주세요." -ForegroundColor Yellow
    Write-Host "아무 키나 눌러서 종료..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Invoke the main setup script
try {
    & powershell -ExecutionPolicy Bypass -File "$scriptPath" @PSBoundParameters -AsAdmin
} catch {
    Write-Host "스크립트 실행 중 오류가 발생했습니다: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "대신 install_all.bat 파일을 사용해주세요." -ForegroundColor Yellow
    Write-Host "아무 키나 눌러서 종료..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
