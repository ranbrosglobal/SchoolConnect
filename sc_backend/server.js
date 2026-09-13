/**
 * SchoolConnect production entrypoint.
 *
 * Each frontend and its API share one origin, so the browser only needs the
 * public frontend ports 5173 and 5175. The API is available at /api on each
 * origin and does not require cross-origin requests.
 */

import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { closeDatabases, createServer } from './src/server.js'
import { seedSchooladmin, seedSuperadmin } from './src/seed.js'

const __dirname = dirname(fileURLToPath(import.meta.url))
const HOST = process.env.SC_HOST || '13.205.212.64'
const SCHOOLADMIN_PORT = Number(process.env.SC_SA_PORT || 5173)
const SUPERADMIN_PORT = Number(process.env.SC_SU_PORT || 5175)
const syncSecret = process.env.SC_SYNC_SECRET || 'schoolconnect-sync'

const schooladmin = createServer({
  consoleName: 'schooladmin',
  port: SCHOOLADMIN_PORT,
  seed: seedSchooladmin,
  staticDir: join(__dirname, '..', 'schooladmin', 'dist'),
  sync: { secret: syncSecret },
})

const superadmin = createServer({
  consoleName: 'superadmin',
  port: SUPERADMIN_PORT,
  seed: seedSuperadmin,
  staticDir: join(__dirname, '..', 'superadmin', 'dist'),
  sync: { secret: syncSecret },
})

console.log('SchoolConnect production server ready!')
console.log(`  School Admin: http://${HOST}:${SCHOOLADMIN_PORT}`)
console.log(`  Super Admin:  http://${HOST}:${SUPERADMIN_PORT}`)

function shutdown() {
  schooladmin.close()
  superadmin.close()
  closeDatabases()
  process.exit(0)
}

process.on('SIGINT', shutdown)
process.on('SIGTERM', shutdown)