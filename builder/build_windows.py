#!/usr/bin/env python3
"""
Windows용 Media Explorer 설치 파일 빌더
PyInstaller와 함께 ffmpeg, Node.js 포터블 버전을 포함한 완전한 설치 패키지를 생성합니다.
"""

import os
import sys
import shutil
import subprocess
import zipfile
import urllib.request
import json
from pathlib import Path
import tempfile

class WindowsBuilder:
    def __init__(self):
        self.script_dir = Path(__file__).parent
        self.project_dir = self.script_dir.parent
        self.build_dir = self.script_dir / "build"
        self.dist_dir = self.script_dir / "dist"
        self.output_dir = self.script_dir / "output"
        
        # 다운로드 URL
        self.nodejs_url = "https://nodejs.org/dist/v20.11.0/node-v20.11.0-win-x64.zip"
        self.ffmpeg_url = "https://www.gyan.dev/ffmpeg/builds/packages/release/ffmpeg-7.0.2-essentials_build.zip"
        
    def clean_dirs(self):
        """빌드 디렉토리 정리"""
        print("🧹 빌드 디렉토리 정리 중...")
        for dir_path in [self.build_dir, self.dist_dir, self.output_dir]:
            if dir_path.exists():
                shutil.rmtree(dir_path)
            dir_path.mkdir(parents=True, exist_ok=True)
            
    def download_file(self, url, dest_path):
        """파일 다운로드 with 진행률 표시"""
        print(f"📥 다운로드 중: {url}")
        
        def download_progress(block_num, block_size, total_size):
            downloaded = block_num * block_size
            percent = min(downloaded * 100 / total_size, 100)
            bar_length = 40
            filled_length = int(bar_length * percent // 100)
            bar = '█' * filled_length + '-' * (bar_length - filled_length)
            sys.stdout.write(f'\r  |{bar}| {percent:.1f}%')
            sys.stdout.flush()
            
        urllib.request.urlretrieve(url, dest_path, download_progress)
        print()  # 새 줄
        
    def download_nodejs(self):
        """Node.js 포터블 버전 다운로드 및 압축 해제"""
        print("\n📦 Node.js 포터블 버전 준비 중...")
        
        nodejs_zip = self.build_dir / "nodejs.zip"
        nodejs_dir = self.output_dir / "node"
        
        if not nodejs_zip.exists():
            self.download_file(self.nodejs_url, nodejs_zip)
            
        print("  압축 해제 중...")
        with zipfile.ZipFile(nodejs_zip, 'r') as zip_ref:
            zip_ref.extractall(self.build_dir)
            
        # 압축 해제된 디렉토리 찾기
        extracted_dir = list(self.build_dir.glob("node-*"))[0]
        shutil.move(str(extracted_dir), str(nodejs_dir))
        
        print("✅ Node.js 준비 완료")
        return nodejs_dir
        
    def download_ffmpeg(self):
        """FFmpeg 바이너리 다운로드 및 압축 해제"""
        print("\n📦 FFmpeg 준비 중...")
        
        ffmpeg_zip = self.build_dir / "ffmpeg.zip"
        ffmpeg_dir = self.output_dir / "ffmpeg"
        
        if not ffmpeg_zip.exists():
            self.download_file(self.ffmpeg_url, ffmpeg_zip)
            
        print("  압축 해제 중...")
        with zipfile.ZipFile(ffmpeg_zip, 'r') as zip_ref:
            zip_ref.extractall(self.build_dir)
            
        # 압축 해제된 디렉토리 찾기
        extracted_dir = list(self.build_dir.glob("ffmpeg-*"))[0]
        shutil.move(str(extracted_dir), str(ffmpeg_dir))
        
        print("✅ FFmpeg 준비 완료")
        return ffmpeg_dir
        
    def copy_app_files(self):
        """앱 파일 복사"""
        print("\n📁 애플리케이션 파일 복사 중...")
        
        app_dir = self.output_dir / "app"
        app_dir.mkdir(exist_ok=True)
        
        # 필요한 파일들 복사
        files_to_copy = [
            "package.json",
            "package-lock.json",
            "local-server.cjs",
            "server.cjs",
            "ecosystem.config.cjs",
            "vite.config.ts",
            "tsconfig.json",
            "wrangler.jsonc"
        ]
        
        for file_name in files_to_copy:
            src = self.project_dir / file_name
            if src.exists():
                shutil.copy2(src, app_dir / file_name)
                print(f"  ✓ {file_name}")
                
        # 디렉토리 복사
        dirs_to_copy = ["dist", "src", "public"]
        for dir_name in dirs_to_copy:
            src_dir = self.project_dir / dir_name
            if src_dir.exists():
                shutil.copytree(src_dir, app_dir / dir_name)
                print(f"  ✓ {dir_name}/")
                
        # media-cache 디렉토리 생성
        (app_dir / "media-cache" / "thumbnails").mkdir(parents=True, exist_ok=True)
        
        print("✅ 앱 파일 복사 완료")
        return app_dir
        
    def build_launcher(self):
        """PyInstaller로 런처 빌드"""
        print("\n🔨 런처 빌드 중...")
        
        # PyInstaller 설정 파일 생성
        spec_content = f"""
# -*- mode: python ; coding: utf-8 -*-

a = Analysis(
    ['{self.script_dir / "media_explorer_launcher.py"}'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=['tkinter', 'requests'],
    hookspath=[],
    hooksconfig={{}},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='MediaExplorer',
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
    version_file=None,
)
"""
        
        spec_file = self.build_dir / "launcher.spec"
        spec_file.write_text(spec_content)
        
        # PyInstaller 실행
        try:
            subprocess.run([
                sys.executable, "-m", "PyInstaller",
                "--distpath", str(self.output_dir),
                "--workpath", str(self.build_dir),
                "--noconfirm",
                str(spec_file)
            ], check=True)
            
            print("✅ 런처 빌드 완료")
            
        except subprocess.CalledProcessError as e:
            print(f"❌ 런처 빌드 실패: {e}")
            raise
            
    def create_installer_script(self):
        """NSIS 설치 스크립트 생성"""
        print("\n📝 NSIS 설치 스크립트 생성 중...")
        
        nsis_script = f"""
!define PRODUCT_NAME "Media File Explorer"
!define PRODUCT_VERSION "1.0.0"
!define PRODUCT_PUBLISHER "Media Explorer Team"
!define PRODUCT_DIR_REGKEY "Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\MediaExplorer.exe"
!define PRODUCT_UNINST_KEY "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${{PRODUCT_NAME}}"

; MUI 2.0 설정
!include "MUI2.nsh"
!define MUI_ABORTWARNING
!define MUI_ICON "${{NSISDIR}}\\Contrib\\Graphics\\Icons\\modern-install.ico"
!define MUI_UNICON "${{NSISDIR}}\\Contrib\\Graphics\\Icons\\modern-uninstall.ico"

; 페이지
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\\LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_INSTFILES

; 언어
!insertmacro MUI_LANGUAGE "Korean"
!insertmacro MUI_LANGUAGE "English"

; 설치 정보
Name "${{PRODUCT_NAME}} ${{PRODUCT_VERSION}}"
OutFile "..\\MediaExplorerSetup.exe"
InstallDir "$PROGRAMFILES64\\MediaExplorer"
InstallDirRegKey HKLM "${{PRODUCT_DIR_REGKEY}}" ""
ShowInstDetails show
ShowUnInstDetails show

Section "MainSection" SEC01
    SetOutPath "$INSTDIR"
    SetOverwrite on
    
    ; 파일 복사
    File /r "..\\output\\*.*"
    
    ; 바로가기 생성
    CreateDirectory "$SMPROGRAMS\\Media File Explorer"
    CreateShortcut "$SMPROGRAMS\\Media File Explorer\\Media File Explorer.lnk" "$INSTDIR\\MediaExplorer.exe"
    CreateShortcut "$DESKTOP\\Media File Explorer.lnk" "$INSTDIR\\MediaExplorer.exe"
    
    ; 레지스트리 작성
    WriteRegStr HKLM "${{PRODUCT_DIR_REGKEY}}" "" "$INSTDIR\\MediaExplorer.exe"
    WriteRegStr HKLM "${{PRODUCT_UNINST_KEY}}" "DisplayName" "${{PRODUCT_NAME}}"
    WriteRegStr HKLM "${{PRODUCT_UNINST_KEY}}" "UninstallString" "$INSTDIR\\uninst.exe"
    WriteRegStr HKLM "${{PRODUCT_UNINST_KEY}}" "DisplayIcon" "$INSTDIR\\MediaExplorer.exe"
    WriteRegStr HKLM "${{PRODUCT_UNINST_KEY}}" "DisplayVersion" "${{PRODUCT_VERSION}}"
    WriteRegStr HKLM "${{PRODUCT_UNINST_KEY}}" "Publisher" "${{PRODUCT_PUBLISHER}}"
    
    ; PATH에 ffmpeg 추가 옵션
    MessageBox MB_YESNO "FFmpeg를 시스템 PATH에 추가하시겠습니까? (비디오 썸네일 생성에 필요)" IDYES AddPath IDNO NoPath
    
    AddPath:
        ; PATH에 ffmpeg\\bin 추가
        Push "$INSTDIR\\ffmpeg\\bin"
        Call AddToPath
        
    NoPath:
    
SectionEnd

Section -Post
    WriteUninstaller "$INSTDIR\\uninst.exe"
SectionEnd

Section Uninstall
    ; 파일 삭제
    Delete "$INSTDIR\\*.*"
    RMDir /r "$INSTDIR"
    
    ; 바로가기 삭제
    Delete "$DESKTOP\\Media File Explorer.lnk"
    Delete "$SMPROGRAMS\\Media File Explorer\\*.*"
    RMDir "$SMPROGRAMS\\Media File Explorer"
    
    ; 레지스트리 삭제
    DeleteRegKey HKLM "${{PRODUCT_UNINST_KEY}}"
    DeleteRegKey HKLM "${{PRODUCT_DIR_REGKEY}}"
    
    SetAutoClose true
SectionEnd

; PATH 추가 함수
Function AddToPath
    ; 구현 필요
FunctionEnd
"""
        
        nsis_file = self.script_dir / "installer.nsi"
        nsis_file.write_text(nsis_script)
        
        print("✅ NSIS 스크립트 생성 완료")
        return nsis_file
        
    def create_batch_installer(self):
        """배치 파일 기반 간단한 설치 프로그램 생성"""
        print("\n📝 배치 설치 프로그램 생성 중...")
        
        batch_content = """@echo off
chcp 65001 > nul
title Media File Explorer 설치

echo.
echo ===============================================
echo     Media File Explorer 설치 프로그램
echo ===============================================
echo.

:: 관리자 권한 확인
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 관리자 권한이 필요합니다.
    echo 마우스 오른쪽 버튼으로 클릭 후 "관리자 권한으로 실행"을 선택하세요.
    pause
    exit /b 1
)

:: 설치 경로 설정
set INSTALL_PATH=%ProgramFiles%\\MediaExplorer
echo 설치 경로: %INSTALL_PATH%
echo.

:: 기존 설치 확인
if exist "%INSTALL_PATH%" (
    echo 기존 설치를 발견했습니다. 덮어쓰시겠습니까? [Y/N]
    set /p OVERWRITE=
    if /i not "%OVERWRITE%"=="Y" (
        echo 설치를 취소했습니다.
        pause
        exit /b 0
    )
    echo 기존 파일을 제거하는 중...
    rmdir /s /q "%INSTALL_PATH%"
)

:: 설치 디렉토리 생성
echo 파일을 복사하는 중...
mkdir "%INSTALL_PATH%"

:: 파일 복사
xcopy /E /I /Y "output\\*" "%INSTALL_PATH%\\" > nul

:: 바탕화면 바로가기 생성
echo 바로가기를 생성하는 중...
powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\\Desktop\\Media File Explorer.lnk'); $Shortcut.TargetPath = '%INSTALL_PATH%\\MediaExplorer.exe'; $Shortcut.WorkingDirectory = '%INSTALL_PATH%'; $Shortcut.IconLocation = '%INSTALL_PATH%\\MediaExplorer.exe'; $Shortcut.Save()"

:: 시작 메뉴 바로가기 생성
mkdir "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Media File Explorer"
powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Media File Explorer\\Media File Explorer.lnk'); $Shortcut.TargetPath = '%INSTALL_PATH%\\MediaExplorer.exe'; $Shortcut.WorkingDirectory = '%INSTALL_PATH%'; $Shortcut.IconLocation = '%INSTALL_PATH%\\MediaExplorer.exe'; $Shortcut.Save()"

:: PATH에 ffmpeg 추가 옵션
echo.
set /p ADD_PATH=FFmpeg를 시스템 PATH에 추가하시겠습니까? (비디오 썸네일 생성에 필요) [Y/N]: 
if /i "%ADD_PATH%"=="Y" (
    echo PATH에 FFmpeg 추가 중...
    setx PATH "%PATH%;%INSTALL_PATH%\\ffmpeg\\bin" /M > nul 2>&1
    echo FFmpeg가 PATH에 추가되었습니다.
)

echo.
echo ===============================================
echo     설치가 완료되었습니다!
echo     바탕화면의 바로가기를 실행하세요.
echo ===============================================
echo.
pause
"""
        
        installer_file = self.output_dir.parent / "install.bat"
        installer_file.write_text(batch_content, encoding='utf-8')
        
        print("✅ 배치 설치 프로그램 생성 완료")
        return installer_file
        
    def create_package(self):
        """최종 패키지 생성"""
        print("\n📦 최종 패키지 생성 중...")
        
        # ZIP 파일로 압축
        package_name = f"MediaExplorer_Windows_Setup_v1.0.0.zip"
        package_path = self.script_dir / package_name
        
        with zipfile.ZipFile(package_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            # output 디렉토리 전체 압축
            for root, dirs, files in os.walk(self.output_dir):
                for file in files:
                    file_path = Path(root) / file
                    arcname = file_path.relative_to(self.output_dir.parent)
                    zipf.write(file_path, arcname)
                    
            # install.bat 추가
            installer = self.output_dir.parent / "install.bat"
            if installer.exists():
                zipf.write(installer, "install.bat")
                
        print(f"✅ 패키지 생성 완료: {package_path}")
        print(f"   크기: {package_path.stat().st_size / (1024*1024):.1f} MB")
        
        return package_path
        
    def build(self):
        """전체 빌드 프로세스"""
        print("🚀 Windows용 Media Explorer 빌드 시작\n")
        
        try:
            # 1. 디렉토리 정리
            self.clean_dirs()
            
            # 2. Node.js 다운로드
            self.download_nodejs()
            
            # 3. FFmpeg 다운로드
            self.download_ffmpeg()
            
            # 4. 앱 파일 복사
            self.copy_app_files()
            
            # 5. 런처 빌드
            self.build_launcher()
            
            # 6. 설치 프로그램 생성
            self.create_batch_installer()
            
            # 7. NSIS 스크립트 생성 (선택사항)
            self.create_installer_script()
            
            # 8. 최종 패키지 생성
            package = self.create_package()
            
            print("\n" + "="*50)
            print("✅ 빌드 완료!")
            print(f"📦 설치 파일: {package}")
            print("="*50)
            
        except Exception as e:
            print(f"\n❌ 빌드 실패: {e}")
            sys.exit(1)

if __name__ == "__main__":
    # 필요한 패키지 설치 확인
    try:
        import PyInstaller
    except ImportError:
        print("PyInstaller를 설치합니다...")
        subprocess.run([sys.executable, "-m", "pip", "install", "pyinstaller"], check=True)
        
    builder = WindowsBuilder()
    builder.build()