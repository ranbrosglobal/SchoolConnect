/*
 * Release-candidate smoke test — exercises every observable behavior
 * our patch added or changed, via real HTTP entry points.
 *
 * Run: node scripts/test-release.mjs
 */

import { mkdtempSync, rmSync, readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

const tempDir = mkdtempSync(join(tmpdir(), 'sc-rc-'))
process.env.SC_DATA_DIR = tempDir

const { createServer } = await import('../src/server.js')
const { createOutbox } = await import('../src/sync.js')
const { listEndpoints } = await import('../src/handlers.js')
const { seedSchooladmin, seedSuperadmin } = await import('../src/seed.js')

const SA = `http://127.0.0.1:8390`
const SU = `http://127.0.0.1:8391`

let pass = 0, fail = 0
function check(ok, desc, detail) {
  if (ok) { pass++; console.log(`  ✓ ${desc}`) }
  else { fail++; console.log(`  ✗ ${desc}${detail ? ` — ${detail}` : ''}`) }
}

let ipN = 0
async function req(url, path, { method = 'GET', body, cookie, csrf, ip, origin } = {}) {
  const headers = { Accept: 'application/json' }
  if (cookie) headers.Cookie = cookie
  if (csrf) headers['X-CSRF-Token'] = csrf
  if (ip) headers['X-Forwarded-For'] = ip
  if (origin) headers.Origin = origin
  if (body !== undefined) {
    headers['Content-Type'] = 'application/json'
  }
  const res = await fetch(`${url}${path}`, {
    method, headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })
  const setCookies = res.headers.getSetCookie?.() || []
  let sid = cookie
  for (const c of setCookies) { const s = c.split(';')[0]; if (s.startsWith('sid=')) sid = s }
  let json = null
  try { json = await res.json() } catch {}
  return { status: res.status, json, cookie: sid, headers: Object.fromEntries(res.headers.entries()) }
}

const servers = []
try {
  const outbox1 = createOutbox({ consoleName: 'schooladmin', peerUrl: 'http://127.0.0.1:8391', secret: 'x' })
  const outbox2 = createOutbox({ consoleName: 'superadmin', peerUrl: 'http://127.0.0.1:8390', secret: 'x' })
  servers.push(createServer({ consoleName: 'schooladmin', port: 8390, seed: seedSchooladmin, sync: { secret: 'x', outbox: outbox1, reconcile() {} } }))
  servers.push(createServer({ consoleName: 'superadmin', port: 8391, seed: seedSuperadmin, sync: { secret: 'x', outbox: outbox2, reconcile() {} } }))
  await new Promise(r => setTimeout(r, 300))

  /* ── 1. Security headers ──────────────────────────────── */
  console.log('\n1. Security headers')
  const h = await req(SA, '/health')
  check(h.headers['x-content-type-options'] === 'nosniff', 'X-Content-Type-Options: nosniff')
  check(h.headers['x-frame-options'] === 'DENY', 'X-Frame-Options: DENY')
  check(h.headers['cache-control']?.includes('no-store'), 'Cache-Control: no-store')
  check(h.headers['content-security-policy']?.includes("default-src 'none'"), 'CSP: default-src none')

  /* ── 2. CORS — localhost allowed ──────────────────────── */
  console.log('\n2. CORS')
  const cors = await req(SA, '/health', { origin: 'http://localhost:5173' })
  check(cors.headers['access-control-allow-origin'] === 'http://localhost:5173', 'localhost origin reflected')
  check(cors.headers['access-control-allow-credentials'] === 'true', 'credentials: true')
  const blocked = await req(SA, '/health', { origin: 'https://evil.com' })
  check(!blocked.headers['access-control-allow-origin'], 'evil.com origin blocked')

  /* ── 3. CSRF — POST without token → 403 ──────────────── */
  console.log('\n3. CSRF protection')
  // Login first to get a real session (CSRF check requires session != null)
  const csrfLogin = await req(SA, '/api/method/school_connect.api.auth.login', { method: 'POST', body: { usr: 'ravi@riverside.edu', pwd: 'admin123' }, ip: '15.0.0.1' })
  const sessionCookie = csrfLogin.cookie
  // POST without CSRF token → should be 403
  const noCsrf = await req(SA, '/api/method/school_connect.api.admin.get_admin_dashboard', { method: 'POST', body: { school: 'riverside' }, cookie: sessionCookie })
  check(noCsrf.status === 403 && noCsrf.json?.exc_type === 'CSRFError', 'POST without CSRF → 403')
  // POST with correct CSRF token → should be 200
  const withCsrf = await req(SA, '/api/method/school_connect.api.admin.get_admin_dashboard', { method: 'POST', body: { school: 'riverside' }, cookie: sessionCookie, csrf: csrfLogin.json?.message?.name })
  check(withCsrf.status === 200, 'POST with valid CSRF → 200')

  /* ── 4. Lockout lifecycle ─────────────────────────────── */
  console.log('\n4. Lockout')
  // 10 failures → locked
  for (let i = 0; i < 10; i++) await req(SA, '/api/method/school_connect.api.auth.login', { method: 'POST', body: { usr: 'priya@springfield.edu', pwd: 'x' }, ip: `11.0.${i}` })
  const locked = await req(SA, '/api/method/school_connect.api.auth.login', { method: 'POST', body: { usr: 'priya@springfield.edu', pwd: 'admin123' }, ip: '11.0.99' })
  check(locked.status === 429 && locked.json?.message?.includes('temporarily locked'), 'locked → 429')
  // Non-locked account works
  const ok = await req(SA, '/api/method/school_connect.api.auth.login', { method: 'POST', body: { usr: 'ravi@riverside.edu', pwd: 'admin123' }, ip: '12.0.0.1' })
  check(ok.status === 200, 'non-locked account → 200')

  /* ── 5. Rate limiter ──────────────────────────────────── */
  console.log('\n5. Rate limiter')
  const rlIp = `13.0.0.1`
  let last
  for (let i = 0; i < 6; i++) last = await req(SA, '/api/method/school_connect.api.auth.login', { method: 'POST', body: { usr: 'x@y.com', pwd: 'x' }, ip: rlIp })
  check(last.status === 429 && last.json?.exc_type === 'RateLimitError', '6th attempt same IP → 429 RateLimitError')

  /* ── 6. Auth — login, session, logout ─────────────────── */
  console.log('\n6. Auth lifecycle')
  const login = await req(SA, '/api/method/school_connect.api.auth.login', { method: 'POST', body: { usr: 'ravi@riverside.edu', pwd: 'admin123' }, ip: '14.0.0.1' })
  check(login.status === 200 && login.json?.message?.name, 'login → 200 + user')
  const cookie = login.cookie
  const me = await req(SA, '/api/method/school_connect.api.auth.get_session', { cookie })
  check(me.json?.message?.isLoggedIn, 'get_session with cookie → logged in')

  /* ── 7. Endpoint parity ───────────────────────────────── */
  console.log('\n7. Endpoint parity')
  const __dirname = fileURLToPath(new URL('.', import.meta.url))
  const contract = JSON.parse(readFileSync(join(__dirname, '..', 'contract.json'), 'utf8'))
  for (const c of ['schooladmin', 'superadmin']) {
    const server = listEndpoints(c).sort()
    const mock = contract[c].sort()
    const ok = server.length === mock.length && server.every((k, i) => k === mock[i])
    check(ok, `${c}: ${server.length} endpoints match contract`)
  }

  /* ── 8. Health endpoint ───────────────────────────────── */
  console.log('\n8. Health')
  check(h.json?.ok === true && h.json?.console === 'schooladmin', 'health returns ok + console name')

} finally {
  for (const s of servers) s.close()
  try { rmSync(tempDir, { recursive: true, force: true }) } catch {}
}

console.log(`\n${pass}/${pass + fail} release-candidate checks passed`)
process.exitCode = fail ? 1 : 0
