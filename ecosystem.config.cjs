module.exports = {
  apps: [
    {
      name: 'media-explorer-frontend',
      script: 'npx',
      args: 'wrangler pages dev dist --ip 0.0.0.0 --port 3000',
      env: {
        NODE_ENV: 'development',
        PORT: 3000
      },
      watch: false,
      instances: 1,
      exec_mode: 'fork'
    },
    {
      name: 'media-explorer-backend',
      script: 'server.cjs',
      cwd: '/home/user/webapp',
      env: {
        NODE_ENV: 'development',
        PORT: 3001
      },
      watch: false,
      instances: 1,
      exec_mode: 'fork'
    }
  ]
}