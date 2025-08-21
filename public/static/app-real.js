// Media File Explorer Frontend - Real Backend Integration

class MediaExplorer {
    constructor() {
        this.sessionId = this.generateSessionId();
        this.currentPath = '';
        this.files = [];
        this.isScanning = false;
        this.searchTimeout = null;
        
        // Backend URL - Node.js server
        // In sandbox environment, use public URL instead of localhost
        this.API_BASE = window.location.hostname.includes('e2b.dev') 
            ? 'https://3001-i51luexms0t8qbiy65hut-6532622b.e2b.dev'
            : 'http://localhost:3001';
        
        this.init();
    }
    
    generateSessionId() {
        return 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    }
    
    async init() {
        this.renderUI();
        this.attachEventListeners();
        await this.loadSystemInfo();
        await this.loadRecentPaths();
    }
    
    renderUI() {
        const app = document.getElementById('app');
        app.innerHTML = `
            <!-- Header -->
            <div class="bg-white shadow-sm border-b">
                <div class="container mx-auto px-4 py-4">
                    <div class="flex items-center justify-between mb-4">
                        <h1 class="text-2xl font-bold text-gray-800">
                            <i class="fas fa-folder-open mr-2 text-blue-500"></i>
                            Media File Explorer (Real File System)
                        </h1>
                        <div class="flex items-center">
                            <span class="status-dot ready" id="statusDot"></span>
                            <span class="text-sm text-gray-600" id="statusText">Ready</span>
                        </div>
                    </div>
                    
                    <!-- Path Input Section -->
                    <div class="flex gap-2 mb-4">
                        <div class="flex-1">
                            <input 
                                type="text" 
                                id="folderPath" 
                                class="path-input w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                                placeholder="폴더 경로 입력 (예: /home/user 또는 C:\\Users)"
                            />
                        </div>
                        <button 
                            id="validateBtn"
                            class="px-4 py-2 bg-gray-500 text-white rounded-lg hover:bg-gray-600 transition-colors"
                            onclick="explorer.validatePath()"
                        >
                            <i class="fas fa-check mr-2"></i>확인
                        </button>
                        <button 
                            id="scanBtn"
                            class="px-6 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
                            onclick="explorer.scanFolder()"
                        >
                            <i class="fas fa-search mr-2"></i>스캔
                        </button>
                    </div>
                    
                    <!-- Scan Options -->
                    <div class="flex items-center gap-4 mb-2">
                        <label class="flex items-center">
                            <input type="checkbox" id="includeSubfolders" checked class="mr-2">
                            <span class="text-sm">하위 폴더 포함</span>
                        </label>
                        <label class="flex items-center">
                            <span class="text-sm mr-2">깊이:</span>
                            <select id="maxDepth" class="px-2 py-1 border rounded text-sm">
                                <option value="1">1 레벨</option>
                                <option value="2">2 레벨</option>
                                <option value="3" selected>3 레벨</option>
                                <option value="5">5 레벨</option>
                                <option value="10">10 레벨</option>
                            </select>
                        </label>
                    </div>
                    
                    <!-- Recent Paths -->
                    <div class="flex items-center gap-2">
                        <label class="text-sm text-gray-600">최근 경로:</label>
                        <select 
                            id="recentPaths" 
                            class="flex-1 px-3 py-1 border rounded text-sm"
                            onchange="explorer.loadRecentPath(this.value)"
                        >
                            <option value="">선택하세요...</option>
                        </select>
                        <span id="systemInfo" class="text-xs text-gray-500"></span>
                    </div>
                </div>
            </div>
            
            <!-- Search Section -->
            <div class="container mx-auto px-4 py-4">
                <div class="bg-white rounded-lg shadow-sm p-4">
                    <div class="relative">
                        <i class="fas fa-search absolute left-3 top-3 text-gray-400"></i>
                        <input 
                            type="text" 
                            id="searchBox" 
                            class="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                            placeholder="파일명 검색..."
                            disabled
                            oninput="explorer.handleSearch(this.value)"
                        />
                    </div>
                    
                    <!-- Results Info -->
                    <div id="resultsInfo" class="mt-2 text-sm text-gray-600"></div>
                </div>
            </div>
            
            <!-- File Grid -->
            <div class="container mx-auto px-4 pb-8">
                <div id="fileGrid" class="file-grid">
                    <!-- Files will be displayed here -->
                </div>
                
                <!-- Loading Indicator -->
                <div id="loadingIndicator" class="hidden fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
                    <div class="bg-white rounded-lg p-6 flex flex-col items-center">
                        <div class="spinner mb-4"></div>
                        <p class="text-gray-700" id="loadingText">스캔 중...</p>
                    </div>
                </div>
                
                <!-- Preview Modal -->
                <div id="previewModal" class="hidden fixed inset-0 modal-backdrop flex items-center justify-center z-50">
                    <div class="bg-white rounded-lg max-w-5xl max-h-[90vh] w-full mx-4 overflow-hidden">
                        <div class="flex items-center justify-between p-4 border-b">
                            <h3 id="previewTitle" class="font-semibold text-lg truncate"></h3>
                            <button onclick="explorer.closePreview()" class="text-gray-500 hover:text-gray-700">
                                <i class="fas fa-times text-xl"></i>
                            </button>
                        </div>
                        <div id="previewContent" class="p-4 overflow-auto max-h-[75vh]">
                            <!-- Preview content -->
                        </div>
                    </div>
                </div>
            </div>
        `;
    }
    
    attachEventListeners() {
        // Enter key on path input
        document.getElementById('folderPath').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.scanFolder();
            }
        });
        
        // Click outside modal to close
        document.getElementById('previewModal').addEventListener('click', (e) => {
            if (e.target.id === 'previewModal') {
                this.closePreview();
            }
        });
        
        // ESC key to close modal
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closePreview();
            }
        });
    }
    
    async loadSystemInfo() {
        try {
            const response = await axios.get(`${this.API_BASE}/api/system-info`);
            const info = response.data;
            document.getElementById('systemInfo').textContent = 
                `시스템: ${info.platform} | 홈: ${info.homeDir}`;
            
            // Set default path based on system
            if (!document.getElementById('folderPath').value) {
                document.getElementById('folderPath').value = info.homeDir;
            }
        } catch (error) {
            console.error('Failed to load system info:', error);
        }
    }
    
    async loadRecentPaths() {
        try {
            const response = await axios.get(`${this.API_BASE}/api/recent-paths`);
            const select = document.getElementById('recentPaths');
            
            // Clear existing options except the first one
            while (select.options.length > 1) {
                select.remove(1);
            }
            
            response.data.paths.forEach(path => {
                const option = document.createElement('option');
                option.value = path;
                option.textContent = path;
                select.appendChild(option);
            });
        } catch (error) {
            console.error('Failed to load recent paths:', error);
        }
    }
    
    loadRecentPath(path) {
        if (path) {
            document.getElementById('folderPath').value = path;
            this.validatePath();
        }
    }
    
    async validatePath() {
        const pathInput = document.getElementById('folderPath');
        const path = pathInput.value.trim();
        
        if (!path) {
            alert('폴더 경로를 입력해주세요.');
            return;
        }
        
        try {
            const response = await axios.post(`${this.API_BASE}/api/validate-path`, {
                path: path
            });
            
            if (response.data.valid) {
                pathInput.classList.remove('border-red-500');
                pathInput.classList.add('border-green-500');
                this.updateStatus('ready', '경로 확인됨');
                document.getElementById('scanBtn').disabled = false;
            } else {
                pathInput.classList.remove('border-green-500');
                pathInput.classList.add('border-red-500');
                this.updateStatus('error', response.data.error);
                alert(`경로 오류: ${response.data.error}`);
            }
        } catch (error) {
            console.error('Path validation error:', error);
            alert('경로 확인 중 오류가 발생했습니다.');
        }
    }
    
    async scanFolder() {
        const pathInput = document.getElementById('folderPath');
        const path = pathInput.value.trim();
        
        if (!path) {
            alert('폴더 경로를 입력해주세요.');
            return;
        }
        
        const includeSubfolders = document.getElementById('includeSubfolders').checked;
        const maxDepth = parseInt(document.getElementById('maxDepth').value);
        
        this.showLoading(true, '파일 시스템 스캔 중...');
        this.updateStatus('scanning', '스캔 중...');
        
        try {
            const response = await axios.post(`${this.API_BASE}/api/scan`, {
                path: path,
                sessionId: this.sessionId,
                includeSubfolders: includeSubfolders,
                maxDepth: maxDepth
            });
            
            if (response.data.status === 'success') {
                this.currentPath = path;
                const scanTime = response.data.scanTime;
                this.updateStatus('ready', 
                    `${response.data.totalFiles}개 파일 발견 (${scanTime}ms)`
                );
                
                // Reset border color
                pathInput.classList.remove('border-red-500', 'border-green-500');
                
                // Enable search
                const searchBox = document.getElementById('searchBox');
                searchBox.disabled = false;
                searchBox.focus();
                
                // Reload recent paths
                await this.loadRecentPaths();
                
                // Perform initial search to show all files
                this.handleSearch('');
            } else {
                throw new Error(response.data.message || 'Scan failed');
            }
        } catch (error) {
            console.error('Scan error:', error);
            this.updateStatus('error', '스캔 실패');
            alert('폴더 스캔 중 오류가 발생했습니다: ' + 
                  (error.response?.data?.message || error.message));
        } finally {
            this.showLoading(false);
        }
    }
    
    handleSearch(query) {
        // Debounce search
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.searchFiles(query);
        }, 300);
    }
    
    async searchFiles(query) {
        if (!this.currentPath) return;
        
        try {
            const response = await axios.post(`${this.API_BASE}/api/search`, {
                query: query,
                sessionId: this.sessionId
            });
            
            if (response.data.status === 'success') {
                this.files = response.data.files;
                this.renderFiles(response.data.files);
                this.updateResultsInfo(response.data.totalResults, query);
            }
        } catch (error) {
            console.error('Search error:', error);
        }
    }
    
    renderFiles(files) {
        const grid = document.getElementById('fileGrid');
        
        if (files.length === 0) {
            grid.innerHTML = `
                <div class="col-span-full text-center py-12 text-gray-500">
                    <i class="fas fa-search text-4xl mb-4"></i>
                    <p>미디어 파일을 찾을 수 없습니다.</p>
                    <p class="text-sm mt-2">다른 폴더를 스캔하거나 검색어를 변경해보세요.</p>
                </div>
            `;
            return;
        }
        
        grid.innerHTML = files.map((file, index) => {
            const icon = this.getFileIcon(file.extension);
            const sizeStr = this.formatFileSize(file.size);
            const dateStr = new Date(file.modifiedAt).toLocaleDateString('ko-KR');
            
            return `
                <div class="file-card bg-white rounded-lg shadow hover:shadow-lg cursor-pointer p-4" 
                     onclick="explorer.previewFile(${index})"
                     title="${file.fullPath}">
                    <div class="flex flex-col h-full">
                        <div class="text-5xl mb-3 text-center ${icon.color}">
                            <i class="${icon.class}"></i>
                        </div>
                        <div class="flex-1 min-h-0">
                            <p class="text-sm font-medium text-gray-800 truncate" title="${file.filename}">
                                ${this.highlightSearch(file.filename, document.getElementById('searchBox').value)}
                            </p>
                            <p class="text-xs text-gray-500 truncate mt-1" title="${file.path}">
                                📁 ${file.path}
                            </p>
                            <div class="flex justify-between items-center mt-2 text-xs text-gray-400">
                                <span>${sizeStr}</span>
                                <span>${dateStr}</span>
                            </div>
                        </div>
                    </div>
                </div>
            `;
        }).join('');
    }
    
    highlightSearch(text, query) {
        if (!query) return text;
        const regex = new RegExp(`(${query})`, 'gi');
        return text.replace(regex, '<span class="search-highlight">$1</span>');
    }
    
    getFileIcon(extension) {
        const ext = extension.toLowerCase();
        const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp', 'ico', 'tiff'];
        const videoExts = ['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm', 'm4v'];
        const audioExts = ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma'];
        const docExts = ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt'];
        
        if (imageExts.includes(ext)) {
            return { class: 'fas fa-image', color: 'file-type-image' };
        } else if (videoExts.includes(ext)) {
            return { class: 'fas fa-video', color: 'file-type-video' };
        } else if (audioExts.includes(ext)) {
            return { class: 'fas fa-music', color: 'file-type-audio' };
        } else if (docExts.includes(ext)) {
            return { class: 'fas fa-file-alt', color: 'file-type-document' };
        } else {
            return { class: 'fas fa-file', color: 'file-type-other' };
        }
    }
    
    formatFileSize(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
    }
    
    async previewFile(index) {
        const file = this.files[index];
        if (!file) return;
        
        const modal = document.getElementById('previewModal');
        const title = document.getElementById('previewTitle');
        const content = document.getElementById('previewContent');
        
        title.textContent = file.filename;
        
        try {
            const response = await axios.get(
                `${this.API_BASE}/api/preview/${this.sessionId}/${index}`
            );
            
            if (response.data.status === 'success') {
                const fileData = response.data.file;
                const icon = this.getFileIcon(fileData.extension);
                
                let previewHtml = '';
                
                // If image with thumbnail
                if (response.data.hasPreview && response.data.thumbnailUrl) {
                    previewHtml = `
                        <div class="text-center">
                            <img src="${this.API_BASE}${response.data.thumbnailUrl}" 
                                 alt="${fileData.filename}"
                                 class="max-w-full h-auto mx-auto mb-4 rounded shadow-lg"
                                 style="max-height: 400px;">
                            <button onclick="explorer.openOriginal('${encodeURIComponent(fileData.fullPath)}')"
                                    class="mb-4 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
                                <i class="fas fa-external-link-alt mr-2"></i>원본 보기
                            </button>
                        </div>
                    `;
                } else {
                    // No preview available
                    previewHtml = `
                        <div class="text-center">
                            <div class="text-8xl mb-4 ${icon.color}">
                                <i class="${icon.class}"></i>
                            </div>
                            ${fileData.mediaType === 'image' ? 
                                `<button onclick="explorer.openOriginal('${encodeURIComponent(fileData.fullPath)}')"
                                        class="mb-4 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
                                    <i class="fas fa-external-link-alt mr-2"></i>원본 보기
                                </button>` : ''
                            }
                        </div>
                    `;
                }
                
                content.innerHTML = previewHtml + `
                    <div class="text-left bg-gray-50 rounded p-4 mt-4">
                        <h4 class="font-semibold mb-3 text-lg">파일 정보</h4>
                        <dl class="space-y-2">
                            <div class="flex">
                                <dt class="font-medium text-gray-600 w-28">파일명:</dt>
                                <dd class="text-gray-800 break-all">${fileData.filename}</dd>
                            </div>
                            <div class="flex">
                                <dt class="font-medium text-gray-600 w-28">전체 경로:</dt>
                                <dd class="text-gray-800 font-mono text-xs break-all bg-gray-100 p-2 rounded">
                                    ${fileData.fullPath}
                                </dd>
                            </div>
                            <div class="flex">
                                <dt class="font-medium text-gray-600 w-28">크기:</dt>
                                <dd class="text-gray-800">${this.formatFileSize(fileData.size)}</dd>
                            </div>
                            <div class="flex">
                                <dt class="font-medium text-gray-600 w-28">타입:</dt>
                                <dd class="text-gray-800">${fileData.type}</dd>
                            </div>
                            <div class="flex">
                                <dt class="font-medium text-gray-600 w-28">수정일:</dt>
                                <dd class="text-gray-800">
                                    ${new Date(fileData.modifiedAt).toLocaleString('ko-KR')}
                                </dd>
                            </div>
                        </dl>
                    </div>
                `;
            }
        } catch (error) {
            content.innerHTML = `
                <div class="text-center text-red-500">
                    <i class="fas fa-exclamation-triangle text-4xl mb-4"></i>
                    <p>미리보기를 불러올 수 없습니다.</p>
                    <p class="text-sm mt-2">${error.message}</p>
                </div>
            `;
        }
        
        modal.classList.remove('hidden');
    }
    
    openOriginal(encodedPath) {
        const path = decodeURIComponent(encodedPath);
        window.open(`${this.API_BASE}/api/serve-file?path=${encodeURIComponent(path)}`, '_blank');
    }
    
    closePreview() {
        document.getElementById('previewModal').classList.add('hidden');
    }
    
    updateStatus(status, text) {
        const dot = document.getElementById('statusDot');
        const statusText = document.getElementById('statusText');
        
        dot.className = `status-dot ${status}`;
        statusText.textContent = text;
    }
    
    updateResultsInfo(count, query) {
        const info = document.getElementById('resultsInfo');
        if (query) {
            info.innerHTML = `"<strong>${query}</strong>" 검색 결과: ${count}개 파일`;
        } else {
            info.textContent = `전체 미디어 파일: ${count}개`;
        }
    }
    
    showLoading(show, text = '스캔 중...') {
        const indicator = document.getElementById('loadingIndicator');
        const loadingText = document.getElementById('loadingText');
        
        if (show) {
            loadingText.textContent = text;
            indicator.classList.remove('hidden');
        } else {
            indicator.classList.add('hidden');
        }
    }
}

// Initialize the application
let explorer;
document.addEventListener('DOMContentLoaded', () => {
    explorer = new MediaExplorer();
});