#!/bin/bash

echo "🚀 Media File Explorer Setup"
echo "=========================="

# 프로젝트 다운로드
echo "📦 Downloading project files..."
curl -L https://page.gensparksite.com/project_backups/toolu_01T6mEUUuhQ7qa7xg5b5Q9n2.tar.gz -o media-explorer.tar.gz

# 압축 해제
echo "📂 Extracting files..."
tar -xzf media-explorer.tar.gz
cd home/user/webapp

# 의존성 설치
echo "📦 Installing dependencies..."
npm install

# 실행
echo "✅ Starting server..."
npm start
