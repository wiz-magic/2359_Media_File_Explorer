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

// Initialize cache directories
async function initCacheDirectories() {
    try {
        await fs.mkdir(CACHE_DIR, { recursive: true });
        await fs.mkdir(THUMBNAILS_DIR, { recursive: true });
        await fs.mkdir(VIDEO_THUMBNAILS_DIR, { recursive: true });
        console.log('✅ Cache directories initialized');
    } catch (error) {
        console.error('Error creating cache directories:', error);
    }
}

initCacheDirectories();

// Check if ffmpeg is available
async function checkFFmpeg() {
    try {
        await execPromise('ffmpeg -version');
        return true;
    } catch {
        return false;
    }
}

// Generate video thumbnail using ffmpeg
async function generateVideoThumbnail(videoPath) {
    try {
        const hash = crypto.createHash('md5').update(videoPath).digest('hex');
        const thumbnailPath = path.join(VIDEO_THUMBNAILS_DIR, `${hash}.jpg`);
        
        // Check if thumbnail already exists
        try {
            await fs.access(thumbnailPath);
            return `/api/serve-video-thumbnail/${hash}.jpg`;
        } catch {
            // Generate new thumbnail
            const ffmpegAvailable = await checkFFmpeg();
            if (!ffmpegAvailable) {
                return null;
            }
            
            // Extract frame at 1 second (or 10% of video duration)
            const command = `ffmpeg -i "${videoPath}" -ss 00:00:01.000 -vframes 1 -vf "scale=200:200:force_original_aspect_ratio=decrease,pad=200:200:(ow-iw)/2:(oh-ih)/2" -q:v 2 "${thumbnailPath}" -y`;
            
            try {
                await execPromise(command);
                return `/api/serve-video-thumbnail/${hash}.jpg`;
            } catch (error) {
                console.error('Error generating video thumbnail:', error.message);
                return null;
            }
        }
    } catch (error) {
        console.error('Error in video thumbnail generation:', error.message);
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
                    
                    return `/api/serve-thumbnail/${hash}.jpg`;
                } catch (heicError) {
                    console.log('HEIC thumbnail generation failed, trying with sips (macOS) or convert...');
                    
                    // macOS의 경우 sips 사용
                    if (process.platform === 'darwin') {
                        try {
                            const tempPath = thumbnailPath.replace('.jpg', '_temp.jpg');
                            await execPromise(`sips -s format jpeg "${imagePath}" --out "${tempPath}" --resampleHeightWidthMax 200`);
                            await fs.rename(tempPath, thumbnailPath);
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
        
        const ffmpegAvailable = await checkFFmpeg();
        if (!ffmpegAvailable) {
            console.log('⚠️  FFmpeg not found. Video thumbnails will not be generated.');
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
            ffmpegAvailable: ffmpegAvailable,
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

const server = app.listen(PORT, '127.0.0.1', () => {
    console.log('\n================================================');
    console.log('🚀 Media File Explorer - Local Server');
    console.log('================================================');
    console.log(`✅ Server running at: http://localhost:${PORT}`);
    console.log(`📁 Platform: ${process.platform === 'win32' ? 'Windows' : process.platform === 'darwin' ? 'macOS' : 'Linux'}`);
    console.log(`🏠 Home Directory: ${process.env.HOME || process.env.USERPROFILE}`);
    console.log('================================================');
    console.log('📌 Instructions:');
    console.log(`   1. Open browser: http://localhost:${PORT}`);
    console.log('   2. Enter any folder path on your computer');
    console.log('   3. Click "Scan" to index media files');
    console.log('   4. Search and preview your files!');
    console.log('================================================');
    console.log('⭐ 한글 검색 + 북마크 + HEIC 썸네일 지원 버전');
    console.log('================================================');
    console.log('Press Ctrl+C to stop the server\n');
});

process.on('SIGINT', () => {
    console.log('\n👋 Shutting down server...');
    server.close(() => {
        console.log('✅ Server closed');
        process.exit(0);
    });
});
