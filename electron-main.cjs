const { app, BrowserWindow, Menu, Tray, shell, dialog } = require('electron');
const path = require('path');
const { spawn } = require('child_process');
const fs = require('fs');

// Server process handle
let serverProcess = null;
let mainWindow = null;
let tray = null;

// Configuration
const SERVER_PORT = 3001;
const FRONTEND_PORT = 3000;

// Helper function to find available port
async function isPortAvailable(port) {
    return new Promise((resolve) => {
        const net = require('net');
        const server = net.createServer();
        
        server.once('error', () => resolve(false));
        server.once('listening', () => {
            server.close();
            resolve(true);
        });
        
        server.listen(port);
    });
}

// Start the Node.js backend server
async function startServer() {
    return new Promise((resolve, reject) => {
        try {
            // Check if server is already running
            if (serverProcess && !serverProcess.killed) {
                resolve();
                return;
            }

            // Set FFmpeg path if bundled
            const ffmpegPath = path.join(process.resourcesPath || __dirname, 'ffmpeg', 'ffmpeg.exe');
            if (fs.existsSync(ffmpegPath)) {
                process.env.FFMPEG_PATH = ffmpegPath;
                process.env.FFPROBE_PATH = path.join(path.dirname(ffmpegPath), 'ffprobe.exe');
            }

            // Start the server
            const serverPath = path.join(__dirname, 'local-server.cjs');
            serverProcess = spawn('node', [serverPath], {
                cwd: __dirname,
                env: { ...process.env },
                stdio: 'pipe'
            });

            serverProcess.stdout.on('data', (data) => {
                console.log(`Server: ${data}`);
                if (data.toString().includes('Server running')) {
                    resolve();
                }
            });

            serverProcess.stderr.on('data', (data) => {
                console.error(`Server Error: ${data}`);
            });

            serverProcess.on('error', (error) => {
                console.error('Failed to start server:', error);
                reject(error);
            });

            serverProcess.on('exit', (code) => {
                console.log(`Server exited with code ${code}`);
                serverProcess = null;
            });

            // Timeout after 10 seconds
            setTimeout(() => {
                if (!serverProcess || serverProcess.killed) {
                    reject(new Error('Server failed to start within timeout'));
                } else {
                    resolve(); // Assume server started even if no confirmation
                }
            }, 10000);

        } catch (error) {
            reject(error);
        }
    });
}

// Stop the server
function stopServer() {
    if (serverProcess && !serverProcess.killed) {
        serverProcess.kill();
        serverProcess = null;
    }
}

// Create the main window
function createWindow() {
    mainWindow = new BrowserWindow({
        width: 1400,
        height: 900,
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            webSecurity: true
        },
        icon: path.join(__dirname, 'public', 'icon.png'), // Add an icon if available
        title: 'Media File Explorer',
        autoHideMenuBar: true
    });

    // Load the application
    mainWindow.loadURL(`http://localhost:${FRONTEND_PORT}/real`);

    // Handle window closed
    mainWindow.on('closed', () => {
        mainWindow = null;
    });

    // Handle external links
    mainWindow.webContents.setWindowOpenHandler(({ url }) => {
        shell.openExternal(url);
        return { action: 'deny' };
    });

    // Create application menu
    const template = [
        {
            label: 'File',
            submenu: [
                {
                    label: 'Open Folder',
                    accelerator: 'CmdOrCtrl+O',
                    click: async () => {
                        const result = await dialog.showOpenDialog(mainWindow, {
                            properties: ['openDirectory']
                        });
                        if (!result.canceled && result.filePaths.length > 0) {
                            // Send folder path to the web app
                            mainWindow.webContents.executeJavaScript(`
                                if (window.scanFolder) {
                                    window.scanFolder('${result.filePaths[0].replace(/\\/g, '\\\\')}');
                                }
                            `);
                        }
                    }
                },
                { type: 'separator' },
                {
                    label: 'Quit',
                    accelerator: 'CmdOrCtrl+Q',
                    click: () => {
                        app.quit();
                    }
                }
            ]
        },
        {
            label: 'View',
            submenu: [
                { role: 'reload' },
                { role: 'forceReload' },
                { role: 'toggleDevTools' },
                { type: 'separator' },
                { role: 'resetZoom' },
                { role: 'zoomIn' },
                { role: 'zoomOut' },
                { type: 'separator' },
                { role: 'togglefullscreen' }
            ]
        },
        {
            label: 'Help',
            submenu: [
                {
                    label: 'About',
                    click: () => {
                        dialog.showMessageBox(mainWindow, {
                            type: 'info',
                            title: 'About Media File Explorer',
                            message: 'Media File Explorer',
                            detail: 'Version 1.0.0\n\nA powerful media file browser and organizer.\n\n© 2024 Media File Explorer',
                            buttons: ['OK']
                        });
                    }
                },
                {
                    label: 'GitHub Repository',
                    click: () => {
                        shell.openExternal('https://github.com/wiz-magic/2359_Media_File_Explorer');
                    }
                }
            ]
        }
    ];

    const menu = Menu.buildFromTemplate(template);
    Menu.setApplicationMenu(menu);
}

// Create system tray
function createTray() {
    if (process.platform === 'win32' || process.platform === 'darwin') {
        // Create a simple tray icon (you can replace with actual icon)
        tray = new Tray(path.join(__dirname, 'public', 'icon.png'));
        
        const contextMenu = Menu.buildFromTemplate([
            {
                label: 'Show',
                click: () => {
                    if (mainWindow) {
                        mainWindow.show();
                        mainWindow.focus();
                    }
                }
            },
            {
                label: 'Hide',
                click: () => {
                    if (mainWindow) {
                        mainWindow.hide();
                    }
                }
            },
            { type: 'separator' },
            {
                label: 'Quit',
                click: () => {
                    app.quit();
                }
            }
        ]);

        tray.setToolTip('Media File Explorer');
        tray.setContextMenu(contextMenu);

        // Show window on double click
        tray.on('double-click', () => {
            if (mainWindow) {
                mainWindow.show();
                mainWindow.focus();
            }
        });
    }
}

// App event handlers
app.whenReady().then(async () => {
    try {
        // Check if ports are available
        const isBackendPortFree = await isPortAvailable(SERVER_PORT);
        const isFrontendPortFree = await isPortAvailable(FRONTEND_PORT);

        if (!isBackendPortFree || !isFrontendPortFree) {
            dialog.showErrorBox(
                'Port In Use',
                `Required ports (${FRONTEND_PORT} or ${SERVER_PORT}) are already in use.\nPlease close other applications and try again.`
            );
            app.quit();
            return;
        }

        // Start the server
        console.log('Starting server...');
        await startServer();
        console.log('Server started successfully');

        // Wait a bit for server to fully initialize
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Create the window
        createWindow();

        // Create tray icon
        createTray();

    } catch (error) {
        console.error('Failed to start application:', error);
        dialog.showErrorBox('Startup Error', `Failed to start the application:\n${error.message}`);
        app.quit();
    }
});

// Quit when all windows are closed
app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

// Re-create window on macOS
app.on('activate', () => {
    if (mainWindow === null) {
        createWindow();
    }
});

// Clean up on exit
app.on('before-quit', () => {
    stopServer();
});

app.on('will-quit', () => {
    stopServer();
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
    console.error('Uncaught exception:', error);
    dialog.showErrorBox('Unexpected Error', error.message);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled rejection at:', promise, 'reason:', reason);
});