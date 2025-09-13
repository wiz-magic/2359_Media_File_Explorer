#!/bin/bash

echo "================================================"
echo "🎮 Intel Iris Xe Graphics GPU 가속 설정 도구"
echo "================================================"

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# OS 감지
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
else
    OS="unknown"
fi

echo "🖥️  운영체제: $OS"
echo ""

# Intel GPU 감지
echo "🔍 Intel GPU 감지 중..."

if [ "$OS" == "linux" ]; then
    # Linux에서 Intel GPU 감지
    if [ -e /dev/dri/renderD128 ]; then
        echo -e "${GREEN}✅ Intel GPU 디바이스 감지됨: /dev/dri/renderD128${NC}"
        
        # 권한 확인
        if [ -r /dev/dri/renderD128 ] && [ -w /dev/dri/renderD128 ]; then
            echo -e "${GREEN}✅ GPU 접근 권한 정상${NC}"
        else
            echo -e "${YELLOW}⚠️  GPU 권한 설정 필요${NC}"
            echo "   실행: sudo usermod -a -G video,render $USER"
        fi
        
        # VA-API 드라이버 확인
        if command -v vainfo &> /dev/null; then
            echo -e "${GREEN}✅ VA-API 설치됨${NC}"
            vainfo 2>/dev/null | head -5
        else
            echo -e "${YELLOW}⚠️  VA-API 미설치${NC}"
            echo "   설치 명령어:"
            echo "   sudo apt-get install vainfo intel-media-va-driver i965-va-driver"
        fi
        
        # Intel Media SDK 확인
        if [ -d "/opt/intel/mediasdk" ]; then
            echo -e "${GREEN}✅ Intel Media SDK 설치됨${NC}"
        else
            echo -e "${YELLOW}ℹ️  Intel Media SDK 미설치 (선택사항)${NC}"
            echo "   더 나은 QSV 성능을 위해 설치 권장"
        fi
        
    else
        echo -e "${RED}❌ Intel GPU 디바이스를 찾을 수 없음${NC}"
    fi
    
    # Intel GPU 도구 확인
    if command -v intel_gpu_top &> /dev/null; then
        echo -e "${GREEN}✅ Intel GPU Tools 설치됨${NC}"
    else
        echo -e "${YELLOW}ℹ️  Intel GPU Tools 미설치${NC}"
        echo "   설치: sudo apt-get install intel-gpu-tools"
    fi

elif [ "$OS" == "windows" ]; then
    echo "🪟 Windows에서 Intel Iris Xe Graphics 설정"
    echo ""
    echo "1. Intel Graphics Driver 최신 버전 확인:"
    echo "   https://www.intel.com/content/www/us/en/support/detect.html"
    echo ""
    echo "2. FFmpeg QSV 지원 버전 확인:"
    echo "   ffmpeg -encoders | findstr qsv"
    echo ""
    echo "3. 드라이버 설치 후 시스템 재시작 필요"
    
elif [ "$OS" == "macos" ]; then
    echo "🍎 macOS는 VideoToolbox 사용 (QSV 대신)"
    echo "   FFmpeg에서 자동으로 활용됨"
fi

echo ""
echo "================================================"
echo "📊 FFmpeg 하드웨어 가속 테스트"
echo "================================================"

# FFmpeg QSV 지원 확인
echo "🔧 FFmpeg QSV 인코더 확인..."
if ffmpeg -encoders 2>&1 | grep -q "h264_qsv"; then
    echo -e "${GREEN}✅ h264_qsv 인코더 사용 가능${NC}"
else
    echo -e "${RED}❌ h264_qsv 인코더 없음${NC}"
fi

if ffmpeg -encoders 2>&1 | grep -q "hevc_qsv"; then
    echo -e "${GREEN}✅ hevc_qsv 인코더 사용 가능${NC}"
else
    echo -e "${YELLOW}⚠️  hevc_qsv 인코더 없음${NC}"
fi

if ffmpeg -encoders 2>&1 | grep -q "mjpeg_qsv"; then
    echo -e "${GREEN}✅ mjpeg_qsv 인코더 사용 가능 (썸네일에 최적)${NC}"
else
    echo -e "${YELLOW}⚠️  mjpeg_qsv 인코더 없음${NC}"
fi

# VA-API 지원 확인
echo ""
echo "🔧 FFmpeg VA-API 인코더 확인..."
if ffmpeg -encoders 2>&1 | grep -q "h264_vaapi"; then
    echo -e "${GREEN}✅ h264_vaapi 인코더 사용 가능${NC}"
else
    echo -e "${YELLOW}⚠️  h264_vaapi 인코더 없음${NC}"
fi

# 실제 테스트
echo ""
echo "================================================"
echo "⚡ 실제 가속 테스트 (10초 소요)"
echo "================================================"

# 테스트 비디오 생성
TEST_VIDEO="/tmp/test_video.mp4"
TEST_THUMB="/tmp/test_thumb.jpg"

echo "📹 테스트 비디오 생성 중..."
ffmpeg -f lavfi -i testsrc2=duration=5:size=1920x1080:rate=30 -c:v libx264 -preset ultrafast "$TEST_VIDEO" -y 2>/dev/null

if [ -f "$TEST_VIDEO" ]; then
    echo "✅ 테스트 비디오 생성 완료"
    
    # CPU 버전 테스트
    echo ""
    echo "🖥️  CPU 버전 테스트..."
    START=$(date +%s%N)
    ffmpeg -i "$TEST_VIDEO" -ss 1 -vframes 1 -vf scale=200:200 -q:v 5 "${TEST_THUMB}_cpu.jpg" -y 2>/dev/null
    END=$(date +%s%N)
    CPU_TIME=$((($END - $START) / 1000000))
    echo "   처리 시간: ${CPU_TIME}ms"
    
    # QSV 테스트
    echo ""
    echo "🚀 QSV 가속 테스트..."
    START=$(date +%s%N)
    ffmpeg -init_hw_device qsv=hw -filter_hw_device hw -i "$TEST_VIDEO" -ss 1 -vframes 1 \
           -vf "hwupload=extra_hw_frames=64,format=qsv,scale_qsv=200:200,hwdownload,format=nv12" \
           -c:v mjpeg_qsv "${TEST_THUMB}_qsv.jpg" -y 2>/dev/null
    END=$(date +%s%N)
    QSV_TIME=$((($END - $START) / 1000000))
    
    if [ -f "${TEST_THUMB}_qsv.jpg" ]; then
        echo -e "${GREEN}   ✅ QSV 성공! 처리 시간: ${QSV_TIME}ms${NC}"
        SPEEDUP=$(echo "scale=1; $CPU_TIME / $QSV_TIME" | bc 2>/dev/null || echo "N/A")
        echo "   🎯 속도 향상: ${SPEEDUP}x"
    else
        echo -e "${RED}   ❌ QSV 실패${NC}"
    fi
    
    # VA-API 테스트
    echo ""
    echo "🚀 VA-API 가속 테스트..."
    START=$(date +%s%N)
    ffmpeg -vaapi_device /dev/dri/renderD128 -i "$TEST_VIDEO" -ss 1 -vframes 1 \
           -vf "format=nv12,hwupload,scale_vaapi=200:200,hwdownload,format=nv12" \
           "${TEST_THUMB}_vaapi.jpg" -y 2>/dev/null
    END=$(date +%s%N)
    VAAPI_TIME=$((($END - $START) / 1000000))
    
    if [ -f "${TEST_THUMB}_vaapi.jpg" ]; then
        echo -e "${GREEN}   ✅ VA-API 성공! 처리 시간: ${VAAPI_TIME}ms${NC}"
        SPEEDUP=$(echo "scale=1; $CPU_TIME / $VAAPI_TIME" | bc 2>/dev/null || echo "N/A")
        echo "   🎯 속도 향상: ${SPEEDUP}x"
    else
        echo -e "${YELLOW}   ⚠️  VA-API 실패${NC}"
    fi
    
    # 정리
    rm -f "$TEST_VIDEO" "${TEST_THUMB}"*.jpg
fi

echo ""
echo "================================================"
echo "💡 권장 설정"
echo "================================================"

if [ "$OS" == "linux" ]; then
    echo "1. Intel Media Driver 설치:"
    echo "   sudo apt-get update"
    echo "   sudo apt-get install intel-media-va-driver-non-free"
    echo ""
    echo "2. 환경 변수 설정 (~/.bashrc에 추가):"
    echo "   export LIBVA_DRIVER_NAME=iHD"
    echo "   export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri"
    echo ""
    echo "3. 권한 설정:"
    echo "   sudo usermod -a -G video,render $USER"
    echo "   (로그아웃 후 재로그인 필요)"
elif [ "$OS" == "windows" ]; then
    echo "1. Intel Graphics Driver 최신 버전 설치"
    echo "2. FFmpeg 최신 버전 설치 (QSV 지원 버전)"
    echo "3. Windows 설정 > 그래픽 설정에서 하드웨어 가속 GPU 스케줄링 활성화"
fi

echo ""
echo "================================================"
echo "✅ 설정 완료 후 서버 재시작:"
echo "   pm2 restart all"
echo "================================================"