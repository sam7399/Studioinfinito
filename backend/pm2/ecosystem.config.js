module.exports = {
  apps: [{
    name: 'tm-backend',
    script: './src/server.js',
    instances: 1, // or 'max' for cluster mode
    exec_mode: 'fork', // or 'cluster'
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'development',
      PORT: 26627
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 26627
    },
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_file: './logs/pm2-combined.log',
    time: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    autorestart: true,
    max_restarts: 10,
    min_uptime: '10s',
    listen_timeout: 3000,
    kill_timeout: 5000,
    wait_ready: true,
    shutdown_with_message: true
  }]
};