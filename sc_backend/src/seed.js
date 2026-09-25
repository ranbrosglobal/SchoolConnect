/**
 * Seed functions for both databases.
 *
 * Each function receives a database instance and populates it with demo data
 * if the database is empty. Used by the test harness (test-release.mjs,
 * test-lockout.mjs) and by the main server for fresh databases.
 *
 * Demo accounts (matching the Flutter demo panel):
 *   School Admin:  admin@springfield.edu / admin123
 *   Teacher:       robert.johnson@school.com / Teacher@123
 *   Teacher:       emily.davis@school.com / Teacher@123
 *   Student:       alex.smith@school.com / Student@123
 *   Student:       emma.wilson@school.com / Student@123
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
    parent_name    TEXT,
    parent_phone   TEXT,
    parent_email   TEXT,
    address        TEXT,
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
    attachment_id   TEXT,
    attachment_name TEXT,
    created_by  TEXT,
    created_at  TEXT
  )`)
  db.exec(`CREATE TABLE IF NOT EXISTS file_blobs (
    id         TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    mime_type  TEXT NOT NULL DEFAULT 'application/octet-stream',
    size       INTEGER NOT NULL DEFAULT 0,
    data       TEXT NOT NULL,
    uploaded_by TEXT,
    created_at TEXT NOT NULL
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
    file_id       TEXT,
    file_name     TEXT,
    score         TEXT,
    feedback      TEXT,
    status        TEXT NOT NULL DEFAULT 'Submitted',
    submitted_at  TEXT
  )`)

  // Migrations for databases created before the attachment columns existed
  const addColumn = (table, column, type) => {
    try { db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${type}`) } catch (_e) { /* already exists */ }
  }
  addColumn('assignments', 'attachment_id', 'TEXT')
  addColumn('assignments', 'attachment_name', 'TEXT')
  addColumn('submissions', 'file_id', 'TEXT')
  addColumn('students', 'parent_name', 'TEXT')
  addColumn('students', 'parent_phone', 'TEXT')
  addColumn('students', 'parent_email', 'TEXT')
  addColumn('students', 'address', 'TEXT')
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

/** Store a base64 file in the file_blobs table. */
export function storeFileBlob(db, { name, mimeType, data, uploadedBy }) {
  const id = genFileId()
  const size = Math.floor(data.length * 3 / 4)
  db.prepare('INSERT INTO file_blobs (id, name, mime_type, size, data, uploaded_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(id, name || 'file', mimeType || 'application/octet-stream', size, data, uploadedBy || '', new Date().toISOString())
  return id
}

export function genFileId() {
  return `file-${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`
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

// ─── School Admin seed data ────────────────────────────────────────

const SA_SCHOOLS = [
  { id: 'springfield', name: 'Springfield High School', location: 'Springfield', status: 'Active', established: 2020, periods: JSON.stringify([
    { n: 1, time: '8:00 – 8:45' }, { n: 2, time: '8:45 – 9:30' },
    { n: 3, time: '9:30 – 10:15' }, { n: 4, time: '10:30 – 11:15' },
    { n: 5, time: '11:15 – 12:00' }, { n: 6, time: '12:45 – 13:30' },
    { n: 7, time: '13:30 – 14:15' },
  ]) },
]

const SA_USERS = [
  { id: 'u-admin', email: 'admin@springfield.edu', password: 'admin123', full_name: 'School Administrator', role: 'School Admin', school_id: 'springfield', class_ids: '[]', subjects: '[]', status: 'Active' },
  { id: 't-robert', email: 'robert.johnson@school.com', password: 'Teacher@123', full_name: 'Robert Johnson', role: 'Teacher', school_id: 'springfield', class_ids: JSON.stringify(['c-8a', 'c-8b']), subjects: JSON.stringify(['Mathematics', 'Science']), status: 'Active' },
  { id: 't-emily', email: 'emily.davis@school.com', password: 'Teacher@123', full_name: 'Emily Davis', role: 'Teacher', school_id: 'springfield', class_ids: JSON.stringify(['c-8a', 'c-9a']), subjects: JSON.stringify(['English', 'History']), status: 'Active' },
]

const SA_CLASSES = [
  { id: 'c-8a', name: 'Grade 8 - A', program: 'Grade 8', school_id: 'springfield', room: 'Room 201', teacher_ids: JSON.stringify(['t-robert', 't-emily']) },
  { id: 'c-8b', name: 'Grade 8 - B', program: 'Grade 8', school_id: 'springfield', room: 'Room 202', teacher_ids: JSON.stringify(['t-robert']) },
  { id: 'c-9a', name: 'Grade 9 - A', program: 'Grade 9', school_id: 'springfield', room: 'Room 103', teacher_ids: JSON.stringify(['t-emily']) },
]

function buildStudents() {
  return [
    // Grade 8-A
    { id: 'stu-001', name: 'Alex Smith', email: 'alex.smith@school.com', password: 'Student@123', roll_number: 1, class_id: 'c-8a', school_id: 'springfield', attendance_pct: 92, status: 'Active', parent_name: 'John Smith', parent_phone: '555-0101', parent_email: 'john.smith@email.com', address: '12 Oak Street' },
    { id: 'stu-002', name: 'Emma Wilson', email: 'emma.wilson@school.com', password: 'Student@123', roll_number: 2, class_id: 'c-8a', school_id: 'springfield', attendance_pct: 88, status: 'Active', parent_name: 'David Wilson', parent_phone: '555-0102', parent_email: 'david.wilson@email.com', address: '34 Maple Avenue' },
    { id: 'stu-003', name: 'Michael Brown', email: 'michael.brown@school.com', password: 'Student@123', roll_number: 3, class_id: 'c-8a', school_id: 'springfield', attendance_pct: 76, status: 'Active', parent_name: 'Sarah Brown', parent_phone: '555-0103', parent_email: 'sarah.brown@email.com', address: '56 Pine Road' },
    { id: 'stu-004', name: 'Sophia Taylor', email: 'sophia.taylor@school.com', password: 'Student@123', roll_number: 4, class_id: 'c-8a', school_id: 'springfield', attendance_pct: 95, status: 'Active', parent_name: 'Robert Taylor', parent_phone: '555-0104', parent_email: 'robert.taylor@email.com', address: '78 Elm Drive' },
    { id: 'stu-005', name: 'Aisha Patel', email: 'aisha.patel@school.com', password: 'Student@123', roll_number: 5, class_id: 'c-8a', school_id: 'springfield', attendance_pct: 84, status: 'Active', parent_name: 'Raj Patel', parent_phone: '555-0105', parent_email: 'raj.patel@email.com', address: '90 Cedar Lane' },
    { id: 'stu-006', name: 'Daniel Kim', email: 'daniel.kim@school.com', password: 'Student@123', roll_number: 6, class_id: 'c-8a', school_id: 'springfield', attendance_pct: 71, status: 'Active', parent_name: 'Min Kim', parent_phone: '555-0106', parent_email: 'min.kim@email.com', address: '23 Birch Street' },
    // Grade 8-B
    { id: 'stu-007', name: 'James Miller', email: 'james.miller@school.com', password: 'Student@123', roll_number: 1, class_id: 'c-8b', school_id: 'springfield', attendance_pct: 89, status: 'Active', parent_name: 'Linda Miller', parent_phone: '555-0107', parent_email: 'linda.miller@email.com', address: '45 Walnut Avenue' },
    { id: 'stu-008', name: 'Jessica Davis', email: 'jessica.davis@school.com', password: 'Student@123', roll_number: 2, class_id: 'c-8b', school_id: 'springfield', attendance_pct: 93, status: 'Active', parent_name: 'Mark Davis', parent_phone: '555-0108', parent_email: 'mark.davis@email.com', address: '67 Ash Road' },
    { id: 'stu-009', name: 'Ryan Garcia', email: 'ryan.garcia@school.com', password: 'Student@123', roll_number: 3, class_id: 'c-8b', school_id: 'springfield', attendance_pct: 82, status: 'Active', parent_name: 'Maria Garcia', parent_phone: '555-0109', parent_email: 'maria.garcia@email.com', address: '89 Spruce Drive' },
    { id: 'stu-010', name: 'Priya Sharma', email: 'priya.sharma@school.com', password: 'Student@123', roll_number: 4, class_id: 'c-8b', school_id: 'springfield', attendance_pct: 97, status: 'Active', parent_name: 'Vikram Sharma', parent_phone: '555-0110', parent_email: 'vikram.sharma@email.com', address: '12 Willow Lane' },
    // Grade 9-A
    { id: 'stu-011', name: 'Thomas Gonzalez', email: 'thomas.gonzalez@school.com', password: 'Student@123', roll_number: 1, class_id: 'c-9a', school_id: 'springfield', attendance_pct: 85, status: 'Active', parent_name: 'Carlos Gonzalez', parent_phone: '555-0111', parent_email: 'carlos.gonzalez@email.com', address: '34 Redwood Street' },
    { id: 'stu-012', name: 'Barbara Lee', email: 'barbara.lee@school.com', password: 'Student@123', roll_number: 2, class_id: 'c-9a', school_id: 'springfield', attendance_pct: 91, status: 'Active', parent_name: 'Steven Lee', parent_phone: '555-0112', parent_email: 'steven.lee@email.com', address: '56 Cypress Avenue' },
    { id: 'stu-013', name: 'Kevin Nguyen', email: 'kevin.nguyen@school.com', password: 'Student@123', roll_number: 3, class_id: 'c-9a', school_id: 'springfield', attendance_pct: 78, status: 'Active', parent_name: 'Linh Nguyen', parent_phone: '555-0113', parent_email: 'linh.nguyen@email.com', address: '78 Magnolia Road' },
    { id: 'stu-014', name: 'Olivia Chen', email: 'olivia.chen@school.com', password: 'Student@123', roll_number: 4, class_id: 'c-9a', school_id: 'springfield', attendance_pct: 94, status: 'Active', parent_name: 'Wei Chen', parent_phone: '555-0114', parent_email: 'wei.chen@email.com', address: '90 Poplar Drive' },
    { id: 'stu-015', name: 'Marcus Johnson', email: 'marcus.johnson@school.com', password: 'Student@123', roll_number: 5, class_id: 'c-9a', school_id: 'springfield', attendance_pct: 67, status: 'Active', parent_name: 'Angela Johnson', parent_phone: '555-0115', parent_email: 'angela.johnson@email.com', address: '23 Dogwood Lane' },
  ]
}

const SEED_TIMETABLE = [
  // Grade 8-A - Monday
  { school_id: 'springfield', class_id: 'c-8a', day: 'Monday', period: 1, teacher_id: 't-robert', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Monday', period: 2, teacher_id: 't-robert', subject: 'Science' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Monday', period: 3, teacher_id: 't-emily', subject: 'English' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Monday', period: 4, teacher_id: 't-emily', subject: 'History' },
  // Grade 8-A - Tuesday
  { school_id: 'springfield', class_id: 'c-8a', day: 'Tuesday', period: 1, teacher_id: 't-emily', subject: 'English' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Tuesday', period: 2, teacher_id: 't-robert', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Tuesday', period: 3, teacher_id: 't-robert', subject: 'Science' },
  // Grade 8-A - Wednesday
  { school_id: 'springfield', class_id: 'c-8a', day: 'Wednesday', period: 1, teacher_id: 't-robert', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Wednesday', period: 2, teacher_id: 't-emily', subject: 'English' },
  // Grade 8-A - Thursday
  { school_id: 'springfield', class_id: 'c-8a', day: 'Thursday', period: 1, teacher_id: 't-robert', subject: 'Science' },
  { school_id: 'springfield', class_id: 'c-8a', day: 'Thursday', period: 2, teacher_id: 't-robert', subject: 'Mathematics' },
  // Grade 8-B - Monday
  { school_id: 'springfield', class_id: 'c-8b', day: 'Monday', period: 5, teacher_id: 't-robert', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-8b', day: 'Monday', period: 6, teacher_id: 't-robert', subject: 'Science' },
  // Grade 8-B - Tuesday
  { school_id: 'springfield', class_id: 'c-8b', day: 'Tuesday', period: 5, teacher_id: 't-robert', subject: 'Mathematics' },
  // Grade 9-A - Monday
  { school_id: 'springfield', class_id: 'c-9a', day: 'Monday', period: 1, teacher_id: 't-emily', subject: 'English' },
  { school_id: 'springfield', class_id: 'c-9a', day: 'Monday', period: 2, teacher_id: 't-emily', subject: 'History' },
  // Grade 9-A - Wednesday
  { school_id: 'springfield', class_id: 'c-9a', day: 'Wednesday', period: 1, teacher_id: 't-emily', subject: 'English' },
  // Grade 9-A - Friday
  { school_id: 'springfield', class_id: 'c-9a', day: 'Friday', period: 1, teacher_id: 't-emily', subject: 'History' },
]

function today() { return new Date().toISOString().split('T')[0] }
function daysFromNow(n) { const d = new Date(); d.setDate(d.getDate() + n); return d.toISOString().split('T')[0] }

const SEED_ASSIGNMENTS = [
  { id: 'asgn-001', title: 'Algebra Practice Set', course: 'Mathematics', class_id: 'c-8a', school_id: 'springfield', due_date: daysFromNow(7), description: 'Complete problems 1-20 from Chapter 3. Show all your work.', attachment_id: null, attachment_name: null, created_by: 't-robert', created_at: today() },
  { id: 'asgn-002', title: 'Science Lab Report', course: 'Science', class_id: 'c-8a', school_id: 'springfield', due_date: daysFromNow(5), description: 'Write a lab report on the photosynthesis experiment conducted in class.', attachment_id: null, attachment_name: null, created_by: 't-robert', created_at: today() },
  { id: 'asgn-003', title: 'Essay: My Favorite Book', course: 'English', class_id: 'c-8a', school_id: 'springfield', due_date: daysFromNow(10), description: 'Write a 500-word essay about your favorite book. Include why you enjoyed it.', attachment_id: null, attachment_name: null, created_by: 't-emily', created_at: today() },
  { id: 'asgn-004', title: 'World War II Timeline', course: 'History', class_id: 'c-9a', school_id: 'springfield', due_date: daysFromNow(14), description: 'Create a timeline of major events in World War II from 1939 to 1945.', attachment_id: null, attachment_name: null, created_by: 't-emily', created_at: today() },
  { id: 'asgn-005', title: 'Geometry Quiz Prep', course: 'Mathematics', class_id: 'c-8b', school_id: 'springfield', due_date: daysFromNow(3), description: 'Complete the practice quiz on angles and triangles.', attachment_id: null, attachment_name: null, created_by: 't-robert', created_at: today() },
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

  console.log('[seed] Seeding schooladmin database with demo data...')

  // Insert school
  const insertSchool = db.prepare('INSERT INTO schools (id, name, location, status, established, periods) VALUES (?, ?, ?, ?, ?, ?)')
  for (const s of SA_SCHOOLS) {
    insertSchool.run(s.id, s.name, s.location, s.status, s.established, s.periods)
  }

  // Insert users (teachers + admin) with per-user passwords
  const insertUser = db.prepare('INSERT INTO users (id, email, password, full_name, role, school_id, class_ids, subjects, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)')
  for (const u of SA_USERS) {
    insertUser.run(u.id, u.email, hashPassword(u.password), u.full_name, u.role, u.school_id, u.class_ids, u.subjects, u.status)
  }

  // Insert classes
  const insertClass = db.prepare('INSERT INTO classes (id, name, program, school_id, room, teacher_ids) VALUES (?, ?, ?, ?, ?, ?)')
  for (const c of SA_CLASSES) {
    insertClass.run(c.id, c.name, c.program, c.school_id, c.room, c.teacher_ids)
  }

  // Insert students with passwords
  const students = buildStudents()
  const insertStudent = db.prepare('INSERT INTO students (id, name, email, password, roll_number, class_id, school_id, parent_name, parent_phone, parent_email, address, attendance_pct, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
  for (const s of students) {
    insertStudent.run(s.id, s.name, s.email, hashPassword(s.password), s.roll_number, s.class_id, s.school_id, s.parent_name, s.parent_phone, s.parent_email, s.address, s.attendance_pct, s.status)
  }

  // Insert timetable
  let ttId = 0
  const insertTt = db.prepare('INSERT INTO timetable (id, school_id, class_id, day, period, teacher_id, subject) VALUES (?, ?, ?, ?, ?, ?, ?)')
  for (const e of SEED_TIMETABLE) {
    insertTt.run(`tt-${++ttId}`, e.school_id, e.class_id, e.day, e.period, e.teacher_id, e.subject)
  }

  // Insert assignments
  const insertAssignment = db.prepare('INSERT INTO assignments (id, title, course, class_id, school_id, due_date, description, attachment_id, attachment_name, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
  for (const a of SEED_ASSIGNMENTS) {
    insertAssignment.run(a.id, a.title, a.course, a.class_id, a.school_id, a.due_date, a.description, a.attachment_id, a.attachment_name, a.created_by, a.created_at)
  }

  // Generate attendance records for the last 15 school days
  const insertAttendance = db.prepare('INSERT INTO attendance_log (id, student_id, class_id, school_id, date, status, recorded_by, course) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
  let attId = 0
  let attDate = new Date()
  let schoolDays = 0
  while (schoolDays < 15) {
    if (attDate.getDay() !== 0 && attDate.getDay() !== 6) {
      const dateStr = attDate.toISOString().split('T')[0]
      for (const s of students) {
        const rand = Math.random()
        const status = rand < 0.82 ? 'Present' : (rand < 0.92 ? 'Absent' : 'Late')
        insertAttendance.run(`att-${++attId}`, s.id, s.class_id, s.school_id, dateStr, status, 't-robert', 'General')
      }
      schoolDays++
    }
    attDate.setDate(attDate.getDate() - 1)
  }

  console.log(`[seed] Created: ${SA_USERS.length} users, ${SA_CLASSES.length} classes, ${students.length} students, ${SEED_TIMETABLE.length} timetable entries, ${SEED_ASSIGNMENTS.length} assignments, ${attId} attendance records`)
}

// ─── Super Admin seed ──────────────────────────────────────────────

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
