import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    host: true, // accessible on LAN for mobile device testing
    port: 5173,
    proxy: {
      // Dev proxy to the SQLite backend (sc_backend, port 8090 by default).
      // The web app talks to the real backend only when VITE_APP_MODE=live;
      // otherwise it runs in mock mode (no server needed).
      '/api': {
        target: `http://localhost:${process.env.SC_PROXY_PORT || 3000}`,
        changeOrigin: true,
      },
    },
  },
})
