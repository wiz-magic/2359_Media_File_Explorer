import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { serveStatic } from 'hono/cloudflare-workers'

// Type definitions
type MediaFile = {
  filename: string
  path: string
  fullPath: string
  size: number
  type: string
  extension: string
  modifiedAt: string
}

type ScanResult = {
  currentPath: string
  indexedAt: string
  totalFiles: number
  files: MediaFile[]
  status: 'scanning' | 'completed' | 'error'
  message?: string
}

// In-memory storage for session data (per worker instance)
const sessionStorage = new Map<string, ScanResult>()

const app = new Hono()

// Enable CORS for all API routes
app.use('/api/*', cors({
  origin: '*',
  allowHeaders: ['Content-Type', 'Authorization'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
}))

// Serve static files
app.use('/static/*', serveStatic({ root: './public' }))

// API: Scan folder (mock implementation for Cloudflare environment)
app.post('/api/scan', async (c) => {
  try {
    const { path, sessionId } = await c.req.json()
    
    if (!path || !sessionId) {
      return c.json({ error: 'Path and sessionId are required' }, 400)
    }

    // In Cloudflare Workers environment, we cannot access local file system
    // This is a mock implementation that simulates folder scanning
    const mockFiles: MediaFile[] = generateMockFiles(path)
    
    const scanResult: ScanResult = {
      currentPath: path,
      indexedAt: new Date().toISOString(),
      totalFiles: mockFiles.length,
      files: mockFiles,
      status: 'completed'
    }
    
    sessionStorage.set(sessionId, scanResult)
    
    return c.json({
      status: 'success',
      message: `Found ${mockFiles.length} files`,
      totalFiles: mockFiles.length,
      currentPath: path
    })
  } catch (error) {
    return c.json({ 
      status: 'error', 
      message: error instanceof Error ? error.message : 'Unknown error'
    }, 500)
  }
})

// API: Search files
app.post('/api/search', async (c) => {
  try {
    const { query, sessionId } = await c.req.json()
    
    if (!sessionId) {
      return c.json({ error: 'SessionId is required' }, 400)
    }
    
    const scanResult = sessionStorage.get(sessionId)
    
    if (!scanResult) {
      return c.json({ 
        error: 'No scan data found. Please scan a folder first.' 
      }, 404)
    }
    
    // Filter files based on query
    const searchQuery = query?.toLowerCase() || ''
    const filteredFiles = searchQuery 
      ? scanResult.files.filter(file => 
          file.filename.toLowerCase().includes(searchQuery)
        )
      : scanResult.files
    
    return c.json({
      status: 'success',
      totalResults: filteredFiles.length,
      currentPath: scanResult.currentPath,
      files: filteredFiles.slice(0, 100) // Limit to 100 results
    })
  } catch (error) {
    return c.json({ 
      status: 'error', 
      message: error instanceof Error ? error.message : 'Unknown error'
    }, 500)
  }
})

// API: Get recent paths (mock implementation)
app.get('/api/recent-paths', async (c) => {
  // In production, this would be stored in KV or D1
  const mockRecentPaths = [
    'C:\\Users\\Marketing\\Images',
    '\\\\NAS\\shared\\media',
    '/Users/design/projects',
    'D:\\Archive\\2024',
    '\\\\Server\\public\\assets'
  ]
  
  return c.json({
    status: 'success',
    paths: mockRecentPaths
  })
})

// API: Get file preview URL
app.get('/api/preview/:sessionId/:fileIndex', async (c) => {
  const { sessionId, fileIndex } = c.req.param()
  
  const scanResult = sessionStorage.get(sessionId)
  if (!scanResult) {
    return c.json({ error: 'Session not found' }, 404)
  }
  
  const index = parseInt(fileIndex)
  if (isNaN(index) || index < 0 || index >= scanResult.files.length) {
    return c.json({ error: 'Invalid file index' }, 400)
  }
  
  const file = scanResult.files[index]
  
  // In production, this would return actual file content or proxy URL
  // For demo, return mock preview data
  return c.json({
    status: 'success',
    file: file,
    previewUrl: `/static/mock-preview.jpg`,
    message: 'Note: This is a mock preview. In production, actual file would be served.'
  })
})

// Helper function to generate mock files
function generateMockFiles(path: string): MediaFile[] {
  const mockFiles: MediaFile[] = []
  const extensions = {
    image: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'],
    video: ['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm'],
    audio: ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'],
    document: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx']
  }
  
  const categories = ['campaign', 'products', 'team', 'events', 'archive']
  const years = ['2023', '2024']
  const months = ['01-January', '02-February', '03-March', '04-April', '05-May', '06-June']
  
  // Generate sample files
  for (let i = 0; i < 50; i++) {
    const category = categories[Math.floor(Math.random() * categories.length)]
    const year = years[Math.floor(Math.random() * years.length)]
    const month = months[Math.floor(Math.random() * months.length)]
    const typeKey = Object.keys(extensions)[Math.floor(Math.random() * 4)] as keyof typeof extensions
    const extArray = extensions[typeKey]
    const ext = extArray[Math.floor(Math.random() * extArray.length)]
    
    const filename = `${category}_${year}_${String(i + 1).padStart(3, '0')}.${ext}`
    const relativePath = `${year}/${month}/${category}/`
    
    mockFiles.push({
      filename,
      path: relativePath,
      fullPath: `${path}/${relativePath}${filename}`,
      size: Math.floor(Math.random() * 10000000), // Random size up to 10MB
      type: `${typeKey}/${ext}`,
      extension: ext,
      modifiedAt: new Date(2024, Math.floor(Math.random() * 12), Math.floor(Math.random() * 28) + 1).toISOString()
    })
  }
  
  return mockFiles
}

// Real file system page
app.get('/real', (c) => {
  return c.html(`
    <!DOCTYPE html>
    <html lang="ko">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Media File Explorer - Real File System</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.4.0/css/all.min.css" rel="stylesheet">
        <link href="/static/styles.css" rel="stylesheet">
    </head>
    <body class="bg-gray-50">
        <div id="app" class="min-h-screen">
            <!-- Content will be loaded by JavaScript -->
        </div>
        
        <script src="https://cdn.jsdelivr.net/npm/axios@1.6.0/dist/axios.min.js"></script>
        <script src="/static/app-real.js"></script>
    </body>
    </html>
  `)
})

// Main page (mock version)
app.get('/', (c) => {
  return c.html(`
    <!DOCTYPE html>
    <html lang="ko">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Media File Explorer</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.4.0/css/all.min.css" rel="stylesheet">
        <link href="/static/styles.css" rel="stylesheet">
    </head>
    <body class="bg-gray-50">
        <div id="app" class="min-h-screen">
            <!-- Content will be loaded by JavaScript -->
        </div>
        
        <script src="https://cdn.jsdelivr.net/npm/axios@1.6.0/dist/axios.min.js"></script>
        <script src="/static/app.js"></script>
    </body>
    </html>
  `)
})

export default app