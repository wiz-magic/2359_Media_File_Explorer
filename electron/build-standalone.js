#!/usr/bin/env node
/**
 * Electron 기반 독립 실행형 exe 빌드 스크립트
 * Python 설치 없이 완전히 독립적으로 실행 가능한 설치 파일을 생성합니다.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');
const { createWriteStream } = require('fs');
const { pipeline } = require('stream');
const { promisify } = require('util');
const streamPipeline = promisify(pipeline);

class ElectronBuilder {
  constructor() {
    this.rootDir = path.join(__dirname, '..');
    this.electronDir = __dirname;
    this.distDir = path.join(this.electronDir, 'dist');
    
    // 다운로드 URL
    this.ffmpegUrl = 'https://www.gyan.dev/ffmpeg/builds/packages/release/ffmpeg-7.0.2-essentials_build.zip';
    this.nodeUrl = 'https://nodejs.org/dist/v20.11.0/node-v20.11.0-win-x64.zip';
  }

  log(message, type = 'info') {
    const prefix = {
      info: '📘',
      success: '✅',
      error: '❌',
      warning: '⚠️',
      progress: '🔄'
    };
    console.log(`${prefix[type]} ${message}`);
  }

  async downloadFile(url, destPath) {
    this.log(`다운로드 중: ${url}`, 'progress');
    
    return new Promise((resolve, reject) => {
      const file = createWriteStream(destPath);
      
      https.get(url, (response) => {
        if (response.statusCode === 302 || response.statusCode === 301) {
          // 리다이렉트 처리
          return this.downloadFile(response.headers.location, destPath)
            .then(resolve)
            .catch(reject);
        }
        
        const totalSize = parseInt(response.headers['content-length'], 10);
        let downloadedSize = 0;
        
        response.on('data', (chunk) => {
          downloadedSize += chunk.length;
          const percent = ((downloadedSize / totalSize) * 100).toFixed(1);
          process.stdout.write(`\r  진행률: ${percent}%`);
        });
        
        response.pipe(file);
        
        file.on('finish', () => {
          file.close();
          console.log(''); // 새 줄
          this.log('다운로드 완료', 'success');
          resolve();
        });
      }).on('error', (err) => {
        fs.unlink(destPath, () => {});
        reject(err);
      });
    });
  }

  async downloadFFmpeg() {
    const ffmpegZip = path.join(this.electronDir, 'ffmpeg.zip');
    const ffmpegDir = path.join(this.electronDir, 'ffmpeg');
    
    if (fs.existsSync(ffmpegDir)) {
      this.log('FFmpeg가 이미 존재합니다', 'info');
      return;
    }
    
    if (!fs.existsSync(ffmpegZip)) {
      await this.downloadFile(this.ffmpegUrl, ffmpegZip);
    }
    
    this.log('FFmpeg 압축 해제 중...', 'progress');
    
    // unzip 명령어 사용 (Windows의 경우 PowerShell 사용)
    if (process.platform === 'win32') {
      execSync(`powershell -Command "Expand-Archive -Path '${ffmpegZip}' -DestinationPath '${this.electronDir}' -Force"`);
      
      // 압축 해제된 폴더 이름 변경
      const extractedDir = fs.readdirSync(this.electronDir).find(dir => dir.startsWith('ffmpeg-'));
      if (extractedDir) {
        fs.renameSync(
          path.join(this.electronDir, extractedDir),
          ffmpegDir
        );
      }
    } else {
      execSync(`unzip -q "${ffmpegZip}" -d "${this.electronDir}"`);
    }
    
    this.log('FFmpeg 준비 완료', 'success');
  }

  async downloadNode() {
    const nodeZip = path.join(this.electronDir, 'node.zip');
    const nodeDir = path.join(this.electronDir, 'node');
    
    if (fs.existsSync(nodeDir)) {
      this.log('Node.js가 이미 존재합니다', 'info');
      return;
    }
    
    if (!fs.existsSync(nodeZip)) {
      await this.downloadFile(this.nodeUrl, nodeZip);
    }
    
    this.log('Node.js 압축 해제 중...', 'progress');
    
    if (process.platform === 'win32') {
      execSync(`powershell -Command "Expand-Archive -Path '${nodeZip}' -DestinationPath '${this.electronDir}' -Force"`);
      
      // 압축 해제된 폴더 이름 변경
      const extractedDir = fs.readdirSync(this.electronDir).find(dir => dir.startsWith('node-'));
      if (extractedDir) {
        fs.renameSync(
          path.join(this.electronDir, extractedDir),
          nodeDir
        );
      }
    } else {
      execSync(`unzip -q "${nodeZip}" -d "${this.electronDir}"`);
    }
    
    this.log('Node.js 준비 완료', 'success');
  }

  createIcon() {
    // 간단한 아이콘 생성 (실제로는 ico 파일이 필요)
    const iconPath = path.join(this.electronDir, 'icon.ico');
    if (!fs.existsSync(iconPath)) {
      this.log('아이콘 파일을 생성합니다 (임시)', 'warning');
      // 실제로는 적절한 .ico 파일이 필요합니다
      fs.writeFileSync(iconPath, '');
    }
  }

  installDependencies() {
    this.log('Electron 의존성 설치 중...', 'progress');
    
    try {
      execSync('npm install', {
        cwd: this.electronDir,
        stdio: 'inherit'
      });
      this.log('의존성 설치 완료', 'success');
    } catch (error) {
      this.log(`의존성 설치 실패: ${error.message}`, 'error');
      throw error;
    }
  }

  buildElectron() {
    this.log('Electron 앱 빌드 중...', 'progress');
    
    try {
      // Windows installer와 portable 버전 모두 빌드
      execSync('npm run build-win', {
        cwd: this.electronDir,
        stdio: 'inherit',
        env: {
          ...process.env,
          CSC_IDENTITY_AUTO_DISCOVERY: false // 코드 서명 비활성화
        }
      });
      
      this.log('빌드 완료!', 'success');
      
      // 빌드 결과 확인
      const installerPath = path.join(this.distDir, 'Media File Explorer Setup 1.0.0.exe');
      const portablePath = path.join(this.distDir, 'MediaExplorer-Portable-1.0.0.exe');
      
      if (fs.existsSync(installerPath)) {
        const size = (fs.statSync(installerPath).size / 1024 / 1024).toFixed(1);
        this.log(`설치 파일: ${installerPath} (${size} MB)`, 'success');
      }
      
      if (fs.existsSync(portablePath)) {
        const size = (fs.statSync(portablePath).size / 1024 / 1024).toFixed(1);
        this.log(`포터블 파일: ${portablePath} (${size} MB)`, 'success');
      }
      
    } catch (error) {
      this.log(`빌드 실패: ${error.message}`, 'error');
      throw error;
    }
  }

  async build() {
    console.log('');
    console.log('='.repeat(50));
    console.log('   Media File Explorer Electron 빌드 시작');
    console.log('='.repeat(50));
    console.log('');
    
    try {
      // 1. FFmpeg 다운로드 (선택사항)
      // await this.downloadFFmpeg();
      
      // 2. Node.js 포터블 다운로드
      // await this.downloadNode();
      
      // 3. 아이콘 생성
      this.createIcon();
      
      // 4. 의존성 설치
      this.installDependencies();
      
      // 5. Electron 빌드
      this.buildElectron();
      
      console.log('');
      console.log('='.repeat(50));
      this.log('빌드가 성공적으로 완료되었습니다!', 'success');
      console.log('');
      console.log('📦 생성된 파일:');
      console.log(`   - 설치 프로그램: electron/dist/Media File Explorer Setup 1.0.0.exe`);
      console.log(`   - 포터블 버전: electron/dist/MediaExplorer-Portable-1.0.0.exe`);
      console.log('');
      console.log('설치 프로그램은 Python이나 Node.js 없이도 실행됩니다!');
      console.log('='.repeat(50));
      
    } catch (error) {
      this.log(`빌드 중 오류 발생: ${error.message}`, 'error');
      process.exit(1);
    }
  }
}

// 실행
if (require.main === module) {
  const builder = new ElectronBuilder();
  builder.build();
}