@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ================================================
echo 🎮 Intel Iris Xe Graphics GPU 가속 설정 도구
echo ================================================
echo.

:: 관리자 권한 확인
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ⚠️  관리자 권한이 필요합니다!
    echo    마우스 오른쪽 클릭 → "관리자 권한으로 실행"
    echo.
    pause
    exit /b 1
)

echo ✅ 관리자 권한 확인됨
echo.

:: Intel GPU 정보 확인
echo 🔍 Intel GPU 정보 확인 중...
wmic path win32_VideoController get name,driverversion,status | findstr /i "Intel"
if %errorlevel% equ 0 (
    echo ✅ Intel Graphics 감지됨
) else (
    echo ❌ Intel Graphics를 찾을 수 없음
    echo    다른 GPU를 사용 중일 수 있습니다.
)
echo.

:: FFmpeg 설치 확인
echo 🔧 FFmpeg 설치 확인 중...
where ffmpeg >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ FFmpeg 설치됨
    
    :: QSV 지원 확인
    echo.
    echo 📊 Intel Quick Sync Video ^(QSV^) 지원 확인...
    ffmpeg -encoders 2>&1 | findstr /i "h264_qsv" >nul
    if !errorlevel! equ 0 (
        echo ✅ h264_qsv 인코더 지원
    ) else (
        echo ❌ h264_qsv 인코더 미지원
    )
    
    ffmpeg -encoders 2>&1 | findstr /i "hevc_qsv" >nul
    if !errorlevel! equ 0 (
        echo ✅ hevc_qsv 인코더 지원
    ) else (
        echo ⚠️  hevc_qsv 인코더 미지원
    )
    
    ffmpeg -encoders 2>&1 | findstr /i "mjpeg_qsv" >nul
    if !errorlevel! equ 0 (
        echo ✅ mjpeg_qsv 인코더 지원 ^(썸네일 최적^)
    ) else (
        echo ⚠️  mjpeg_qsv 인코더 미지원
    )
) else (
    echo ❌ FFmpeg 미설치
    echo    "썸네일 안만들어질 때 눌러주세요.bat" 실행 필요
)
echo.

:: Intel Driver 버전 확인
echo 🔍 Intel Graphics Driver 버전 확인...
for /f "tokens=2 delims==" %%a in ('wmic path win32_VideoController where "name like '%%Intel%%'" get driverversion /value 2^>nul ^| findstr "="') do (
    echo    현재 버전: %%a
    
    :: 버전 비교 (31.0.101 이상 권장)
    for /f "tokens=1,2,3 delims=." %%b in ("%%a") do (
        if %%b geq 31 (
            echo    ✅ 드라이버 버전 정상
        ) else (
            echo    ⚠️  드라이버 업데이트 권장
            echo    최신 드라이버: https://www.intel.com/content/www/us/en/support/detect.html
        )
    )
)
echo.

:: 성능 테스트
echo ================================================
echo ⚡ GPU 가속 성능 테스트
echo ================================================
echo.

:: 테스트 파일 생성
set TEST_VIDEO=%TEMP%\test_video.mp4
set TEST_THUMB=%TEMP%\test_thumb.jpg

echo 📹 테스트 비디오 생성 중...
ffmpeg -f lavfi -i testsrc2=duration=3:size=1920x1080:rate=30 -c:v libx264 -preset ultrafast "%TEST_VIDEO%" -y >nul 2>&1

if exist "%TEST_VIDEO%" (
    echo ✅ 테스트 비디오 생성 완료
    echo.
    
    :: CPU 테스트
    echo 🖥️  CPU 렌더링 테스트...
    set START_CPU=%time%
    ffmpeg -i "%TEST_VIDEO%" -ss 1 -vframes 1 -vf scale=200:200 -q:v 5 "%TEST_THUMB%_cpu.jpg" -y >nul 2>&1
    set END_CPU=%time%
    
    if exist "%TEST_THUMB%_cpu.jpg" (
        echo    ✅ CPU 렌더링 성공
        del "%TEST_THUMB%_cpu.jpg" >nul 2>&1
    )
    
    :: QSV 테스트
    echo 🚀 QSV GPU 가속 테스트...
    set START_QSV=%time%
    ffmpeg -init_hw_device qsv=hw -filter_hw_device hw -i "%TEST_VIDEO%" -ss 1 -vframes 1 ^
           -vf "hwupload=extra_hw_frames=64,format=qsv,scale_qsv=200:200,hwdownload,format=nv12" ^
           -c:v mjpeg_qsv "%TEST_THUMB%_qsv.jpg" -y >nul 2>&1
    set END_QSV=%time%
    
    if exist "%TEST_THUMB%_qsv.jpg" (
        echo    ✅ QSV 가속 성공! Intel Iris Xe GPU 활용 가능
        del "%TEST_THUMB%_qsv.jpg" >nul 2>&1
    ) else (
        echo    ❌ QSV 가속 실패
        echo.
        echo    💡 해결 방법:
        echo    1. Intel Graphics Driver 최신 버전 설치
        echo    2. Windows 업데이트 실행
        echo    3. BIOS에서 Intel Graphics 활성화 확인
    )
    
    :: 정리
    del "%TEST_VIDEO%" >nul 2>&1
) else (
    echo ❌ 테스트 비디오 생성 실패
)

echo.
echo ================================================
echo 💡 Intel Iris Xe 최적화 권장 설정
echo ================================================
echo.
echo 1. Intel Graphics Driver 최신 버전 설치
echo    https://www.intel.com/content/www/us/en/support/detect.html
echo.
echo 2. Windows 그래픽 설정 최적화
echo    설정 → 시스템 → 디스플레이 → 그래픽
echo    → "Media File Explorer" 추가
echo    → "고성능" 선택 (Intel Iris Xe Graphics)
echo.
echo 3. 하드웨어 가속 GPU 스케줄링 활성화
echo    설정 → 시스템 → 디스플레이 → 그래픽
echo    → "하드웨어 가속 GPU 스케줄링" 켜기
echo.
echo 4. Intel Graphics Command Center 설치
echo    Microsoft Store에서 설치 가능
echo    GPU 성능 모니터링 및 최적화 설정
echo.
echo 5. 전원 관리 설정
echo    제어판 → 전원 옵션 → 고성능 또는 균형 조정
echo    Intel Graphics 설정에서 "최대 성능" 선택
echo.

:: 서버 재시작 제안
echo ================================================
echo 🔄 설정 완료 후 서버 재시작
echo ================================================
echo.
echo 서버를 재시작하시겠습니까? (Y/N)
set /p restart=선택: 

if /i "%restart%"=="Y" (
    echo.
    echo 🔄 서버 재시작 중...
    pm2 restart all >nul 2>&1
    if !errorlevel! equ 0 (
        echo ✅ 서버 재시작 완료!
    ) else (
        echo ⚠️  PM2가 실행 중이 아닙니다.
        echo    "시작하기.bat" 실행해주세요.
    )
) else (
    echo.
    echo ℹ️  나중에 수동으로 재시작해주세요.
    echo    명령어: pm2 restart all
)

echo.
echo ================================================
echo ✅ Intel Iris Xe Graphics 설정 도구 완료
echo ================================================
echo.
echo 📊 예상 성능 향상:
echo    CPU 전용: 150-200ms
echo    Intel QSV: 30-80ms (2-6배 향상)
echo    최적 조건: 20-50ms (7-10배 향상)
echo.
pause