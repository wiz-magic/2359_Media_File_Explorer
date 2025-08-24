# Media Explorer 원파일 설치 프로그램 생성 스크립트
# 이 스크립트는 자체 압축 해제 실행 파일을 생성합니다

$ErrorActionPreference = "Stop"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "   Media Explorer 원파일 설치 프로그램 생성" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# 7-Zip 확인
$7zipPath = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path $7zipPath)) {
    Write-Host "7-Zip이 설치되지 않았습니다." -ForegroundColor Red
    Write-Host "https://www.7-zip.org 에서 다운로드하세요." -ForegroundColor Yellow
    exit 1
}

# 빌드 디렉토리 확인
$outputDir = Join-Path $PSScriptRoot "output"
if (-not (Test-Path $outputDir)) {
    Write-Host "먼저 build_windows.py를 실행하여 빌드를 완료하세요." -ForegroundColor Red
    exit 1
}

# SFX 설정 파일 생성
$sfxConfig = @"
;!@Install@!UTF-8!
Title="Media File Explorer 설치"
BeginPrompt="Media File Explorer를 설치하시겠습니까?\n\n주요 기능:\n- 모든 미디어 파일 검색\n- 썸네일 자동 생성\n- 비디오 미리보기 (FFmpeg 포함)\n- 빠른 파일 검색"
RunProgram="install.bat"
;!@InstallEnd@!
"@

$configFile = Join-Path $PSScriptRoot "sfx_config.txt"
$sfxConfig | Out-File -FilePath $configFile -Encoding UTF8

# 임시 아카이브 생성
Write-Host "아카이브 생성 중..." -ForegroundColor Yellow
$tempArchive = Join-Path $PSScriptRoot "temp_installer.7z"

# install.bat을 output 디렉토리로 복사
$installBat = Join-Path (Split-Path $outputDir) "install.bat"
if (Test-Path $installBat) {
    Copy-Item $installBat -Destination $outputDir -Force
}

# 7z 아카이브 생성
& $7zipPath a -t7z -mx=9 -mfb=256 -md=64m $tempArchive "$outputDir\*"

# SFX 모듈 경로
$sfxModule = "C:\Program Files\7-Zip\7z.sfx"

# 최종 실행 파일 생성
Write-Host "실행 파일 생성 중..." -ForegroundColor Yellow
$finalExe = Join-Path $PSScriptRoot "MediaExplorer_Setup.exe"

# SFX 실행 파일 결합
$sfxBytes = [System.IO.File]::ReadAllBytes($sfxModule)
$configBytes = [System.Text.Encoding]::UTF8.GetBytes($sfxConfig)
$archiveBytes = [System.IO.File]::ReadAllBytes($tempArchive)

$finalBytes = $sfxBytes + $configBytes + $archiveBytes
[System.IO.File]::WriteAllBytes($finalExe, $finalBytes)

# 임시 파일 정리
Remove-Item $tempArchive -Force
Remove-Item $configFile -Force

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "✅ 원파일 설치 프로그램 생성 완료!" -ForegroundColor Green
Write-Host "📦 파일: $finalExe" -ForegroundColor Green
$fileSize = (Get-Item $finalExe).Length / 1MB
Write-Host "📊 크기: $([math]::Round($fileSize, 1)) MB" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green