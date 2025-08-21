#!/usr/bin/env node
/**
 * Electron App Builder for Media File Explorer
 * Creates Windows installer and portable executable with embedded FFmpeg
 */

const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');
const { execSync, exec } = require('child_process');
const https = require('https');
const AdmZip = require('adm-zip');

class ElectronAppBuilder {
    constructor() {
        this.projectRoot = __dirname;
        this.buildAssetsDir = path.join(this.projectRoot, 'build-assets');
        this.ffmpegBinariesDir = path.join(this.projectRoot, 'ffmpeg-binaries');
        this.distDir = path.join(this.projectRoot, 'electron-dist');
    }

    log(message, type = 'info') {
        const prefix = {
            info: '📋',
            success: '✅',
            error: '❌',
            warning: '⚠️',
            download: '📥',
            build: '🔨',
            package: '📦'
        };
        console.log(`${prefix[type] || '📌'} ${message}`);
    }

    async ensureDirectories() {
        this.log('Creating build directories...', 'info');
        
        const dirs = [this.buildAssetsDir, this.ffmpegBinariesDir];
        for (const dir of dirs) {
            await fs.mkdir(dir, { recursive: true });
        }
        
        this.log('Directories created', 'success');
    }

    async downloadFile(url, destPath, showProgress = true) {
        return new Promise((resolve, reject) => {
            const file = fsSync.createWriteStream(destPath);
            
            https.get(url, (response) => {
                // Handle redirects
                if (response.statusCode === 301 || response.statusCode === 302) {
                    file.close();
                    this.downloadFile(response.headers.location, destPath, showProgress)
                        .then(resolve)
                        .catch(reject);
                    return;
                }
                
                const totalSize = parseInt(response.headers['content-length'], 10);
                let downloadedSize = 0;
                
                response.on('data', (chunk) => {
                    downloadedSize += chunk.length;
                    if (showProgress && totalSize) {
                        const percent = ((downloadedSize / totalSize) * 100).toFixed(1);
                        process.stdout.write(`  Progress: ${percent}%\r`);
                    }
                });
                
                response.pipe(file);
                
                file.on('finish', () => {
                    file.close();
                    if (showProgress) console.log(''); // New line
                    resolve();
                });
            }).on('error', (err) => {
                fs.unlink(destPath).catch(() => {});
                reject(err);
            });
        });
    }

    async downloadFFmpeg() {
        this.log('Downloading FFmpeg for Windows...', 'download');
        
        const ffmpegZip = path.join(this.projectRoot, 'ffmpeg-temp.zip');
        
        // Using gyan.dev FFmpeg builds (reliable source)
        const ffmpegUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';
        
        try {
            // Download FFmpeg
            await this.downloadFile(ffmpegUrl, ffmpegZip);
            this.log('FFmpeg downloaded', 'success');
            
            // Extract FFmpeg
            this.log('Extracting FFmpeg...', 'info');
            const zip = new AdmZip(ffmpegZip);
            zip.extractAllTo(this.projectRoot, true);
            
            // Find and copy FFmpeg binaries
            const files = ['ffmpeg.exe', 'ffprobe.exe'];
            for (const fileName of files) {
                const found = await this.findFile(this.projectRoot, fileName);
                if (found) {
                    const destPath = path.join(this.ffmpegBinariesDir, fileName);
                    await fs.copyFile(found, destPath);
                    this.log(`Copied ${fileName}`, 'success');
                }
            }
            
            // Clean up
            await fs.unlink(ffmpegZip);
            
            // Remove extracted folder
            const extractedDirs = await fs.readdir(this.projectRoot);
            for (const dir of extractedDirs) {
                if (dir.startsWith('ffmpeg-') && dir.includes('-essentials')) {
                    await fs.rm(path.join(this.projectRoot, dir), { recursive: true, force: true });
                }
            }
            
            this.log('FFmpeg setup complete', 'success');
            
        } catch (error) {
            this.log(`FFmpeg download failed: ${error.message}`, 'warning');
            this.log('Continuing without FFmpeg (video features limited)', 'warning');
        }
    }

    async findFile(dir, fileName) {
        const entries = await fs.readdir(dir, { withFileTypes: true });
        
        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            
            if (entry.isFile() && entry.name === fileName) {
                return fullPath;
            } else if (entry.isDirectory() && !entry.name.startsWith('.') && entry.name !== 'node_modules') {
                const found = await this.findFile(fullPath, fileName);
                if (found) return found;
            }
        }
        
        return null;
    }

    async createIcons() {
        this.log('Creating application icons...', 'info');
        
        // Create a simple icon using canvas (for demonstration)
        // In production, you would use actual icon files
        
        const iconContent = `
<svg width="256" height="256" xmlns="http://www.w3.org/2000/svg">
  <rect width="256" height="256" fill="#2563eb"/>
  <text x="128" y="128" text-anchor="middle" dominant-baseline="middle" 
        font-family="Arial" font-size="48" font-weight="bold" fill="white">
    MEDIA
  </text>
  <text x="128" y="170" text-anchor="middle" dominant-baseline="middle" 
        font-family="Arial" font-size="32" fill="white">
    EXPLORER
  </text>
</svg>`;

        // Save SVG icon
        const svgPath = path.join(this.buildAssetsDir, 'icon.svg');
        await fs.writeFile(svgPath, iconContent);
        
        // For Windows, we need an ICO file
        // For now, we'll create a placeholder
        const icoPlaceholder = path.join(this.buildAssetsDir, 'icon.ico');
        await fs.writeFile(icoPlaceholder, ''); // Empty placeholder
        
        // Copy to public directory for the app to use
        const publicIcon = path.join(this.projectRoot, 'public', 'icon.png');
        if (!fsSync.existsSync(publicIcon)) {
            // Create a simple PNG placeholder
            await fs.writeFile(publicIcon, '');
        }
        
        this.log('Icons created', 'success');
    }

    async updatePackageJson() {
        this.log('Updating package.json for Electron...', 'info');
        
        const packagePath = path.join(this.projectRoot, 'package.json');
        const packageJson = JSON.parse(await fs.readFile(packagePath, 'utf-8'));
        
        // Update for Electron
        packageJson.main = 'electron-main.js';
        packageJson.scripts = {
            ...packageJson.scripts,
            'electron': 'electron .',
            'electron-build': 'electron-builder',
            'dist': 'electron-builder --win'
        };
        
        // Save updated package.json
        await fs.writeFile(packagePath, JSON.stringify(packageJson, null, 2));
        
        this.log('package.json updated', 'success');
    }

    async installElectronDependencies() {
        this.log('Installing Electron and dependencies...', 'package');
        
        try {
            // Install Electron and electron-builder
            execSync('npm install --save-dev electron electron-builder', {
                cwd: this.projectRoot,
                stdio: 'inherit'
            });
            
            this.log('Electron dependencies installed', 'success');
        } catch (error) {
            this.log(`Failed to install dependencies: ${error.message}`, 'error');
            throw error;
        }
    }

    async buildElectronApp() {
        this.log('Building Electron app...', 'build');
        
        try {
            // Run electron-builder
            execSync('npm run dist', {
                cwd: this.projectRoot,
                stdio: 'inherit',
                env: {
                    ...process.env,
                    CSC_IDENTITY_AUTO_DISCOVERY: 'false' // Skip code signing
                }
            });
            
            this.log('Electron app built successfully', 'success');
            
            // List output files
            const distFiles = await fs.readdir(this.distDir);
            this.log('Generated files:', 'success');
            for (const file of distFiles) {
                console.log(`  - ${file}`);
            }
            
        } catch (error) {
            this.log(`Build failed: ${error.message}`, 'error');
            throw error;
        }
    }

    async createPortableLauncher() {
        this.log('Creating portable launcher batch file...', 'info');
        
        const batchContent = `@echo off
title Media File Explorer - Portable
echo ========================================
echo    Media File Explorer - Portable
echo ========================================
echo.
echo Starting application...
echo.

REM Get the directory of this batch file
set APP_DIR=%~dp0

REM Check if the executable exists
if not exist "%APP_DIR%MediaFileExplorer-Portable.exe" (
    echo Error: MediaFileExplorer-Portable.exe not found!
    echo Please make sure all files are extracted.
    pause
    exit /b 1
)

REM Start the application
start "" "%APP_DIR%MediaFileExplorer-Portable.exe"

echo Application started!
echo You can close this window.
timeout /t 3 >nul
exit`;

        const batchPath = path.join(this.distDir, 'Start-Portable.bat');
        await fs.writeFile(batchPath, batchContent);
        
        this.log('Portable launcher created', 'success');
    }

    async createReadme() {
        this.log('Creating README file...', 'info');
        
        const readmeContent = `# Media File Explorer - Windows Application

## Installation Options

### Option 1: Installer (Recommended)
1. Run "Media File Explorer Setup [version].exe"
2. Follow the installation wizard
3. Launch from Start Menu or Desktop shortcut

### Option 2: Portable Version
1. Extract all files to a folder
2. Run "MediaFileExplorer-Portable.exe" or "Start-Portable.bat"
3. No installation required!

## Features
- 📁 Browse all media files on your computer
- 🔍 Fast file search
- 🖼️ Image thumbnail generation
- 🎬 Video file support (with FFmpeg)
- 🎵 Audio file browsing
- 📄 Document file support

## System Requirements
- Windows 10 or Windows 11
- 4GB RAM (8GB recommended)
- 100MB free disk space

## Usage
1. Launch the application
2. Enter a folder path or click "Browse"
3. Click "Scan" to index files
4. Use the search box to find files
5. Click on files to preview

## Troubleshooting

### Application won't start
- Make sure all files are extracted
- Try running as Administrator
- Check if antivirus is blocking the app

### Port already in use error
- Another application is using port 3000 or 3001
- Close other applications and try again

### No thumbnails for videos
- FFmpeg is required for video thumbnails
- The app includes FFmpeg, but antivirus might block it

## Support
GitHub: https://github.com/wiz-magic/2359_Media_File_Explorer

---
Version 1.0.0
© 2024 Media File Explorer
`;

        const readmePath = path.join(this.distDir, 'README.txt');
        await fs.writeFile(readmePath, readmeContent);
        
        this.log('README created', 'success');
    }

    async run() {
        console.log('🚀 Media File Explorer - Electron App Builder');
        console.log(''.padEnd(50, '='));
        
        try {
            // Step 1: Ensure directories
            await this.ensureDirectories();
            
            // Step 2: Download FFmpeg
            await this.downloadFFmpeg();
            
            // Step 3: Create icons
            await this.createIcons();
            
            // Step 4: Update package.json
            await this.updatePackageJson();
            
            // Step 5: Install Electron dependencies
            await this.installElectronDependencies();
            
            // Step 6: Build Electron app
            await this.buildElectronApp();
            
            // Step 7: Create portable launcher
            await this.createPortableLauncher();
            
            // Step 8: Create README
            await this.createReadme();
            
            console.log(''.padEnd(50, '='));
            console.log('✅ Build completed successfully!');
            console.log(`📦 Output directory: ${this.distDir}`);
            console.log('\n📋 Distribution files:');
            console.log('1. Installer: Media File Explorer Setup *.exe');
            console.log('2. Portable: MediaFileExplorer-Portable.exe');
            console.log('\n🚀 Ready for distribution to Windows users!');
            
        } catch (error) {
            console.error(''.padEnd(50, '='));
            console.error('❌ Build failed:', error.message);
            console.error(error.stack);
            process.exit(1);
        }
    }
}

// Main execution
if (require.main === module) {
    const builder = new ElectronAppBuilder();
    builder.run().catch(console.error);
}

module.exports = ElectronAppBuilder;