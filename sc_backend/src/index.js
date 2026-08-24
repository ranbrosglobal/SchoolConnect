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

// Set up cross-backend sync
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
