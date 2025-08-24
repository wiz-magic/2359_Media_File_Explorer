const { app, BrowserWindow, Menu, Tray, dialog, shell, ipcMain } = require('electron');
const path = require('path');
const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');

// 서버 프로세스와 설정
let serverProcess = null;
let mainWindow = null;
let tray = null;
let serverPort = 3000;
let isQuitting = false;

// 앱 경로 설정
const isDev = !app.isPackaged;
const appPath = isDev ? path.join(__dirname, '..') : process.resourcesPath;
const ffmpegPath = isDev 
  ? path.join(__dirname, '..', 'ffmpeg', 'bin')
  : path.join(process.resourcesPath, 'ffmpeg', 'bin');

// 포트 사용 가능 여부 확인
function isPortAvailable(port) {
  return new Promise((resolve) => {
    const server = http.createServer();
    server.once('error', () => resolve(false));
    server.once('listening', () => {
      server.close();
      resolve(true);
    });
    server.listen(port, '127.0.0.1');
  });
}

// 사용 가능한 포트 찾기
async function findAvailablePort(startPort = 3000) {
  for (let port = startPort; port < startPort + 100; port++) {
    if (await isPortAvailable(port)) {
      return port;
    }
  }
  throw new Error('사용 가능한 포트를 찾을 수 없습니다');
}

// 서버 시작
async function startServer() {
  try {
    // 포트 찾기
    serverPort = await findAvailablePort(3000);
    console.log(`서버를 포트 ${serverPort}에서 시작합니다...`);

    // 환경 변수 설정
    const env = {
      ...process.env,
      PORT: serverPort.toString(),
      NODE_ENV: 'production'
    };

    // FFmpeg 경로 추가
    if (fs.existsSync(ffmpegPath)) {
      env.PATH = `${ffmpegPath}${path.delimiter}${process.env.PATH}`;
      env.FFMPEG_PATH = path.join(ffmpegPath, 'ffmpeg.exe');
    }

    // 서버 스크립트 경로
    const serverScript = isDev
      ? path.join(__dirname, '..', 'local-server.cjs')
      : path.join(process.resourcesPath, 'app', 'local-server.cjs');

    // Node.js 실행 파일 경로 (시스템 Node.js 사용)
    const nodePath = 'node';

    // 서버 프로세스 시작
    serverProcess = spawn(nodePath, [serverScript], {
      cwd: isDev ? path.join(__dirname, '..') : path.join(process.resourcesPath, 'app'),
      env: env,
      stdio: ['pipe', 'pipe', 'pipe']
    });

    serverProcess.stdout.on('data', (data) => {
      console.log(`[서버]: ${data.toString()}`);
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('server-log', data.toString());
      }
    });

    serverProcess.stderr.on('data', (data) => {
      console.error(`[서버 에러]: ${data.toString()}`);
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('server-error', data.toString());
      }
    });

    serverProcess.on('close', (code) => {
      console.log(`서버 프로세스 종료: ${code}`);
      serverProcess = null;
    });

    // 서버 시작 대기
    await waitForServer(serverPort);
    console.log('서버가 성공적으로 시작되었습니다');

    return serverPort;
  } catch (error) {
    console.error('서버 시작 실패:', error);
    throw error;
  }
}

// 서버 응답 대기
async function waitForServer(port, maxRetries = 30) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await new Promise((resolve, reject) => {
        const req = http.get(`http://localhost:${port}/api/system-info`, (res) => {
          resolve(res.statusCode === 200);
        });
        req.on('error', reject);
        req.setTimeout(1000, () => reject(new Error('timeout')));
      });
      return true;
    } catch (error) {
      // 서버가 아직 준비되지 않음
    }
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  throw new Error('서버 시작 시간 초과');
}

// 서버 중지
function stopServer() {
  if (serverProcess) {
    console.log('서버를 중지합니다...');
    serverProcess.kill('SIGTERM');
    serverProcess = null;
  }
}

// 메인 윈도우 생성
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    title: 'Media File Explorer',
    icon: path.join(__dirname, 'icon.ico'),
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    },
    show: false
  });

  // 스플래시 화면 표시
  mainWindow.loadFile(path.join(__dirname, 'loading.html'));

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    
    // 서버 시작 후 앱 로드
    startServer()
      .then((port) => {
        setTimeout(() => {
          mainWindow.loadURL(`http://localhost:${port}/real`);
        }, 1000);
      })
      .catch((error) => {
        dialog.showErrorBox('서버 시작 실패', error.message);
        app.quit();
      });
  });

  // 창 닫기 이벤트
  mainWindow.on('close', (event) => {
    if (!isQuitting) {
      event.preventDefault();
      mainWindow.hide();
      
      // 트레이 알림
      if (tray) {
        tray.displayBalloon({
          title: 'Media File Explorer',
          content: '프로그램이 시스템 트레이에서 실행 중입니다'
        });
      }
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// 시스템 트레이 생성
function createTray() {
  tray = new Tray(path.join(__dirname, 'icon.ico'));
  
  const contextMenu = Menu.buildFromTemplate([
    {
      label: '열기',
      click: () => {
        if (mainWindow) {
          mainWindow.show();
          mainWindow.focus();
        }
      }
    },
    {
      label: '서버 재시작',
      click: async () => {
        stopServer();
        const port = await startServer();
        if (mainWindow) {
          mainWindow.loadURL(`http://localhost:${port}/real`);
        }
      }
    },
    { type: 'separator' },
    {
      label: '종료',
      click: () => {
        isQuitting = true;
        app.quit();
      }
    }
  ]);

  tray.setToolTip('Media File Explorer');
  tray.setContextMenu(contextMenu);

  tray.on('double-click', () => {
    if (mainWindow) {
      mainWindow.show();
      mainWindow.focus();
    }
  });
}

// 메뉴 설정
function createMenu() {
  const template = [
    {
      label: '파일',
      submenu: [
        {
          label: '새 스캔',
          accelerator: 'CmdOrCtrl+N',
          click: () => {
            if (mainWindow) {
              mainWindow.webContents.send('new-scan');
            }
          }
        },
        { type: 'separator' },
        {
          label: '종료',
          accelerator: 'CmdOrCtrl+Q',
          click: () => {
            isQuitting = true;
            app.quit();
          }
        }
      ]
    },
    {
      label: '보기',
      submenu: [
        {
          label: '새로고침',
          accelerator: 'F5',
          click: () => {
            if (mainWindow) {
              mainWindow.reload();
            }
          }
        },
        {
          label: '개발자 도구',
          accelerator: 'F12',
          click: () => {
            if (mainWindow) {
              mainWindow.webContents.toggleDevTools();
            }
          }
        }
      ]
    },
    {
      label: '도움말',
      submenu: [
        {
          label: '정보',
          click: () => {
            dialog.showMessageBox(mainWindow, {
              type: 'info',
              title: 'Media File Explorer',
              message: 'Media File Explorer v1.0.0',
              detail: '컴퓨터의 모든 미디어 파일을 쉽게 검색하고 미리보기할 수 있는 프로그램입니다.\n\n© 2024 Media Explorer Team',
              buttons: ['확인']
            });
          }
        },
        {
          label: 'GitHub',
          click: () => {
            shell.openExternal('https://github.com/your-repo/media-explorer');
          }
        }
      ]
    }
  ];

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}

// 앱 시작
app.whenReady().then(() => {
  createWindow();
  createTray();
  createMenu();
});

// 모든 창이 닫혔을 때
app.on('window-all-closed', () => {
  // macOS가 아닌 경우 앱 종료
  if (process.platform !== 'darwin') {
    if (!tray) {
      isQuitting = true;
      app.quit();
    }
  }
});

// 앱 활성화 (macOS)
app.on('activate', () => {
  if (mainWindow === null) {
    createWindow();
  } else {
    mainWindow.show();
  }
});

// 앱 종료 전 정리
app.on('before-quit', () => {
  isQuitting = true;
  stopServer();
});

// IPC 통신 핸들러
ipcMain.handle('get-server-port', () => serverPort);
ipcMain.handle('restart-server', async () => {
  stopServer();
  return await startServer();
});