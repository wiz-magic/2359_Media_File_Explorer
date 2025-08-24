#!/usr/bin/env python3
"""
Media Explorer Launcher for Windows
이 프로그램은 Media Explorer를 실행하는 런처입니다.
"""

import os
import sys
import subprocess
import webbrowser
import time
import json
import socket
import shutil
from pathlib import Path
import tkinter as tk
from tkinter import messagebox, ttk
import threading
import requests

class MediaExplorerLauncher:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Media Explorer")
        self.root.geometry("500x400")
        self.root.resizable(False, False)
        
        # 프로그램 경로 설정
        if getattr(sys, 'frozen', False):
            # PyInstaller로 빌드된 경우
            self.base_path = Path(sys._MEIPASS)
            self.install_path = Path(os.path.dirname(sys.executable))
        else:
            # 개발 환경
            self.base_path = Path(__file__).parent.parent
            self.install_path = self.base_path
        
        self.node_path = self.install_path / "node"
        self.ffmpeg_path = self.install_path / "ffmpeg"
        self.app_path = self.install_path / "app"
        
        self.server_process = None
        self.setup_ui()
        
    def setup_ui(self):
        """UI 설정"""
        # 타이틀
        title_frame = tk.Frame(self.root, bg="#2C3E50", height=80)
        title_frame.pack(fill="x")
        title_frame.pack_propagate(False)
        
        title_label = tk.Label(
            title_frame,
            text="📂 Media File Explorer",
            font=("Arial", 20, "bold"),
            bg="#2C3E50",
            fg="white"
        )
        title_label.pack(pady=20)
        
        # 상태 프레임
        status_frame = tk.Frame(self.root, bg="white", padx=20, pady=20)
        status_frame.pack(fill="both", expand=True)
        
        # 상태 표시
        self.status_label = tk.Label(
            status_frame,
            text="시스템 점검 중...",
            font=("Arial", 12),
            bg="white"
        )
        self.status_label.pack(pady=10)
        
        # 프로그레스 바
        self.progress = ttk.Progressbar(
            status_frame,
            length=400,
            mode='indeterminate'
        )
        self.progress.pack(pady=10)
        
        # 로그 텍스트
        log_frame = tk.Frame(status_frame, bg="white")
        log_frame.pack(fill="both", expand=True, pady=10)
        
        scrollbar = tk.Scrollbar(log_frame)
        scrollbar.pack(side="right", fill="y")
        
        self.log_text = tk.Text(
            log_frame,
            height=10,
            width=50,
            yscrollcommand=scrollbar.set,
            bg="#F5F5F5",
            font=("Consolas", 9)
        )
        self.log_text.pack(side="left", fill="both", expand=True)
        scrollbar.config(command=self.log_text.yview)
        
        # 버튼 프레임
        button_frame = tk.Frame(status_frame, bg="white")
        button_frame.pack(pady=10)
        
        self.start_button = tk.Button(
            button_frame,
            text="시작",
            command=self.start_app,
            bg="#3498DB",
            fg="white",
            font=("Arial", 12, "bold"),
            padx=30,
            pady=10,
            state="disabled"
        )
        self.start_button.pack(side="left", padx=5)
        
        self.stop_button = tk.Button(
            button_frame,
            text="종료",
            command=self.stop_app,
            bg="#E74C3C",
            fg="white",
            font=("Arial", 12, "bold"),
            padx=30,
            pady=10,
            state="disabled"
        )
        self.stop_button.pack(side="left", padx=5)
        
    def log(self, message):
        """로그 메시지 추가"""
        self.log_text.insert("end", f"{message}\n")
        self.log_text.see("end")
        self.root.update()
        
    def check_system(self):
        """시스템 체크"""
        self.progress.start()
        
        try:
            # Node.js 체크
            self.log("✓ Node.js 확인 중...")
            node_exe = self.node_path / "node.exe"
            if not node_exe.exists():
                raise FileNotFoundError("Node.js가 설치되지 않았습니다.")
            
            # ffmpeg 체크
            self.log("✓ FFmpeg 확인 중...")
            ffmpeg_exe = self.ffmpeg_path / "bin" / "ffmpeg.exe"
            if not ffmpeg_exe.exists():
                self.log("⚠ FFmpeg가 없습니다. 비디오 썸네일이 제한됩니다.")
            else:
                # PATH에 ffmpeg 추가
                os.environ["PATH"] = str(self.ffmpeg_path / "bin") + os.pathsep + os.environ.get("PATH", "")
                
            # 앱 파일 체크
            self.log("✓ 애플리케이션 파일 확인 중...")
            if not self.app_path.exists():
                raise FileNotFoundError("애플리케이션 파일이 없습니다.")
            
            # npm 패키지 체크 및 설치
            node_modules = self.app_path / "node_modules"
            if not node_modules.exists():
                self.log("📦 필요한 패키지 설치 중...")
                self.install_packages()
            
            self.progress.stop()
            self.status_label.config(text="✅ 시스템 준비 완료")
            self.start_button.config(state="normal")
            self.log("\n✅ 모든 점검 완료! '시작' 버튼을 눌러주세요.")
            
        except Exception as e:
            self.progress.stop()
            self.status_label.config(text="❌ 시스템 오류")
            self.log(f"\n❌ 오류: {str(e)}")
            messagebox.showerror("시스템 오류", str(e))
            
    def install_packages(self):
        """npm 패키지 설치"""
        npm_exe = self.node_path / "npm.cmd"
        if not npm_exe.exists():
            npm_exe = self.node_path / "npm"
            
        try:
            process = subprocess.Popen(
                [str(npm_exe), "install", "--production"],
                cwd=str(self.app_path),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env={**os.environ, "PATH": str(self.node_path) + os.pathsep + os.environ.get("PATH", "")}
            )
            
            for line in process.stdout:
                self.log(f"  {line.strip()}")
                
            process.wait()
            
            if process.returncode != 0:
                raise Exception("패키지 설치 실패")
                
        except Exception as e:
            raise Exception(f"패키지 설치 중 오류: {str(e)}")
            
    def is_port_in_use(self, port):
        """포트 사용 여부 확인"""
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            return s.connect_ex(('localhost', port)) == 0
            
    def start_app(self):
        """앱 시작"""
        self.start_button.config(state="disabled")
        self.stop_button.config(state="normal")
        
        try:
            # 포트 확인
            if self.is_port_in_use(3000):
                self.log("⚠ 포트 3000이 사용 중입니다. 다른 포트로 시도...")
                port = 3001
                while self.is_port_in_use(port) and port < 3100:
                    port += 1
            else:
                port = 3000
                
            self.log(f"\n🚀 서버를 포트 {port}에서 시작합니다...")
            
            # 서버 시작
            node_exe = self.node_path / "node.exe"
            server_js = self.app_path / "local-server.cjs"
            
            env = os.environ.copy()
            env["PATH"] = str(self.node_path) + os.pathsep + str(self.ffmpeg_path / "bin") + os.pathsep + env.get("PATH", "")
            env["PORT"] = str(port)
            
            self.server_process = subprocess.Popen(
                [str(node_exe), str(server_js)],
                cwd=str(self.app_path),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env
            )
            
            # 서버 시작 대기
            time.sleep(2)
            
            # 서버 상태 확인
            max_retries = 10
            for i in range(max_retries):
                try:
                    response = requests.get(f"http://localhost:{port}/api/system-info", timeout=1)
                    if response.status_code == 200:
                        self.log(f"✅ 서버가 성공적으로 시작되었습니다!")
                        break
                except:
                    time.sleep(1)
                    
            # 브라우저 열기
            self.log(f"🌐 브라우저를 엽니다...")
            webbrowser.open(f"http://localhost:{port}/real")
            
            self.status_label.config(text=f"✅ 실행 중 (포트: {port})")
            
            # 서버 로그 모니터링 시작
            threading.Thread(target=self.monitor_server, daemon=True).start()
            
        except Exception as e:
            self.log(f"❌ 시작 실패: {str(e)}")
            messagebox.showerror("시작 실패", str(e))
            self.start_button.config(state="normal")
            self.stop_button.config(state="disabled")
            
    def monitor_server(self):
        """서버 로그 모니터링"""
        if self.server_process:
            for line in self.server_process.stdout:
                if line.strip():
                    self.log(f"[서버] {line.strip()}")
                    
    def stop_app(self):
        """앱 종료"""
        try:
            if self.server_process:
                self.log("\n⏹ 서버를 종료합니다...")
                self.server_process.terminate()
                time.sleep(1)
                if self.server_process.poll() is None:
                    self.server_process.kill()
                self.server_process = None
                
            self.status_label.config(text="⏹ 중지됨")
            self.start_button.config(state="normal")
            self.stop_button.config(state="disabled")
            self.log("✅ 서버가 종료되었습니다.")
            
        except Exception as e:
            self.log(f"❌ 종료 실패: {str(e)}")
            
    def run(self):
        """런처 실행"""
        # 시스템 체크를 별도 스레드에서 실행
        threading.Thread(target=self.check_system, daemon=True).start()
        
        # 종료 이벤트 처리
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        
        # GUI 실행
        self.root.mainloop()
        
    def on_closing(self):
        """창 닫기 이벤트"""
        if self.server_process:
            if messagebox.askokcancel("종료", "서버가 실행 중입니다. 종료하시겠습니까?"):
                self.stop_app()
                self.root.destroy()
        else:
            self.root.destroy()

if __name__ == "__main__":
    launcher = MediaExplorerLauncher()
    launcher.run()