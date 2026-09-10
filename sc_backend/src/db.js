/**
 * SQLite database wrapper for both schooladmin and superadmin databases.
 *
 * Uses Node 24's built-in node:sqlite module (experimental but functional).
 * Each database is opened as a separate DatabaseSync instance.
 */

import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { DatabaseSync } from 'node:sqlite'

const __dirname = dirname(fileURLToPath(import.meta.url))
const DEFAULT_DATA_DIR = join(__dirname, '..', 'data')

let saDb = null
let suDb = null

/**
 * Open (or return existing) database connections.
 * @param {string} [dataDir] Override the data directory.
 */
export function openDatabases(dataDir = process.env.SC_DATA_DIR || DEFAULT_DATA_DIR) {
  if (saDb) return { sa: saDb, su: suDb }

  saDb = new DatabaseSync(join(dataDir, 'schooladmin.db'))
  suDb = new DatabaseSync(join(dataDir, 'superadmin.db'))

  // WAL mode for better concurrent read performance
  saDb.exec('PRAGMA journal_mode = WAL')
  suDb.exec('PRAGMA journal_mode = WAL')

  return { sa: saDb, su: suDb }
}

/** Get the schooladmin database. */
export function getSaDb() {
  if (!saDb) throw new Error('Call openDatabases() first')
  return saDb
}

/** Get the superadmin database. */
export function getSuDb() {
  if (!suDb) throw new Error('Call openDatabases() first')
  return suDb
}

/** Close both databases. */
export function closeDatabases() {
  if (saDb) { try { saDb.close() } catch {} saDb = null }
  if (suDb) { try { suDb.close() } catch {} suDb = null }
}

// ─── Query helpers ───────────────────────────────────────────────────

/** Get one row by primary key. */
export function getById(db, table, id) {
  return db.prepare(`SELECT * FROM ${table} WHERE id = ?`).get(id)
}

/** Get one row by arbitrary field. */
export function getOne(db, table, field, value) {
  return db.prepare(`SELECT * FROM ${table} WHERE ${field} = ?`).get(value)
}

/** Get all rows, optionally filtered. */
export function getAll(db, table, where = '', ...args) {
  const sql = where ? `SELECT * FROM ${table} WHERE ${where}` : `SELECT * FROM ${table}`
  return db.prepare(sql).all(...args)
}

/** Count rows. */
export function count(db, table, where = '', ...args) {
  const sql = where ? `SELECT COUNT(*) as n FROM ${table} WHERE ${where}` : `SELECT COUNT(*) as n FROM ${table}`
  return db.prepare(sql).get(...args).n
}

/** Insert a row. */
export function insert(db, table, row) {
  const cols = Object.keys(row)
  const placeholders = cols.map(() => '?').join(', ')
  const sql = `INSERT INTO ${table} (${cols.join(', ')}) VALUES (${placeholders})`
  db.prepare(sql).run(...Object.values(row))
  return row
}

/** Update a row by id. */
export function updateById(db, table, id, updates) {
  const cols = Object.keys(updates)
  if (cols.length === 0) return
  const sets = cols.map(c => `${c} = ?`).join(', ')
  db.prepare(`UPDATE ${table} SET ${sets} WHERE id = ?`).run(...Object.values(updates), id)
}

/** Delete a row by id. */
export function deleteById(db, table, id) {
  db.prepare(`DELETE FROM ${table} WHERE id = ?`).run(id)
}

/** Delete rows by field. */
export function deleteWhere(db, table, field, value) {
  db.prepare(`DELETE FROM ${table} WHERE ${field} = ?`).run(value)
}

/** Generate a unique ID. */
export function genId(prefix = '') {
  return `${prefix}${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
}
