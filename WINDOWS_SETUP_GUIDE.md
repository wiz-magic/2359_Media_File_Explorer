# 🚀 Windows용 Media Explorer 빌드 완벽 가이드

## 🎯 목표
**Python 설치 없이** 실행 가능한 완전한 독립형 Windows exe 파일 생성

## 📋 준비 사항

### 1단계: Node.js 설치 (빌드용 - 한 번만)
```
🌐 https://nodejs.org 접속
📥 "20.17.0 LTS" 또는 최신 LTS 버전 다운로드
⚙️ 설치 옵션에서 "Add to PATH" 체크 필수!
🔄 설치 후 컴퓨터 재시작
```

### 2단계: 설치 확인
```batch
# 명령 프롬프트에서 확인
node --version
npm --version
```

## 🚀 빌드 방법 (3가지 옵션)

### 옵션 1: 완전 자동 빌드 (권장) ⭐
```batch
build-electron-auto.bat 더블클릭
```
- ✅ Node.js 자동 설치 (필요시)
- ✅ 모든 과정 자동 처리
- ✅ 문제 자동 해결 시도

### 옵션 2: 기본 빌드
```batch
build-electron-exe.bat 더블클릭
```
- ✅ Node.js 설치 확인
- ✅ 빌드 과정 표시
- ✅ 결과 파일 안내

### 옵션 3: 수동 빌드 (고급 사용자)
```batch
cd electron
npm install
npm run build-win
```

## 🔧 문제 해결

### "Node.js를 찾을 수 없습니다" 오류

#### 해결방법 1: 진단 도구 실행
```batch
check-nodejs.bat 더블클릭
```
이 도구가 정확한 문제와 해결방법을 알려줍니다.

#### 해결방법 2: 수동 확인
1. **명령 프롬프트 열기**: `Win + R` → `cmd` → Enter
2. **버전 체크**: `node --version` 입력
3. **결과 확인**:
   - ✅ `v20.17.0` 표시 → 정상
   - ❌ `'node'은(는) 내부 또는 외부 명령...` → 설치 필요

#### 해결방법 3: PATH 환경변수 수정
```
1. Win + X → "시스템" 클릭
2. "고급 시스템 설정" 클릭  
3. "환경 변수" 버튼 클릭
4. 시스템 변수에서 "Path" 선택 → "편집"
5. "새로 만들기" → Node.js 경로 추가
   예: C:\Program Files\nodejs
6. 확인 → 컴퓨터 재시작
```

### "npm install 실패" 오류

#### 해결방법 1: 캐시 정리
```batch
npm cache clean --force
npm install
```

#### 해결방법 2: 네트워크 설정
```batch
npm config set registry https://registry.npmjs.org/
npm install
```

#### 해결방법 3: 권한 문제
- 명령 프롬프트를 **관리자 권한**으로 실행

### "빌드 실패" 오류

#### 해결방법 1: 백신 프로그램
- 백신 프로그램 일시 중지
- Windows Defender 실시간 보호 일시 중지

#### 해결방법 2: 디스크 공간
- 최소 2GB 여유 공간 확보
- C:\Users\%USERNAME%\AppData\Local\Temp 정리

#### 해결방법 3: 관리자 권한
- 배치 파일을 **관리자 권한으로 실행**

## 📦 생성되는 파일

### 빌드 성공 시 생성 파일:
```
electron/dist/
├── Media File Explorer Setup 1.0.0.exe  (설치 프로그램)
└── MediaExplorer-Portable-1.0.0.exe      (포터블 버전)
```

### 파일 크기:
- 설치 프로그램: 약 80-120MB
- 포터블 버전: 약 80-120MB

## 🎉 배포 및 사용

### 최종 사용자 요구사항:
- ✅ **Python 불필요**
- ✅ **Node.js 불필요**  
- ✅ **Windows 10/11만 필요**

### 설치 프로그램 사용법:
1. `Media File Explorer Setup 1.0.0.exe` 실행
2. 설치 위치 선택
3. 설치 완료 후 바탕화면 아이콘 클릭

### 포터블 버전 사용법:
1. `MediaExplorer-Portable-1.0.0.exe` 실행
2. 바로 사용 가능 (설치 불필요)

## 🔍 고급 팁

### 빌드 속도 향상:
```batch
# electron 폴더에서
npm config set cache C:\npm-cache
npm install
```

### 빌드 결과 최적화:
- `electron/package.json`에서 불필요한 파일 제외
- 아이콘 파일을 실제 .ico 파일로 교체

### 코드 서명 (선택사항):
```batch
# 코드 서명 인증서가 있는 경우
signtool sign /a /t http://timestamp.digicert.com "Media File Explorer Setup 1.0.0.exe"
```

## 🆘 여전히 문제가 있나요?

### 단계별 체크리스트:
- [ ] Node.js 20.17.0 이상 설치됨
- [ ] `node --version` 명령어 작동함
- [ ] `npm --version` 명령어 작동함
- [ ] 관리자 권한으로 실행함
- [ ] 백신 프로그램 일시 중지함
- [ ] 디스크 공간 2GB 이상 여유있음
- [ ] 인터넷 연결 정상

### 마지막 수단:
1. **Node.js 완전 재설치**:
   - 제어판에서 기존 Node.js 제거
   - https://nodejs.org에서 최신 LTS 다운로드
   - 재설치 후 컴퓨터 재시작

2. **수동 빌드 시도**:
   ```batch
   cd electron
   npm install electron electron-builder --save-dev
   npx electron-builder --win
   ```

## 📞 지원

문제가 계속 발생하면:
1. `check-nodejs.bat` 실행 결과 스크린샷
2. 오류 메시지 전체 복사
3. Windows 버전 (Win + R → winver)
4. 위 정보와 함께 문의

---

**🎯 목표: 원클릭으로 완전한 독립 실행형 Windows 프로그램 생성!**