/**
 * Seed functions for both databases.
 *
 * Each function receives a database instance and populates it with demo data
 * if the database is empty. Used by the test harness (test-release.mjs,
 * test-lockout.mjs) and by the main server for fresh databases.
 */

import crypto from 'node:crypto'

// ─── Password hashing (scrypt, same as the server uses) ─────────────

export function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex')
  const hash = crypto.scryptSync(password, salt, 64).toString('hex')
  return `${salt}:${hash}`
}

export function verifyPassword(password, stored) {
  if (!stored) return false

  // Format 1: salt:hash (our hashPassword format)
  if (stored.includes(':') && !stored.startsWith('scrypt$')) {
    const [salt, hash] = stored.split(':')
    const test = crypto.scryptSync(password, salt, 64).toString('hex')
    return test === hash
  }

  // Format 2: scrypt$N$k$r$salt$hash (existing DB format)
  if (stored.startsWith('scrypt$')) {
    const parts = stored.split('$')
    // scrypt$16384$8$1$<salt>$<hash>
    const salt = Buffer.from(parts[4], 'hex')
    const expectedHash = Buffer.from(parts[5], 'hex')
    const keylen = expectedHash.length
    const test = crypto.scryptSync(password, salt, keylen)
    return crypto.timingSafeEqual(test, expectedHash)
  }

  // Format 3: plain text fallback (for development)
  if (password === stored) return true

  return false
}

// ─── Table creation ────────────────────────────────────────────────

function createSchooladminTables(db) {
  db.exec(`CREATE TABLE IF NOT EXISTS schools (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    location    TEXT,
    status      TEXT NOT NULL DEFAULT 'Active',
    established INTEGER,
    periods     TEXT NOT NULL DEFAULT '[]'
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS users (
    id        TEXT PRIMARY KEY,
    email     TEXT NOT NULL UNIQUE,
    password  TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role      TEXT NOT NULL,
    school_id TEXT,
    class_ids TEXT NOT NULL DEFAULT '[]',
    subjects  TEXT NOT NULL DEFAULT '[]',
    status    TEXT NOT NULL DEFAULT 'Active'
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS classes (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    program     TEXT,
    school_id   TEXT,
    room        TEXT,
    teacher_ids TEXT NOT NULL DEFAULT '[]'
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS students (
    id             TEXT PRIMARY KEY,
    name           TEXT NOT NULL,
    email          TEXT,
    password       TEXT NOT NULL DEFAULT '',
    roll_number    INTEGER,
    class_id       TEXT,
    school_id      TEXT,
    attendance_pct INTEGER NOT NULL DEFAULT 0,
    status         TEXT NOT NULL DEFAULT 'Active'
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS timetable (
    id         TEXT PRIMARY KEY,
    school_id  TEXT,
    class_id   TEXT,
    day        TEXT,
    period     INTEGER,
    teacher_id TEXT,
    subject    TEXT
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS assignments (
    id          TEXT PRIMARY KEY,
    title       TEXT NOT NULL,
    course      TEXT,
    class_id    TEXT,
    school_id   TEXT,
    due_date    TEXT,
    description TEXT,
    created_by  TEXT,
    created_at  TEXT
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS attendance_log (
    id          TEXT PRIMARY KEY,
    student_id  TEXT NOT NULL,
    class_id    TEXT,
    school_id   TEXT,
    date        TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'Present',
    recorded_by TEXT,
    course      TEXT
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS submissions (
    id            TEXT PRIMARY KEY,
    assignment_id TEXT NOT NULL,
    student_id    TEXT NOT NULL,
    file_name     TEXT,
    score         TEXT,
    feedback      TEXT,
    status        TEXT NOT NULL DEFAULT 'Submitted',
    submitted_at  TEXT
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS sessions (
    sid TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at INTEGER NOT NULL
  )`)
  db.exec(`CREATE INDEX IF NOT EXISTS idx_students_class ON students (class_id)`)
  db.exec(`CREATE INDEX IF NOT EXISTS idx_students_school ON students (school_id)`)
  db.exec(`CREATE INDEX IF NOT EXISTS idx_timetable_class ON timetable (class_id, day, period)`)
  db.exec(`CREATE INDEX IF NOT EXISTS idx_users_school ON users (school_id)`)
}

function createSuperadminTables(db) {
  db.exec(`CREATE TABLE IF NOT EXISTS schools (
    id            TEXT PRIMARY KEY,
    name          TEXT NOT NULL,
    location      TEXT,
    status        TEXT NOT NULL DEFAULT 'Active',
    established   INTEGER,
    teacher_count INTEGER NOT NULL DEFAULT 0,
    class_count   INTEGER NOT NULL DEFAULT 0,
    student_count INTEGER NOT NULL DEFAULT 0
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS users (
    id        TEXT PRIMARY KEY,
    email     TEXT NOT NULL UNIQUE,
    password  TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role      TEXT NOT NULL,
    school_id TEXT,
    status    TEXT NOT NULL DEFAULT 'Active'
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS sessions (
    sid TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at INTEGER NOT NULL
  )`)
}

// ─── School Admin seed ──────────────────────────────────────────────

const SA_SCHOOLS = []
const SA_USERS = []
const SA_CLASSES = []

function buildStudents() {
  return []
}

const SEED_TIMETABLE = []

/**
 * Seed the schooladmin database.
 * @param {object} db — DatabaseSync instance
 */
export function seedSchooladmin(db) {
  // Create tables if they don't exist (for fresh/temp databases)
  createSchooladminTables(db)

  // Check if already seeded
  if (db.prepare('SELECT COUNT(*) as n FROM users').get().n > 0) return

  const insertSchool = db.prepare('INSERT INTO schools (id, name, location, status, established, periods) VALUES (?, ?, ?, ?, ?, ?)')
  for (const s of SA_SCHOOLS) {
    insertSchool.run(s.id, s.name, s.location, s.status, s.established, s.periods)
  }

  const insertUser = db.prepare('INSERT INTO users (id, email, password, full_name, role, school_id, class_ids, subjects, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)')
  for (const u of SA_USERS) {
    insertUser.run(u.id, u.email, hashPassword('admin123'), u.full_name, u.role, u.school_id, u.class_ids, u.subjects, u.status)
  }

  const insertClass = db.prepare('INSERT INTO classes (id, name, program, school_id, room, teacher_ids) VALUES (?, ?, ?, ?, ?, ?)')
  for (const c of SA_CLASSES) {
    insertClass.run(c.id, c.name, c.program, c.school_id, c.room, c.teacher_ids)
  }

  const students = buildStudents()
  const insertStudent = db.prepare('INSERT INTO students (id, name, email, roll_number, class_id, school_id, attendance_pct, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
  for (const s of students) {
    insertStudent.run(s.id, s.name, s.email, s.roll_number, s.class_id, s.school_id, s.attendance_pct, s.status)
  }

  let ttId = 0
  const insertTt = db.prepare('INSERT INTO timetable (id, school_id, class_id, day, period, teacher_id, subject) VALUES (?, ?, ?, ?, ?, ?, ?)')
  for (const e of SEED_TIMETABLE) {
    insertTt.run(`tt-${++ttId}`, e.school_id, e.class_id, e.day, e.period, e.teacher_id, e.subject)
  }
}

// ─── Super Admin seed ───────────────────────────────────────────────

const SU_SCHOOLS = []

const SU_USERS = [
  { id: 'u-admin', email: 'admin', full_name: 'Administrator', role: 'Administrator', school_id: null, status: 'Active' },
]

/**
 * Seed the superadmin database.
 * @param {object} db — DatabaseSync instance
 */
export function seedSuperadmin(db) {
  // Create tables if they don't exist (for fresh/temp databases)
  createSuperadminTables(db)

  if (db.prepare('SELECT COUNT(*) as n FROM users').get().n > 0) return

  const insertSchool = db.prepare('INSERT INTO schools (id, name, location, status, established, teacher_count, class_count, student_count) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
  for (const s of SU_SCHOOLS) {
    insertSchool.run(s.id, s.name, s.location, s.status, s.established, s.teacher_count, s.class_count, s.student_count)
  }

  const insertUser = db.prepare('INSERT INTO users (id, email, password, full_name, role, school_id, status) VALUES (?, ?, ?, ?, ?, ?, ?)')
  for (const u of SU_USERS) {
    insertUser.run(u.id, u.email, hashPassword('ranbrosglobal'), u.full_name, u.role, u.school_id, u.status)
  }
}
