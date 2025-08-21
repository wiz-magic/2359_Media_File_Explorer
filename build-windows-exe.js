#!/usr/bin/env node
/**
 * Windows Executable Builder for Media File Explorer
 * Creates a standalone .exe file with embedded Node.js runtime and FFmpeg
 */

const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const https = require('https');
const AdmZip = require('adm-zip');

class WindowsExeBuilder {
    constructor() {
        this.projectRoot = __dirname;
        this.buildDir = path.join(this.projectRoot, 'windows-build');
        this.distDir = path.join(this.projectRoot, 'windows-dist');
        this.ffmpegDir = path.join(this.buildDir, 'ffmpeg');
    }

    async log(message, type = 'info') {
        const prefix = {
            info: '📋',
            success: '✅',
            error: '❌',
            warning: '⚠️',
            download: '📥',
            build: '🔨'
        };
        console.log(`${prefix[type] || '📌'} ${message}`);
    }

    async cleanDirectories() {
        await this.log('Cleaning build directories...', 'info');
        
        // Remove old build directories
        const dirsToClean = [this.buildDir, this.distDir];
        for (const dir of dirsToClean) {
            if (fsSync.existsSync(dir)) {
                await fs.rm(dir, { recursive: true, force: true });
            }
        }
        
        // Create fresh directories
        await fs.mkdir(this.buildDir, { recursive: true });
        await fs.mkdir(this.distDir, { recursive: true });
        await fs.mkdir(this.ffmpegDir, { recursive: true });
        
        await this.log('Build directories cleaned', 'success');
    }

    async downloadFile(url, destPath) {
        return new Promise((resolve, reject) => {
            const file = fsSync.createWriteStream(destPath);
            https.get(url, (response) => {
                if (response.statusCode === 302 || response.statusCode === 301) {
                    // Handle redirect
                    this.downloadFile(response.headers.location, destPath)
                        .then(resolve)
                        .catch(reject);
                    return;
                }
                
                const totalSize = parseInt(response.headers['content-length'], 10);
                let downloadedSize = 0;
                
                response.on('data', (chunk) => {
                    downloadedSize += chunk.length;
                    const percent = ((downloadedSize / totalSize) * 100).toFixed(1);
                    process.stdout.write(`  Downloading: ${percent}%\r`);
                });
                
                response.pipe(file);
                
                file.on('finish', () => {
                    file.close();
                    console.log(''); // New line after progress
                    resolve();
                });
            }).on('error', (err) => {
                fs.unlink(destPath);
                reject(err);
            });
        });
    }

    async downloadFFmpeg() {
        await this.log('Downloading FFmpeg for Windows...', 'download');
        
        // Using a direct link to FFmpeg essentials build
        const ffmpegUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';
        const ffmpegZip = path.join(this.buildDir, 'ffmpeg.zip');
        
        try {
            // Download FFmpeg
            await this.downloadFile(ffmpegUrl, ffmpegZip);
            await this.log('FFmpeg downloaded', 'success');
            
            // Extract FFmpeg
            await this.log('Extracting FFmpeg...', 'info');
            const zip = new AdmZip(ffmpegZip);
            zip.extractAllTo(this.buildDir, true);
            
            // Find and copy ffmpeg.exe and ffprobe.exe
            const files = await this.findFiles(this.buildDir, ['ffmpeg.exe', 'ffprobe.exe']);
            for (const file of files) {
                const destPath = path.join(this.ffmpegDir, path.basename(file));
                await fs.copyFile(file, destPath);
            }
            
            // Clean up zip file
            await fs.unlink(ffmpegZip);
            await this.log('FFmpeg extracted successfully', 'success');
            
        } catch (error) {
            await this.log(`Could not download FFmpeg: ${error.message}`, 'warning');
            await this.log('Continuing without FFmpeg (video thumbnails will be limited)', 'warning');
        }
    }

    async findFiles(dir, fileNames) {
        const results = [];
        const entries = await fs.readdir(dir, { withFileTypes: true });
        
        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            if (entry.isDirectory()) {
                const subResults = await this.findFiles(fullPath, fileNames);
                results.push(...subResults);
            } else if (fileNames.includes(entry.name)) {
                results.push(fullPath);
            }
        }
        
        return results;
    }

    async createMainExecutable() {
        await this.log('Creating main executable wrapper...', 'build');
        
        const mainScript = `
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

// Get the directory where the executable is located
const exeDir = path.dirname(process.execPath);
const ffmpegPath = path.join(exeDir, 'ffmpeg', 'ffmpeg.exe');
const ffprobePath = path.join(exeDir, 'ffmpeg', 'ffprobe.exe');

// Set FFmpeg in environment
if (fs.existsSync(ffmpegPath)) {
    process.env.FFMPEG_PATH = ffmpegPath;
    process.env.FFPROBE_PATH = ffprobePath;
    process.env.PATH = path.dirname(ffmpegPath) + path.delimiter + process.env.PATH;
}

// Change to app directory
process.chdir(exeDir);

// Load the actual server
require('./local-server.cjs');
`;

        const mainFile = path.join(this.buildDir, 'main.js');
        await fs.writeFile(mainFile, mainScript);
        
        await this.log('Main wrapper created', 'success');
        return mainFile;
    }

    async copyProjectFiles() {
        await this.log('Copying project files...', 'info');
        
        const filesToCopy = [
            'package.json',
            'server.cjs',
            'local-server.cjs',
            'ecosystem.config.cjs'
        ];
        
        const dirsToCopy = [
            'public',
            'src'
        ];
        
        // Copy files
        for (const file of filesToCopy) {
            const src = path.join(this.projectRoot, file);
            const dest = path.join(this.buildDir, file);
            if (fsSync.existsSync(src)) {
                await fs.copyFile(src, dest);
                await this.log(`Copied ${file}`, 'success');
            }
        }
        
        // Copy directories
        for (const dir of dirsToCopy) {
            const src = path.join(this.projectRoot, dir);
            const dest = path.join(this.buildDir, dir);
            if (fsSync.existsSync(src)) {
                await this.copyDirectory(src, dest);
                await this.log(`Copied ${dir}/`, 'success');
            }
        }
    }

    async copyDirectory(src, dest) {
        await fs.mkdir(dest, { recursive: true });
        const entries = await fs.readdir(src, { withFileTypes: true });
        
        for (const entry of entries) {
            const srcPath = path.join(src, entry.name);
            const destPath = path.join(dest, entry.name);
            
            if (entry.isDirectory()) {
                await this.copyDirectory(srcPath, destPath);
            } else {
                await fs.copyFile(srcPath, destPath);
            }
        }
    }

    async installDependencies() {
        await this.log('Installing production dependencies...', 'info');
        
        try {
            execSync('npm install --production', {
                cwd: this.buildDir,
                stdio: 'inherit'
            });
            await this.log('Dependencies installed', 'success');
        } catch (error) {
            await this.log('Failed to install dependencies', 'error');
            throw error;
        }
    }

    async buildWithPkg() {
        await this.log('Building executable with pkg...', 'build');
        
        // Install pkg if not already installed
        try {
            execSync('npm list -g pkg', { stdio: 'ignore' });
        } catch {
            await this.log('Installing pkg...', 'info');
            execSync('npm install -g pkg', { stdio: 'inherit' });
        }
        
        // Create package.json for pkg
        const packageJson = JSON.parse(
            await fs.readFile(path.join(this.buildDir, 'package.json'), 'utf-8')
        );
        
        packageJson.bin = 'main.js';
        packageJson.pkg = {
            scripts: ['*.js', '*.cjs'],
            assets: [
                'public/**/*',
                'src/**/*',
                'ffmpeg/**/*'
            ],
            targets: ['node18-win-x64'],
            outputPath: this.distDir
        };
        
        await fs.writeFile(
            path.join(this.buildDir, 'package.json'),
            JSON.stringify(packageJson, null, 2)
        );
        
        // Build with pkg
        try {
            const outputName = 'MediaFileExplorer.exe';
            execSync(
                `pkg . --targets node18-win-x64 --output "${path.join(this.distDir, outputName)}"`,
                {
                    cwd: this.buildDir,
                    stdio: 'inherit'
                }
            );
            
            // Copy FFmpeg to dist
            if (fsSync.existsSync(this.ffmpegDir)) {
                const distFfmpegDir = path.join(this.distDir, 'ffmpeg');
                await fs.mkdir(distFfmpegDir, { recursive: true });
                
                const ffmpegFiles = await fs.readdir(this.ffmpegDir);
                for (const file of ffmpegFiles) {
                    await fs.copyFile(
                        path.join(this.ffmpegDir, file),
                        path.join(distFfmpegDir, file)
                    );
                }
            }
            
            await this.log('Executable built successfully', 'success');
            return path.join(this.distDir, outputName);
        } catch (error) {
            await this.log(`Build failed: ${error.message}`, 'error');
            throw error;
        }
    }

    async createBatchLauncher() {
        await this.log('Creating batch launcher...', 'info');
        
        const batchContent = `@echo off
title Media File Explorer
echo Starting Media File Explorer...
echo.
echo The application will open in your default browser.
echo Close this window to stop the server.
echo.

REM Set FFmpeg path if available
if exist "%~dp0ffmpeg\\ffmpeg.exe" (
    set FFMPEG_PATH=%~dp0ffmpeg\\ffmpeg.exe
    set FFPROBE_PATH=%~dp0ffmpeg\\ffprobe.exe
    set PATH=%~dp0ffmpeg;%PATH%
)

REM Start the application
"%~dp0MediaFileExplorer.exe"

pause
`;

        const batchFile = path.join(this.distDir, 'Start Media File Explorer.bat');
        await fs.writeFile(batchFile, batchContent);
        
        await this.log('Batch launcher created', 'success');
    }

    async createReadme() {
        await this.log('Creating README...', 'info');
        
        const readmeContent = `# Media File Explorer - Windows Executable

## 🚀 Quick Start

1. Double-click "Start Media File Explorer.bat" or "MediaFileExplorer.exe"
2. The application will start and open in your default browser
3. Use the web interface to browse and search your media files

## 📋 Features

- Browse all media files on your computer
- Search files by name
- Preview images with thumbnails
- Support for videos, audio, and documents
- No installation required - just run!

## 🎬 Video Thumbnails

FFmpeg is included for video thumbnail generation.
The application will automatically use it if available.

## ⚠️ Windows Security

Windows may show a security warning when first running the application.
This is normal for unsigned executables. Click "More info" and then "Run anyway".

## 🔧 Troubleshooting

### Port Already in Use
If you see an error about port 3000 or 3001 being in use:
1. Close any other applications using these ports
2. Or edit the configuration to use different ports

### Application Won't Start
1. Make sure you have extracted all files from the ZIP
2. Try running as Administrator
3. Check Windows Defender or antivirus isn't blocking the app

## 📁 Files

- MediaFileExplorer.exe - Main application
- Start Media File Explorer.bat - Easy launcher
- ffmpeg/ - Video processing tools (optional)

## 🆘 Support

For issues or questions, please visit:
https://github.com/wiz-magic/2359_Media_File_Explorer

---
Version 1.0.0
`;

        const readmeFile = path.join(this.distDir, 'README.txt');
        await fs.writeFile(readmeFile, readmeContent);
        
        await this.log('README created', 'success');
    }

    async createZipPackage() {
        await this.log('Creating ZIP package...', 'info');
        
        const zip = new AdmZip();
        
        // Add all files from dist directory
        const files = await fs.readdir(this.distDir);
        for (const file of files) {
            const filePath = path.join(this.distDir, file);
            const stats = await fs.stat(filePath);
            
            if (stats.isDirectory()) {
                zip.addLocalFolder(filePath, file);
            } else {
                zip.addLocalFile(filePath);
            }
        }
        
        const zipPath = path.join(this.projectRoot, 'MediaFileExplorer-Windows.zip');
        zip.writeZip(zipPath);
        
        await this.log(`ZIP package created: ${zipPath}`, 'success');
        return zipPath;
    }

    async run() {
        console.log('🚀 Media File Explorer - Windows Executable Builder');
        console.log(''.padEnd(50, '='));
        
        try {
            // Step 1: Clean directories
            await this.cleanDirectories();
            
            // Step 2: Download FFmpeg
            await this.downloadFFmpeg();
            
            // Step 3: Copy project files
            await this.copyProjectFiles();
            
            // Step 4: Install dependencies
            await this.installDependencies();
            
            // Step 5: Create main executable wrapper
            await this.createMainExecutable();
            
            // Step 6: Build with pkg
            const exePath = await this.buildWithPkg();
            
            // Step 7: Create batch launcher
            await this.createBatchLauncher();
            
            // Step 8: Create README
            await this.createReadme();
            
            // Step 9: Create ZIP package
            const zipPath = await this.createZipPackage();
            
            console.log(''.padEnd(50, '='));
            console.log('✅ Build completed successfully!');
            console.log(`📦 Executable: ${exePath}`);
            console.log(`📦 ZIP Package: ${zipPath}`);
            console.log('\n📋 Distribution:');
            console.log('1. Share the ZIP file with users');
            console.log('2. Users extract and run "Start Media File Explorer.bat"');
            console.log('3. No installation or dependencies required!');
            
        } catch (error) {
            console.error(''.padEnd(50, '='));
            console.error('❌ Build failed:', error.message);
            process.exit(1);
        }
    }
}

// Check if required modules are installed
async function checkDependencies() {
    const requiredModules = ['adm-zip'];
    const missing = [];
    
    for (const module of requiredModules) {
        try {
            require.resolve(module);
        } catch {
            missing.push(module);
        }
    }
    
    if (missing.length > 0) {
        console.log('📦 Installing required build dependencies...');
        execSync(`npm install ${missing.join(' ')}`, { stdio: 'inherit' });
    }
}

// Main execution
if (require.main === module) {
    checkDependencies().then(() => {
        const builder = new WindowsExeBuilder();
        builder.run().catch(console.error);
    });
}

module.exports = WindowsExeBuilder;