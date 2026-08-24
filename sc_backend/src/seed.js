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

const SA_SCHOOLS = [
  { id: 'springfield', name: 'Springfield Elementary', location: 'Springfield', status: 'Active', established: 1998,
    periods: JSON.stringify([
      { n: 1, time: '8:30 – 9:15' }, { n: 2, time: '9:15 – 10:00' },
      { n: 3, time: '10:00 – 10:45' }, { n: 4, time: '11:00 – 11:45' },
      { n: 5, time: '11:45 – 12:30' }, { n: 6, time: '13:00 – 13:45' },
      { n: 7, time: '13:45 – 14:30' }, { n: 8, time: '14:30 – 15:15' },
    ])
  },
  { id: 'riverside', name: 'Riverside Academy', location: 'Riverside', status: 'Active', established: 2005,
    periods: JSON.stringify([
      { n: 1, time: '8:00 – 8:45' }, { n: 2, time: '8:45 – 9:30' },
      { n: 3, time: '9:30 – 10:15' }, { n: 4, time: '10:30 – 11:15' },
      { n: 5, time: '11:15 – 12:00' }, { n: 6, time: '12:45 – 13:30' },
      { n: 7, time: '13:30 – 14:15' },
    ])
  },
  { id: 'sunrise', name: 'Sunrise International School', location: 'Sunrise City', status: 'Active', established: 2011,
    periods: JSON.stringify([
      { n: 1, time: '9:00 – 9:50' }, { n: 2, time: '9:50 – 10:40' },
      { n: 3, time: '10:40 – 11:30' }, { n: 4, time: '11:45 – 12:35' },
      { n: 5, time: '12:35 – 13:25' }, { n: 6, time: '14:00 – 14:50' },
    ])
  },
  { id: 'maple', name: 'Maple Grove Public School', location: 'Maple Hill', status: 'Disabled', established: 2001,
    periods: JSON.stringify([
      { n: 1, time: '8:30 – 9:15' }, { n: 2, time: '9:15 – 10:00' },
      { n: 3, time: '10:00 – 10:45' }, { n: 4, time: '11:00 – 11:45' },
      { n: 5, time: '11:45 – 12:30' }, { n: 6, time: '13:00 – 13:45' },
      { n: 7, time: '13:45 – 14:30' }, { n: 8, time: '14:30 – 15:15' },
    ])
  },
]

const SA_USERS = [
  { id: 'u-priya', email: 'priya@springfield.edu', full_name: 'Priya Sharma', role: 'School Admin', school_id: 'springfield', class_ids: '[]', subjects: '[]', status: 'Active' },
  { id: 'u-ravi', email: 'ravi@riverside.edu', full_name: 'Ravi Menon', role: 'School Admin', school_id: 'riverside', class_ids: '[]', subjects: '[]', status: 'Active' },
  { id: 'u-aman', email: 'aman@sunrise.edu', full_name: 'Aman Kapoor', role: 'School Admin', school_id: 'sunrise', class_ids: '[]', subjects: '[]', status: 'Active' },
  // Teachers — subjects is the list of subjects this teacher can teach
  { id: 't-anita', email: 'anita.sharma@springfield.edu', full_name: 'Anita Sharma', role: 'Teacher', school_id: 'springfield', class_ids: '["c-8a","c-8b"]', subjects: '["Mathematics"]', status: 'Active' },
  { id: 't-rajesh', email: 'rajesh.iyer@springfield.edu', full_name: 'Rajesh Iyer', role: 'Teacher', school_id: 'springfield', class_ids: '["c-8a","c-9a"]', subjects: '["Science","Mathematics"]', status: 'Active' },
  { id: 't-kavita', email: 'kavita.nair@springfield.edu', full_name: 'Kavita Nair', role: 'Teacher', school_id: 'springfield', class_ids: '["c-8a","c-8b"]', subjects: '["English"]', status: 'Active' },
  { id: 't-david', email: 'david.thomas@springfield.edu', full_name: 'David Thomas', role: 'Teacher', school_id: 'springfield', class_ids: '["c-9a"]', subjects: '["History","Geography"]', status: 'Active' },
  { id: 't-sarah', email: 'sarah.chen@riverside.edu', full_name: 'Sarah Chen', role: 'Teacher', school_id: 'riverside', class_ids: '["c-r8a","c-r9a"]', subjects: '["Mathematics"]', status: 'Active' },
  { id: 't-alex', email: 'alex.johnson@riverside.edu', full_name: 'Alex Johnson', role: 'Teacher', school_id: 'riverside', class_ids: '["c-r9a"]', subjects: '["Physics"]', status: 'Active' },
  { id: 't-meera', email: 'meera.reddy@sunrise.edu', full_name: 'Meera Reddy', role: 'Teacher', school_id: 'sunrise', class_ids: '["c-s8a"]', subjects: '["Biology","Chemistry"]', status: 'Active' },
  { id: 't-vikram', email: 'vikram.singh@sunrise.edu', full_name: 'Vikram Singh', role: 'Teacher', school_id: 'sunrise', class_ids: '["c-s8a","c-s9a"]', subjects: '["Computer Science","Mathematics"]', status: 'Active' },
]

const SA_CLASSES = [
  { id: 'c-8a', name: 'Grade 8 - A', program: 'Grade 8', school_id: 'springfield', room: 'Room 201', teacher_ids: '["t-anita","t-kavita"]' },
  { id: 'c-8b', name: 'Grade 8 - B', program: 'Grade 8', school_id: 'springfield', room: 'Room 202', teacher_ids: '["t-anita","t-kavita"]' },
  { id: 'c-9a', name: 'Grade 9 - A', program: 'Grade 9', school_id: 'springfield', room: 'Room 103', teacher_ids: '["t-rajesh","t-david"]' },
  { id: 'c-r8a', name: 'Grade 8 - A', program: 'Grade 8', school_id: 'riverside', room: 'Block A - 4', teacher_ids: '["t-sarah"]' },
  { id: 'c-r9a', name: 'Grade 9 - A', program: 'Grade 9', school_id: 'riverside', room: 'Block A - 7', teacher_ids: '["t-sarah","t-alex"]' },
  { id: 'c-s8a', name: 'Grade 8 - A', program: 'Grade 8', school_id: 'sunrise', room: 'G - 12', teacher_ids: '["t-meera","t-vikram"]' },
  { id: 'c-s9a', name: 'Grade 9 - A', program: 'Grade 9', school_id: 'sunrise', room: 'G - 15', teacher_ids: '["t-vikram"]' },
]

const FIRST = ['Aarav', 'Diya', 'Rohan', 'Ananya', 'Vivaan', 'Ishaan', 'Saanvi', 'Kabir', 'Myra', 'Arjun', 'Sneha', 'Aditya', 'Riya', 'Dev', 'Nisha', 'Kunal', 'Pooja', 'Rahul', 'Simran', 'Vikram', 'Tanvi', 'Aisha', 'Mohit', 'Neha', 'Siddharth', 'Lakshmi', 'Farhan', 'Gauri', 'Harsh', 'Ira', 'Jatin', 'Kiara', 'Liam', 'Maya', 'Nikhil', 'Om', 'Pranav', 'Qasim', 'Ritika', 'Samarth']
const LAST = ['Sharma', 'Verma', 'Patel', 'Reddy', 'Iyer', 'Gupta', 'Singh', 'Khan', 'Nair', 'Menon', 'Das', 'Bose', 'Joshi', 'Kulkarni', 'Rao', 'Chopra', 'Mehta', 'Kapoor', 'Malhotra', 'Bhatia']

const CLASS_SIZES = { 'c-8a': 22, 'c-8b': 18, 'c-9a': 15, 'c-r8a': 20, 'c-r9a': 17, 'c-s8a': 16, 'c-s9a': 19 }

function seededRandom(seed) {
  let s = seed % 2147483647
  if (s <= 0) s += 2147483646
  return () => {
    s = (s * 16807) % 2147483646
    return (s - 1) / 2147483646
  }
}

function buildStudents() {
  const students = []
  let seed = 101
  for (const cls of SA_CLASSES) {
    const rand = seededRandom(seed)
    const used = new Set()
    const count = CLASS_SIZES[cls.id] || 15
    for (let i = 1; i <= count; i++) {
      let first, last
      do {
        first = FIRST[Math.floor(rand() * FIRST.length)]
        last = LAST[Math.floor(rand() * LAST.length)]
      } while (used.has(`${first} ${last}`))
      used.add(`${first} ${last}`)
      students.push({
        id: `${cls.id}-s${i}`,
        name: `${first} ${last}`,
        email: `${first.toLowerCase()}.${last.toLowerCase()}${i}@student.edu`,
        roll_number: i,
        class_id: cls.id,
        school_id: cls.school_id,
        attendance_pct: Math.round(72 + rand() * 28),
        status: rand() > 0.15 ? 'Active' : 'Inactive',
      })
    }
    seed += 97
  }
  return students
}

const SEED_TIMETABLE = [
  { school_id: 'springfield', class_id: 'c-8a', day: 'Monday', period: 1, teacher_id: 't-anita', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Monday', period: 2, teacher_id: 't-rajesh', subject: 'Science' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Monday', period: 3, teacher_id: 't-kavita', subject: 'English' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Monday', period: 4, teacher_id: 't-anita', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Monday', period: 5, teacher_id: 't-rajesh', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Monday', period: 6, teacher_id: 't-kavita', subject: 'English' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Tuesday', period: 1, teacher_id: 't-kavita', subject: 'English' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Tuesday', period: 2, teacher_id: 't-anita', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Tuesday', period: 3, teacher_id: 't-rajesh', subject: 'Science' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Wednesday', period: 1, teacher_id: 't-rajesh', subject: 'Science' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Wednesday', period: 2, teacher_id: 't-kavita', subject: 'English' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Wednesday', period: 3, teacher_id: 't-anita', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-8b', day: 'Monday', period: 1, teacher_id: 't-kavita', subject: 'English' },
  { school_id: 'springfield', class_id: 'c-8b', day: 'Monday', period: 2, teacher_id: 't-anita', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-8b', day: 'Monday', period: 3, teacher_id: 't-anita', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-9a', day: 'Monday', period: 1, teacher_id: 't-rajesh', subject: 'Science' },
  { school_id: 'springfield', class_id: 'c-9a', day: 'Monday', period: 2, teacher_id: 't-david', subject: 'History' },
  { school_id: 'springfield', class_id: 'c-9a', day: 'Monday', period: 3, teacher_id: 't-rajesh', subject: 'Science' },
  { school_id: 'springfield', class_id: 'c-9a', day: 'Tuesday', period: 1, teacher_id: 't-david', subject: 'Geography' },
  { school_id: 'springfield', class_id: 'c-9a', day: 'Tuesday', period: 2, teacher_id: 't-rajesh', subject: 'Mathematics' },
  { school_id: 'riverside', class_id: 'c-r8a', day: 'Monday', period: 1, teacher_id: 't-sarah', subject: 'Mathematics' },
  { school_id: 'riverside', class_id: 'c-r8a', day: 'Monday', period: 2, teacher_id: 't-sarah', subject: 'Mathematics' },
  { school_id: 'riverside', class_id: 'c-r9a', day: 'Monday', period: 1, teacher_id: 't-alex', subject: 'Physics' },
  { school_id: 'riverside', class_id: 'c-r9a', day: 'Monday', period: 2, teacher_id: 't-sarah', subject: 'Mathematics' },
  { school_id: 'sunrise', class_id: 'c-s8a', day: 'Monday', period: 1, teacher_id: 't-meera', subject: 'Biology' },
  { school_id: 'sunrise', class_id: 'c-s8a', day: 'Monday', period: 2, teacher_id: 't-vikram', subject: 'Computer Science' },
]

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

const SU_SCHOOLS = [
  { id: 'springfield', name: 'Springfield Elementary', location: 'Springfield', status: 'Active', established: 1998, teacher_count: 4, class_count: 3, student_count: 55 },
  { id: 'riverside', name: 'Riverside Academy', location: 'Riverside', status: 'Active', established: 2005, teacher_count: 2, class_count: 2, student_count: 37 },
  { id: 'sunrise', name: 'Sunrise International School', location: 'Sunrise City', status: 'Active', established: 2011, teacher_count: 2, class_count: 2, student_count: 35 },
  { id: 'maple', name: 'Maple Grove Public School', location: 'Maple Hill', status: 'Disabled', established: 2001, teacher_count: 0, class_count: 0, student_count: 0 },
]

const SU_USERS = [
  { id: 'u-admin', email: 'admin@schoolconnect.app', full_name: 'Alex Morgan', role: 'Administrator', school_id: null, status: 'Active' },
  { id: 'u-priya', email: 'priya@springfield.edu', full_name: 'Priya Sharma', role: 'School Admin', school_id: 'springfield', status: 'Active' },
  { id: 'u-ravi', email: 'ravi@riverside.edu', full_name: 'Ravi Menon', role: 'School Admin', school_id: 'riverside', status: 'Active' },
  { id: 'u-aman', email: 'aman@sunrise.edu', full_name: 'Aman Kapoor', role: 'School Admin', school_id: 'sunrise', status: 'Active' },
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
    insertUser.run(u.id, u.email, hashPassword('admin123'), u.full_name, u.role, u.school_id, u.status)
  }
}
