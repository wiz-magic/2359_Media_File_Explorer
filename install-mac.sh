#!/bin/bash

echo "================================================"
echo "   Media File Explorer - macOS/Linux 설치"
echo "================================================"
echo

# Node.js 확인
echo "[1/4] Node.js 확인 중..."
if ! command -v node &> /dev/null; then
    echo "❌ Node.js가 설치되어 있지 않습니다!"
    echo "https://nodejs.org 에서 설치해주세요."
    exit 1
fi
echo "✅ Node.js 확인 완료"

# npm 패키지 설치
echo
echo "[2/4] 필요한 패키지 설치 중..."
npm install
echo "✅ 패키지 설치 완료"

# 캐시 디렉토리 생성
echo
echo "[3/4] 캐시 폴더 생성 중..."
mkdir -p media-cache/thumbnails
echo "✅ 캐시 폴더 생성 완료"

# 실행 권한 부여
echo
echo "[4/4] 실행 권한 설정 중..."
chmod +x start.sh
echo "✅ 설정 완료"

echo
echo "================================================"
echo "   ✅ 설치가 완료되었습니다!"
echo "================================================"
echo
echo "실행: ./start.sh"
echo

