/**
 * Dev helper: serve the Flutter web build and the API from one origin.
 *
 * The app keeps its session in a first-party cookie, so a browser needs the
 * API on the same origin as the page. This starts the real backend (on
 * API_PORT) and a small static server (on WEB_PORT) that proxies /api and
 * /health through to it.
 *
 * Usage (from the repo root):
 *   node --experimental-sqlite sc_backend/scripts/serve-app.mjs
 *   API_PORT=3000 WEB_PORT=5173 node --experimental-sqlite sc_backend/scripts/serve-app.mjs
 *
 * Build the app first:
 *   cd school_connect_app && flutter build web --release
 */

import http from 'node:http'
import { existsSync, readFileSync, statSync } from 'node:fs'
import { extname, join, normalize, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createServer } from '../src/server.js'
import { seedSchooladmin } from '../src/seed.js'

const __dirname = dirname(fileURLToPath(import.meta.url))
const WEB_ROOT = join(__dirname, '..', '..', 'school_connect_app', 'build', 'web')
const API_PORT = Number(process.env.API_PORT || 3000)
const WEB_PORT = Number(process.env.WEB_PORT || 5173)

if (!existsSync(join(WEB_ROOT, 'index.html'))) {
  console.error(`No web build at ${WEB_ROOT}\nRun: cd school_connect_app && flutter build web --release`)
  process.exit(1)
}

// The API. staticDir is intentionally null: the proxy below owns static files
// so we don't inherit the console's restrictive CSP.
createServer({
  consoleName: 'schooladmin',
  port: API_PORT,
  seed: seedSchooladmin,
  staticDir: null,
})

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.data': 'application/octet-stream',
  '.symbols': 'application/octet-stream',
}

function proxy(req, res) {
  const proxied = http.request(
    { host: '127.0.0.1', port: API_PORT, path: req.url, method: req.method, headers: req.headers },
    (upstream) => {
      res.writeHead(upstream.statusCode || 502, upstream.headers)
      upstream.pipe(res)
    },
  )
  proxied.on('error', (err) => {
    res.writeHead(502, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ message: `API unreachable: ${err.message}` }))
  })
  req.pipe(proxied)
}

http
  .createServer((req, res) => {
    if (req.url.startsWith('/api/') || req.url === '/health') return proxy(req, res)

    const requested = decodeURIComponent(req.url.split('?')[0])
    let filePath = normalize(join(WEB_ROOT, requested))
    if (!filePath.startsWith(normalize(WEB_ROOT)) || !existsSync(filePath) || statSync(filePath).isDirectory()) {
      filePath = join(WEB_ROOT, 'index.html')
    }
    const body = readFileSync(filePath)
    res.writeHead(200, {
      'Content-Type': MIME[extname(filePath).toLowerCase()] || 'application/octet-stream',
      'Content-Length': body.length,
      'Cache-Control': 'no-store',
    })
    res.end(body)
  })
  .listen(WEB_PORT, '127.0.0.1', () => {
    console.log(`[app] Flutter web + API on http://localhost:${WEB_PORT}`)
    console.log(`[app] API proxied to http://localhost:${API_PORT}/api/method/...`)
  })
