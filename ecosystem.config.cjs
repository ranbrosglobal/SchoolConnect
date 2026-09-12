/**
 * PM2 Ecosystem Config for SchoolConnect
 *
 * Usage:
 *   pm2 start ecosystem.config.cjs          — start all services
 *   pm2 restart ecosystem.config.cjs        — restart all
 *   pm2 stop ecosystem.config.cjs           — stop all
 *   pm2 delete ecosystem.config.cjs         — remove all from PM2
 *   pm2 save && pm2 startup                  — persist across reboots
 */

const path = require('path')

module.exports = {
  apps: [
    {
      name: 'sc_backend',
      script: path.join(__dirname, 'sc_backend', 'src', 'index.js'),
      node_args: '--experimental-sqlite',
      env: {
        NODE_ENV: 'production',
        SC_SA_PORT: 3000,
        SC_SU_PORT: 3001,
        SC_HOST: process.env.SC_HOST || '13.205.212.64',
      },
      // Restart on crash, limit restarts to avoid infinite loops
      max_restarts: 10,
      restart_delay: 3000,
      autorestart: true,
      // Memory limit — the backend is lightweight SQLite
      max_memory_restart: '300M',
    },
    {
      name: 'schooladmin',
      script: path.join(__dirname, 'schooladmin', 'node_modules', '.bin', 'serve'),
      args: '-s dist -l 5173',
      cwd: path.join(__dirname, 'schooladmin'),
      env: {
        NODE_ENV: 'production',
      },
      max_restarts: 10,
      restart_delay: 2000,
      autorestart: true,
    },
    {
      name: 'superadmin',
      script: path.join(__dirname, 'superadmin', 'node_modules', '.bin', 'serve'),
      args: '-s dist -l 5175',
      cwd: path.join(__dirname, 'superadmin'),
      env: {
        NODE_ENV: 'production',
      },
      max_restarts: 10,
      restart_delay: 2000,
      autorestart: true,
    },
  ],
}
