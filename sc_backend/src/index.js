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
import { runDailyAbsenceSweep } from './handlers.js'
import { repairLegacyAttendance as repairAttendanceRows } from './attendance_repair.js'

const SA_PORT = Number(process.env.SC_SA_PORT || 3000)
const SU_PORT = Number(process.env.SC_SU_PORT || 3001)
const SERVER_IP = process.env.SC_HOST || '13.205.212.64'

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

/**
 * Repair attendance rows written by older app builds: they posted a full ISO
 * timestamp (`2026-10-07T14:30:00.000Z`) instead of a calendar day and the
 * student's NAME instead of their id, so a teacher's saved register looked
 * unmarked forever. Idempotent; see src/attendance_repair.js.
 */
function repairLegacyAttendance() {
  const { sa } = openDatabases()
  repairAttendanceRows(sa)
}

// Set up cross-backend sync (sync moved to after servers start)
const saOutbox = createOutbox({
  consoleName: 'schooladmin',
  peerUrl: `http://${SERVER_IP}:${SU_PORT}`,
  secret: process.env.SC_SYNC_SECRET || 'schoolconnect-sync',
})
const suOutbox = createOutbox({
  consoleName: 'superadmin',
  peerUrl: `http://${SERVER_IP}:${SA_PORT}`,
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
try { repairLegacyAttendance() } catch (e) { console.error('[attendance] Legacy attendance repair failed:', e.message) }

// ─── Daily auto-absent sweep (7:00 PM) ───────────────────────────────
// Classes whose teacher never marked attendance get every student recorded
// Absent, so the register is always complete for history and percentages.
const ABSENCE_SWEEP_HOUR = 19

function startAbsenceSweep() {
  const { sa } = openDatabases()

  // On startup: catch up if we're past 7pm and today hasn't been swept yet.
  // A server restart at 9am must not sweep the day early, so the startup run
  // only fires when the local hour is past the cutoff.
  const now = new Date()
  if (now.getHours() >= ABSENCE_SWEEP_HOUR) {
    try {
      runDailyAbsenceSweep(sa, now.toISOString().split('T')[0], { when: 'startup' })
    } catch (e) {
      console.error('[attendance] Startup absence sweep failed:', e.message)
    }
  }

  // Tick every 5 minutes; sweep once per local day after the cutoff.
  let lastSweptDate = now.toISOString().split('T')[0]
  setInterval(() => {
    try {
      const t = new Date()
      const date = t.toISOString().split('T')[0]
      if (date === lastSweptDate) return
      if (t.getHours() < ABSENCE_SWEEP_HOUR) return
      lastSweptDate = date
      runDailyAbsenceSweep(openDatabases().sa, date)
    } catch (e) {
      console.error('[attendance] Scheduled absence sweep failed:', e.message)
    }
  }, 5 * 60 * 1000).unref()
  console.log(`[attendance] Auto-absent scheduler armed: unmarked classes close at ${ABSENCE_SWEEP_HOUR}:00 daily`)
}

try { startAbsenceSweep() } catch (e) { console.error('[attendance] Scheduler failed to start:', e.message) }

console.log(`\nSchoolConnect backend ready!`)
console.log(`  School Admin: http://${SERVER_IP}:${SA_PORT}`)
console.log(`  Super Admin:  http://${SERVER_IP}:${SU_PORT}`)
console.log(`  Health:       http://${SERVER_IP}:${SA_PORT}/health\n`)

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down...')
  saServer.close()
  suServer.close()
  closeDatabases()
  process.exit(0)
})
