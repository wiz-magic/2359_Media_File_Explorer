const express = require('express');
const cors = require('cors');
const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');
const sharp = require('sharp');
const mime = require('mime-types');
const crypto = require('crypto');

const app = express();
const PORT = 3001;

// Middleware
app.use(cors());
app.use(express.json());

// In-memory storage for sessions
const sessions = new Map();
const recentPaths = new Set();
const MAX_RECENT_PATHS = 10;

// Cache directory for thumbnails
const CACHE_DIR = path.join(__dirname, 'media-cache');
const THUMBNAILS_DIR = path.join(CACHE_DIR, 'thumbnails');

// Create cache directories
async function initCacheDirectories() {
    try {
        await fs.mkdir(CACHE_DIR, { recursive: true });
        await fs.mkdir(THUMBNAILS_DIR, { recursive: true });
        console.log('Cache directories initialized');
    } catch (error) {
        console.error('Error creating cache directories:', error);
    }
}

// Initialize on startup
initCacheDirectories();

// Helper function to check if path exists and is accessible
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

// Supported media extensions
const MEDIA_EXTENSIONS = {
    image: ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp', '.ico', '.tiff'],
    video: ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.mkv', '.webm', '.m4v', '.mpg', '.mpeg'],
    audio: ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a', '.wma', '.opus'],
    document: ['.pdf', '.doc', '.docx', '.ppt', '.pptx', '.xls', '.xlsx', '.txt', '.rtf']
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

// Recursive file scanner
async function scanDirectory(dirPath, baseDir = dirPath, maxDepth = 5, currentDepth = 0) {
    const files = [];
    
    if (currentDepth >= maxDepth) {
        return files;
    }
    
    try {
        const entries = await fs.readdir(dirPath, { withFileTypes: true });
        
        for (const entry of entries) {
            const fullPath = path.join(dirPath, entry.name);
            
            // Skip hidden files and system directories
            if (entry.name.startsWith('.') || entry.name === 'node_modules') {
                continue;
            }
            
            if (entry.isDirectory()) {
                // Recursively scan subdirectories
                const subFiles = await scanDirectory(fullPath, baseDir, maxDepth, currentDepth + 1);
                files.push(...subFiles);
            } else if (entry.isFile()) {
                const mediaInfo = isMediaFile(entry.name);
                if (mediaInfo.isMedia) {
                    try {
                        const stats = await fs.stat(fullPath);
                        const relativePath = path.relative(baseDir, path.dirname(fullPath));
                        
                        files.push({
                            filename: entry.name,
                            path: relativePath || '.',
                            fullPath: fullPath,
                            size: stats.size,
                            type: `${mediaInfo.type}/${mediaInfo.extension}`,
                            extension: mediaInfo.extension,
                            modifiedAt: stats.mtime.toISOString(),
                            mediaType: mediaInfo.type
                        });
                    } catch (error) {
                        console.error(`Error reading file stats for ${fullPath}:`, error);
                    }
                }
            }
        }
    } catch (error) {
        console.error(`Error scanning directory ${dirPath}:`, error);
    }
    
    return files;
}

// Generate thumbnail for images
async function generateThumbnail(imagePath, thumbnailPath) {
    try {
        await sharp(imagePath)
            .resize(300, 300, {
                fit: 'inside',
                withoutEnlargement: true
            })
            .jpeg({ quality: 80 })
            .toFile(thumbnailPath);
        return true;
    } catch (error) {
        console.error('Error generating thumbnail:', error);
        return false;
    }
}

// API: Validate path
app.post('/api/validate-path', async (req, res) => {
    const { path: folderPath } = req.body;
    
    if (!folderPath) {
        return res.status(400).json({ error: 'Path is required' });
    }
    
    const validation = await validatePath(folderPath);
    res.json(validation);
});

// API: Scan folder
app.post('/api/scan', async (req, res) => {
    const { path: folderPath, sessionId, includeSubfolders = true, maxDepth = 3 } = req.body;
    
    if (!folderPath || !sessionId) {
        return res.status(400).json({ error: 'Path and sessionId are required' });
    }
    
    // Validate path first
    const validation = await validatePath(folderPath);
    if (!validation.valid) {
        return res.status(400).json({ 
            status: 'error', 
            message: validation.error 
        });
    }
    
    // Add to recent paths
    recentPaths.add(folderPath);
    if (recentPaths.size > MAX_RECENT_PATHS) {
        const pathsArray = Array.from(recentPaths);
        recentPaths.delete(pathsArray[0]);
    }
    
    try {
        // Start scanning
        const startTime = Date.now();
        const files = await scanDirectory(
            folderPath, 
            folderPath, 
            includeSubfolders ? maxDepth : 1
        );
        const scanTime = Date.now() - startTime;
        
        // Sort files by modified date (newest first)
        files.sort((a, b) => new Date(b.modifiedAt) - new Date(a.modifiedAt));
        
        // Store in session
        const scanResult = {
            currentPath: folderPath,
            indexedAt: new Date().toISOString(),
            totalFiles: files.length,
            files: files,
            status: 'completed',
            scanTime: scanTime
        };
        
        sessions.set(sessionId, scanResult);
        
        res.json({
            status: 'success',
            message: `Found ${files.length} media files in ${scanTime}ms`,
            totalFiles: files.length,
            currentPath: folderPath,
            scanTime: scanTime
        });
    } catch (error) {
        console.error('Scan error:', error);
        res.status(500).json({ 
            status: 'error', 
            message: error.message 
        });
    }
});

// API: Search files
app.post('/api/search', async (req, res) => {
    const { query, sessionId } = req.body;
    
    if (!sessionId) {
        return res.status(400).json({ error: 'SessionId is required' });
    }
    
    const session = sessions.get(sessionId);
    if (!session) {
        return res.status(404).json({ 
            error: 'No scan data found. Please scan a folder first.' 
        });
    }
    
    // Filter files
    const searchQuery = query?.toLowerCase() || '';
    const filteredFiles = searchQuery 
        ? session.files.filter(file => 
            file.filename.toLowerCase().includes(searchQuery) ||
            file.path.toLowerCase().includes(searchQuery)
          )
        : session.files;
    
    res.json({
        status: 'success',
        totalResults: filteredFiles.length,
        currentPath: session.currentPath,
        files: filteredFiles.slice(0, 200) // Limit results
    });
});

// API: Get recent paths
app.get('/api/recent-paths', (req, res) => {
    // Add some default paths if empty
    if (recentPaths.size === 0) {
        recentPaths.add('/home/user');
        recentPaths.add('/home/user/Downloads');
        recentPaths.add('/home/user/Documents');
        recentPaths.add('/home/user/Pictures');
    }
    
    res.json({
        status: 'success',
        paths: Array.from(recentPaths)
    });
});

// API: Get file preview/thumbnail
app.get('/api/preview/:sessionId/:fileIndex', async (req, res) => {
    const { sessionId, fileIndex } = req.params;
    
    const session = sessions.get(sessionId);
    if (!session) {
        return res.status(404).json({ error: 'Session not found' });
    }
    
    const index = parseInt(fileIndex);
    if (isNaN(index) || index < 0 || index >= session.files.length) {
        return res.status(400).json({ error: 'Invalid file index' });
    }
    
    const file = session.files[index];
    
    // For images, generate or serve thumbnail
    if (file.mediaType === 'image') {
        const hash = crypto.createHash('md5').update(file.fullPath).digest('hex');
        const thumbnailPath = path.join(THUMBNAILS_DIR, `${hash}.jpg`);
        
        try {
            // Check if thumbnail already exists
            await fs.access(thumbnailPath);
        } catch {
            // Generate thumbnail if it doesn't exist
            await generateThumbnail(file.fullPath, thumbnailPath);
        }
        
        // Check if thumbnail was created successfully
        try {
            await fs.access(thumbnailPath);
            return res.json({
                status: 'success',
                file: file,
                thumbnailUrl: `/api/serve-thumbnail/${hash}.jpg`,
                hasPreview: true
            });
        } catch {
            // Thumbnail generation failed
        }
    }
    
    // For other files or if thumbnail failed
    res.json({
        status: 'success',
        file: file,
        hasPreview: false
    });
});

// API: Serve thumbnail
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

// API: Serve original file
app.get('/api/serve-file', async (req, res) => {
    const { path: filePath } = req.query;
    
    if (!filePath) {
        return res.status(400).json({ error: 'File path is required' });
    }
    
    try {
        // Validate file exists and is readable
        await fs.access(filePath, fsSync.constants.R_OK);
        const stats = await fs.stat(filePath);
        
        if (!stats.isFile()) {
            return res.status(400).json({ error: 'Path is not a file' });
        }
        
        // Set appropriate content type
        const mimeType = mime.lookup(filePath) || 'application/octet-stream';
        res.contentType(mimeType);
        
        // Send file
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

// API: Get system info
app.get('/api/system-info', (req, res) => {
    res.json({
        platform: process.platform,
        homeDir: process.env.HOME || process.env.USERPROFILE,
        separator: path.sep
    });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Node.js backend server running on http://localhost:${PORT}`);
    console.log('Ready to scan real file system!');
});