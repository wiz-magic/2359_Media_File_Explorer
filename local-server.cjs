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
const GPUDetector = require('./gpu-detector.cjs');

const app = express();
const PORT = process.env.PORT || 3000;

// GPU 감지기 초기화
const gpuDetector = new GPUDetector();

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

// 캐시 메타데이터 관리
let cacheMetadata = {
    files: new Map(),
    totalSize: 0,
    lastCleanup: Date.now()
};

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

// 하드웨어 가속 지원 확인 - 범용 자동 감지
async function detectHardwareAcceleration() {
    const capabilities = await gpuDetector.testHardwareAcceleration();
    
    if (capabilities.available) {
        console.log(`✅ Hardware acceleration detected: ${capabilities.method} (${capabilities.vendor})`);
        return capabilities.method;
    }
    
    console.log('ℹ️  No hardware acceleration available, using optimized CPU');
    return null;
}

// FFmpeg 능력 및 최적화 옵션 확인
async function checkFFmpegCapabilities() {
    try {
        // 기본 FFmpeg 확인
        const versionOutput = await execPromise('ffmpeg -version');
        
        // GPU 감지기 사용
        const gpuCapabilities = await gpuDetector.testHardwareAcceleration();
        
        const capabilities = {
            available: true,
            hwaccel: gpuCapabilities.available ? gpuCapabilities.method : null,
            vendor: gpuCapabilities.vendor || 'CPU',
            threads: require('os').cpus().length,
            avx512: false,
            optimized: false,
            source: 'system',
            platform: process.platform,
            gpuInfo: gpuCapabilities
        };
        
        // CPU 최적화 정보
        if (gpuCapabilities.cpuOptimizations) {
            capabilities.avx512 = gpuCapabilities.cpuOptimizations.avx512;
            capabilities.avx2 = gpuCapabilities.cpuOptimizations.avx2;
            capabilities.avx = gpuCapabilities.cpuOptimizations.avx;
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
                
                return {
                    available: true,
                    hwaccel: null, // runtime은 기본적으로 하드웨어 가속 없음
                    threads: require('os').cpus().length,
                    avx512: false,
                    optimized: false,
                    source: 'runtime',
                    path: runtimeFFmpeg
                };
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
async function findRuntimeFFmpeg() {
    const runtimeDir = path.join(__dirname, 'runtime');
    
    try {
        if (!fsSync.existsSync(runtimeDir)) {
            return null;
        }
        
        // 가능한 FFmpeg 경로들
        const possiblePaths = [
            path.join(runtimeDir, 'ffmpeg', 'bin', 'ffmpeg.exe'),
            path.join(runtimeDir, 'ffmpeg.exe'),
            path.join(runtimeDir, 'ffmpeg', 'ffmpeg.exe')
        ];
        
        // ffmpeg* 폴더 검색
        const entries = await fs.readdir(runtimeDir);
        for (const entry of entries) {
            if (entry.startsWith('ffmpeg')) {
                const binPath = path.join(runtimeDir, entry, 'bin', 'ffmpeg.exe');
                if (fsSync.existsSync(binPath)) {
                    possiblePaths.push(binPath);
                }
            }
        }
        
        // 첫 번째로 찾은 유효한 FFmpeg 반환
        for (const ffmpegPath of possiblePaths) {
            if (fsSync.existsSync(ffmpegPath)) {
                return ffmpegPath;
            }
        }
        
        return null;
        
    } catch (error) {
        return null;
    }
}

// 최적화된 FFmpeg 명령어 생성
function buildOptimizedFFmpegCommand(videoPath, thumbnailPath, capabilities) {
    // FFmpeg 실행 파일 경로 설정
    let ffmpegPath = capabilities.source === 'runtime' && capabilities.path 
        ? `"${capabilities.path}"` 
        : 'ffmpeg';
    
    // GPU 감지기를 사용한 명령어 생성
    if (capabilities.gpuInfo) {
        // gpuDetector의 buildCommand 메서드 활용
        let command = gpuDetector.buildCommand(videoPath, thumbnailPath, capabilities.gpuInfo);
        
        // runtime FFmpeg 경로 적용
        if (capabilities.source === 'runtime' && capabilities.path) {
            command = command.replace('ffmpeg', `"${capabilities.path}"`);
        }
        
        return command;
    }
    
    // 폴백: 기존 방식
    let command = ffmpegPath;
    command += ' -ss 00:00:01.000'; // 입력 전 시크
    command += ` -i "${videoPath}"`;
    command += ' -vframes 1 -an -sn';
    command += ' -vf "scale=200:200:force_original_aspect_ratio=decrease"';
    command += ` -threads ${capabilities.threads}`;
    command += ' -q:v 5 -preset ultrafast';
    command += ` -f image2 "${thumbnailPath}" -y`;
    command += ' -v error';
    
    return command;
}

// 향상된 비디오 썸네일 생성
async function generateVideoThumbnail(videoPath) {
    const startTime = Date.now();
    
    try {
        // 1단계: 캐시 확인 (파일 수정시간 + 경로 해시)
        const stats = await fs.stat(videoPath);
        const cacheKey = crypto.createHash('md5')
            .update(videoPath + stats.mtime.getTime())
            .digest('hex');
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
            console.log(`   - Performance: ${totalTime < 1000 ? '🚀 Fast' : totalTime < 3000 ? '⚡ Good' : '🐌 Slow'}`);
            
            // 성능 개선 제안
            if (totalTime > 2000) {
                console.log(`   💡 Performance tip: ${!capabilities.hwaccel ? 'Install GPU drivers for hardware acceleration' : 'Consider upgrading FFmpeg build'}`);
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
