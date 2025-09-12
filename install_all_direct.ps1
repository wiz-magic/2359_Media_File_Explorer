# ===================================================================
# 자동 개발 환경 설치 스크립트 (PowerShell)
#
# 기능: Node.js, Python, FFmpeg 자동 설치 및 환경 설정
# 실행 방법: 파일을 우클릭하여 'PowerShell에서 실행' 클릭
# 주의: 스크립트 실행을 위해 관리자 권한이 필요할 수 있습니다.
# ===================================================================

# 스크립트 실행 정책 임시 변경 (필요한 경우)
Set-ExecutionPolicy Bypass -Scope Process -Force

Write-Host "===============================================" -ForegroundColor Green
Write-Host "   Media File Explorer - 자동 설치 스크립트" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "설치 순서: Node.js → Python → FFmpeg" -ForegroundColor Cyan
Write-Host ""

# --- 1. Node.js 설치 ---
Write-Host "1. Node.js 설치를 시작합니다..." -ForegroundColor Green
try {
    # 기존 Node.js 확인
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        Write-Host "    Node.js가 이미 설치되어 있습니다: $nodeVersion" -ForegroundColor Yellow
    } else {
        # 다운로드할 Node.js 버전 및 파일 정보
        $nodeUrl = "https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi"
        $nodeInstaller = "$env:TEMP\node-installer.msi"

        Write-Host "    Node.js v20.18.0 다운로드 중..." -ForegroundColor Yellow
        # 다운로드
        Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeInstaller

        Write-Host "    Node.js 설치 중..." -ForegroundColor Yellow
        # MSI 설치 파일을 조용한 모드로 실행 (/qn = UI 없음)
        Start-Process msiexec.exe -ArgumentList "/i `"$nodeInstaller`" /qn" -Wait
        
        # 환경변수 새로고침
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "    Node.js v20.18.0 설치 완료." -ForegroundColor Green
    }
} catch {
    Write-Host "    Node.js 설치 중 오류가 발생했습니다: $($_.Exception.Message)" -ForegroundColor Red
}

# --- 2. Python 설치 ---
Write-Host "`n2. Python 설치를 시작합니다..." -ForegroundColor Green
try {
    # 기존 Python 확인
    $pythonVersion = python --version 2>$null
    if ($pythonVersion) {
        Write-Host "    Python이 이미 설치되어 있습니다: $pythonVersion" -ForegroundColor Yellow
    } else {
        # 다운로드할 파이썬 버전 및 파일 정보
        $pythonUrl = "https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe"
        $pythonInstaller = "$env:TEMP\python-installer.exe"

        Write-Host "    Python 3.12.4 다운로드 중..." -ForegroundColor Yellow
        # 다운로드
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller

        Write-Host "    Python 설치 중..." -ForegroundColor Yellow
        # 조용한(Silent) 모드로 설치 (모든 사용자용, PATH 자동 추가)
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
        
        # 환경변수 새로고침
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "    Python 설치 완료." -ForegroundColor Green
    }
} catch {
    Write-Host "    Python 설치 중 오류가 발생했습니다: $($_.Exception.Message)" -ForegroundColor Red
}

# --- 3. FFmpeg 설치 (Winget 사용) ---
Write-Host "`n3. FFmpeg 설치를 시작합니다..." -ForegroundColor Green
try {
    # 기존 FFmpeg 확인
    $ffmpegVersion = ffmpeg -version 2>$null | Select-Object -First 1
    if ($ffmpegVersion) {
        Write-Host "    FFmpeg가 이미 설치되어 있습니다" -ForegroundColor Yellow
    } else {
        # Winget이 설치되어 있는지 확인
        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            Write-Host "    FFmpeg 설치 중 (Winget 사용)..." -ForegroundColor Yellow
            # --silent : UI 최소화, --accept-source-agreements : 라이선스 자동 동의
            winget install Gyan.FFmpeg --silent --accept-source-agreements
            
            # 환경변수 새로고침
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            Write-Host "    FFmpeg 설치 완료." -ForegroundColor Green
        } else {
            Write-Host "    Winget이 설치되어 있지 않아 FFmpeg를 자동 설치할 수 없습니다." -ForegroundColor Yellow
            Write-Host "    수동으로 https://ffmpeg.org/ 에서 다운로드하여 설치해 주세요." -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "    FFmpeg 설치 중 오류가 발생했습니다: $($_.Exception.Message)" -ForegroundColor Red
}

# --- 4. 프로젝트 의존성 설치 ---
Write-Host "`n4. 프로젝트 의존성 설치를 시작합니다..." -ForegroundColor Green
try {
    # 프로젝트 디렉토리로 이동
    Set-Location $PSScriptRoot
    
    if (Test-Path "package.json") {
        if (-not (Test-Path "node_modules")) {
            Write-Host "    npm 패키지 설치 중..." -ForegroundColor Yellow
            npm install
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    프로젝트 의존성 설치 완료!" -ForegroundColor Green
            } else {
                Write-Host "    일부 패키지 설치에 문제가 있을 수 있습니다." -ForegroundColor Yellow
            }
        } else {
            Write-Host "    의존성이 이미 설치되어 있습니다." -ForegroundColor Yellow
        }
    } else {
        Write-Host "    package.json 파일을 찾을 수 없습니다." -ForegroundColor Yellow
    }
} catch {
    Write-Host "    프로젝트 의존성 설치 중 오류가 발생했습니다: $($_.Exception.Message)" -ForegroundColor Red
}

# --- 5. 설치 확인 ---
Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host "           설치 결과 확인" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "아래 버전 정보가 올바르게 나오면 성공입니다." -ForegroundColor White
Write-Host ""

# 새로운 PowerShell 프로세스를 열어 환경 변수가 적용된 상태에서 버전을 확인합니다.
try {
    $nodeVer = powershell -NoProfile -Command "node --version 2>$null"
    if ($nodeVer) {
        Write-Host "✓ Node.js: $nodeVer" -ForegroundColor Green
    } else {
        Write-Host "✗ Node.js: 설치되지 않음 또는 PATH 설정 필요" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Node.js: 확인할 수 없음" -ForegroundColor Red
}

try {
    $pythonVer = powershell -NoProfile -Command "python --version 2>$null"
    if ($pythonVer) {
        Write-Host "✓ Python: $pythonVer" -ForegroundColor Green
    } else {
        Write-Host "✗ Python: 설치되지 않음 또는 PATH 설정 필요" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Python: 확인할 수 없음" -ForegroundColor Red
}

try {
    $ffmpegVer = powershell -NoProfile -Command "ffmpeg -version 2>$null | Select-Object -First 1"
    if ($ffmpegVer) {
        Write-Host "✓ FFmpeg: 설치됨" -ForegroundColor Green
    } else {
        Write-Host "✗ FFmpeg: 설치되지 않음 또는 PATH 설정 필요" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ FFmpeg: 확인할 수 없음" -ForegroundColor Red
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "         설치 스크립트 완료!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "설치가 완료되었습니다. 터미널을 다시 시작한 후 애플리케이션을 실행해 주세요." -ForegroundColor White
Write-Host ""
Write-Host "애플리케이션 실행 방법:" -ForegroundColor Cyan
Write-Host "  - MediaExplorer-Start.bat 실행" -ForegroundColor White
Write-Host "  - 또는 🚀 CLICK HERE TO START.bat 실행" -ForegroundColor White
Write-Host ""

# 사용자 입력 대기
Write-Host "아무 키나 눌러서 종료하세요..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")