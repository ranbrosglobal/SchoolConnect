/*
 * Lockout + rate limiter — compact behavioral contract.
 *
 * Each row exercises one observable behavior. Unique IPs isolate the
 * rate limiter from the lockout so each mechanism is tested independently,
 * then their interaction is tested as a separate case.
 *
 * Run: node scripts/test-lockout.mjs
 */

import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const tempDir = mkdtempSync(join(tmpdir(), 'sc-lockout-'))
process.env.SC_DATA_DIR = tempDir

const { createServer } = await import('../src/server.js')
const { createOutbox } = await import('../src/sync.js')
const { seedSchooladmin, seedSuperadmin } = await import('../src/seed.js')

const SA_PORT = 8290
const SU_PORT = 8291

let ipN = 0
const ip = () => `10.0.${ipN++}`

async function attempt(url, usr, pwd, fwdIp) {
  const headers = { Accept: 'application/json', 'Content-Type': 'application/json' }
  if (fwdIp) headers['X-Forwarded-For'] = fwdIp
  const res = await fetch(`${url}/api/method/school_connect.api.auth.login`, {
    method: 'POST', headers, body: JSON.stringify({ usr, pwd }),
  })
  let json = null
  try { json = await res.json() } catch {}
  return { status: res.status, json }
}

function boot(name, port, seedFn) {
  const outbox = createOutbox({ consoleName: name, peerUrl: 'http://127.0.0.1:0', secret: 'x' })
  return createServer({ consoleName: name, port, seed: (db) => seedFn(db), sync: { secret: 'x', outbox, reconcile() {} } })
}

/* ---- contract table ---- */
// Each entry: [description, () => actual, expected]
// `actual` returns { status, msg? }. Expected is a predicate or { status }.

const SA = `http://127.0.0.1:${SA_PORT}`
const servers = []
let pass = 0, fail = 0

try {
  servers.push(boot('schooladmin', SA_PORT, seedSchooladmin))
  servers.push(boot('superadmin', SU_PORT, seedSuperadmin))
  await new Promise(r => setTimeout(r, 300))

  const tests = [
    // --- lockout basics ---
    ['wrong password → 401',
      () => attempt(SA, 'priya@springfield.edu', 'wrong', ip()),
      { status: 401 }],

    ['3 failures + success → still loginable',
      async () => {
        for (let i = 0; i < 3; i++) await attempt(SA, 'ravi@riverside.edu', 'wrong', ip())
        return attempt(SA, 'ravi@riverside.edu', 'admin123', ip())
      },
      { status: 200 }],

    ['10 failures → lockout engages on 11th attempt',
      async () => {
        for (let i = 0; i < 10; i++) await attempt(SA, 'aman@sunrise.edu', 'wrong', ip())
        return attempt(SA, 'aman@sunrise.edu', 'admin123', ip())
      },
      { status: 429 }],

    ['locked error message mentions "temporarily locked"',
      async () => {
        // aman is locked from the previous test
        const r = await attempt(SA, 'aman@sunrise.edu', 'x', ip())
        return { status: r.status, msg: r.json?.message }
      },
      (r) => r.status === 429 && r.msg?.includes('temporarily locked')],

    ['non-locked account unaffected',
      () => attempt(SA, 'priya@springfield.edu', 'admin123', ip()),
      { status: 200 }],

    // --- rate limiter ---
    ['6th attempt from same IP → 429 RateLimitError',
      async () => {
        const sameIp = ip()
        let last
        for (let i = 0; i < 6; i++) last = await attempt(SA, `rl${i}@x.com`, 'x', sameIp)
        return last
      },
      (r) => r.status === 429 && r.json?.exc_type === 'RateLimitError'],

    // --- interaction ---
    ['rate limiter blocks failures from counting toward lockout',
      async () => {
        const sameIp = ip()
        // 10 wrong attempts from same IP: 5 counted + 5 rate-limited → only 5 failures
        for (let i = 0; i < 10; i++) await attempt(SA, 'priya@springfield.edu', 'wrong', sameIp)
        return attempt(SA, 'priya@springfield.edu', 'admin123', ip())
      },
      { status: 200 }],

    ['lockout is per-email (different IP, same email → still locked)',
      () => attempt(SA, 'aman@sunrise.edu', 'admin123', ip()),
      { status: 429 }],

    // --- clearLockout resets count ---
    ['9 failures → success → 9 more failures → not locked',
      async () => {
        // ravi is not locked (cleared by test 2). Use SA where ravi can log in.
        // Each attempt uses a unique IP to avoid rate limiter interference.
        for (let i = 0; i < 9; i++) await attempt(SA, 'ravi@riverside.edu', 'wrong', ip())
        // success → clearLockout resets failure count to 0
        await attempt(SA, 'ravi@riverside.edu', 'admin123', ip())
        // 9 more failures → count is 9 (under threshold), so login should work
        for (let i = 0; i < 9; i++) await attempt(SA, 'ravi@riverside.edu', 'wrong', ip())
        return attempt(SA, 'ravi@riverside.edu', 'admin123', ip())
      },
      { status: 200 }],
  ]

  for (const [desc, fn, expected] of tests) {
    try {
      const result = await fn()
      const ok = typeof expected === 'function'
        ? expected(result)
        : Object.entries(expected).every(([k, v]) => result[k] === v)
      if (ok) { pass++; console.log(`  ✓ ${desc}`) }
      else { fail++; console.log(`  ✗ ${desc} — got ${JSON.stringify(result)}`) }
    } catch (e) { fail++; console.log(`  ✗ ${desc} — ${e.message}`) }
  }
} finally {
  for (const s of servers) s.close()
  try { rmSync(tempDir, { recursive: true, force: true }) } catch {}
}

console.log(`\n${pass}/${pass + fail} lockout contract checks passed`)
process.exitCode = fail ? 1 : 0
