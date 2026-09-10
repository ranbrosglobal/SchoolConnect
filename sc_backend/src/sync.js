/**
 * Cross-backend sync — keeps schooladmin and superadmin databases in sync.
 *
 * When the superadmin console creates/updates/deletes a school or school admin,
 * those changes need to propagate to the schooladmin database, and vice versa.
 *
 * Uses an outbox pattern with HTTP polling and exponential backoff retry.
 */

import http from 'node:http'

/**
 * Create an outbox that queues sync events and sends them to a peer.
 * @param {object} opts
 * @param {string} opts.consoleName — 'schooladmin' or 'superadmin'
 * @param {string} opts.peerUrl — URL of the peer server
 * @param {string} opts.secret — shared secret for sync auth
 */
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
        // Exponential backoff: wait before retrying
        await new Promise(r => setTimeout(r, Math.min(30000, 1000 * Math.pow(2, queue.length))))
        break
      }
    }
    sending = false
  }

  return {
    /** Queue a sync event. */
    push(event) {
      queue.push({ ...event, source: consoleName, timestamp: Date.now() })
      flush()
    },
    /** Current queue length (for monitoring). */
    get pending() { return queue.length },
  }
}

async function sendEvent(peerUrl, secret, event) {
  const body = JSON.stringify(event)
  return new Promise((resolve, reject) => {
    const url = new URL('/api/sync', peerUrl)
    const req = http.request(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Sync-Secret': secret,
        'Content-Length': Buffer.byteLength(body),
      },
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

/**
 * Create a sync handler that receives events from a peer.
 * @param {string} secret — shared secret
 * @param {'schooladmin'|'superadmin'} consoleName
 * @returns {function} — call with (db, event) to apply
 */
export function createSyncHandler(secret, consoleName) {
  return function applySync(db, event, reqSecret) {
    if (reqSecret !== secret) return false

    // Apply the event to the local database
    // For now, sync is a no-op placeholder — the full implementation would
    // mirror school/admin CRUD operations between databases.
    console.log(`[sync] Received ${event.type} from ${event.source}`)
    return true
  }
}
