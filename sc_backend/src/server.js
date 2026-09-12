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
import { openDatabases, closeDatabases } from './db.js'
import { handleRequest, listEndpoints } from './handlers.js'
import { seedSchooladmin, seedSuperadmin } from './seed.js'

const ALLOWED_ORIGINS = [
  'http://13.205.212.64:5173',
  'http://13.205.212.64:5175',
  'http://13.205.212.64:3000',
  'http://13.205.212.64:3001',
  'http://13.205.212.64',
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

export function createServer({ consoleName, port, seed, sync }) {
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
    res.setHeader('Content-Security-Policy', "default-src 'none'")
    res.setHeader('Referrer-Policy', 'no-referrer')
    res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()')
    if (IS_SECURE) res.setHeader('Strict-Transport-Security', 'max-age=63072000; includeSubDomains')

    // CORS
    const origin = req.headers.origin
    if (origin && ALLOWED_ORIGINS.includes(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin)
      res.setHeader('Access-Control-Allow-Credentials', 'true')
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-CSRF-Token, X-Sync-Secret, X-Mobile-Key, Authorization, Cookie')
    }

    // Handle preflight
    if (req.method === 'OPTIONS') {
      res.writeHead(204)
      res.end()
      return
    }

    // Parse URL
    const url = new URL(req.url, `http://13.205.212.64:${port}`)

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
    console.log(`[${consoleName}] Server running on http://13.205.212.64:${port}`)
  })

  // Graceful shutdown
  server.on('close', () => closeDatabases())

  return server
}
