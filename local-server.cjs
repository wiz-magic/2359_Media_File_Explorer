/**
 * Media File Explorer - Local Standalone Server
 * 한글 검색, 파일 열기, 비디오 미리보기, 미디어 타입 필터, 북마크 기능 개선 버전
 */

const express = require('express');
const cors = require('cors');
const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');
const sharp = require('sharp');
const mime = require('mime-types');
const crypto = require('crypto');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);
const open = require('open');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware - UTF-8 인코딩 설정 추가
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.static('public'));

// Response 헤더에 UTF-8 설정
app.use((req, res, next) => {
    res.header('Content-Type', 'application/json; charset=utf-8');
    next();
});

// In-memory storage
const sessions = new Map();
const recentPaths = new Set();
const MAX_RECENT_PATHS = 10;

// Cache directory
const CACHE_DIR = path.join(__dirname, 'media-cache');
const THUMBNAILS_DIR = path.join(CACHE_DIR, 'thumbnails');
const VIDEO_THUMBNAILS_DIR = path.join(CACHE_DIR, 'video-thumbnails');
const CACHE_METADATA_FILE = path.join(CACHE_DIR, 'cache-metadata.json');

// 캐시 설정
const CACHE_CONFIG = {
    maxSizeGB: 5, // 최대 캐시 크기 (GB)
    maxFiles: 10000, // 최대 캐시 파일 수
    cleanupIntervalMs: 30 * 60 * 1000, // 30분마다 정리
    maxAgeMs: 7 * 24 * 60 * 60 * 1000, // 7일 후 만료
    compressionQuality: 80 // WebP 압축 품질
};

// GPU 가속 설정 캐시
const GPU_PERFORMANCE_CACHE_FILE = path.join(CACHE_DIR, 'gpu-performance.json');
let gpuPerformanceCache = {
    lastDetection: null,
    optimalAccelerator: null,
    performanceMetrics: {},
    systemFingerprint: null,
    detectionCount: 0
};

// 캐시 메타데이터 관리
let cacheMetadata = {
    files: new Map(),
    totalSize: 0,
    lastCleanup: Date.now()
};

// 시스템 핑거프린트 생성 (하드웨어 변경 감지용)
function generateSystemFingerprint() {
    const os = require('os');
    const platform = process.platform;
    const arch = process.arch;
    const cpus = os.cpus();
    const totalMem = os.totalmem();
    
    const fingerprint = {
        platform,
        arch,
        cpuModel: cpus[0]?.model || 'unknown',
        cpuCount: cpus.length,
        totalMemory: Math.floor(totalMem / (1024 * 1024 * 1024)), // GB
        nodeVersion: process.version
    };
    
    return crypto.createHash('md5')
        .update(JSON.stringify(fingerprint))
        .digest('hex');
}

// GPU 성능 캐시 로드
async function loadGPUPerformanceCache() {
    try {
        if (fsSync.existsSync(GPU_PERFORMANCE_CACHE_FILE)) {
            const data = JSON.parse(await fs.readFile(GPU_PERFORMANCE_CACHE_FILE, 'utf-8'));
            gpuPerformanceCache = { ...gpuPerformanceCache, ...data };
            console.log('📋 Loaded GPU performance cache:', {
                optimalAccelerator: gpuPerformanceCache.optimalAccelerator,
                detectionCount: gpuPerformanceCache.detectionCount,
                lastDetection: gpuPerformanceCache.lastDetection ? new Date(gpuPerformanceCache.lastDetection).toLocaleString() : 'Never'
            });
        }
    } catch (error) {
        console.log('⚠️ Failed to load GPU performance cache:', error.message);
        gpuPerformanceCache = {
            lastDetection: null,
            optimalAccelerator: null,
            performanceMetrics: {},
            systemFingerprint: null,
            detectionCount: 0
        };
    }
}

// GPU 성능 캐시 저장
async function saveGPUPerformanceCache() {
    try {
        await fs.writeFile(GPU_PERFORMANCE_CACHE_FILE, JSON.stringify(gpuPerformanceCache, null, 2));
    } catch (error) {
        console.log('⚠️ Failed to save GPU performance cache:', error.message);
    }
}

// 시스템 변경 감지
function hasSystemChanged() {
    const currentFingerprint = generateSystemFingerprint();
    const changed = gpuPerformanceCache.systemFingerprint !== currentFingerprint;
    
    if (changed) {
        console.log('🔄 System change detected, will re-detect GPU capabilities');
        gpuPerformanceCache.systemFingerprint = currentFingerprint;
    }
    
    return changed;
}

// GPU 가속 설정 캐시 확인
function shouldSkipGPUDetection() {
    // 시스템이 변경되었다면 재감지 필요
    if (hasSystemChanged()) {
        return false;
    }
    
    // 최근 1시간 이내에 감지했고 결과가 있다면 사용
    if (gpuPerformanceCache.lastDetection && gpuPerformanceCache.optimalAccelerator) {
        const hourAgo = Date.now() - (60 * 60 * 1000);
        const recentDetection = gpuPerformanceCache.lastDetection > hourAgo;
        
        if (recentDetection) {
            console.log(`💾 Using cached GPU setting: ${gpuPerformanceCache.optimalAccelerator}`);
            return true;
        }
    }
    
    return false;
}

// 캐시된 GPU 설정 업데이트
async function updateGPUPerformanceCache(accelerator, performanceMetrics, alternatives) {
    gpuPerformanceCache.lastDetection = Date.now();
    gpuPerformanceCache.optimalAccelerator = accelerator;
    gpuPerformanceCache.detectionCount += 1;
    gpuPerformanceCache.systemFingerprint = generateSystemFingerprint();
    
    // 성능 메트릭 업데이트
    if (performanceMetrics) {
        gpuPerformanceCache.performanceMetrics[accelerator] = performanceMetrics;
    }
    
    // 대안 가속기 성능도 저장
    if (alternatives && alternatives.length > 0) {
        alternatives.forEach(alt => {
            if (alt.benchmark) {
                gpuPerformanceCache.performanceMetrics[alt.name] = alt.benchmark;
            }
        });
    }
    
    await saveGPUPerformanceCache();
    
    console.log(`💾 Updated GPU cache: ${accelerator} (detection #${gpuPerformanceCache.detectionCount})`);
}

// Get OS-specific default paths
function getDefaultPaths() {
    const platform = process.platform;
    const homeDir = process.env.HOME || process.env.USERPROFILE;
    
    if (platform === 'win32') {
        return [
            homeDir,
            path.join(homeDir, 'Desktop'),
            path.join(homeDir, 'Documents'),
            path.join(homeDir, 'Pictures'),
            path.join(homeDir, 'Videos'),
            path.join(homeDir, 'Downloads')
        ].filter(p => fsSync.existsSync(p));
    } else if (platform === 'darwin') {
        return [
            homeDir,
            path.join(homeDir, 'Desktop'),
            path.join(homeDir, 'Documents'),
            path.join(homeDir, 'Pictures'),
            path.join(homeDir, 'Movies'),
            path.join(homeDir, 'Downloads')
        ].filter(p => fsSync.existsSync(p));
    } else {
        return [
            homeDir,
            path.join(homeDir, 'Desktop'),
            path.join(homeDir, 'Documents'),
            path.join(homeDir, 'Pictures'),
            path.join(homeDir, 'Videos'),
            path.join(homeDir, 'Downloads')
        ].filter(p => fsSync.existsSync(p));
    }
}

// 캐시 메타데이터 로드
async function loadCacheMetadata() {
    try {
        if (fsSync.existsSync(CACHE_METADATA_FILE)) {
            const data = JSON.parse(await fs.readFile(CACHE_METADATA_FILE, 'utf-8'));
            cacheMetadata.files = new Map(data.files);
            cacheMetadata.totalSize = data.totalSize || 0;
            cacheMetadata.lastCleanup = data.lastCleanup || Date.now();
            console.log(`📊 Cache metadata loaded: ${cacheMetadata.files.size} files, ${(cacheMetadata.totalSize / 1024 / 1024).toFixed(1)}MB`);
        }
    } catch (error) {
        console.log('ℹ️  Creating new cache metadata');
    }
    
    // GPU 성능 캐시도 로드
    await loadGPUPerformanceCache();
}

// 캐시 메타데이터 저장
async function saveCacheMetadata() {
    try {
        const data = {
            files: Array.from(cacheMetadata.files.entries()),
            totalSize: cacheMetadata.totalSize,
            lastCleanup: cacheMetadata.lastCleanup
        };
        await fs.writeFile(CACHE_METADATA_FILE, JSON.stringify(data, null, 2));
    } catch (error) {
        console.error('Error saving cache metadata:', error);
    }
}

// 캐시 정리 (LRU + 크기 기반)
async function cleanupCache() {
    const now = Date.now();
    
    // 정리 주기 확인
    if (now - cacheMetadata.lastCleanup < CACHE_CONFIG.cleanupIntervalMs) {
        return;
    }
    
    console.log('🧹 Starting cache cleanup...');
    const startTime = now;
    
    try {
        // 1. 만료된 파일 제거
        let removedFiles = 0;
        let freedSize = 0;
        
        for (const [filePath, metadata] of cacheMetadata.files.entries()) {
            const age = now - metadata.accessTime;
            
            if (age > CACHE_CONFIG.maxAgeMs) {
                try {
                    if (fsSync.existsSync(filePath)) {
                        await fs.unlink(filePath);
                        freedSize += metadata.size;
                        removedFiles++;
                    }
                    cacheMetadata.files.delete(filePath);
                } catch (error) {
                    // 파일 삭제 실패 시 메타데이터만 정리
                    cacheMetadata.files.delete(filePath);
                }
            }
        }
        
        // 2. 크기 또는 파일 수 초과 시 LRU 정리
        if (cacheMetadata.files.size > CACHE_CONFIG.maxFiles || 
            cacheMetadata.totalSize > CACHE_CONFIG.maxSizeGB * 1024 * 1024 * 1024) {
            
            // 접근 시간 기준으로 정렬
            const sortedFiles = Array.from(cacheMetadata.files.entries())
                .sort((a, b) => a[1].accessTime - b[1].accessTime);
            
            const targetSize = CACHE_CONFIG.maxSizeGB * 1024 * 1024 * 1024 * 0.8; // 80%까지 줄임
            const targetFiles = Math.floor(CACHE_CONFIG.maxFiles * 0.8);
            
            while ((cacheMetadata.totalSize > targetSize || cacheMetadata.files.size > targetFiles) && 
                   sortedFiles.length > 0) {
                
                const [filePath, metadata] = sortedFiles.shift();
                
                try {
                    if (fsSync.existsSync(filePath)) {
                        await fs.unlink(filePath);
                        freedSize += metadata.size;
                        removedFiles++;
                    }
                    cacheMetadata.files.delete(filePath);
                    cacheMetadata.totalSize -= metadata.size;
                } catch (error) {
                    cacheMetadata.files.delete(filePath);
                }
            }
        }
        
        cacheMetadata.lastCleanup = now;
        await saveCacheMetadata();
        
        const cleanupTime = Date.now() - startTime;
        console.log(`✅ Cache cleanup completed: ${removedFiles} files removed, ${(freedSize / 1024 / 1024).toFixed(1)}MB freed (${cleanupTime}ms)`);
        
    } catch (error) {
        console.error('Error during cache cleanup:', error);
    }
}

// 캐시 파일 기록
async function recordCacheFile(filePath, size = 0) {
    try {
        if (size === 0) {
            const stats = await fs.stat(filePath);
            size = stats.size;
        }
        
        const metadata = {
            createdTime: Date.now(),
            accessTime: Date.now(),
            size: size
        };
        
        cacheMetadata.files.set(filePath, metadata);
        cacheMetadata.totalSize += size;
        
        // 비동기로 메타데이터 저장
        setImmediate(() => saveCacheMetadata());
        
    } catch (error) {
        console.error('Error recording cache file:', error);
    }
}

// 캐시 파일 접근 기록
function touchCacheFile(filePath) {
    const metadata = cacheMetadata.files.get(filePath);
    if (metadata) {
        metadata.accessTime = Date.now();
        // 즉시 저장하지 않고 배치로 처리 (성능상 이유)
    }
}

// Initialize cache directories
async function initCacheDirectories() {
    try {
        await fs.mkdir(CACHE_DIR, { recursive: true });
        await fs.mkdir(THUMBNAILS_DIR, { recursive: true });
        await fs.mkdir(VIDEO_THUMBNAILS_DIR, { recursive: true });
        
        // 캐시 메타데이터 로드
        await loadCacheMetadata();
        
        console.log('✅ Cache directories initialized');
        
        // 주기적 캐시 정리 설정
        setInterval(cleanupCache, CACHE_CONFIG.cleanupIntervalMs);
        
        // 시작 시 한 번 정리
        setTimeout(cleanupCache, 5000);
        
    } catch (error) {
        console.error('Error creating cache directories:', error);
    }
}

initCacheDirectories();

// GPU 하드웨어 정보 감지
async function detectGPUHardware() {
    const platform = process.platform;
    const gpuInfo = {
        nvidia: false,
        intel: false,
        amd: false,
        apple: false,
        devices: []
    };

    try {
        if (platform === 'win32') {
            // Windows GPU 감지
            try {
                const { stdout } = await execPromise('wmic path win32_VideoController get name /format:csv');
                const lines = stdout.split('\n').filter(line => line.includes(','));
                
                for (const line of lines) {
                    const name = line.split(',')[1]?.toLowerCase() || '';
                    if (name.includes('nvidia') || name.includes('geforce') || name.includes('rtx') || name.includes('gtx')) {
                        gpuInfo.nvidia = true;
                        gpuInfo.devices.push({ vendor: 'nvidia', name: line.split(',')[1] });
                    }
                    if (name.includes('intel') || name.includes('uhd') || name.includes('iris')) {
                        gpuInfo.intel = true;
                        gpuInfo.devices.push({ vendor: 'intel', name: line.split(',')[1] });
                    }
                    if (name.includes('amd') || name.includes('radeon') || name.includes('vega')) {
                        gpuInfo.amd = true;
                        gpuInfo.devices.push({ vendor: 'amd', name: line.split(',')[1] });
                    }
                }
            } catch (e) {
                console.log('⚠️ Windows GPU detection failed, trying alternative methods...');
                
                // 대안 1: PowerShell로 GPU 정보 확인
                try {
                    const { stdout } = await execPromise('powershell "Get-WmiObject Win32_VideoController | Select-Object Name | Format-Table -HideTableHeaders"');
                    const lines = stdout.split('\n').filter(line => line.trim());
                    
                    for (const line of lines) {
                        const name = line.trim().toLowerCase();
                        if (name.includes('nvidia') || name.includes('geforce') || name.includes('rtx') || name.includes('gtx')) {
                            gpuInfo.nvidia = true;
                            gpuInfo.devices.push({ vendor: 'nvidia', name: line.trim() });
                        }
                        if (name.includes('intel') || name.includes('uhd') || name.includes('iris') || name.includes('hd graphics')) {
                            gpuInfo.intel = true;
                            gpuInfo.devices.push({ vendor: 'intel', name: line.trim() });
                        }
                        if (name.includes('amd') || name.includes('radeon') || name.includes('vega')) {
                            gpuInfo.amd = true;
                            gpuInfo.devices.push({ vendor: 'amd', name: line.trim() });
                        }
                    }
                    console.log('✅ PowerShell GPU detection successful');
                } catch (e2) {
                    console.log('⚠️ PowerShell GPU detection also failed');
                    
                    // 대안 2: DirectX 진단 도구 사용
                    try {
                        const { stdout } = await execPromise('dxdiag /t temp_dxdiag.txt && type temp_dxdiag.txt && del temp_dxdiag.txt', { timeout: 10000 });
                        if (stdout.toLowerCase().includes('nvidia') || stdout.toLowerCase().includes('geforce')) {
                            gpuInfo.nvidia = true;
                            gpuInfo.devices.push({ vendor: 'nvidia', name: 'Detected via DirectX' });
                        }
                        if (stdout.toLowerCase().includes('intel') || stdout.toLowerCase().includes('uhd') || stdout.toLowerCase().includes('iris')) {
                            gpuInfo.intel = true;
                            gpuInfo.devices.push({ vendor: 'intel', name: 'Detected via DirectX' });
                        }
                        if (stdout.toLowerCase().includes('amd') || stdout.toLowerCase().includes('radeon')) {
                            gpuInfo.amd = true;
                            gpuInfo.devices.push({ vendor: 'amd', name: 'Detected via DirectX' });
                        }
                        console.log('✅ DirectX GPU detection successful');
                    } catch (e3) {
                        console.log('⚠️ All Windows GPU detection methods failed');
                        
                        // 대안 3: 일반적인 GPU 가속 테스트로 우회
                        console.log('🔄 Proceeding with universal GPU acceleration tests...');
                        gpuInfo.universal = true; // 범용 테스트 플래그
                    }
                }
            }
        } else if (platform === 'linux') {
            // Linux GPU 감지
            try {
                // lspci 시도
                const { stdout } = await execPromise('lspci | grep -i vga');
                const lines = stdout.split('\n');
                
                for (const line of lines) {
                    const lower = line.toLowerCase();
                    if (lower.includes('nvidia')) {
                        gpuInfo.nvidia = true;
                        gpuInfo.devices.push({ vendor: 'nvidia', name: line });
                    }
                    if (lower.includes('intel')) {
                        gpuInfo.intel = true;
                        gpuInfo.devices.push({ vendor: 'intel', name: line });
                    }
                    if (lower.includes('amd') || lower.includes('radeon')) {
                        gpuInfo.amd = true;
                        gpuInfo.devices.push({ vendor: 'amd', name: line });
                    }
                }
            } catch (e) {
                // lspci 실패 시 /proc/cpuinfo로 Intel 내장 그래픽 추정
                try {
                    const { stdout } = await execPromise('cat /proc/cpuinfo | grep "model name" | head -1');
                    if (stdout.toLowerCase().includes('intel')) {
                        gpuInfo.intel = true;
                        gpuInfo.devices.push({ vendor: 'intel', name: 'Intel Integrated Graphics (estimated)' });
                    }
                } catch (e2) {
                    console.log('⚠️ Linux GPU detection failed');
                }
            }
        } else if (platform === 'darwin') {
            // macOS GPU 감지
            try {
                const { stdout } = await execPromise('system_profiler SPDisplaysDataType | grep "Chipset Model"');
                const lines = stdout.split('\n');
                
                for (const line of lines) {
                    const lower = line.toLowerCase();
                    if (lower.includes('nvidia')) {
                        gpuInfo.nvidia = true;
                        gpuInfo.devices.push({ vendor: 'nvidia', name: line.trim() });
                    }
                    if (lower.includes('intel')) {
                        gpuInfo.intel = true;
                        gpuInfo.devices.push({ vendor: 'intel', name: line.trim() });
                    }
                    if (lower.includes('amd') || lower.includes('radeon')) {
                        gpuInfo.amd = true;
                        gpuInfo.devices.push({ vendor: 'amd', name: line.trim() });
                    }
                    if (lower.includes('apple') || lower.includes('m1') || lower.includes('m2') || lower.includes('m3')) {
                        gpuInfo.apple = true;
                        gpuInfo.devices.push({ vendor: 'apple', name: line.trim() });
                    }
                }
            } catch (e) {
                console.log('⚠️ macOS GPU detection failed');
            }
        }
    } catch (error) {
        console.log('⚠️ GPU detection error:', error.message);
    }

    return gpuInfo;
}

// 플랫폼별 최적 가속 우선순위
function getAcceleratorPriorities(platform, gpuInfo) {
    const priorities = {
        'win32': {
            nvidia: ['cuda', 'nvenc'],
            intel: ['qsv', 'dxva2', 'd3d11va'],
            amd: ['amf', 'dxva2', 'd3d11va'],
            fallback: ['dxva2', 'opencl']
        },
        'linux': {
            nvidia: ['cuda', 'nvenc'],
            intel: ['qsv', 'vaapi'],
            amd: ['vaapi', 'amf'],
            fallback: ['vaapi', 'opencl']
        },
        'darwin': {
            apple: ['videotoolbox'],
            nvidia: ['cuda'],
            intel: ['videotoolbox', 'qsv'],
            amd: ['videotoolbox'],
            fallback: ['videotoolbox', 'opencl']
        }
    };

    const platformPriorities = priorities[platform] || priorities['linux'];
    let accelerators = [];

    // GPU별 우선순위 추가
    if (gpuInfo.nvidia && platformPriorities.nvidia) {
        accelerators.push(...platformPriorities.nvidia);
    }
    if (gpuInfo.intel && platformPriorities.intel) {
        accelerators.push(...platformPriorities.intel);
    }
    if (gpuInfo.amd && platformPriorities.amd) {
        accelerators.push(...platformPriorities.amd);
    }
    if (gpuInfo.apple && platformPriorities.apple) {
        accelerators.push(...platformPriorities.apple);
    }

    // 범용 테스트가 필요한 경우 (GPU 감지 실패 시)
    if (gpuInfo.universal) {
        console.log('🔄 Using universal GPU acceleration tests');
        if (platform === 'win32') {
            accelerators.push('dxva2', 'd3d11va', 'cuda', 'qsv', 'opencl');
        } else if (platform === 'linux') {
            accelerators.push('vaapi', 'cuda', 'qsv', 'opencl');
        } else if (platform === 'darwin') {
            accelerators.push('videotoolbox', 'opencl');
        }
    }

    // 폴백 옵션 추가
    if (platformPriorities.fallback) {
        accelerators.push(...platformPriorities.fallback);
    }

    // 중복 제거
    return [...new Set(accelerators)];
}

// FFmpeg에서 지원하는 하드웨어 가속 확인
async function checkFFmpegHardwareSupport(ffmpegPath = 'ffmpeg') {
    try {
        const { stdout } = await execPromise(`${ffmpegPath} -hwaccels`);
        const supportedAccels = stdout
            .split('\n')
            .filter(line => line.trim() && !line.includes('Hardware acceleration methods:'))
            .map(line => line.trim());

        return supportedAccels;
    } catch (error) {
        console.log('⚠️ Could not check FFmpeg hardware acceleration support');
        return [];
    }
}

// 향상된 하드웨어 가속 테스트
async function testHardwareAcceleration(accelerator, ffmpegPath = 'ffmpeg') {
    const tests = {
        cuda: {
            decoder: `${ffmpegPath} -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -hwaccel cuda -c:v h264_nvenc -f null - -v quiet`,
            encoder: `${ffmpegPath} -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -c:v h264_nvenc -f null - -v quiet`
        },
        qsv: {
            test: `${ffmpegPath} -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -c:v h264_qsv -f null - -v quiet`
        },
        vaapi: {
            test: `${ffmpegPath} -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -vaapi_device /dev/dri/renderD128 -vf format=nv12,hwupload -c:v h264_vaapi -f null - -v quiet`
        },
        videotoolbox: {
            test: `${ffmpegPath} -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -c:v h264_videotoolbox -f null - -v quiet`
        },
        opencl: {
            test: `${ffmpegPath} -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -init_hw_device opencl -filter_hw_device opencl -vf hwupload,scale_opencl=320:240 -f null - -v quiet`
        },
        dxva2: {
            test: `${ffmpegPath} -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -hwaccel dxva2 -f null - -v quiet`
        }
    };

    const accelTests = tests[accelerator];
    if (!accelTests) return false;

    try {
        // 기본 테스트 실행
        if (accelTests.test) {
            await execPromise(accelTests.test);
            return { success: true, type: 'basic' };
        }

        // CUDA의 경우 인코더와 디코더 개별 테스트
        if (accelTests.decoder && accelTests.encoder) {
            let decoderWorks = false;
            let encoderWorks = false;

            try {
                await execPromise(accelTests.decoder);
                decoderWorks = true;
            } catch (e) {
                // 디코더 실패는 괜찮음
            }

            try {
                await execPromise(accelTests.encoder);
                encoderWorks = true;
            } catch (e) {
                // 인코더 실패
            }

            if (encoderWorks || decoderWorks) {
                return {
                    success: true,
                    type: 'cuda',
                    decoder: decoderWorks,
                    encoder: encoderWorks
                };
            }
        }

        return false;
    } catch (error) {
        console.log(`❌ ${accelerator} test failed: ${error.message.split('\n')[0]}`);
        return false;
    }
}

// GPU 가속용 최적 명령어 생성
function getOptimalCommand(accelerator, ffmpegPath = 'ffmpeg', options = {}) {
    const { input = 'testsrc2=duration=1:size=320x240:rate=1', output = '/dev/null', isTest = false } = options;
    
    let command = `"${ffmpegPath}"`;
    
    // Windows에서 /dev/null 대신 NUL 사용
    const nullOutput = process.platform === 'win32' ? 'NUL' : '/dev/null';
    const finalOutput = output === '/dev/null' ? nullOutput : output;
    
    // 가속기별 명령어 생성
    switch (accelerator) {
        case 'cuda':
            command += ` -f lavfi -i ${input} -c:v h264_nvenc -f null ${finalOutput} -v quiet`;
            break;
        case 'qsv':
            command += ` -f lavfi -i ${input} -c:v h264_qsv -f null ${finalOutput} -v quiet`;
            break;
        case 'vaapi':
            command += ` -f lavfi -i ${input} -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -c:v h264_vaapi -f null ${finalOutput} -v quiet`;
            break;
        case 'dxva2':
            command += ` -f lavfi -i ${input} -hwaccel dxva2 -f null ${finalOutput} -v quiet`;
            break;
        case 'd3d11va':
            command += ` -f lavfi -i ${input} -hwaccel d3d11va -f null ${finalOutput} -v quiet`;
            break;
        case 'opencl':
            command += ` -f lavfi -i ${input} -init_hw_device opencl -filter_hw_device opencl -vf hwupload,scale_opencl=320:240 -f null ${finalOutput} -v quiet`;
            break;
        default:
            return null;
    }
    
    return command;
}

// 성능 기반 가속기 벤치마크
async function benchmarkAccelerator(accelerator, ffmpegPath = 'ffmpeg') {
    const testCommand = getOptimalCommand(accelerator, ffmpegPath, {
        input: 'testsrc2=duration=2:size=640x480:rate=30',
        output: '/dev/null',
        isTest: true
    });

    if (!testCommand) return null;

    try {
        const startTime = Date.now();
        await execPromise(testCommand);
        const duration = Date.now() - startTime;
        
        console.log(`⏱️ ${accelerator} benchmark: ${duration}ms`);
        return { accelerator, duration, fps: Math.round(60000 / duration) };
    } catch (error) {
        console.log(`❌ ${accelerator} benchmark failed: ${error.message.split('\n')[0]}`);
        return null;
    }
}

// 지능형 하드웨어 가속 감지 (캐시 지원)
async function detectHardwareAcceleration(ffmpegPath = 'ffmpeg') {
    console.log('🔍 Advanced GPU acceleration detection starting...');
    console.log(`🔧 Using FFmpeg path: ${ffmpegPath}`);
    
    // 캐시된 설정 확인
    if (shouldSkipGPUDetection()) {
        return {
            accelerator: gpuPerformanceCache.optimalAccelerator,
            details: {
                name: gpuPerformanceCache.optimalAccelerator,
                benchmark: gpuPerformanceCache.performanceMetrics[gpuPerformanceCache.optimalAccelerator] || null
            },
            alternatives: [],
            cached: true,
            gpuInfo: {}
        };
    }
    
    console.log('🔄 Performing fresh GPU detection...');
    
    // 1단계: 시스템 GPU 하드웨어 감지
    const gpuInfo = await detectGPUHardware();
    console.log('🖥️ GPU Hardware detected:', gpuInfo);
    
    // 2단계: FFmpeg 지원 가속 확인
    const ffmpegSupport = await checkFFmpegHardwareSupport(ffmpegPath);
    console.log('🛠️ FFmpeg supports:', ffmpegSupport);
    
    // 3단계: 플랫폼별 우선순위 결정
    const platform = process.platform;
    const priorities = getAcceleratorPriorities(platform, gpuInfo);
    console.log('📋 Testing accelerators in priority order:', priorities);
    
    // 4단계: 실제 테스트 및 벤치마크
    const workingAccelerators = [];
    
    for (const accelerator of priorities) {
        if (!ffmpegSupport.includes(accelerator)) {
            console.log(`  ⏭️ ${accelerator} - Not supported by FFmpeg`);
            continue;
        }
        
        console.log(`  🧪 Testing ${accelerator}...`);
        const testResult = await testHardwareAcceleration(accelerator, ffmpegPath);
        
        if (testResult && testResult.success) {
            console.log(`  ✅ ${accelerator} - Working`);
            
            // 성능 벤치마크
            const benchmark = await benchmarkAccelerator(accelerator, ffmpegPath);
            
            workingAccelerators.push({
                name: accelerator,
                ...testResult,
                benchmark
            });
            
            // 첫 번째로 작동하는 가속기를 우선 선택하되, 더 나은 옵션이 있는지 몇 개 더 테스트
            if (workingAccelerators.length >= 3) break;
        } else {
            console.log(`  ❌ ${accelerator} - Failed`);
        }
    }
    
    // 5단계: 최적 가속기 선택
    if (workingAccelerators.length > 0) {
        // 성능 기반 정렬 (속도 우선)
        workingAccelerators.sort((a, b) => {
            const aDuration = a.benchmark?.duration || 9999;
            const bDuration = b.benchmark?.duration || 9999;
            return aDuration - bDuration;
        });
        
        const best = workingAccelerators[0];
        const alternatives = workingAccelerators.slice(1);
        
        console.log(`🏆 Selected accelerator: ${best.name} (${best.benchmark?.duration || 'N/A'}ms)`);
        
        // 성능 캐시 업데이트
        await updateGPUPerformanceCache(best.name, best.benchmark, alternatives);
        
        return {
            accelerator: best.name,
            details: best,
            alternatives,
            cached: false,
            gpuInfo
        };
    }
    
    console.log('ℹ️ No hardware acceleration available, using optimized CPU');
    
    // CPU 모드도 캐시
    await updateGPUPerformanceCache('cpu', null, []);
    
    return null;
}

// FFmpeg 능력 및 최적화 옵션 확인
async function checkFFmpegCapabilities() {
    try {
        // 기본 FFmpeg 확인
        console.log('🔧 Checking system FFmpeg...');
        const versionOutput = await execPromise('ffmpeg -version');
        console.log('✅ System FFmpeg found');
        
        const capabilities = {
            available: true,
            hwaccel: null,
            threads: require('os').cpus().length,
            avx512: false,
            optimized: false,
            source: 'system'
        };

        // 하드웨어 가속 감지 (에러가 나도 FFmpeg 자체는 사용 가능)
        console.log('🎯 Starting hardware acceleration detection...');
        try {
            const hwaccelResult = await detectHardwareAcceleration();
            if (hwaccelResult && hwaccelResult.accelerator) {
                capabilities.hwaccel = hwaccelResult.accelerator;
                console.log(`✅ Hardware acceleration detection completed: ${hwaccelResult.accelerator}`);
            } else {
                capabilities.hwaccel = null;
                console.log('ℹ️ No hardware acceleration available');
            }
        } catch (hwError) {
            console.log('⚠️ GPU acceleration detection failed, continuing with CPU-only');
            console.log(`   Error: ${hwError.message.split('\n')[0]}`);
            capabilities.hwaccel = null;
        }
        
        // AVX-512 지원 확인 (CPU 기반 추정)
        const cpuinfo = require('os').cpus()[0].model;
        console.log(`🔍 CPU Info: ${cpuinfo} (${require('os').cpus().length} cores)`);
        
        if (cpuinfo.includes('Xeon') || cpuinfo.includes('Ryzen') || 
            cpuinfo.includes('i7') || cpuinfo.includes('i9') ||
            cpuinfo.includes('i5') || cpuinfo.includes('AMD')) {
            capabilities.avx512 = true;
        }

        // 컴파일 옵션에서 최적화 확인
        if (versionOutput.includes('--enable-libx264') && versionOutput.includes('--enable-libx265')) {
            capabilities.optimized = true;
        }

        console.log('🔧 FFmpeg Capabilities:', capabilities);
        return capabilities;
        
    } catch (error) {
        // 시스템 FFmpeg 실패 시 runtime 폴더 확인
        console.log('⚠️  System FFmpeg not found, checking runtime folder...');
        
        try {
            // runtime 폴더에서 FFmpeg 검색
            const runtimeFFmpeg = await findRuntimeFFmpeg();
            if (runtimeFFmpeg) {
                console.log(`✅ Found FFmpeg in runtime: ${runtimeFFmpeg}`);
                
                // runtime FFmpeg로 버전 확인
                const versionOutput = await execPromise(`"${runtimeFFmpeg}" -version`);
                
                const runtimeCapabilities = {
                    available: true,
                    hwaccel: null,
                    threads: require('os').cpus().length,
                    avx512: false,
                    optimized: false,
                    source: 'runtime',
                    path: runtimeFFmpeg
                };

                // Runtime FFmpeg에서도 GPU 가속 시도
                console.log('🎯 Starting hardware acceleration detection for runtime FFmpeg...');
                try {
                    const hwaccelResult = await detectHardwareAcceleration(runtimeFFmpeg);
                    if (hwaccelResult && hwaccelResult.accelerator) {
                        runtimeCapabilities.hwaccel = hwaccelResult.accelerator;
                        console.log(`✅ Runtime FFmpeg hardware acceleration detection completed: ${hwaccelResult.accelerator}`);
                    } else {
                        runtimeCapabilities.hwaccel = null;
                        console.log('ℹ️ No runtime FFmpeg hardware acceleration available');
                    }
                } catch (hwError) {
                    console.log('⚠️ Runtime FFmpeg GPU acceleration detection failed');
                    console.log(`   Error: ${hwError.message.split('\n')[0]}`);
                    runtimeCapabilities.hwaccel = null;
                }

                return runtimeCapabilities;
            }
        } catch (runtimeError) {
            console.log('❌ Runtime FFmpeg also not available');
        }
        
        // 모든 방법 실패
        console.log('💡 Solution: Run "썸네일 안만들어질 때 눌러주세요.bat" to fix FFmpeg installation');
        
        return { 
            available: false, 
            hwaccel: null, 
            threads: 1, 
            avx512: false, 
            optimized: false,
            source: 'none',
            error: 'FFmpeg not found. Please install FFmpeg or run the thumbnail fix tool.'
        };
    }
}

// runtime 폴더에서 FFmpeg 찾기
// runtime 폴더에서 FFmpeg 검색 (플랫폼 지원 향상)
async function findRuntimeFFmpeg() {
    try {
        const runtimeDir = path.join(__dirname, 'runtime');
        
        // runtime 폴더 존재 확인
        if (!fsSync.existsSync(runtimeDir)) {
            console.log('⚠️ Runtime directory not found');
            return null;
        }
        
        const platform = process.platform;
        const executableName = platform === 'win32' ? 'ffmpeg.exe' : 'ffmpeg';
        
        // 플랫폼별 가능한 FFmpeg 경로들
        const possiblePaths = [
            path.join(runtimeDir, 'ffmpeg', 'bin', executableName),
            path.join(runtimeDir, executableName),
            path.join(runtimeDir, 'ffmpeg', executableName)
        ];
        
        // ffmpeg* 폴더 검색
        const entries = await fs.readdir(runtimeDir);
        for (const entry of entries) {
            if (entry.startsWith('ffmpeg')) {
                const binPath = path.join(runtimeDir, entry, 'bin', executableName);
                const directPath = path.join(runtimeDir, entry, executableName);
                
                if (fsSync.existsSync(binPath)) {
                    possiblePaths.push(binPath);
                }
                if (fsSync.existsSync(directPath)) {
                    possiblePaths.push(directPath);
                }
            }
        }
        
        // 첫 번째로 찾은 유효한 FFmpeg 반환
        for (const ffmpegPath of possiblePaths) {
            if (fsSync.existsSync(ffmpegPath)) {
                console.log(`📍 Found runtime FFmpeg: ${ffmpegPath}`);
                return ffmpegPath;
            }
        }
        
        console.log('❌ No valid FFmpeg found in runtime directory');
        return null;
        
    } catch (error) {
        console.log('❌ Error searching runtime FFmpeg:', error.message);
        return null;
    }
}

// 최적화된 FFmpeg 명령어 생성
function buildOptimizedFFmpegCommand(videoPath, thumbnailPath, capabilities) {
    // FFmpeg 실행 파일 경로 설정
    let command = capabilities.source === 'runtime' && capabilities.path 
        ? `"${capabilities.path}"` 
        : 'ffmpeg';
    
    // 하드웨어 가속 설정
    if (capabilities.hwaccel) {
        switch (capabilities.hwaccel) {
            case 'cuda':
                command += ' -hwaccel cuda -hwaccel_output_format cuda';
                break;
            case 'qsv':
                command += ' -hwaccel qsv -hwaccel_output_format qsv';
                break;
            case 'vaapi':
                command += ' -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi';
                break;
            case 'opencl':
                command += ' -init_hw_device opencl -hwaccel opencl';
                break;
        }
    }

    // 멀티스레딩 최적화
    command += ` -threads ${capabilities.threads}`;
    
    // 입력 파일
    command += ` -i "${videoPath}"`;
    
    // 썸네일 추출 최적화 (빠른 시크 + 단일 프레임)
    command += ' -ss 00:00:01.000 -vframes 1 -an -sn';
    
    // 스케일링 필터 (하드웨어 가속 고려)
    if (capabilities.hwaccel === 'cuda') {
        command += ' -vf "scale_cuda=200:200:force_original_aspect_ratio=decrease,pad_cuda=200:200:(ow-iw)/2:(oh-ih)/2"';
    } else if (capabilities.hwaccel === 'qsv') {
        command += ' -vf "scale_qsv=200:200:force_original_aspect_ratio=decrease"';
    } else if (capabilities.hwaccel === 'opencl') {
        command += ' -vf "hwupload,scale_opencl=200:200:force_original_aspect_ratio=decrease,hwdownload,format=yuv420p,pad=200:200:(ow-iw)/2:(oh-ih)/2"';
    } else {
        // CPU 기반 최적화 (빠른 스케일링 알고리즘 + 멀티스레드)
        if (capabilities.avx512) {
            command += ' -vf "scale=200:200:force_original_aspect_ratio=decrease:flags=fast_bilinear,pad=200:200:(ow-iw)/2:(oh-ih)/2"';
        } else {
            command += ' -vf "scale=200:200:force_original_aspect_ratio=decrease:flags=bilinear,pad=200:200:(ow-iw)/2:(oh-ih)/2"';
        }
    }
    
    // 속도 우선 설정 (품질보다 속도)
    command += ` -q:v 5 -preset ultrafast -f image2 "${thumbnailPath}" -y`;
    
    // 로그 레벨 최소화
    command += ' -v error';

    return command;
}

// 파일 고유 식별자 기반 캐시 키 생성 (하이브리드 방식)
async function generateCacheKey(videoPath, stats) {
    if (process.platform === 'win32') {
        // Windows: 크기 + 수정시간 기반 (inode 제한적 지원)
        return crypto.createHash('md5')
            .update(`${stats.size}_${stats.mtime.getTime()}`)
            .digest('hex');
    } else {
        // Linux/Mac: inode 기반 (파일 시스템 레벨 고유 식별)
        return crypto.createHash('md5')
            .update(`${stats.ino}_${stats.dev}_${stats.mtime.getTime()}`)
            .digest('hex');
    }
}

// 향상된 비디오 썸네일 생성
async function generateVideoThumbnail(videoPath) {
    const startTime = Date.now();
    
    try {
        // 1단계: 캐시 확인 (파일 고유 식별자 기반)
        const stats = await fs.stat(videoPath);
        const cacheKey = await generateCacheKey(videoPath, stats);
        const thumbnailPath = path.join(VIDEO_THUMBNAILS_DIR, `${cacheKey}.jpg`);
        
        // 캐시된 썸네일이 존재하면 즉시 반환
        try {
            await fs.access(thumbnailPath);
            const cacheTime = Date.now() - startTime;
            console.log(`⚡ Cache hit: ${videoPath} (${cacheTime}ms)`);
            return `/api/serve-video-thumbnail/${cacheKey}.jpg`;
        } catch {
            // 캐시 미스, 새로 생성
        }
        
        // 2단계: FFmpeg 능력 확인
        const capabilities = await checkFFmpegCapabilities();
        if (!capabilities.available) {
            console.log('❌ FFmpeg not available');
            return null;
        }
        
        // 3단계: 최적화된 명령어로 썸네일 생성
        const command = buildOptimizedFFmpegCommand(videoPath, thumbnailPath, capabilities);
        
        console.log(`🚀 Generating optimized thumbnail: ${path.basename(videoPath)}`);
        console.log(`🔧 Command: ${command}`);
        
        try {
            await execPromise(command);
            const totalTime = Date.now() - startTime;
            
            // 생성된 캐시 파일 기록
            await recordCacheFile(thumbnailPath);
            
            console.log(`✅ Thumbnail generated: ${path.basename(videoPath)} (${totalTime}ms)`);
            console.log(`   - Hardware: ${capabilities.hwaccel || 'CPU'}`);
            console.log(`   - Threads: ${capabilities.threads}`);
            console.log(`   - AVX-512: ${capabilities.avx512 ? 'Yes' : 'No'}`);
            console.log(`   - FFmpeg Source: ${capabilities.source}`);
            console.log(`   - Performance: ${totalTime < 50 ? '🚀🚀 Ultra Fast' : totalTime < 200 ? '🚀 Fast' : totalTime < 1000 ? '⚡ Good' : totalTime < 3000 ? '🐢 Moderate' : '🐌 Slow'}`);
            
            // 향상된 성능 분석 및 제안
            if (capabilities.hwaccelDetails && capabilities.hwaccelDetails.alternatives.length > 0) {
                const currentPerf = totalTime;
                const alternatives = capabilities.hwaccelDetails.alternatives;
                const betterAlts = alternatives.filter(alt => alt.benchmark && alt.benchmark.duration < currentPerf);
                
                if (betterAlts.length > 0) {
                    console.log(`   💡 Better alternatives available: ${betterAlts.map(alt => `${alt.name} (${alt.benchmark.duration}ms)`).join(', ')}`);
                }
            }
            
            if (totalTime > 1000) {
                const suggestions = [];
                if (!capabilities.hwaccel) {
                    suggestions.push('Install GPU drivers for hardware acceleration');
                }
                if (capabilities.threads < 4) {
                    suggestions.push('Upgrade to multi-core CPU');
                }
                if (!capabilities.optimized) {
                    suggestions.push('Use optimized FFmpeg build');
                }
                
                if (suggestions.length > 0) {
                    console.log(`   💡 Performance tips: ${suggestions.join(', ')}`);
                }
            }
            
            return `/api/serve-video-thumbnail/${cacheKey}.jpg`;
            
        } catch (error) {
            console.error(`❌ Optimized generation failed: ${error.message}`);
            
            // 4단계: Fallback - 기본 FFmpeg 명령어
            console.log('🔄 Falling back to basic FFmpeg...');
            const ffmpegExe = capabilities.source === 'runtime' && capabilities.path 
                ? `"${capabilities.path}"` 
                : 'ffmpeg';
            const fallbackCommand = `${ffmpegExe} -i "${videoPath}" -ss 00:00:01.000 -vframes 1 -an -sn -vf "scale=200:200:force_original_aspect_ratio=decrease:flags=fast_bilinear,pad=200:200:(ow-iw)/2:(oh-ih)/2" -q:v 5 -preset ultrafast "${thumbnailPath}" -y -v error`;
            
            try {
                await execPromise(fallbackCommand);
                const totalTime = Date.now() - startTime;
                
                // 생성된 캐시 파일 기록
                await recordCacheFile(thumbnailPath);
                
                console.log(`✅ Fallback successful: ${path.basename(videoPath)} (${totalTime}ms)`);
                console.log(`   - Used: Basic CPU encoding (fallback mode)`);
                return `/api/serve-video-thumbnail/${cacheKey}.jpg`;
            } catch (fallbackError) {
                console.error('❌ Fallback also failed:', fallbackError.message);
                return null;
            }
        }
        
    } catch (error) {
        console.error('❌ Error in video thumbnail generation:', error.message);
        return null;
    }
}

// Generate thumbnail for images (HEIC 지원 추가)
async function generateImageThumbnail(imagePath) {
    try {
        const ext = path.extname(imagePath).toLowerCase();
        
        // Skip PSD files
        if (ext === '.psd') {
            return null;
        }
        
        const hash = crypto.createHash('md5').update(imagePath).digest('hex');
        const thumbnailPath = path.join(THUMBNAILS_DIR, `${hash}.jpg`);
        
        // Check if thumbnail already exists
        try {
            await fs.access(thumbnailPath);
            touchCacheFile(thumbnailPath); // 캐시 접근 기록
            return `/api/serve-thumbnail/${hash}.jpg`;
        } catch {
            // HEIC 파일 처리
            if (ext === '.heic' || ext === '.heif') {
                try {
                    // sharp는 libheif 플러그인이 설치되어 있으면 HEIC를 지원합니다
                    await sharp(imagePath)
                        .resize(200, 200, {
                            fit: 'cover',
                            position: 'center'
                        })
                        .jpeg({ quality: 85 })
                        .toFile(thumbnailPath);
                    
                    await recordCacheFile(thumbnailPath); // 캐시 파일 기록
                    return `/api/serve-thumbnail/${hash}.jpg`;
                } catch (heicError) {
                    console.log('HEIC thumbnail generation failed, trying with sips (macOS) or convert...');
                    
                    // macOS의 경우 sips 사용
                    if (process.platform === 'darwin') {
                        try {
                            const tempPath = thumbnailPath.replace('.jpg', '_temp.jpg');
                            await execPromise(`sips -s format jpeg "${imagePath}" --out "${tempPath}" --resampleHeightWidthMax 200`);
                            await fs.rename(tempPath, thumbnailPath);
                            await recordCacheFile(thumbnailPath); // 캐시 파일 기록
                            return `/api/serve-thumbnail/${hash}.jpg`;
                        } catch (sipsError) {
                            console.error('HEIC conversion with sips failed:', sipsError.message);
                        }
                    }
                    
                    return null;
                }
            }
            
            // 일반 이미지 처리
            await sharp(imagePath)
                .resize(200, 200, {
                    fit: 'cover',
                    position: 'center'
                })
                .jpeg({ quality: 85 })
                .toFile(thumbnailPath);
            
            await recordCacheFile(thumbnailPath); // 캐시 파일 기록
            return `/api/serve-thumbnail/${hash}.jpg`;
        }
    } catch (error) {
        console.error('Error generating image thumbnail:', error.message);
        return null;
    }
}

// Validate path
async function validatePath(folderPath) {
    try {
        const stats = await fs.stat(folderPath);
        if (!stats.isDirectory()) {
            return { valid: false, error: 'Path is not a directory' };
        }
        await fs.access(folderPath, fsSync.constants.R_OK);
        return { valid: true };
    } catch (error) {
        if (error.code === 'ENOENT') {
            return { valid: false, error: 'Path does not exist' };
        } else if (error.code === 'EACCES') {
            return { valid: false, error: 'Permission denied' };
        }
        return { valid: false, error: error.message };
    }
}

// Supported media extensions (HEIC 추가)
const MEDIA_EXTENSIONS = {
    image: ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp', '.ico', '.tiff', '.heic', '.heif', '.raw', '.psd'],
    video: ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.mkv', '.webm', '.m4v', '.mpg', '.mpeg', '.3gp', '.mts'],
    audio: ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a', '.wma', '.opus', '.aiff', '.ape'],
    document: ['.pdf', '.doc', '.docx', '.ppt', '.pptx', '.xls', '.xlsx', '.txt', '.rtf', '.odt']
};

function isMediaFile(filename) {
    const ext = path.extname(filename).toLowerCase();
    for (const type in MEDIA_EXTENSIONS) {
        if (MEDIA_EXTENSIONS[type].includes(ext)) {
            return { isMedia: true, type, extension: ext.slice(1) };
        }
    }
    return { isMedia: false, type: 'other', extension: ext.slice(1) || 'unknown' };
}

// Scan directory with thumbnail generation - NFC 정규화 추가
async function scanDirectory(dirPath, baseDir = dirPath, maxDepth = 5, currentDepth = 0) {
    const files = [];
    
    if (currentDepth >= maxDepth) {
        return files;
    }
    
    try {
        const entries = await fs.readdir(dirPath, { withFileTypes: true });
        
        for (const entry of entries) {
            const fullPath = path.join(dirPath, entry.name);
            
            // Skip hidden and system directories
            if (entry.name.startsWith('.') || 
                entry.name === 'node_modules' || 
                entry.name === '$RECYCLE.BIN' ||
                entry.name === 'System Volume Information') {
                continue;
            }
            
            try {
                if (entry.isDirectory()) {
                    const subFiles = await scanDirectory(fullPath, baseDir, maxDepth, currentDepth + 1);
                    files.push(...subFiles);
                } else if (entry.isFile()) {
                    const mediaInfo = isMediaFile(entry.name);
                    if (mediaInfo.isMedia) {
                        const stats = await fs.stat(fullPath);
                        const relativePath = path.relative(baseDir, path.dirname(fullPath));
                        
                        // NFC 정규화를 적용하여 파일 정보 저장
                        const fileInfo = {
                            filename: entry.name.normalize('NFC'),  // 한글 정규화
                            path: (relativePath || '.').normalize('NFC'),  // 한글 정규화
                            fullPath: fullPath.normalize('NFC'),  // 한글 정규화
                            size: stats.size,
                            type: `${mediaInfo.type}/${mediaInfo.extension}`,
                            extension: mediaInfo.extension,
                            modifiedAt: stats.mtime.toISOString(),
                            mediaType: mediaInfo.type,
                            thumbnailUrl: null
                        };
                        
                        // Generate thumbnail based on media type (HEIC 포함)
                        if (mediaInfo.type === 'image') {
                            fileInfo.thumbnailUrl = await generateImageThumbnail(fullPath);
                        } else if (mediaInfo.type === 'video') {
                            fileInfo.thumbnailUrl = await generateVideoThumbnail(fullPath);
                        }
                        
                        files.push(fileInfo);
                    }
                }
            } catch (error) {
                continue;
            }
        }
    } catch (error) {
        console.error(`Error scanning directory ${dirPath}:`, error.message);
    }
    
    return files;
}

// API Routes
app.post('/api/validate-path', async (req, res) => {
    const { path: folderPath } = req.body;
    
    if (!folderPath) {
        return res.status(400).json({ error: 'Path is required' });
    }
    
    const validation = await validatePath(folderPath);
    res.json(validation);
});

app.post('/api/scan', async (req, res) => {
    const { path: folderPath, sessionId, includeSubfolders = true, maxDepth = 3 } = req.body;
    
    if (!folderPath || !sessionId) {
        return res.status(400).json({ error: 'Path and sessionId are required' });
    }
    
    const validation = await validatePath(folderPath);
    if (!validation.valid) {
        return res.status(400).json({ 
            status: 'error', 
            message: validation.error 
        });
    }
    
    recentPaths.add(folderPath);
    if (recentPaths.size > MAX_RECENT_PATHS) {
        const pathsArray = Array.from(recentPaths);
        recentPaths.delete(pathsArray[0]);
    }
    
    try {
        console.log(`📂 Scanning: ${folderPath}`);
        console.log(`  Options: subfolders=${includeSubfolders}, maxDepth=${maxDepth}`);
        
        const ffmpegCapabilities = await checkFFmpegCapabilities();
        if (!ffmpegCapabilities.available) {
            console.log('⚠️  FFmpeg not found. Video thumbnails will not be generated.');
            console.log('💡 To fix this: Run "썸네일 안만들어질 때 눌러주세요.bat" file');
        } else {
            const source = ffmpegCapabilities.source === 'runtime' ? ' (from runtime folder)' : '';
            console.log(`✅ FFmpeg available with ${ffmpegCapabilities.hwaccel || 'CPU'} acceleration${source}`);
        }
        
        const startTime = Date.now();
        const files = await scanDirectory(
            folderPath, 
            folderPath, 
            includeSubfolders ? maxDepth : 1,
            0
        );
        const scanTime = Date.now() - startTime;
        
        files.sort((a, b) => new Date(b.modifiedAt) - new Date(a.modifiedAt));
        
        console.log(`✅ Scan complete: ${files.length} files in ${scanTime}ms`);
        
        // 미디어 타입별 카운트 계산
        const mediaCounts = {
            all: files.length,
            image: files.filter(f => f.mediaType === 'image').length,
            video: files.filter(f => f.mediaType === 'video').length,
            audio: files.filter(f => f.mediaType === 'audio').length,
            document: files.filter(f => f.mediaType === 'document').length
        };
        
        const scanResult = {
            currentPath: folderPath,
            indexedAt: new Date().toISOString(),
            totalFiles: files.length,
            files: files,
            status: 'completed',
            scanTime: scanTime,
            mediaCounts: mediaCounts
        };
        
        sessions.set(sessionId, scanResult);
        
        res.json({
            status: 'success',
            message: `Found ${files.length} media files in ${scanTime}ms`,
            totalFiles: files.length,
            currentPath: folderPath,
            scanTime: scanTime,
            ffmpegAvailable: ffmpegCapabilities.available,
            ffmpegInfo: {
                available: ffmpegCapabilities.available,
                source: ffmpegCapabilities.source || 'none',
                error: ffmpegCapabilities.error || null,
                solution: !ffmpegCapabilities.available ? 
                    'Run "썸네일 안만들어질 때 눌러주세요.bat" to install FFmpeg' : null
            },
            mediaCounts: mediaCounts
        });
    } catch (error) {
        console.error('Scan error:', error);
        res.status(500).json({ 
            status: 'error', 
            message: error.message 
        });
    }
});

// 미디어 타입 필터 + 북마크 필터 추가된 검색 API
app.post('/api/search', async (req, res) => {
    const { query, sessionId, mediaType, bookmarkedOnly, bookmarks } = req.body;
    
    if (!sessionId) {
        return res.status(400).json({ error: 'SessionId is required' });
    }
    
    const session = sessions.get(sessionId);
    if (!session) {
        return res.status(404).json({ 
            error: 'No scan data found. Please scan a folder first.' 
        });
    }
    
    // 디버깅용 로그
    console.log('검색어:', query, '미디어 타입:', mediaType, '북마크만:', bookmarkedOnly);
    
    // 검색어 처리
    const searchQuery = query?.trim() || '';
    
    let filteredFiles = session.files;
    
    // 북마크 필터링 - fullPath 기준으로 변경
    if (bookmarkedOnly && bookmarks && bookmarks.length > 0) {
        filteredFiles = filteredFiles.filter(file => 
            bookmarks.includes(file.fullPath)  // fullPath로 비교
        );
    }
    
    // 검색어 필터링
    if (searchQuery) {
        filteredFiles = filteredFiles.filter(file => {
            // 영어 검색을 위한 소문자 변환
            const lowerQuery = searchQuery.toLowerCase();
            const lowerFilename = file.filename.toLowerCase();
            const lowerPath = (file.path || '').toLowerCase();
            
            // 한글 검색을 위한 NFC 정규화
            const normalizedQuery = searchQuery.normalize('NFC');
            const normalizedFilename = file.filename.normalize('NFC');
            const normalizedPath = (file.path || '').normalize('NFC');
            
            // 공백 제거 버전
            const queryNoSpace = normalizedQuery.replace(/\s+/g, '');
            const filenameNoSpace = normalizedFilename.replace(/\s+/g, '');
            
            // 다양한 조건으로 검색
            return lowerFilename.includes(lowerQuery) ||
                   lowerPath.includes(lowerQuery) ||
                   normalizedFilename.includes(normalizedQuery) ||
                   normalizedPath.includes(normalizedQuery) ||
                   filenameNoSpace.includes(queryNoSpace);
        });
    }
    
    // 미디어 타입 필터링
    if (mediaType && mediaType !== 'all') {
        filteredFiles = filteredFiles.filter(file => file.mediaType === mediaType);
    }
    
    console.log(`검색 결과: ${filteredFiles.length}개 (타입: ${mediaType || 'all'}, 북마크: ${bookmarkedOnly})`);
    
    res.json({
        status: 'success',
        totalResults: filteredFiles.length,
        currentPath: session.currentPath,
        files: filteredFiles.slice(0, 500),
        mediaCounts: session.mediaCounts
    });
});

app.get('/api/recent-paths', (req, res) => {
    if (recentPaths.size === 0) {
        const defaults = getDefaultPaths();
        defaults.forEach(p => recentPaths.add(p));
    }
    
    res.json({
        status: 'success',
        paths: Array.from(recentPaths)
    });
});

app.get('/api/serve-thumbnail/:filename', async (req, res) => {
    const { filename } = req.params;
    const thumbnailPath = path.join(THUMBNAILS_DIR, filename);
    
    try {
        await fs.access(thumbnailPath);
        
        // 캐시 접근 기록
        touchCacheFile(thumbnailPath);
        
        // 캐시 헤더 설정 (1주일)
        res.set({
            'Cache-Control': 'public, max-age=604800, immutable',
            'ETag': `"${filename}"`,
            'Last-Modified': new Date().toUTCString()
        });
        
        res.sendFile(thumbnailPath);
    } catch {
        res.status(404).send('Thumbnail not found');
    }
});

app.get('/api/serve-video-thumbnail/:filename', async (req, res) => {
    const { filename } = req.params;
    const thumbnailPath = path.join(VIDEO_THUMBNAILS_DIR, filename);
    
    try {
        await fs.access(thumbnailPath);
        
        // 캐시 접근 기록
        touchCacheFile(thumbnailPath);
        
        // 캐시 헤더 설정 (1주일)
        res.set({
            'Cache-Control': 'public, max-age=604800, immutable',
            'ETag': `"${filename}"`,
            'Last-Modified': new Date().toUTCString()
        });
        
        res.sendFile(thumbnailPath);
    } catch {
        res.status(404).send('Video thumbnail not found');
    }
});

app.get('/api/serve-file', async (req, res) => {
    const { path: filePath } = req.query;
    
    if (!filePath) {
        return res.status(400).json({ error: 'File path is required' });
    }
    
    try {
        await fs.access(filePath, fsSync.constants.R_OK);
        const stats = await fs.stat(filePath);
        
        if (!stats.isFile()) {
            return res.status(400).json({ error: 'Path is not a file' });
        }
        
        const mimeType = mime.lookup(filePath) || 'application/octet-stream';
        res.contentType(mimeType);
        res.sendFile(filePath);
    } catch (error) {
        if (error.code === 'ENOENT') {
            res.status(404).json({ error: 'File not found' });
        } else if (error.code === 'EACCES') {
            res.status(403).json({ error: 'Permission denied' });
        } else {
            res.status(500).json({ error: error.message });
        }
    }
});

// API: Open file in system
app.post('/api/open-file', async (req, res) => {
    const { path: filePath } = req.body;
    
    if (!filePath) {
        return res.status(400).json({ error: 'File path is required' });
    }
    
    try {
        await open(filePath);
        res.json({ status: 'success', message: 'File opened successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/system-info', (req, res) => {
    const platform = process.platform;
    const homeDir = process.env.HOME || process.env.USERPROFILE;
    
    res.json({
        platform: platform,
        platformName: platform === 'win32' ? 'Windows' : platform === 'darwin' ? 'macOS' : 'Linux',
        homeDir: homeDir,
        separator: path.sep,
        defaultPaths: getDefaultPaths()
    });
});

// 캐시 상태 정보 API
app.get('/api/cache-status', (req, res) => {
    res.json({
        status: 'success',
        cache: {
            totalFiles: cacheMetadata.files.size,
            totalSizeBytes: cacheMetadata.totalSize,
            totalSizeMB: Math.round(cacheMetadata.totalSize / 1024 / 1024 * 100) / 100,
            maxSizeGB: CACHE_CONFIG.maxSizeGB,
            maxFiles: CACHE_CONFIG.maxFiles,
            lastCleanup: new Date(cacheMetadata.lastCleanup).toISOString(),
            hitRate: calculateCacheHitRate(),
            oldestFile: getOldestCacheFile(),
            newestFile: getNewestCacheFile()
        },
        config: CACHE_CONFIG
    });
});

// 캐시 정리 수동 실행 API
app.post('/api/cache-cleanup', async (req, res) => {
    try {
        await cleanupCache();
        res.json({
            status: 'success',
            message: 'Cache cleanup completed'
        });
    } catch (error) {
        res.status(500).json({
            status: 'error',
            message: error.message
        });
    }
});

// 캐시 히트율 계산 (간단한 추정)
function calculateCacheHitRate() {
    // 실제 구현에서는 히트/미스 카운터를 사용
    const recentAccess = Array.from(cacheMetadata.files.values())
        .filter(meta => Date.now() - meta.accessTime < 24 * 60 * 60 * 1000).length;
    
    return cacheMetadata.files.size > 0 
        ? Math.round(recentAccess / cacheMetadata.files.size * 100) 
        : 0;
}

// 가장 오래된 캐시 파일 정보
function getOldestCacheFile() {
    let oldest = null;
    let oldestTime = Date.now();
    
    for (const [filePath, metadata] of cacheMetadata.files.entries()) {
        if (metadata.createdTime < oldestTime) {
            oldestTime = metadata.createdTime;
            oldest = {
                path: path.basename(filePath),
                created: new Date(metadata.createdTime).toISOString(),
                lastAccess: new Date(metadata.accessTime).toISOString()
            };
        }
    }
    
    return oldest;
}

// 가장 새로운 캐시 파일 정보
function getNewestCacheFile() {
    let newest = null;
    let newestTime = 0;
    
    for (const [filePath, metadata] of cacheMetadata.files.entries()) {
        if (metadata.createdTime > newestTime) {
            newestTime = metadata.createdTime;
            newest = {
                path: path.basename(filePath),
                created: new Date(metadata.createdTime).toISOString(),
                lastAccess: new Date(metadata.accessTime).toISOString()
            };
        }
    }
    
    return newest;
}

// GPU 성능 캐시 상태 API
app.get('/api/gpu-performance', (req, res) => {
    res.json({
        status: 'success',
        data: {
            lastDetection: gpuPerformanceCache.lastDetection ? new Date(gpuPerformanceCache.lastDetection).toISOString() : null,
            optimalAccelerator: gpuPerformanceCache.optimalAccelerator,
            detectionCount: gpuPerformanceCache.detectionCount,
            performanceMetrics: gpuPerformanceCache.performanceMetrics,
            systemFingerprint: gpuPerformanceCache.systemFingerprint
        }
    });
});

// GPU 캐시 재설정 API
app.post('/api/reset-gpu-cache', async (req, res) => {
    try {
        gpuPerformanceCache = {
            lastDetection: null,
            optimalAccelerator: null,
            performanceMetrics: {},
            systemFingerprint: null,
            detectionCount: 0
        };
        
        await saveGPUPerformanceCache();
        
        res.json({
            status: 'success',
            message: 'GPU performance cache has been reset. Next video thumbnail generation will re-detect optimal settings.'
        });
    } catch (error) {
        res.status(500).json({
            status: 'error',
            message: 'Failed to reset GPU cache: ' + error.message
        });
    }
});

// 향상된 캐시 상태 API
app.get('/api/cache-status', (req, res) => {
    const totalSizeMB = (cacheMetadata.totalSize / 1024 / 1024).toFixed(2);
    const maxSizeMB = (CACHE_CONFIG.maxSizeGB * 1024).toFixed(0);
    const usage = ((cacheMetadata.totalSize / (CACHE_CONFIG.maxSizeGB * 1024 * 1024 * 1024)) * 100).toFixed(1);
    
    res.json({
        status: 'success',
        cache: {
            totalFiles: cacheMetadata.files.size,
            totalSize: `${totalSizeMB}MB`,
            maxSize: `${maxSizeMB}MB`,
            usage: `${usage}%`,
            lastCleanup: new Date(cacheMetadata.lastCleanup).toISOString()
        },
        gpu: {
            lastDetection: gpuPerformanceCache.lastDetection ? new Date(gpuPerformanceCache.lastDetection).toISOString() : null,
            optimalAccelerator: gpuPerformanceCache.optimalAccelerator || 'none',
            detectionCount: gpuPerformanceCache.detectionCount,
            availableAccelerators: Object.keys(gpuPerformanceCache.performanceMetrics).length
        }
    });
});

app.get('/', (req, res) => {
    const htmlPath = path.join(__dirname, 'public', 'index.html');
    
    if (!fsSync.existsSync(htmlPath)) {
        const localHtmlPath = path.join(__dirname, 'public', 'local.html');
        if (fsSync.existsSync(localHtmlPath)) {
            res.sendFile(localHtmlPath);
        } else {
            res.send('<h1>Media File Explorer</h1><p>HTML files not found. Please check installation.</p>');
        }
    } else {
        res.sendFile(htmlPath);
    }
});

const server = app.listen(PORT, '127.0.0.1', async () => {
    console.log('\n================================================');
    console.log('🚀 Media File Explorer - OPTIMIZED Local Server');
    console.log('================================================');
    console.log(`✅ Server running at: http://localhost:${PORT}`);
    console.log(`📁 Platform: ${process.platform === 'win32' ? 'Windows' : process.platform === 'darwin' ? 'macOS' : 'Linux'}`);
    console.log(`🏠 Home Directory: ${process.env.HOME || process.env.USERPROFILE}`);
    
    // FFmpeg 능력 확인 및 표시
    setTimeout(async () => {
        const capabilities = await checkFFmpegCapabilities();
        console.log('================================================');
        console.log('⚡ PERFORMANCE OPTIMIZATIONS ACTIVE:');
        console.log(`   🎯 Hardware Acceleration: ${capabilities.hwaccel ? '✅ ' + capabilities.hwaccel.toUpperCase() : '❌ CPU Only'}`);
        console.log(`   🧵 CPU Threads: ${capabilities.threads} cores`);
        console.log(`   🔥 AVX-512 Support: ${capabilities.avx512 ? '✅ Enhanced' : '⚠️  Basic'}`);
        console.log(`   💾 Smart Cache: ✅ LRU + ${CACHE_CONFIG.maxSizeGB}GB limit`);
        console.log(`   📊 Cache Stats: ${cacheMetadata.files.size} files, ${(cacheMetadata.totalSize / 1024 / 1024).toFixed(1)}MB`);
        console.log('================================================');
        console.log('📌 Instructions:');
        console.log(`   1. Open browser: http://localhost:${PORT}`);
        console.log('   2. Enter any folder path on your computer');
        console.log('   3. Click "Scan" to index media files');
        console.log('   4. Experience 20-100x faster thumbnails! 🚀');
        console.log('================================================');
        console.log('⭐ Features: 한글검색 + 북마크 + HEIC + GPU가속 + 지능형캐시');
        console.log('🔧 Monitoring: /api/cache-status for cache info');
        console.log('================================================');
        console.log('Press Ctrl+C to stop the server\n');
    }, 1000);
});

process.on('SIGINT', () => {
    console.log('\n👋 Shutting down server...');
    server.close(() => {
        console.log('✅ Server closed');
        process.exit(0);
    });
});
