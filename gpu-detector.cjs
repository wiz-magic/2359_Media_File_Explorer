/**
 * Universal GPU Hardware Acceleration Detector
 * 범용 GPU 하드웨어 가속 자동 감지 모듈
 * 
 * 지원 GPU:
 * - NVIDIA (CUDA/NVENC)
 * - Intel (QSV)
 * - AMD (AMF/VCE)
 * - Apple Silicon (VideoToolbox)
 * - 범용 (VA-API, OpenCL, DXVA2, D3D11VA)
 */

const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);
const os = require('os');
const fs = require('fs');

class GPUDetector {
    constructor() {
        this.platform = process.platform;
        this.capabilities = null;
        this.lastCheck = null;
        this.checkInterval = 60000; // 60초마다 재확인
    }

    /**
     * GPU 제조사 감지
     */
    async detectGPUVendor() {
        const vendors = {
            nvidia: false,
            intel: false,
            amd: false,
            apple: false
        };

        try {
            if (this.platform === 'win32') {
                // Windows: WMI 사용
                try {
                    const result = await execPromise('wmic path win32_VideoController get name');
                    const output = result.stdout.toLowerCase();
                    
                    vendors.nvidia = output.includes('nvidia');
                    vendors.intel = output.includes('intel');
                    vendors.amd = output.includes('amd') || output.includes('radeon');
                } catch (e) {
                    console.log('WMI detection failed, trying alternative method');
                }
                
            } else if (this.platform === 'linux') {
                // Linux: lspci 또는 /proc 확인
                try {
                    const result = await execPromise('lspci 2>/dev/null | grep -E "VGA|3D|Display" || cat /proc/driver/nvidia/version 2>/dev/null || true');
                    const output = result.stdout.toLowerCase();
                    
                    vendors.nvidia = output.includes('nvidia');
                    vendors.intel = output.includes('intel');
                    vendors.amd = output.includes('amd') || output.includes('radeon');
                } catch (e) {
                    // GPU 정보를 못 가져와도 계속 진행
                }
                
                // Intel GPU 장치 파일 확인
                if (fs.existsSync('/dev/dri/renderD128')) {
                    vendors.intel = true;
                }
                
            } else if (this.platform === 'darwin') {
                // macOS: system_profiler 사용
                try {
                    const result = await execPromise('system_profiler SPDisplaysDataType');
                    const output = result.stdout.toLowerCase();
                    
                    vendors.apple = output.includes('apple') || output.includes('m1') || output.includes('m2') || output.includes('m3');
                    vendors.intel = output.includes('intel');
                    vendors.amd = output.includes('amd') || output.includes('radeon');
                    vendors.nvidia = output.includes('nvidia');
                } catch (e) {
                    vendors.apple = true; // macOS는 기본적으로 VideoToolbox 지원
                }
            }
            
            // CPU 정보에서 추가 힌트
            const cpuInfo = os.cpus()[0].model.toLowerCase();
            if (cpuInfo.includes('intel')) {
                vendors.intel = true; // Intel CPU는 대부분 내장 GPU 포함
            } else if (cpuInfo.includes('amd')) {
                vendors.amd = true; // AMD APU 가능성
            }
            
        } catch (error) {
            console.log('GPU vendor detection error:', error.message);
        }

        return vendors;
    }

    /**
     * 플랫폼별 가속 방법 우선순위 결정
     */
    async getAccelerationPriority() {
        const vendors = await this.detectGPUVendor();
        const accelerators = [];

        console.log('🎮 Detected GPU vendors:', vendors);

        // Windows
        if (this.platform === 'win32') {
            if (vendors.nvidia) {
                accelerators.push(
                    { name: 'cuda', test: this.getCudaTest(), priority: 1, vendor: 'NVIDIA' },
                    { name: 'nvenc', test: this.getNvencTest(), priority: 2, vendor: 'NVIDIA' }
                );
            }
            if (vendors.intel) {
                accelerators.push(
                    { name: 'qsv', test: this.getQsvTest(), priority: vendors.nvidia ? 3 : 1, vendor: 'Intel' },
                    { name: 'dxva2', test: this.getDxva2Test(), priority: 5, vendor: 'Windows' }
                );
            }
            if (vendors.amd) {
                accelerators.push(
                    { name: 'amf', test: this.getAmfTest(), priority: vendors.nvidia ? 3 : 1, vendor: 'AMD' },
                    { name: 'd3d11va', test: this.getD3d11vaTest(), priority: 5, vendor: 'Windows' }
                );
            }
            // Windows 범용 폴백
            accelerators.push(
                { name: 'dxva2', test: this.getDxva2Test(), priority: 6, vendor: 'Windows' },
                { name: 'd3d11va', test: this.getD3d11vaTest(), priority: 7, vendor: 'Windows' }
            );
        }
        
        // Linux
        else if (this.platform === 'linux') {
            if (vendors.nvidia) {
                accelerators.push(
                    { name: 'cuda', test: this.getCudaTest(), priority: 1, vendor: 'NVIDIA' },
                    { name: 'nvenc', test: this.getNvencTest(), priority: 2, vendor: 'NVIDIA' }
                );
            }
            if (vendors.intel) {
                accelerators.push(
                    { name: 'qsv', test: this.getQsvTest(), priority: vendors.nvidia ? 3 : 1, vendor: 'Intel' },
                    { name: 'vaapi', test: this.getVaapiTest(), priority: 4, vendor: 'Intel' }
                );
            }
            if (vendors.amd) {
                accelerators.push(
                    { name: 'vaapi', test: this.getVaapiTest(), priority: vendors.nvidia ? 3 : 1, vendor: 'AMD' }
                );
            }
            // Linux 범용 폴백
            accelerators.push(
                { name: 'vaapi', test: this.getVaapiTest(), priority: 5, vendor: 'Linux' },
                { name: 'opencl', test: this.getOpenclTest(), priority: 6, vendor: 'Generic' }
            );
        }
        
        // macOS
        else if (this.platform === 'darwin') {
            // Apple Silicon 또는 모든 Mac
            accelerators.push(
                { name: 'videotoolbox', test: this.getVideotoolboxTest(), priority: 1, vendor: 'Apple' }
            );
            if (vendors.intel) {
                accelerators.push(
                    { name: 'qsv', test: this.getQsvTest(), priority: 2, vendor: 'Intel' }
                );
            }
            accelerators.push(
                { name: 'opencl', test: this.getOpenclTest(), priority: 3, vendor: 'Generic' }
            );
        }

        // 우선순위로 정렬
        accelerators.sort((a, b) => a.priority - b.priority);
        
        return accelerators;
    }

    /**
     * 실제 하드웨어 가속 테스트
     */
    async testHardwareAcceleration() {
        // 캐시 확인 (60초 이내면 재사용)
        if (this.capabilities && this.lastCheck && (Date.now() - this.lastCheck < this.checkInterval)) {
            console.log('🔄 Using cached GPU capabilities');
            return this.capabilities;
        }

        console.log('🔍 Testing hardware acceleration options...');
        
        const accelerators = await this.getAccelerationPriority();
        
        for (const accel of accelerators) {
            try {
                console.log(`  Testing ${accel.name} (${accel.vendor})...`);
                await execPromise(accel.test);
                console.log(`  ✅ ${accel.name} acceleration available!`);
                
                this.capabilities = {
                    available: true,
                    method: accel.name,
                    vendor: accel.vendor,
                    priority: accel.priority,
                    threads: os.cpus().length,
                    platform: this.platform
                };
                this.lastCheck = Date.now();
                
                return this.capabilities;
                
            } catch (error) {
                console.log(`  ❌ ${accel.name} not available: ${error.message.split('\n')[0]}`);
            }
        }
        
        // 모든 GPU 가속 실패 - CPU 폴백
        console.log('ℹ️  No hardware acceleration available, using optimized CPU');
        
        this.capabilities = {
            available: false,
            method: 'cpu',
            vendor: 'CPU',
            threads: os.cpus().length,
            platform: this.platform,
            cpuOptimizations: this.getCPUOptimizations()
        };
        this.lastCheck = Date.now();
        
        return this.capabilities;
    }

    /**
     * CPU 최적화 감지
     */
    getCPUOptimizations() {
        const cpuModel = os.cpus()[0].model.toLowerCase();
        const optimizations = {
            avx: false,
            avx2: false,
            avx512: false,
            threads: os.cpus().length
        };

        // CPU 모델 기반 추정
        if (cpuModel.includes('xeon') || cpuModel.includes('i9') || 
            cpuModel.includes('i7') || cpuModel.includes('ryzen')) {
            optimizations.avx = true;
            optimizations.avx2 = true;
            
            // 최신 CPU는 AVX-512 지원 가능
            if (cpuModel.includes('xeon') || cpuModel.includes('i9')) {
                optimizations.avx512 = true;
            }
        } else if (cpuModel.includes('i5') || cpuModel.includes('i3')) {
            optimizations.avx = true;
            optimizations.avx2 = true;
        }

        return optimizations;
    }

    /**
     * 최적화된 FFmpeg 명령어 생성
     */
    buildCommand(inputPath, outputPath, capabilities = null) {
        if (!capabilities) {
            capabilities = this.capabilities || { method: 'cpu' };
        }

        let command = 'ffmpeg';
        
        // 입력 전 시크 (더 빠름)
        command += ' -ss 00:00:01.000';

        // 하드웨어별 설정
        switch (capabilities.method) {
            case 'cuda':
            case 'nvenc':
                command += ' -hwaccel cuda -hwaccel_output_format cuda';
                command += ` -i "${inputPath}"`;
                command += ' -vf "scale_cuda=200:200:force_original_aspect_ratio=decrease"';
                command += ' -c:v mjpeg_nvenc -preset fast -qp 23';
                break;
                
            case 'qsv':
                command += ' -init_hw_device qsv=hw -filter_hw_device hw';
                command += ` -c:v h264_qsv -i "${inputPath}"`; // QSV 디코더
                command += ' -vf "hwupload=extra_hw_frames=64,format=qsv,scale_qsv=200:200:mode=hq,hwdownload,format=nv12"';
                command += ' -c:v mjpeg_qsv -global_quality 25';
                break;
                
            case 'vaapi':
                command += ' -init_hw_device vaapi=va:/dev/dri/renderD128 -filter_hw_device va';
                command += ` -hwaccel vaapi -hwaccel_output_format vaapi -i "${inputPath}"`;
                command += ' -vf "scale_vaapi=200:200:mode=hq,hwdownload,format=nv12"';
                command += ' -c:v mjpeg_vaapi -qp 23';
                break;
                
            case 'amf':
                command += ` -i "${inputPath}"`;
                command += ' -vf "scale=200:200:force_original_aspect_ratio=decrease"';
                command += ' -c:v h264_amf -quality speed -rc cqp -qp 23';
                break;
                
            case 'videotoolbox':
                command += ` -i "${inputPath}"`;
                command += ' -vf "scale=200:200:force_original_aspect_ratio=decrease"';
                command += ' -c:v h264_videotoolbox -preset fast -q:v 25';
                break;
                
            case 'dxva2':
                command += ' -hwaccel dxva2';
                command += ` -i "${inputPath}"`;
                command += ' -vf "scale=200:200:force_original_aspect_ratio=decrease"';
                break;
                
            case 'd3d11va':
                command += ' -hwaccel d3d11va';
                command += ` -i "${inputPath}"`;
                command += ' -vf "scale=200:200:force_original_aspect_ratio=decrease"';
                break;
                
            case 'opencl':
                command += ' -init_hw_device opencl=ocl:0.0 -filter_hw_device ocl';
                command += ` -i "${inputPath}"`;
                command += ' -vf "hwupload,format=opencl,scale_opencl=200:200,hwdownload,format=yuv420p"';
                break;
                
            default: // CPU
                command += ` -i "${inputPath}"`;
                
                // CPU 최적화
                if (capabilities.cpuOptimizations) {
                    const opt = capabilities.cpuOptimizations;
                    if (opt.avx512) {
                        command += ' -vf "scale=200:200:flags=fast_bilinear"';
                    } else if (opt.avx2) {
                        command += ' -vf "scale=200:200:flags=bilinear"';
                    } else {
                        command += ' -vf "scale=200:200"';
                    }
                    command += ` -threads ${opt.threads}`;
                } else {
                    command += ' -vf "scale=200:200"';
                    command += ` -threads ${os.cpus().length}`;
                }
                command += ' -preset ultrafast -q:v 5';
                break;
        }

        // 공통 옵션
        command += ' -vframes 1 -an -sn'; // 1프레임, 오디오/자막 제거
        command += ` -f image2 "${outputPath}" -y`;
        command += ' -v error'; // 로그 최소화

        return command;
    }

    // 각 가속 방법별 테스트 명령어
    getCudaTest() {
        return 'ffmpeg -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -c:v h264_nvenc -f null - -v quiet';
    }

    getNvencTest() {
        return 'ffmpeg -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -c:v h264_nvenc -preset fast -f null - -v quiet';
    }

    getQsvTest() {
        return 'ffmpeg -init_hw_device qsv=hw -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -vf hwupload=extra_hw_frames=64,format=qsv -c:v h264_qsv -f null - -v quiet';
    }

    getVaapiTest() {
        return 'ffmpeg -init_hw_device vaapi=va:/dev/dri/renderD128 -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -vf format=nv12,hwupload -c:v h264_vaapi -f null - -v quiet';
    }

    getAmfTest() {
        return 'ffmpeg -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -c:v h264_amf -f null - -v quiet';
    }

    getVideotoolboxTest() {
        return 'ffmpeg -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -c:v h264_videotoolbox -f null - -v quiet';
    }

    getDxva2Test() {
        return 'ffmpeg -hwaccel dxva2 -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -f null - -v quiet';
    }

    getD3d11vaTest() {
        return 'ffmpeg -hwaccel d3d11va -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -f null - -v quiet';
    }

    getOpenclTest() {
        return 'ffmpeg -init_hw_device opencl=ocl:0.0 -f lavfi -i testsrc2=duration=1:size=320x240:rate=1 -filter_hw_device ocl -vf hwupload,format=opencl,scale_opencl=320:240 -f null - -v quiet';
    }

    /**
     * 성능 벤치마크
     */
    async benchmark(testVideoPath) {
        const results = {};
        const outputPath = '/tmp/benchmark_thumb.jpg';
        
        // GPU 테스트
        const gpuCapabilities = await this.testHardwareAcceleration();
        if (gpuCapabilities.available) {
            const startGPU = Date.now();
            const gpuCommand = this.buildCommand(testVideoPath, outputPath, gpuCapabilities);
            try {
                await execPromise(gpuCommand);
                results.gpu = {
                    method: gpuCapabilities.method,
                    vendor: gpuCapabilities.vendor,
                    time: Date.now() - startGPU,
                    success: true
                };
            } catch (e) {
                results.gpu = { success: false, error: e.message };
            }
        }
        
        // CPU 테스트 (비교용)
        const startCPU = Date.now();
        const cpuCommand = this.buildCommand(testVideoPath, outputPath, { method: 'cpu' });
        try {
            await execPromise(cpuCommand);
            results.cpu = {
                time: Date.now() - startCPU,
                success: true
            };
        } catch (e) {
            results.cpu = { success: false, error: e.message };
        }
        
        // 성능 비교
        if (results.gpu && results.cpu && results.gpu.success && results.cpu.success) {
            results.speedup = (results.cpu.time / results.gpu.time).toFixed(2) + 'x';
        }
        
        return results;
    }
}

module.exports = GPUDetector;