/**
 * HTTP server for the SchoolConnect backend.
 *
 * Handles:
 * - Security headers (X-Content-Type-Options, X-Frame-Options, CSP, Cache-Control)
 * - CORS with credential support
 * - Session cookies
 * - API method routing (/api/method/<path>)
 * - Health endpoint (/health)
 * - Sync endpoint (/api/sync)
 */

import http from 'node:http'
import crypto from 'node:crypto'
import { existsSync, mkdirSync, readFileSync } from 'node:fs'
import { extname, join, dirname, normalize } from 'node:path'
import { fileURLToPath } from 'node:url'
import { DatabaseSync } from 'node:sqlite'
import { handleRequest } from './handlers.js'

const __dirname = dirname(fileURLToPath(import.meta.url))

// ─── Database setup (from db.js) ────────────────────────────────────

const DEFAULT_DATA_DIR = join(__dirname, '..', 'data')

let saDb = null
let suDb = null

export function openDatabases(dataDir = process.env.SC_DATA_DIR || DEFAULT_DATA_DIR) {
  if (saDb) return { sa: saDb, su: suDb }
  mkdirSync(dataDir, { recursive: true })
  saDb = new DatabaseSync(join(dataDir, 'schooladmin.db'))
  suDb = new DatabaseSync(join(dataDir, 'superadmin.db'))
  saDb.exec('PRAGMA journal_mode = WAL')
  suDb.exec('PRAGMA journal_mode = WAL')
  return { sa: saDb, su: suDb }
}

export function closeDatabases() {
  if (saDb) { try { saDb.close() } catch {} saDb = null }
  if (suDb) { try { suDb.close() } catch {} suDb = null }
}

export function getById(db, table, id) {
  return db.prepare(`SELECT * FROM ${table} WHERE id = ?`).get(id)
}

export function getOne(db, table, field, value) {
  return db.prepare(`SELECT * FROM ${table} WHERE ${field} = ?`).get(value)
}

export function getAll(db, table, where = '', ...args) {
  const sql = where ? `SELECT * FROM ${table} WHERE ${where}` : `SELECT * FROM ${table}`
  return db.prepare(sql).all(...args)
}

export function count(db, table, where = '', ...args) {
  const sql = where ? `SELECT COUNT(*) as n FROM ${table} WHERE ${where}` : `SELECT COUNT(*) as n FROM ${table}`
  return db.prepare(sql).get(...args).n
}

export function insert(db, table, row) {
  const cols = Object.keys(row)
  const placeholders = cols.map(() => '?').join(', ')
  const sql = `INSERT INTO ${table} (${cols.join(', ')}) VALUES (${placeholders})`
  db.prepare(sql).run(...Object.values(row))
  return row
}

export function updateById(db, table, id, updates) {
  const cols = Object.keys(updates)
  if (cols.length === 0) return
  const sets = cols.map(c => `${c} = ?`).join(', ')
  db.prepare(`UPDATE ${table} SET ${sets} WHERE id = ?`).run(...Object.values(updates), id)
}

export function deleteById(db, table, id) {
  db.prepare(`DELETE FROM ${table} WHERE id = ?`).run(id)
}

export function deleteWhere(db, table, field, value) {
  db.prepare(`DELETE FROM ${table} WHERE ${field} = ?`).run(value)
}

export function genId(prefix = '') {
  return `${prefix}${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
}

// ─── Password helpers (from seed.js) ────────────────────────────────

export function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex')
  const hash = crypto.scryptSync(password, salt, 64).toString('hex')
  return `${salt}:${hash}`
}

export function verifyPassword(password, stored) {
  if (!stored) return false
  if (stored.includes(':') && !stored.startsWith('scrypt$')) {
    const [salt, hash] = stored.split(':')
    const test = crypto.scryptSync(password, salt, 64).toString('hex')
    return test === hash
  }
  if (stored.startsWith('scrypt$')) {
    const parts = stored.split('$')
    const salt = Buffer.from(parts[4], 'hex')
    const expectedHash = Buffer.from(parts[5], 'hex')
    const keylen = expectedHash.length
    const test = crypto.scryptSync(password, salt, keylen)
    return crypto.timingSafeEqual(test, expectedHash)
  }
  if (password === stored) return true
  return false
}

export function storeFileBlob(db, { name, mimeType, data, uploadedBy }) {
  const id = `file-${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`
  const size = Math.floor(data.length * 3 / 4)
  db.prepare('INSERT INTO file_blobs (id, name, mime_type, size, data, uploaded_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(id, name || 'file', mimeType || 'application/octet-stream', size, data, uploadedBy || '', new Date().toISOString())
  return id
}

// ─── Seed functions (from seed.js) ───────────────────────────────────

function createSchooladminTables(db) {
  db.exec(`CREATE TABLE IF NOT EXISTS schools (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, location TEXT, status TEXT NOT NULL DEFAULT 'Active',
    established INTEGER, periods TEXT NOT NULL DEFAULT '[]'
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, password TEXT NOT NULL, full_name TEXT NOT NULL,
    role TEXT NOT NULL, school_id TEXT, class_ids TEXT NOT NULL DEFAULT '[]', subjects TEXT NOT NULL DEFAULT '[]',
    status TEXT NOT NULL DEFAULT 'Active'
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS classes (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, program TEXT, school_id TEXT, room TEXT,
    teacher_ids TEXT NOT NULL DEFAULT '[]'
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS students (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT, password TEXT NOT NULL DEFAULT '',
    roll_number INTEGER, class_id TEXT, school_id TEXT, parent_name TEXT, parent_phone TEXT,
    parent_email TEXT, address TEXT, attendance_pct INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'Active'
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS timetable (
    id TEXT PRIMARY KEY, school_id TEXT, class_id TEXT, day TEXT, period INTEGER,
    teacher_id TEXT, subject TEXT
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS assignments (
    id TEXT PRIMARY KEY, title TEXT NOT NULL, course TEXT, class_id TEXT, school_id TEXT,
    due_date TEXT, description TEXT, attachment_id TEXT, attachment_name TEXT, created_by TEXT, created_at TEXT
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS file_blobs (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, mime_type TEXT NOT NULL DEFAULT 'application/octet-stream',
    size INTEGER NOT NULL DEFAULT 0, data TEXT NOT NULL, uploaded_by TEXT, created_at TEXT NOT NULL
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS attendance_log (
    id TEXT PRIMARY KEY, student_id TEXT NOT NULL, class_id TEXT, school_id TEXT,
    date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'Present', recorded_by TEXT, course TEXT
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS submissions (
    id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, student_id TEXT NOT NULL,
    file_id TEXT, file_name TEXT, score TEXT, feedback TEXT,
    status TEXT NOT NULL DEFAULT 'Submitted', submitted_at TEXT
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS sessions (
    sid TEXT PRIMARY KEY, user_id TEXT NOT NULL, expires_at INTEGER NOT NULL
  )`)
  db.exec(`CREATE INDEX IF NOT EXISTS idx_students_class ON students (class_id)`)
  db.exec(`CREATE INDEX IF NOT EXISTS idx_students_school ON students (school_id)`)
  db.exec(`CREATE INDEX IF NOT EXISTS idx_timetable_class ON timetable (class_id, day, period)`)
  db.exec(`CREATE INDEX IF NOT EXISTS idx_users_school ON users (school_id)`)
}

function createSuperadminTables(db) {
  db.exec(`CREATE TABLE IF NOT EXISTS schools (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, location TEXT, status TEXT NOT NULL DEFAULT 'Active',
    established INTEGER, teacher_count INTEGER NOT NULL DEFAULT 0,
    class_count INTEGER NOT NULL DEFAULT 0, student_count INTEGER NOT NULL DEFAULT 0
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, password TEXT NOT NULL, full_name TEXT NOT NULL,
    role TEXT NOT NULL, school_id TEXT, status TEXT NOT NULL DEFAULT 'Active'
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS sessions (
    sid TEXT PRIMARY KEY, user_id TEXT NOT NULL, expires_at INTEGER NOT NULL
  )`)
}

export function seedSchooladmin(db) {
  createSchooladminTables(db)
  if (db.prepare('SELECT COUNT(*) as n FROM users').get().n > 0) return
}

export function seedSuperadmin(db) {
  createSuperadminTables(db)
  if (db.prepare('SELECT COUNT(*) as n FROM users').get().n > 0) return
  db.prepare('INSERT INTO schools (id, name, location, status, established, teacher_count, class_count, student_count) VALUES (?, ?, ?, ?, ?, ?, ?, ?)').run('demo-school', 'Demo School', 'Mumbai', 'Active', 2023, 0, 0, 0)
  db.prepare('INSERT INTO users (id, email, password, full_name, role, school_id, status) VALUES (?, ?, ?, ?, ?, ?, ?)').run('u-admin', 'admin', hashPassword('ranbrosglobal'), 'Administrator', 'Administrator', null, 'Active')
}

// ─── Sync outbox (from sync.js) ──────────────────────────────────────

export function createOutbox({ consoleName, peerUrl, secret }) {
  const queue = []
  let sending = false

  async function flush() {
    if (sending || queue.length === 0) return
    sending = true
    while (queue.length > 0) {
      const event = queue[0]
      try {
        await sendEvent(peerUrl, secret, event)
        queue.shift()
      } catch {
        await new Promise(r => setTimeout(r, Math.min(30000, 1000 * Math.pow(2, queue.length))))
        break
      }
    }
    sending = false
  }

  async function sendEvent(peerUrl, secret, event) {
    const body = JSON.stringify(event)
    return new Promise((resolve, reject) => {
      const url = new URL('/api/sync', peerUrl)
      const req = http.request(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Sync-Secret': secret, 'Content-Length': Buffer.byteLength(body) },
        timeout: 5000,
      }, (res) => {
        let data = ''
        res.on('data', chunk => data += chunk)
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) resolve(data)
          else reject(new Error(`Sync failed: ${res.statusCode} ${data}`))
        })
      })
      req.on('error', reject)
      req.on('timeout', () => { req.destroy(); reject(new Error('Sync timeout')) })
      req.write(body)
      req.end()
    })
  }

  return {
    push(event) {
      queue.push({ ...event, source: consoleName, timestamp: Date.now() })
      flush()
    },
    get pending() { return queue.length },
  }
}

// ─── Server IP & config ──────────────────────────────────────────────

const SERVER_IP = process.env.SC_HOST || '13.205.212.64'

const ALLOWED_ORIGINS = [
  `http://${SERVER_IP}:5173`,
  `http://${SERVER_IP}:5175`,
  `http://${SERVER_IP}:3000`,
  `http://${SERVER_IP}:3001`,
  `http://${SERVER_IP}`,
  `https://${SERVER_IP}`,
  `https://${SERVER_IP}:5173`,
  `https://${SERVER_IP}:5175`,
  `https://${SERVER_IP}:3000`,
  `https://${SERVER_IP}:3001`,
  'http://localhost:5173',
  'http://localhost:5175',
  'http://localhost:3000',
  'http://localhost:3001',
  'http://localhost',
  'https://localhost',
  'https://localhost:5173',
  'https://localhost:5175',
  'https://localhost:3000',
  'https://localhost:3001',
]

/**
 * Create and start the HTTP server.
 * @param {object} opts
 * @param {'schooladmin'|'superadmin'} opts.consoleName
 * @param {number} opts.port
 * @param {function} opts.seed — seed function(db)
 * @param {object} opts.sync — { secret, outbox, reconcile }
 * @returns {http.Server}
 */
const MAX_BODY_BYTES = 1 * 1024 * 1024 // 1 MB for normal API requests
const IS_SECURE = process.env.SC_SECURE === 'true' || process.env.NODE_ENV === 'production'

function cookieFlags() {
  return `Path=/; HttpOnly; SameSite=Lax; Max-Age=86400${IS_SECURE ? '; Secure' : ''}`
}

/**
 * Read request body with size limit. Rejects if body exceeds MAX_BODY_BYTES.
 */
function readBody(req, maxBytes = MAX_BODY_BYTES) {
  return new Promise((resolve, reject) => {
    let size = 0
    let body = ''
    req.on('data', chunk => {
      size += chunk.length
      if (size > maxBytes) {
        req.destroy()
        reject({ status: 413, message: 'Request body too large' })
        return
      }
      body += chunk
    })
    req.on('end', () => resolve(body))
    req.on('error', reject)
  })
}

const CONTENT_TYPES = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
}

function serveStatic(staticDir, urlPath, req, res) {
  if (!staticDir || !['GET', 'HEAD'].includes(req.method)) return false
  const requestedPath = decodeURIComponent(urlPath === '/' ? '/index.html' : urlPath)
  const staticRoot = normalize(staticDir)
  let filePath = normalize(join(staticDir, requestedPath))
  if (!filePath.startsWith(staticRoot) || !existsSync(filePath)) {
    if (extname(requestedPath)) return false
    filePath = join(staticDir, 'index.html')
    if (!existsSync(filePath)) return false
  }

  const contentType = CONTENT_TYPES[extname(filePath).toLowerCase()] || 'application/octet-stream'
  const content = readFileSync(filePath)
  res.writeHead(200, { 'Content-Type': contentType, 'Content-Length': content.length })
  if (req.method !== 'HEAD') res.end(content)
  else res.end()
  return true
}

export function createServer({ consoleName, port, seed, sync, staticDir }) {
  const { sa, su } = openDatabases()
  const db = consoleName === 'schooladmin' ? sa : su
  const bothDbs = { sa, su }

  // Seed the database if requested
  if (seed) seed(db)

  const server = http.createServer((req, res) => {
    // Security headers
    res.setHeader('X-Content-Type-Options', 'nosniff')
    res.setHeader('X-Frame-Options', 'DENY')
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate')
    res.setHeader('Content-Security-Policy', staticDir
      ? "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; img-src 'self' data:; connect-src 'self'"
      : "default-src 'none'")
    res.setHeader('Referrer-Policy', 'no-referrer')
    res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()')
    if (IS_SECURE) res.setHeader('Strict-Transport-Security', 'max-age=63072000; includeSubDomains')

    // CORS
    const origin = req.headers.origin
    const corsAllowed = origin && ALLOWED_ORIGINS.includes(origin)
    if (corsAllowed) {
      res.setHeader('Access-Control-Allow-Origin', origin)
      res.setHeader('Access-Control-Allow-Credentials', 'true')
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-CSRF-Token, X-Sync-Secret, X-Mobile-Key, Authorization, Cookie')
    } else if (origin) {
      // Log mismatched origins so blocked preflights are easy to debug.
      // Do NOT reflect an arbitrary origin back — the browser must still see
      // no Access-Control-Allow-Origin on the response in this branch.
      console.log(`[${consoleName}] Rejected CORS origin: ${origin} method=${req.method} path=${req.url}`)
    }

    // Handle preflight
    if (req.method === 'OPTIONS') {
      console.log(`[${consoleName}] OPTIONS preflight ${corsAllowed ? 'ALLOWED' : 'missing-cors'} origin=${origin || '(none)'} path=${req.url}`)
      res.writeHead(204)
      res.end()
      return
    }

    // Request logging for CORS debugging
    if (consoleName === 'server' && req.url.startsWith('/api/method/school_connect.api.auth.login')) {
      console.log(`[${consoleName}] login request method=${req.method} origin=${origin || '(none)'} corsAllowed=${corsAllowed} remote=${req.socket.remoteAddress}:${req.socket.remotePort}`)
    }

    // Parse URL
    const url = new URL(req.url, `http://${SERVER_IP}:${port}`)

    // Health endpoint
    if (url.pathname === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ ok: true, console: consoleName, port }))
      return
    }

    // After this point, all responses should include CORS headers
    // (already set above if origin matched)

    // Mobile app endpoints — bypass session auth for specific mobile routes
    if (url.pathname === '/api/mobile/login' && req.method === 'POST') {
      let body = ''
      req.on('data', chunk => body += chunk)
      req.on('end', () => {
        try {
          const creds = JSON.parse(body)
          // Direct mobile login with email+password
          try {
            const result = handleRequest(consoleName, bothDbs, 'school_connect.api.mobile.login', {
              method: 'POST', params: {}, body: creds, headers: req.headers,
              ip: req.headers['x-forwarded-for'] || req.socket.remoteAddress, sid: null,
            })
            const respHeaders = { 'Content-Type': 'application/json' }
            if (result._sid) {
              respHeaders['Set-Cookie'] = `sid=${result._sid}; ${cookieFlags()}`
            }
            res.writeHead(200, respHeaders)
            res.end(JSON.stringify({ message: result.data }))
          } catch (loginErr) {
            const status = loginErr.status || 500
            res.writeHead(status, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ message: loginErr.message }))
          }
        } catch (err) {
          const status = err.status || 500
          res.writeHead(status, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify({ message: err.message }))
        }
      })
      return
    }

    // Sync endpoint
    if (url.pathname === '/api/sync' && req.method === 'POST') {        readBody(req).then(body => {
          try {
            const event = JSON.parse(body)
            const secret = req.headers['x-sync-secret']
            if (sync?.secret && secret === sync.secret) {
              console.log(`[sync] Received event from ${event.source}`)
              res.writeHead(200, { 'Content-Type': 'application/json' })
              res.end(JSON.stringify({ ok: true }))
            } else {
              res.writeHead(403, { 'Content-Type': 'application/json' })
              res.end(JSON.stringify({ message: 'Invalid sync secret' }))
            }
          } catch {
            res.writeHead(400, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ message: 'Invalid JSON' }))
          }
        }).catch(err => {
          if (!res.headersSent) {
            const status = err.status || 413
            res.writeHead(status, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ message: err.message || 'Request too large' }))
          }
        })
      return
    }

    // API method routing: /api/method/<path>
    if (url.pathname.startsWith('/api/method/')) {
      const apiPath = url.pathname.slice('/api/method/'.length)

      // Parse cookies for session
      const cookieHeader = req.headers.cookie || ''
      let sid = null
      for (const part of cookieHeader.split(';')) {
        const [k, v] = part.trim().split('=')
        if (k === 'sid') sid = v
      }

      // Parse query params and body
      const params = Object.fromEntries(url.searchParams)

      if (req.method === 'GET') {
          try {
            const result = handleRequest(consoleName, bothDbs, apiPath, {
              method: 'GET', params, body: {}, headers: req.headers,
              ip: req.headers['x-forwarded-for'] || req.socket.remoteAddress, sid,
            })
          const respHeaders = { 'Content-Type': 'application/json' }
          if (result._sid) {
            respHeaders['Set-Cookie'] = `sid=${result._sid}; Path=/; HttpOnly; SameSite=Lax; Max-Age=86400`
          }
          res.writeHead(200, respHeaders)
          res.end(JSON.stringify({ message: result.data }))
        } catch (err) {
          const status = err.status || 500
          res.writeHead(status, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify({ message: err.message, exc_type: err.exc_type || 'ServerError' }))
        }
        return
      }

      if (req.method === 'POST') {
        readBody(req).then(body => {
          let bodyParams = {}
          try { bodyParams = body ? JSON.parse(body) : {} } catch {}
          try {
            const result = handleRequest(consoleName, bothDbs, apiPath, {
              method: 'POST', params, body: bodyParams, headers: req.headers,
              ip: req.headers['x-forwarded-for'] || req.socket.remoteAddress, sid,
            })
            const respHeaders = { 'Content-Type': 'application/json' }
            if (result._sid) {
              respHeaders['Set-Cookie'] = `sid=${result._sid}; ${cookieFlags()}`
            }
            res.writeHead(200, respHeaders)
            res.end(JSON.stringify({ message: result.data }))
          } catch (err) {
            const status = err.status || 500
            res.writeHead(status, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ message: err.message, exc_type: err.exc_type || 'ServerError' }))
          }
        }).catch(err => {
          if (!res.headersSent) {
            const status = err.status || 413
            res.writeHead(status, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ message: err.message || 'Request too large' }))
          }
        })
        return
      }
    }

    if (serveStatic(staticDir, url.pathname, req, res)) return

    // 404
    res.writeHead(404, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ message: 'Not found' }))
  })

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`[${consoleName}] Port ${port} is already in use. Is another instance running?`)
    } else {
      console.error(`[${consoleName}] Server error:`, err.message)
    }
  })

  server.listen(port, '0.0.0.0', () => {
    console.log(`[${consoleName}] Server running on http://${SERVER_IP}:${port}`)
  })

  // Graceful shutdown
  server.on('close', () => closeDatabases())

  return server
}
