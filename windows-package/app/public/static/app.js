// Media File Explorer Frontend Application

class MediaExplorer {
    constructor() {
        this.sessionId = this.generateSessionId();
        this.currentPath = '';
        this.files = [];
        this.isScanning = false;
        this.searchTimeout = null;
        
        this.init();
    }
    
    generateSessionId() {
        return 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    }
    
    init() {
        this.renderUI();
        this.attachEventListeners();
        this.loadRecentPaths();
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
                            Media File Explorer
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
                                placeholder="폴더 경로 입력 (예: C:\\Images 또는 \\\\NAS\\media)"
                            />
                        </div>
                        <button 
                            id="scanBtn"
                            class="px-6 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
                            onclick="explorer.scanFolder()"
                        >
                            <i class="fas fa-search mr-2"></i>스캔
                        </button>
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
                        <p class="text-gray-700">스캔 중...</p>
                    </div>
                </div>
                
                <!-- Preview Modal -->
                <div id="previewModal" class="hidden fixed inset-0 modal-backdrop flex items-center justify-center z-50">
                    <div class="bg-white rounded-lg max-w-4xl max-h-[90vh] overflow-hidden">
                        <div class="flex items-center justify-between p-4 border-b">
                            <h3 id="previewTitle" class="font-semibold text-lg"></h3>
                            <button onclick="explorer.closePreview()" class="text-gray-500 hover:text-gray-700">
                                <i class="fas fa-times text-xl"></i>
                            </button>
                        </div>
                        <div id="previewContent" class="p-4 overflow-auto max-h-[70vh]">
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
    }
    
    async loadRecentPaths() {
        try {
            const response = await axios.get('/api/recent-paths');
            const select = document.getElementById('recentPaths');
            
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
            this.scanFolder();
        }
    }
    
    async scanFolder() {
        const pathInput = document.getElementById('folderPath');
        const path = pathInput.value.trim();
        
        if (!path) {
            alert('폴더 경로를 입력해주세요.');
            return;
        }
        
        this.showLoading(true);
        this.updateStatus('scanning', '스캔 중...');
        
        try {
            const response = await axios.post('/api/scan', {
                path: path,
                sessionId: this.sessionId
            });
            
            if (response.data.status === 'success') {
                this.currentPath = path;
                this.updateStatus('ready', `${response.data.totalFiles}개 파일 발견`);
                
                // Enable search
                const searchBox = document.getElementById('searchBox');
                searchBox.disabled = false;
                searchBox.focus();
                
                // Perform initial search to show all files
                this.handleSearch('');
            } else {
                throw new Error(response.data.message || 'Scan failed');
            }
        } catch (error) {
            console.error('Scan error:', error);
            this.updateStatus('error', '스캔 실패: ' + error.message);
            alert('폴더 스캔 중 오류가 발생했습니다: ' + error.message);
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
            const response = await axios.post('/api/search', {
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
                    <p>파일을 찾을 수 없습니다.</p>
                </div>
            `;
            return;
        }
        
        grid.innerHTML = files.map((file, index) => {
            const icon = this.getFileIcon(file.extension);
            const sizeStr = this.formatFileSize(file.size);
            
            return `
                <div class="file-card bg-white rounded-lg shadow hover:shadow-lg cursor-pointer p-4" 
                     onclick="explorer.previewFile(${index})">
                    <div class="flex flex-col items-center">
                        <div class="text-5xl mb-3 ${icon.color}">
                            <i class="${icon.class}"></i>
                        </div>
                        <div class="w-full">
                            <p class="text-sm font-medium text-gray-800 truncate" title="${file.filename}">
                                ${file.filename}
                            </p>
                            <p class="text-xs text-gray-500 truncate" title="${file.path}">
                                ${file.path}
                            </p>
                            <div class="flex justify-between items-center mt-2">
                                <span class="text-xs text-gray-400">${sizeStr}</span>
                                <span class="text-xs text-gray-400">.${file.extension}</span>
                            </div>
                        </div>
                    </div>
                </div>
            `;
        }).join('');
    }
    
    getFileIcon(extension) {
        const ext = extension.toLowerCase();
        const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'];
        const videoExts = ['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm'];
        const audioExts = ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'];
        const docExts = ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'];
        
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
            const response = await axios.get(`/api/preview/${this.sessionId}/${index}`);
            
            if (response.data.status === 'success') {
                const icon = this.getFileIcon(file.extension);
                
                content.innerHTML = `
                    <div class="text-center">
                        <div class="text-8xl mb-4 ${icon.color}">
                            <i class="${icon.class}"></i>
                        </div>
                        <div class="text-left bg-gray-50 rounded p-4">
                            <h4 class="font-semibold mb-2">파일 정보</h4>
                            <dl class="space-y-1">
                                <div class="flex">
                                    <dt class="font-medium text-gray-600 w-24">파일명:</dt>
                                    <dd class="text-gray-800">${file.filename}</dd>
                                </div>
                                <div class="flex">
                                    <dt class="font-medium text-gray-600 w-24">경로:</dt>
                                    <dd class="text-gray-800 font-mono text-sm">${file.fullPath}</dd>
                                </div>
                                <div class="flex">
                                    <dt class="font-medium text-gray-600 w-24">크기:</dt>
                                    <dd class="text-gray-800">${this.formatFileSize(file.size)}</dd>
                                </div>
                                <div class="flex">
                                    <dt class="font-medium text-gray-600 w-24">타입:</dt>
                                    <dd class="text-gray-800">${file.type}</dd>
                                </div>
                                <div class="flex">
                                    <dt class="font-medium text-gray-600 w-24">수정일:</dt>
                                    <dd class="text-gray-800">${new Date(file.modifiedAt).toLocaleString('ko-KR')}</dd>
                                </div>
                            </dl>
                        </div>
                        <div class="mt-4 p-4 bg-yellow-50 border border-yellow-200 rounded">
                            <p class="text-sm text-yellow-800">
                                <i class="fas fa-info-circle mr-2"></i>
                                ${response.data.message}
                            </p>
                        </div>
                    </div>
                `;
            }
        } catch (error) {
            content.innerHTML = `
                <div class="text-center text-red-500">
                    <i class="fas fa-exclamation-triangle text-4xl mb-4"></i>
                    <p>미리보기를 불러올 수 없습니다.</p>
                </div>
            `;
        }
        
        modal.classList.remove('hidden');
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
            info.textContent = `"${query}" 검색 결과: ${count}개 파일`;
        } else {
            info.textContent = `전체 파일: ${count}개`;
        }
    }
    
    showLoading(show) {
        const indicator = document.getElementById('loadingIndicator');
        if (show) {
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