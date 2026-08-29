/**
 * Entry point for the SchoolConnect SQLite backend.
 *
 * Starts both the schooladmin server (:8090) and the superadmin server (:8091).
 * In production mode, the web apps proxy to these servers via Vite's dev proxy.
 *
 * Usage:
 *   node src/index.js          — start both servers
 *   node src/index.js --reset  — wipe and reseed both databases, then start
 */

import { openDatabases, closeDatabases } from './db.js'
import { seedSchooladmin, seedSuperadmin } from './seed.js'
import { createServer } from './server.js'
import { createOutbox } from './sync.js'

const SA_PORT = Number(process.env.SC_SA_PORT || 3000)
const SU_PORT = Number(process.env.SC_SU_PORT || 3001)

const reset = process.argv.includes('--reset')

// Reset databases if requested
if (reset) {
  console.log('Resetting databases...')
  const { sa, su } = openDatabases()
  // Drop all tables and recreate
  for (const db of [sa, su]) {
    const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").all()
    for (const t of tables) {
      db.exec(`DELETE FROM ${t.name}`)
    }
  }
  closeDatabases()
  console.log('Databases reset.')
}

// ─── Startup sync: reconcile data between the two databases ─────────
// When the super admin creates a school + school admin, those live in superadmin.db.
// The schooladmin server needs them too. This sync runs once at startup.
function startupSync() {
  const { sa, su } = openDatabases()
  console.log('[sync] Running startup sync between databases...')

  // 1. Mirror schools from superadmin.db → schooladmin.db
  const suSchools = su.prepare('SELECT * FROM schools').all()
  const upsertSchool = sa.prepare(`
    INSERT OR REPLACE INTO schools (id, name, location, status, established, periods)
    VALUES (?, ?, ?, ?, ?, COALESCE(
      (SELECT periods FROM schools WHERE id = ?), '[]'
    ))
  `)
  for (const s of suSchools) {
    // Check if school exists in sa db
    const existing = sa.prepare('SELECT id FROM schools WHERE id = ?').get(s.id)
    if (existing) {
      // Update existing school's name, location, status, established
      sa.prepare('UPDATE schools SET name = ?, location = ?, status = ?, established = ? WHERE id = ?')
        .run(s.name, s.location || '', s.status, s.established || new Date().getFullYear(), s.id)
    } else {
      // Insert new school
      sa.prepare('INSERT INTO schools (id, name, location, status, established, periods) VALUES (?, ?, ?, ?, ?, ?)')
        .run(s.id, s.name, s.location || '', s.status, s.established || new Date().getFullYear(), '[]')
    }
  }

  // 2. Mirror school admins from superadmin.db → schooladmin.db
  const suAdmins = su.prepare("SELECT * FROM users WHERE role = 'School Admin'").all()
  for (const a of suAdmins) {
    const existing = sa.prepare('SELECT id FROM users WHERE id = ?').get(a.id)
    if (existing) {
      // Update existing admin
      sa.prepare('UPDATE users SET email = ?, full_name = ?, school_id = ?, status = ? WHERE id = ?')
        .run(a.email, a.full_name, a.school_id || '', a.status || 'Active', a.id)
    } else {
      // Insert new admin (with password hash from superadmin db)
      try {
        sa.prepare('INSERT INTO users (id, email, password, full_name, role, school_id, class_ids, subjects, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)')
          .run(a.id, a.email, a.password, a.full_name, 'School Admin', a.school_id || '', '[]', '[]', a.status || 'Active')
      } catch (_e) { /* email unique constraint or other issue */ }
    }
  }

  // 3. Sync counts from schooladmin.db → superadmin.db
  for (const s of suSchools) {
    try {
      const tc = sa.prepare("SELECT COUNT(*) as n FROM users WHERE role = 'Teacher' AND school_id = ?").get(s.id)
      const cc = sa.prepare('SELECT COUNT(*) as n FROM classes WHERE school_id = ?').get(s.id)
      const sc = sa.prepare('SELECT COUNT(*) as n FROM students WHERE school_id = ?').get(s.id)
      su.prepare('UPDATE schools SET teacher_count = ?, class_count = ?, student_count = ? WHERE id = ?')
        .run(tc.n, cc.n, sc.n, s.id)
    } catch (_e) {}
  }

  console.log(`[sync] Synced ${suSchools.length} schools, ${suAdmins.length} school admins.`)
}

// Set up cross-backend sync (sync moved to after servers start)
const saOutbox = createOutbox({
  consoleName: 'schooladmin',
  peerUrl: `http://127.0.0.1:${SU_PORT}`,
  secret: process.env.SC_SYNC_SECRET || 'schoolconnect-sync',
})
const suOutbox = createOutbox({
  consoleName: 'superadmin',
  peerUrl: `http://127.0.0.1:${SA_PORT}`,
  secret: process.env.SC_SYNC_SECRET || 'schoolconnect-sync',
})

// Start both servers
const saServer = createServer({
  consoleName: 'schooladmin',
  port: SA_PORT,
  seed: seedSchooladmin,
  sync: { secret: process.env.SC_SYNC_SECRET || 'schoolconnect-sync', outbox: saOutbox, reconcile() {} },
})

const suServer = createServer({
  consoleName: 'superadmin',
  port: SU_PORT,
  seed: seedSuperadmin,
  sync: { secret: process.env.SC_SYNC_SECRET || 'schoolconnect-sync', outbox: suOutbox, reconcile() {} },
})

// Run startup sync AFTER servers are created (seeding happens in createServer)
try { startupSync() } catch (e) { console.error('[sync] Startup sync failed:', e.message) }

console.log(`\nSchoolConnect backend ready!`)
console.log(`  School Admin: http://localhost:${SA_PORT}`)
console.log(`  Super Admin:  http://localhost:${SU_PORT}`)
console.log(`  Health:       http://localhost:${SA_PORT}/health\n`)

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down...')
  saServer.close()
  suServer.close()
  closeDatabases()
  process.exit(0)
})
