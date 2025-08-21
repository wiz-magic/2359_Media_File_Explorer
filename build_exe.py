#!/usr/bin/env python3
"""
Media File Explorer Windows Executable Builder
This script packages the Node.js application with all dependencies
into a standalone Windows executable with embedded FFmpeg support.
"""

import os
import sys
import shutil
import subprocess
import zipfile
import urllib.request
import json
from pathlib import Path

class MediaExplorerBuilder:
    def __init__(self):
        self.base_dir = Path(__file__).parent.absolute()
        self.build_dir = self.base_dir / "build_dist"
        self.dist_dir = self.base_dir / "dist"
        self.resources_dir = self.build_dir / "resources"
        self.ffmpeg_dir = self.resources_dir / "ffmpeg"
        
    def clean_build_directories(self):
        """Clean previous build artifacts"""
        print("🧹 Cleaning build directories...")
        for dir_path in [self.build_dir, self.dist_dir]:
            if dir_path.exists():
                shutil.rmtree(dir_path)
        self.build_dir.mkdir(exist_ok=True)
        self.resources_dir.mkdir(exist_ok=True)
        self.ffmpeg_dir.mkdir(exist_ok=True)
        
    def download_ffmpeg(self):
        """Download FFmpeg for Windows"""
        print("📥 Downloading FFmpeg for Windows...")
        ffmpeg_url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
        ffmpeg_zip = self.build_dir / "ffmpeg.zip"
        
        # Download with progress
        def download_progress(block_num, block_size, total_size):
            downloaded = block_num * block_size
            percent = min(100, (downloaded / total_size) * 100)
            print(f"  Downloading: {percent:.1f}%", end='\r')
            
        try:
            urllib.request.urlretrieve(ffmpeg_url, ffmpeg_zip, reporthook=download_progress)
            print("\n  ✅ FFmpeg downloaded successfully")
            
            # Extract FFmpeg
            print("  📦 Extracting FFmpeg...")
            with zipfile.ZipFile(ffmpeg_zip, 'r') as zip_ref:
                zip_ref.extractall(self.build_dir)
            
            # Find and move ffmpeg.exe and ffprobe.exe
            for root, dirs, files in os.walk(self.build_dir):
                if 'ffmpeg.exe' in files:
                    shutil.copy2(os.path.join(root, 'ffmpeg.exe'), self.ffmpeg_dir)
                    shutil.copy2(os.path.join(root, 'ffprobe.exe'), self.ffmpeg_dir)
                    print("  ✅ FFmpeg extracted successfully")
                    break
                    
            # Clean up zip file
            ffmpeg_zip.unlink()
            
        except Exception as e:
            print(f"  ⚠️ Could not download FFmpeg: {e}")
            print("  Continuing without FFmpeg (video thumbnails will not work)")
            
    def create_node_portable(self):
        """Download portable Node.js for Windows"""
        print("📥 Downloading portable Node.js...")
        node_version = "v20.11.0"
        node_url = f"https://nodejs.org/dist/{node_version}/node-{node_version}-win-x64.zip"
        node_zip = self.build_dir / "node.zip"
        
        try:
            def download_progress(block_num, block_size, total_size):
                downloaded = block_num * block_size
                percent = min(100, (downloaded / total_size) * 100)
                print(f"  Downloading: {percent:.1f}%", end='\r')
                
            urllib.request.urlretrieve(node_url, node_zip, reporthook=download_progress)
            print("\n  ✅ Node.js downloaded successfully")
            
            # Extract Node.js
            print("  📦 Extracting Node.js...")
            with zipfile.ZipFile(node_zip, 'r') as zip_ref:
                zip_ref.extractall(self.build_dir)
            
            # Rename to simple 'node' directory
            for item in self.build_dir.iterdir():
                if item.is_dir() and item.name.startswith('node-'):
                    item.rename(self.resources_dir / 'node')
                    break
                    
            node_zip.unlink()
            print("  ✅ Node.js extracted successfully")
            
        except Exception as e:
            print(f"  ❌ Error downloading Node.js: {e}")
            sys.exit(1)
            
    def copy_project_files(self):
        """Copy project files to build directory"""
        print("📋 Copying project files...")
        
        # Files and directories to copy
        items_to_copy = [
            'package.json',
            'package-lock.json',
            'server.cjs',
            'local-server.cjs',
            'ecosystem.config.cjs',
            'tsconfig.json',
            'vite.config.ts',
            'src',
            'public'
        ]
        
        app_dir = self.resources_dir / 'app'
        app_dir.mkdir(exist_ok=True)
        
        for item in items_to_copy:
            source = self.base_dir / item
            if source.exists():
                dest = app_dir / item
                if source.is_dir():
                    shutil.copytree(source, dest)
                else:
                    shutil.copy2(source, dest)
                print(f"  ✅ Copied {item}")
                
    def install_npm_dependencies(self):
        """Install npm dependencies"""
        print("📦 Installing npm dependencies...")
        app_dir = self.resources_dir / 'app'
        node_exe = self.resources_dir / 'node' / 'node.exe'
        npm_cmd = self.resources_dir / 'node' / 'npm.cmd'
        
        # Create a batch script to run npm with the portable node
        npm_install_script = app_dir / 'install_deps.bat'
        with open(npm_install_script, 'w') as f:
            f.write(f'''@echo off
cd /d "{app_dir}"
"{node_exe}" "{self.resources_dir / 'node' / 'node_modules' / 'npm' / 'bin' / 'npm-cli.js'}" install --production
''')
        
        try:
            # Run npm install
            result = subprocess.run(
                [str(npm_install_script)],
                cwd=str(app_dir),
                shell=True,
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                print("  ✅ Dependencies installed successfully")
            else:
                print(f"  ⚠️ npm install had issues: {result.stderr}")
                
        except Exception as e:
            print(f"  ⚠️ Could not install dependencies: {e}")
            
    def create_launcher_script(self):
        """Create the main launcher Python script"""
        print("🔧 Creating launcher script...")
        
        launcher_content = '''#!/usr/bin/env python3
"""
Media File Explorer Launcher
Starts the Node.js server and opens the browser
"""

import os
import sys
import subprocess
import time
import webbrowser
import threading
from pathlib import Path
import tkinter as tk
from tkinter import ttk, messagebox
import json

class MediaExplorerLauncher:
    def __init__(self):
        self.base_dir = Path(getattr(sys, '_MEIPASS', Path(__file__).parent))
        self.resources_dir = self.base_dir / 'resources'
        self.app_dir = self.resources_dir / 'app'
        self.node_exe = self.resources_dir / 'node' / 'node.exe'
        self.ffmpeg_exe = self.resources_dir / 'ffmpeg' / 'ffmpeg.exe'
        self.server_process = None
        self.port = 3001
        
        # Set FFmpeg path as environment variable
        if self.ffmpeg_exe.exists():
            os.environ['FFMPEG_PATH'] = str(self.ffmpeg_exe.parent)
            os.environ['PATH'] = f"{self.ffmpeg_exe.parent};{os.environ.get('PATH', '')}"
            
    def check_port_available(self):
        """Check if port is available"""
        import socket
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(('', self.port))
                return True
            except:
                return False
                
    def start_server(self):
        """Start the Node.js server"""
        if not self.check_port_available():
            messagebox.showwarning(
                "Port In Use",
                f"Port {self.port} is already in use. Please close other applications and try again."
            )
            return False
            
        try:
            # Start the server
            server_script = self.app_dir / 'local-server.cjs'
            self.server_process = subprocess.Popen(
                [str(self.node_exe), str(server_script)],
                cwd=str(self.app_dir),
                creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Wait for server to start
            time.sleep(3)
            
            # Check if server is running
            if self.server_process.poll() is not None:
                return False
                
            return True
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to start server: {e}")
            return False
            
    def open_browser(self):
        """Open the default browser"""
        time.sleep(2)  # Wait for server to fully start
        webbrowser.open('http://localhost:3000')
        
    def create_gui(self):
        """Create system tray GUI"""
        root = tk.Tk()
        root.title("Media File Explorer")
        root.geometry("400x200")
        root.resizable(False, False)
        
        # Set icon if available
        try:
            icon_path = self.resources_dir / 'icon.ico'
            if icon_path.exists():
                root.iconbitmap(str(icon_path))
        except:
            pass
            
        # Create widgets
        label = ttk.Label(root, text="Media File Explorer is running", font=('Arial', 12))
        label.pack(pady=20)
        
        status_label = ttk.Label(root, text="Server Status: Starting...", font=('Arial', 10))
        status_label.pack(pady=10)
        
        # Button frame
        button_frame = ttk.Frame(root)
        button_frame.pack(pady=20)
        
        open_btn = ttk.Button(
            button_frame,
            text="Open in Browser",
            command=lambda: webbrowser.open('http://localhost:3000')
        )
        open_btn.pack(side=tk.LEFT, padx=5)
        
        stop_btn = ttk.Button(
            button_frame,
            text="Stop Server",
            command=lambda: self.stop_server(root)
        )
        stop_btn.pack(side=tk.LEFT, padx=5)
        
        # Start server in background
        def start_background():
            if self.start_server():
                status_label.config(text="Server Status: Running on http://localhost:3000")
                self.open_browser()
            else:
                status_label.config(text="Server Status: Failed to start")
                messagebox.showerror("Error", "Failed to start the server")
                
        threading.Thread(target=start_background, daemon=True).start()
        
        # Handle window close
        root.protocol("WM_DELETE_WINDOW", lambda: self.stop_server(root))
        
        root.mainloop()
        
    def stop_server(self, root=None):
        """Stop the server and exit"""
        if self.server_process:
            self.server_process.terminate()
            time.sleep(1)
            if self.server_process.poll() is None:
                self.server_process.kill()
                
        if root:
            root.quit()
            
        sys.exit(0)
        
    def run(self):
        """Main entry point"""
        try:
            self.create_gui()
        except KeyboardInterrupt:
            self.stop_server()
        except Exception as e:
            messagebox.showerror("Error", f"An error occurred: {e}")
            self.stop_server()

if __name__ == "__main__":
    launcher = MediaExplorerLauncher()
    launcher.run()
'''
        
        launcher_file = self.build_dir / 'MediaExplorer.py'
        with open(launcher_file, 'w', encoding='utf-8') as f:
            f.write(launcher_content)
            
        print("  ✅ Launcher script created")
        return launcher_file
        
    def create_pyinstaller_spec(self, launcher_file):
        """Create PyInstaller spec file"""
        print("📝 Creating PyInstaller spec file...")
        
        spec_content = f'''# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['{launcher_file}'],
    pathex=[],
    binaries=[],
    datas=[
        ('{self.resources_dir}', 'resources'),
    ],
    hiddenimports=['tkinter'],
    hookspath=[],
    hooksconfig={{}},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='MediaFileExplorer',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,
    version_info=None,
)
'''
        
        spec_file = self.build_dir / 'MediaExplorer.spec'
        with open(spec_file, 'w', encoding='utf-8') as f:
            f.write(spec_content)
            
        print("  ✅ Spec file created")
        return spec_file
        
    def build_executable(self, spec_file):
        """Build the executable using PyInstaller"""
        print("🔨 Building executable with PyInstaller...")
        
        try:
            subprocess.run([
                sys.executable, '-m', 'pip', 'install', 'pyinstaller'
            ], check=True)
            
            result = subprocess.run([
                sys.executable, '-m', 'PyInstaller',
                '--clean',
                '--noconfirm',
                str(spec_file)
            ], cwd=str(self.build_dir), capture_output=True, text=True)
            
            if result.returncode == 0:
                print("  ✅ Executable built successfully")
                
                # Move executable to final location
                exe_path = self.build_dir / 'dist' / 'MediaFileExplorer.exe'
                if exe_path.exists():
                    final_path = self.dist_dir / 'MediaFileExplorer.exe'
                    self.dist_dir.mkdir(exist_ok=True)
                    shutil.move(str(exe_path), str(final_path))
                    print(f"  ✅ Executable moved to: {final_path}")
                    return final_path
            else:
                print(f"  ❌ Build failed: {result.stderr}")
                return None
                
        except Exception as e:
            print(f"  ❌ Error building executable: {e}")
            return None
            
    def create_installer_script(self):
        """Create NSIS installer script for better distribution"""
        print("📝 Creating installer script...")
        
        nsis_script = '''!include "MUI2.nsh"

Name "Media File Explorer"
OutFile "MediaFileExplorer_Setup.exe"
InstallDir "$PROGRAMFILES\\MediaFileExplorer"
RequestExecutionLevel admin

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\\Contrib\\Graphics\\Icons\\modern-install.ico"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

Section "Install"
    SetOutPath "$INSTDIR"
    File /r "dist\\*.*"
    
    CreateDirectory "$SMPROGRAMS\\Media File Explorer"
    CreateShortcut "$SMPROGRAMS\\Media File Explorer\\Media File Explorer.lnk" "$INSTDIR\\MediaFileExplorer.exe"
    CreateShortcut "$DESKTOP\\Media File Explorer.lnk" "$INSTDIR\\MediaFileExplorer.exe"
    
    WriteUninstaller "$INSTDIR\\Uninstall.exe"
    
    WriteRegStr HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\MediaFileExplorer" \\
                     "DisplayName" "Media File Explorer"
    WriteRegStr HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\MediaFileExplorer" \\
                     "UninstallString" "$INSTDIR\\Uninstall.exe"
SectionEnd

Section "Uninstall"
    Delete "$INSTDIR\\*.*"
    RMDir /r "$INSTDIR"
    Delete "$SMPROGRAMS\\Media File Explorer\\*.*"
    RMDir "$SMPROGRAMS\\Media File Explorer"
    Delete "$DESKTOP\\Media File Explorer.lnk"
    
    DeleteRegKey HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\MediaFileExplorer"
SectionEnd
'''
        
        nsis_file = self.dist_dir / 'installer.nsi'
        with open(nsis_file, 'w') as f:
            f.write(nsis_script)
            
        print("  ✅ Installer script created")
        print(f"  📌 To create installer, install NSIS and run: makensis {nsis_file}")
        
    def run(self):
        """Main build process"""
        print("🚀 Starting Media File Explorer build process...")
        print("=" * 50)
        
        # Step 1: Clean
        self.clean_build_directories()
        
        # Step 2: Download FFmpeg
        self.download_ffmpeg()
        
        # Step 3: Download Node.js
        self.create_node_portable()
        
        # Step 4: Copy project files
        self.copy_project_files()
        
        # Step 5: Install npm dependencies
        self.install_npm_dependencies()
        
        # Step 6: Create launcher
        launcher_file = self.create_launcher_script()
        
        # Step 7: Create spec file
        spec_file = self.create_pyinstaller_spec(launcher_file)
        
        # Step 8: Build executable
        exe_path = self.build_executable(spec_file)
        
        # Step 9: Create installer script
        if exe_path:
            self.create_installer_script()
            
        print("=" * 50)
        if exe_path:
            print(f"✅ Build completed successfully!")
            print(f"📦 Executable location: {exe_path}")
            print(f"📦 Distribution folder: {self.dist_dir}")
            print("\n📋 Next steps:")
            print("1. Test the executable on a Windows machine")
            print("2. (Optional) Use NSIS to create an installer")
            print("3. Distribute the MediaFileExplorer.exe file to users")
        else:
            print("❌ Build failed. Please check the errors above.")

if __name__ == "__main__":
    builder = MediaExplorerBuilder()
    builder.run()