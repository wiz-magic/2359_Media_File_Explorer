; NSIS 설치 프로그램 추가 설정

!macro customInstall
  ; FFmpeg 다운로드 및 설치 옵션
  MessageBox MB_YESNO "비디오 썸네일 생성을 위해 FFmpeg를 다운로드하시겠습니까?$\n(약 80MB, 선택사항)" IDYES download_ffmpeg IDNO skip_ffmpeg
  
  download_ffmpeg:
    DetailPrint "FFmpeg 다운로드 중..."
    ; FFmpeg 다운로드 로직은 설치 후 앱에서 처리
    WriteRegStr HKCU "Software\MediaExplorer" "DownloadFFmpeg" "true"
    Goto ffmpeg_done
    
  skip_ffmpeg:
    WriteRegStr HKCU "Software\MediaExplorer" "DownloadFFmpeg" "false"
    
  ffmpeg_done:
!macroend

!macro customUnInstall
  ; 레지스트리 정리
  DeleteRegKey HKCU "Software\MediaExplorer"
  
  ; 캐시 폴더 삭제
  RMDir /r "$APPDATA\media-explorer-cache"
!macroend