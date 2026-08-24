/*
 * In-browser mock backend.
 *
 * Mirrors the shape and endpoints of the real Frappe API
 * (school_connect.api.*) so the app can be developed with zero server.
 * Flip the app to the real backend with VITE_APP_MODE=live — see lib/api.js.
 */

import { DAYS, DEFAULT_PERIODS } from './timetable'
import { DB_KEY, LEGACY_DB_KEY, LEGACY_SESSION_KEY, LEGACY_CSRF_KEY, SESSION_KEY } from './keys'

const SCHOOLS = [
  // Periods are per-school: each school runs its own schedule (times + count).
  { id: 'springfield', name: 'Springfield Elementary', location: 'Springfield', status: 'Active', established: 1998, periods: [...DEFAULT_PERIODS] },
  {
    id: 'riverside',
    name: 'Riverside Academy',
    location: 'Riverside',
    status: 'Active',
    established: 2005,
    periods: [
      { n: 1, time: '8:00 – 8:45' },
      { n: 2, time: '8:45 – 9:30' },
      { n: 3, time: '9:30 – 10:15' },
      { n: 4, time: '10:30 – 11:15' },
      { n: 5, time: '11:15 – 12:00' },
      { n: 6, time: '12:45 – 13:30' },
      { n: 7, time: '13:30 – 14:15' },
    ],
  },
  {
    id: 'sunrise',
    name: 'Sunrise International School',
    location: 'Sunrise City',
    status: 'Active',
    established: 2011,
    periods: [
      { n: 1, time: '9:00 – 9:50' },
      { n: 2, time: '9:50 – 10:40' },
      { n: 3, time: '10:40 – 11:30' },
      { n: 4, time: '11:45 – 12:35' },
      { n: 5, time: '12:35 – 13:25' },
      { n: 6, time: '14:00 – 14:50' },
    ],
  },
  { id: 'maple', name: 'Maple Grove Public School', location: 'Maple Hill', status: 'Disabled', established: 2001, periods: [...DEFAULT_PERIODS] },
]

// School Admin accounts only — super admins sign in from the separate
// Super Admin console, which has its own database.
const USERS = [
  { id: 'u-priya', email: 'priya@springfield.edu', password: 'admin123', full_name: 'Priya Sharma', role: 'School Admin', school_id: 'springfield', class_ids: [], status: 'Active' },
  { id: 'u-ravi', email: 'ravi@riverside.edu', password: 'admin123', full_name: 'Ravi Menon', role: 'School Admin', school_id: 'riverside', class_ids: [], status: 'Active' },
  { id: 'u-aman', email: 'aman@sunrise.edu', password: 'admin123', full_name: 'Aman Kapoor', role: 'School Admin', school_id: 'sunrise', class_ids: [], status: 'Active' },
  // Teachers — subjects is the list of subjects this teacher can teach.
  { id: 't-anita', email: 'anita.sharma@springfield.edu', password: 'teacher123', full_name: 'Anita Sharma', role: 'Teacher', school_id: 'springfield', class_ids: ['c-8a', 'c-8b'], subjects: ['Mathematics'], status: 'Active' },
  { id: 't-rajesh', email: 'rajesh.iyer@springfield.edu', password: 'teacher123', full_name: 'Rajesh Iyer', role: 'Teacher', school_id: 'springfield', class_ids: ['c-8a', 'c-9a'], subjects: ['Science', 'Mathematics'], status: 'Active' },
  { id: 't-kavita', email: 'kavita.nair@springfield.edu', password: 'teacher123', full_name: 'Kavita Nair', role: 'Teacher', school_id: 'springfield', class_ids: ['c-8a', 'c-8b'], subjects: ['English'], status: 'Active' },
  { id: 't-david', email: 'david.thomas@springfield.edu', password: 'teacher123', full_name: 'David Thomas', role: 'Teacher', school_id: 'springfield', class_ids: ['c-9a'], subjects: ['History', 'Geography'], status: 'Active' },
  { id: 't-sarah', email: 'sarah.chen@riverside.edu', password: 'teacher123', full_name: 'Sarah Chen', role: 'Teacher', school_id: 'riverside', class_ids: ['c-r8a', 'c-r9a'], subjects: ['Mathematics'], status: 'Active' },
  { id: 't-alex', email: 'alex.johnson@riverside.edu', password: 'teacher123', full_name: 'Alex Johnson', role: 'Teacher', school_id: 'riverside', class_ids: ['c-r9a'], subjects: ['Physics'], status: 'Active' },
  { id: 't-meera', email: 'meera.reddy@sunrise.edu', password: 'teacher123', full_name: 'Meera Reddy', role: 'Teacher', school_id: 'sunrise', class_ids: ['c-s8a'], subjects: ['Biology', 'Chemistry'], status: 'Active' },
  { id: 't-vikram', email: 'vikram.singh@sunrise.edu', password: 'teacher123', full_name: 'Vikram Singh', role: 'Teacher', school_id: 'sunrise', class_ids: ['c-s8a', 'c-s9a'], subjects: ['Computer Science', 'Mathematics'], status: 'Active' },
]

const CLASSES = [
  { id: 'c-8a', name: 'Grade 8 - A', program: 'Grade 8', school_id: 'springfield', room: 'Room 201', teacher_ids: ['t-anita', 't-kavita'] },
  { id: 'c-8b', name: 'Grade 8 - B', program: 'Grade 8', school_id: 'springfield', room: 'Room 202', teacher_ids: ['t-anita', 't-kavita'] },
  { id: 'c-9a', name: 'Grade 9 - A', program: 'Grade 9', school_id: 'springfield', room: 'Room 103', teacher_ids: ['t-rajesh', 't-david'] },
  { id: 'c-r8a', name: 'Grade 8 - A', program: 'Grade 8', school_id: 'riverside', room: 'Block A - 4', teacher_ids: ['t-sarah'] },
  { id: 'c-r9a', name: 'Grade 9 - A', program: 'Grade 9', school_id: 'riverside', room: 'Block A - 7', teacher_ids: ['t-sarah', 't-alex'] },
  { id: 'c-s8a', name: 'Grade 8 - A', program: 'Grade 8', school_id: 'sunrise', room: 'G - 12', teacher_ids: ['t-meera', 't-vikram'] },
  { id: 'c-s9a', name: 'Grade 9 - A', program: 'Grade 9', school_id: 'sunrise', room: 'G - 15', teacher_ids: ['t-vikram'] },
]

// Weekly timetable: which teacher takes which class, per day and period.
// Entries keep only references; subject + teacher name are derived at read time
// Every entry pins the subject at scheduling time: a teacher can teach
// multiple subjects, and editing a teacher's subject later doesn't rewrite
// past schedule entries.
// Period bounds come from the school's own period list — see periodsFor().

// Seeded example entries — conflict-free (no teacher double-booked in the
// same day + period).
const SEED_TIMETABLE = [
  // Springfield Elementary — Grade 8 - A
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
  // Springfield Elementary — Grade 8 - B
  { school_id: 'springfield', class_id: 'c-8b', day: 'Monday', period: 1, teacher_id: 't-kavita', subject: 'English' },
  { school_id: 'springfield', class_id: 'c-8b', day: 'Monday', period: 2, teacher_id: 't-anita', subject: 'Mathematics' },
  { school_id: 'springfield', class_id: 'c-8b', day: 'Monday', period: 3, teacher_id: 't-anita', subject: 'Mathematics' },
  // Springfield Elementary — Grade 9 - A
  { school_id: 'springfield', class_id: 'c-9a', day: 'Monday', period: 1, teacher_id: 't-rajesh', subject: 'Science' },
  { school_id: 'springfield', class_id: 'c-9a', day: 'Monday', period: 2, teacher_id: 't-david', subject: 'History' },
  { school_id: 'springfield', class_id: 'c-9a', day: 'Monday', period: 3, teacher_id: 't-rajesh', subject: 'Science' },
  { school_id: 'springfield', class_id: 'c-9a', day: 'Tuesday', period: 1, teacher_id: 't-david', subject: 'Geography' },
  { school_id: 'springfield', class_id: 'c-9a', day: 'Tuesday', period: 2, teacher_id: 't-rajesh', subject: 'Mathematics' },
  // Riverside Academy
  { school_id: 'riverside', class_id: 'c-r8a', day: 'Monday', period: 1, teacher_id: 't-sarah', subject: 'Mathematics' },
  { school_id: 'riverside', class_id: 'c-r8a', day: 'Monday', period: 2, teacher_id: 't-sarah', subject: 'Mathematics' },
  { school_id: 'riverside', class_id: 'c-r9a', day: 'Monday', period: 1, teacher_id: 't-alex', subject: 'Physics' },
  { school_id: 'riverside', class_id: 'c-r9a', day: 'Monday', period: 2, teacher_id: 't-sarah', subject: 'Mathematics' },
  // Sunrise International School
  { school_id: 'sunrise', class_id: 'c-s8a', day: 'Monday', period: 1, teacher_id: 't-meera', subject: 'Biology' },
  { school_id: 'sunrise', class_id: 'c-s8a', day: 'Monday', period: 2, teacher_id: 't-vikram', subject: 'Computer Science' },
]

const FIRST = ['Aarav', 'Diya', 'Rohan', 'Ananya', 'Vivaan', 'Ishaan', 'Saanvi', 'Kabir', 'Myra', 'Arjun', 'Sneha', 'Aditya', 'Riya', 'Dev', 'Nisha', 'Kunal', 'Pooja', 'Rahul', 'Simran', 'Vikram', 'Tanvi', 'Aisha', 'Mohit', 'Neha', 'Siddharth', 'Lakshmi', 'Farhan', 'Gauri', 'Harsh', 'Ira', 'Jatin', 'Kiara', 'Liam', 'Maya', 'Nikhil', 'Om', 'Pranav', 'Qasim', 'Ritika', 'Samarth']
const LAST = ['Sharma', 'Verma', 'Patel', 'Reddy', 'Iyer', 'Gupta', 'Singh', 'Khan', 'Nair', 'Menon', 'Das', 'Bose', 'Joshi', 'Kulkarni', 'Rao', 'Chopra', 'Mehta', 'Kapoor', 'Malhotra', 'Bhatia']

// Deterministic pseudo-random so data is stable across reloads.
function seededRandom(seed) {
  let s = seed % 2147483647
  if (s <= 0) s += 2147483646
  return () => {
    s = (s * 16807) % 2147483647
    return (s - 1) / 2147483646
  }
}

function buildStudents(classId, schoolId, count, seed) {
  const rand = seededRandom(seed)
  const used = new Set()
  const students = []
  for (let i = 1; i <= count; i++) {
    let first, last, full
    do {
      first = FIRST[Math.floor(rand() * FIRST.length)]
      last = LAST[Math.floor(rand() * LAST.length)]
      full = `${first} ${last}`
    } while (used.has(full))
    used.add(full)
    students.push({
      id: `${classId}-s${i}`,
      name: full,
      email: `${first.toLowerCase()}.${last.toLowerCase()}${i}@student.edu`,
      roll_number: i,
      class_id: classId,
      school_id: schoolId,
      attendance_pct: Math.round(72 + rand() * 28),
      status: rand() > 0.15 ? 'Active' : 'Inactive',
    })
  }
  return students
}

const CLASS_SIZES = { 'c-8a': 22, 'c-8b': 18, 'c-9a': 15, 'c-r8a': 20, 'c-r9a': 17, 'c-s8a': 16, 'c-s9a': 19 }

// Every timetable entry needs an id (seeded ones predate the id) and a subject
// (entries stored before subjects existed). subjectFor resolves the fallback
// from the teacher's record for legacy rows.
function normalizeTimetable(rows, subjectFor) {
  let n = 0
  return (rows || []).map((e) => ({
    ...e,
    id: e.id || `tt-${e.school_id}-${e.class_id}-${e.day}-${e.period}-${++n}`,
    subject: e.subject || subjectFor?.(e.teacher_id)?.[0] || 'General',
  }))
}

// Bring older stored DBs up to the current shape:
//   schools:   gain a per-school periods list
//   users:     subject (string)  -> subjects (array)
//   timetable: entries gain a subject (backfilled from the teacher)
function migrateDb(parsed) {
  const schools = (parsed.schools || []).map((s) => ({
    ...s,
    periods: Array.isArray(s.periods) ? s.periods : [...DEFAULT_PERIODS],
  }))
  const users = (parsed.users || []).map((u) => {
    if (u.role !== 'Teacher') return u
    if (Array.isArray(u.subjects) && u.subjects.length > 0) return u
    return { ...u, subjects: u.subject ? [u.subject] : ['General'] }
  })
  const byId = new Map(users.map((u) => [u.id, u]))
  const timetable = normalizeTimetable(parsed.timetable, (tid) => byId.get(tid)?.subjects)
  return { ...parsed, schools, users, timetable }
}

function buildFreshDb() {
  let students = []
  let seed = 101
  for (const cls of CLASSES) {
    students = students.concat(buildStudents(cls.id, cls.school_id, CLASS_SIZES[cls.id], seed))
    seed += 97
  }
  return {
    schools: SCHOOLS.map((s) => ({ ...s, periods: [...(s.periods || DEFAULT_PERIODS)] })),
    users: [...USERS],
    classes: [...CLASSES],
    students,
    timetable: normalizeTimetable(SEED_TIMETABLE),
  }
}

// Persist the mock DB in localStorage so mutations survive page reloads,
// mirroring how a real backend keeps state between sessions.
function loadDb() {
  try {
    // Drop leftover shared-namespace keys from older builds (see keys.js). The
    // session and CSRF token are deliberately not adopted — the user signs in
    // again after the console split.
    localStorage.removeItem(LEGACY_SESSION_KEY)
    localStorage.removeItem(LEGACY_CSRF_KEY)
    // One-time migration: older builds stored this DB under a key shared with
    // the Super Admin console. Adopt it into our own key and drop the shared one.
    let raw = localStorage.getItem(DB_KEY)
    let migrated = false
    if (!raw) {
      raw = localStorage.getItem(LEGACY_DB_KEY)
      migrated = !!raw
    }
    if (raw) {
      const parsed = JSON.parse(raw)
      if (parsed && Array.isArray(parsed.schools) && parsed.schools.length > 0) {
        if (migrated) localStorage.setItem(DB_KEY, raw)
        localStorage.removeItem(LEGACY_DB_KEY)
        // migrate older stored DBs: teachers gained a subjects list, and
        // timetable entries gained a pinned subject
        return migrateDb(parsed)
      }
    }
  } catch {
    /* fall through to a fresh seed */
  }
  return buildFreshDb()
}
const DB = loadDb()

function persist() {
  try {
    localStorage.setItem(DB_KEY, JSON.stringify(DB))
  } catch {
    /* storage unavailable — in-memory only */
  }
}

/* ---------- helpers ---------- */

// The signed-in user from the persisted auth session (see lib/keys.js).
function currentUser() {
  try {
    const raw = localStorage.getItem(SESSION_KEY)
    if (!raw) return null
    const session = JSON.parse(raw)
    return DB.users.find((u) => u.email === session.email) || null
  } catch {
    return null
  }
}

function bySchool(rows, schoolId) {
  return schoolId ? rows.filter((r) => r.school_id === schoolId) : rows
}

// A school's configured periods, or the default schedule when unset.
function periodsFor(schoolId) {
  const school = DB.schools.find((s) => s.id === schoolId)
  return school?.periods?.length ? school.periods : DEFAULT_PERIODS
}

function teacherNames(ids) {
  return DB.users.filter((u) => ids.includes(u.id)).map((u) => u.full_name)
}

function withSchoolName(row) {
  const school = DB.schools.find((s) => s.id === row.school_id)
  return { ...row, school_name: school?.name || null }
}

function publicUser(u) {
  return {
    name: u.id,
    email: u.email,
    full_name: u.full_name,
    role: u.role,
    roles: [u.role],
    school: u.school_id,
    school_name: u.school_id ? DB.schools.find((s) => s.id === u.school_id)?.name : null,
  }
}

// The console is School Admin only — the overview is always scoped to the
// signed-in admin's own school.
function overview(scopeSchool) {
  const classes = bySchool(DB.classes, scopeSchool)
  const students = bySchool(DB.students, scopeSchool)
  const teachers = DB.users.filter((u) => u.role === 'Teacher' && u.school_id === scopeSchool)
  const recentClasses = classes.slice(0, 4).map((c) => ({
    id: c.id,
    name: c.name,
    program: c.program,
    room: c.room,
    school_name: withSchoolName(c).school_name,
    student_count: students.filter((s) => s.class_id === c.id).length,
    teachers: teacherNames(c.teacher_ids),
  }))
  return {
    school_count: 1,
    school_admin_count: DB.users.filter((u) => u.role === 'School Admin' && u.school_id === scopeSchool).length,
    teacher_count: teachers.length,
    class_count: classes.length,
    student_count: students.length,
    attendance_avg: students.length
      ? Math.round(students.reduce((a, s) => a + s.attendance_pct, 0) / students.length)
      : 0,
    recent_classes: recentClasses,
  }
}

/* ---------- handlers ---------- */

const HANDLERS = {
  'school_connect.api.auth.login': (body) => {
    const user = DB.users.find((u) => u.email === body.usr && u.password === body.pwd)
    if (!user) {
      throw { status: 401, message: 'Invalid email or password' }
    }
    if (user.role !== 'School Admin') {
      throw { status: 403, message: 'Access denied. This console is for School Admins only.' }
    }
    if (user.status === 'Inactive') {
      throw { status: 403, message: 'This account is disabled. Contact your super admin.' }
    }
    const school = DB.schools.find((s) => s.id === user.school_id)
    if (school && school.status === 'Disabled') {
      throw { status: 403, message: 'This school is disabled. Contact your super admin.' }
    }
    return { token: `mock-${user.id}-${Date.now()}`, ...publicUser(user) }
  },

  'school_connect.api.auth.logout': () => ({ message: 'Logged out' }),

  'school_connect.api.auth.get_session': () => ({ message: 'Not logged in', isLoggedIn: false }),

  // The current session user, mirroring Frappe's cookie-authenticated session.
  'school_connect.api.auth.update_profile': (body) => {
    const current = currentUser()
    const name = body.full_name?.trim()
    if (!name || name.length < 2) throw { status: 400, message: 'Name must be at least 2 characters long' }
    current.full_name = name
    persist()
    return publicUser(current)
  },

  'school_connect.api.auth.change_password': (body) => {
    const current = currentUser()
    if (!current) throw { status: 401, message: 'Not signed in' }
    if (body.current_password !== current.password) {
      throw { status: 400, message: 'Current password is incorrect' }
    }
    if (!body.new_password || body.new_password.length < 6) {
      throw { status: 400, message: 'New password must be at least 6 characters long' }
    }
    if (body.new_password === body.current_password) {
      throw { status: 400, message: 'New password must be different from the current password' }
    }
    current.password = body.new_password
    persist()
    return { message: 'Password updated successfully' }
  },

  'school_connect.api.admin.get_admin_dashboard': (params) => ({ data: overview(params.school) }),

  'school_connect.api.admin.get_admin_teachers': (params) => ({
    data: DB.users
      .filter((u) => u.role === 'Teacher')
      .filter((u) => !params.school || u.school_id === params.school)
      .map((u) => ({
        id: u.id,
        name: u.full_name,
        email: u.email,
        subjects: Array.isArray(u.subjects) ? u.subjects : [u.subject || 'General'],
        subject: (Array.isArray(u.subjects) && u.subjects[0]) || u.subject || 'General',
        school_id: u.school_id,
        school_name: DB.schools.find((s) => s.id === u.school_id)?.name,
        classes: u.class_ids.map((cid) => DB.classes.find((c) => c.id === cid)).filter(Boolean).map((c) => c.name),
        class_ids: u.class_ids,
        status: u.status || 'Active',
      })),
  }),

  'school_connect.api.admin.create_teacher': (body) => {
    const name = body.name?.trim()
    const email = body.email?.trim().toLowerCase()
    if (!name) throw { status: 400, message: 'Name is required' }
    if (!email) throw { status: 400, message: 'Email is required' }
    if (!body.password) throw { status: 400, message: 'Password is required' }
    if (DB.users.some((u) => u.email === email)) throw { status: 400, message: 'An account with this email already exists' }
    const schoolId = body.school || (DB.schools[0] && DB.schools[0].id)
    if (!DB.schools.some((s) => s.id === schoolId)) throw { status: 400, message: 'Unknown school' }
    const classIds = (body.class_ids || []).filter((cid) => DB.classes.some((c) => c.id === cid && c.school_id === schoolId))
    const user = {
      id: `t-${Date.now().toString(36)}`,
      email,
      password: body.password,
      full_name: name,
      role: 'Teacher',
      school_id: schoolId,
      class_ids: classIds,
      subjects: Array.isArray(body.subjects) && body.subjects.length > 0 ? body.subjects : [body.subject || 'General'],
      status: 'Active',
    }
    DB.users.push(user)
    persist()
    return publicUser(user)
  },

  'school_connect.api.admin.update_teacher': (body) => {
    const u = DB.users.find((x) => x.id === body.id && x.role === 'Teacher')
    if (!u) throw { status: 404, message: 'Teacher not found' }
    const name = body.name?.trim()
    const email = body.email?.trim().toLowerCase()
    if (!name) throw { status: 400, message: 'Name is required' }
    if (!email) throw { status: 400, message: 'Email is required' }
    if (DB.users.some((x) => x.email === email && x.id !== u.id)) {
      throw { status: 400, message: 'An account with this email already exists' }
    }
    u.full_name = name
    u.email = email
    if (Array.isArray(body.subjects)) {
      u.subjects = body.subjects.length > 0 ? body.subjects : [u.subjects?.[0] || u.subject || 'General']
    } else if (body.subject) {
      u.subjects = [body.subject]
    }
    if (body.password) u.password = body.password
    if (Array.isArray(body.class_ids)) {
      u.class_ids = body.class_ids.filter((cid) => DB.classes.some((c) => c.id === cid && c.school_id === u.school_id))
    }
    persist()
    return publicUser(u)
  },

  'school_connect.api.admin.set_teacher_status': (body) => {
    const u = DB.users.find((x) => x.id === body.id && x.role === 'Teacher')
    if (!u) throw { status: 404, message: 'Teacher not found' }
    u.status = body.status === 'Inactive' ? 'Inactive' : 'Active'
    persist()
    return publicUser(u)
  },

  'school_connect.api.admin.delete_teacher': (body) => {
    const idx = DB.users.findIndex((x) => x.id === body.id && x.role === 'Teacher')
    if (idx === -1) throw { status: 404, message: 'Teacher not found' }
    const [removed] = DB.users.splice(idx, 1)
    persist()
    return { message: 'Teacher deleted', id: removed.id }
  },

  'school_connect.api.admin.get_admin_classes': (params) => ({
    data: bySchool(DB.classes, params.school).map((c) => ({
      id: c.id,
      name: c.name,
      program: c.program,
      room: c.room,
      school_id: c.school_id,
      school_name: withSchoolName(c).school_name,
      student_count: DB.students.filter((s) => s.class_id === c.id).length,
      teachers: teacherNames(c.teacher_ids),
    })),
  }),

  'school_connect.api.admin.get_admin_class': (params) => {
    const c = DB.classes.find((cls) => cls.id === params.id)
    if (!c) throw { status: 404, message: 'Class not found' }
    return {
      data: {
        id: c.id,
        name: c.name,
        program: c.program,
        room: c.room,
        school_id: c.school_id,
        school_name: withSchoolName(c).school_name,
        teachers: teacherNames(c.teacher_ids),
        students: DB.students
          .filter((s) => s.class_id === c.id)
          .sort((a, b) => a.roll_number - b.roll_number)
          .map((s) => ({ ...s, school_name: withSchoolName(s).school_name })),
      },
    }
  },

  'school_connect.api.admin.get_admin_students': (params) => ({
    data: DB.students
      .filter((s) => !params.school || s.school_id === params.school)
      .filter((s) => !params.class || s.class_id === params.class)
      .map((s) => {
        const cls = DB.classes.find((c) => c.id === s.class_id)
        return { ...s, class_name: cls?.name, school_name: withSchoolName(s).school_name }
      }),
  }),

  'school_connect.api.admin.get_admin_student': (params) => {
    const s = DB.students.find((st) => st.id === params.id)
    if (!s) throw { status: 404, message: 'Student not found' }
    const cls = DB.classes.find((c) => c.id === s.class_id)
    return {
      data: {
        ...s,
        class_name: cls?.name,
        room: cls?.room,
        school_name: withSchoolName(s).school_name,
        teachers: teacherNames(cls?.teacher_ids || []),
      },
    }
  },

  'school_connect.api.admin.create_class': (body) => {
    const name = body.name?.trim()
    if (!name) throw { status: 400, message: 'Class name is required' }
    const school = body.school || null
    if (school && !DB.schools.some((s) => s.id === school)) throw { status: 400, message: 'Unknown school' }
    const cls = {
      id: `c-${Date.now().toString(36)}`,
      name,
      program: body.program?.trim() || '',
      room: body.room?.trim() || '',
      school_id: school,
      teacher_ids: Array.isArray(body.teacher_ids) ? body.teacher_ids : [],
    }
    DB.classes.push(cls)
    persist()
    return cls
  },

  'school_connect.api.admin.update_class': (body) => {
    const c = DB.classes.find((x) => x.id === body.id)
    if (!c) throw { status: 404, message: 'Class not found' }
    const name = body.name?.trim()
    if (!name) throw { status: 400, message: 'Class name is required' }
    c.name = name
    c.program = body.program?.trim() || c.program
    c.room = body.room?.trim() || c.room
    if (Array.isArray(body.teacher_ids)) c.teacher_ids = body.teacher_ids
    persist()
    return c
  },

  'school_connect.api.admin.delete_class': (body) => {
    const c = DB.classes.find((x) => x.id === body.id)
    if (!c) throw { status: 404, message: 'Class not found' }
    DB.students = DB.students.filter((s) => s.class_id !== c.id)
    DB.classes = DB.classes.filter((x) => x.id !== c.id)
    DB.timetable = DB.timetable.filter((e) => e.class_id !== c.id)
    // unassign the class from its teachers
    for (const u of DB.users) {
      if (u.role === 'Teacher' && Array.isArray(u.class_ids)) u.class_ids = u.class_ids.filter((cid) => cid !== c.id)
    }
    persist()
    return { message: 'Class deleted', id: c.id }
  },

  'school_connect.api.admin.get_timetable': (params) => {
    const scopeSchool = params.school
    const classId = params.class
    let rows = DB.timetable
    if (classId) rows = rows.filter((e) => e.class_id === classId)
    else if (scopeSchool) rows = rows.filter((e) => e.school_id === scopeSchool)
    const enriched = rows.map((e) => {
      const cls = DB.classes.find((c) => c.id === e.class_id)
      const teacher = DB.users.find((u) => u.id === e.teacher_id && u.role === 'Teacher')
      return {
        id: e.id,
        school_id: e.school_id,
        class_id: e.class_id,
        class_name: cls?.name || null,
        day: e.day,
        period: e.period,
        teacher_id: e.teacher_id,
        teacher_name: teacher?.full_name || 'Unknown teacher',
        subject: e.subject || teacher?.subjects?.[0] || teacher?.subject || 'General',
        teacher_status: teacher?.status || 'Active',
      }
    })
    enriched.sort((a, b) => {
      const d = DAYS.indexOf(a.day) - DAYS.indexOf(b.day)
      return d !== 0 ? d : a.period - b.period
    })
    return { periods: periodsFor(scopeSchool), entries: enriched }
  },

  'school_connect.api.admin.update_timetable_periods': (body) => {
    const school = DB.schools.find((s) => s.id === body.school)
    if (!school) throw { status: 404, message: 'School not found' }
    const cleaned = Array.isArray(body.periods)
      ? body.periods
          .filter((p) => p && Number.isInteger(p.n) && p.n >= 1 && String(p.time || '').trim())
          .map((p) => ({ n: p.n, time: String(p.time).trim() }))
          .sort((a, b) => a.n - b.n)
      : []
    if (cleaned.length === 0) {
      throw { status: 400, message: 'At least one period with a valid time is required' }
    }
    school.periods = cleaned
    persist()
    return { message: 'Periods updated', periods: cleaned }
  },

  'school_connect.api.admin.set_timetable_entry': (body) => {
    const cls = DB.classes.find((c) => c.id === body.class_id)
    if (!cls) throw { status: 404, message: 'Class not found' }
    if (!DAYS.includes(body.day)) throw { status: 400, message: 'Invalid day' }
    const period = Number(body.period)
    const periodCount = periodsFor(cls.school_id).length
    if (!Number.isInteger(period) || period < 1 || period > periodCount) {
      throw { status: 400, message: `Period must be between 1 and ${periodCount}` }
    }
    const teacher = DB.users.find((u) => u.id === body.teacher_id && u.role === 'Teacher')
    if (!teacher) throw { status: 400, message: 'Teacher not found' }
    if (teacher.status === 'Inactive') {
      throw { status: 400, message: `${teacher.full_name} is inactive and can't be scheduled` }
    }
    if (teacher.school_id !== cls.school_id) {
      throw { status: 400, message: "This teacher doesn't belong to the class's school" }
    }
    const subject = body.subject?.trim()
    if (!subject) throw { status: 400, message: 'A subject is required for this period' }
    const teacherSubjects = Array.isArray(teacher.subjects) ? teacher.subjects : [teacher.subject || 'General']
    if (teacherSubjects.length > 0 && !teacherSubjects.includes(subject)) {
      throw { status: 400, message: `${teacher.full_name} doesn't teach ${subject}` }
    }
    // a teacher can only be in one class per day + period
    const clash = DB.timetable.find(
      (e) => e.teacher_id === teacher.id && e.day === body.day && e.period === period && e.class_id !== cls.id,
    )
    if (clash) {
      const other = DB.classes.find((c) => c.id === clash.class_id)
      throw {
        status: 400,
        message: `${teacher.full_name} already teaches ${other?.name || 'another class'} on ${body.day} period ${period}`,
      }
    }
    // one slot per class/day/period — replacing is an update, not a duplicate
    const existing = DB.timetable.find((e) => e.class_id === cls.id && e.day === body.day && e.period === period)
    if (existing) {
      existing.teacher_id = teacher.id
      existing.subject = subject
    } else {
      DB.timetable.push({
        id: `tt-${Date.now().toString(36)}`,
        school_id: cls.school_id,
        class_id: cls.id,
        day: body.day,
        period,
        teacher_id: teacher.id,
        subject,
      })
    }
    persist()
    return { message: 'Timetable updated' }
  },

  'school_connect.api.admin.remove_timetable_entry': (body) => {
    const idx = DB.timetable.findIndex((e) => e.id === body.id)
    if (idx === -1) throw { status: 404, message: 'Timetable entry not found' }
    DB.timetable.splice(idx, 1)
    persist()
    return { message: 'Timetable entry removed' }
  },

  'school_connect.api.admin.create_student': (body) => {
    const name = body.name?.trim()
    if (!name) throw { status: 400, message: 'Student name is required' }
    const cls = DB.classes.find((c) => c.id === body.class_id)
    if (!cls) throw { status: 400, message: 'Unknown class' }
    const email = body.email?.trim().toLowerCase() || ''
    if (email && DB.students.some((s) => s.email === email)) {
      throw { status: 400, message: 'A student with this email already exists' }
    }
    const peers = DB.students.filter((s) => s.class_id === cls.id)
    const roll = Number(body.roll_number) || (peers.length ? Math.max(...peers.map((s) => s.roll_number)) + 1 : 1)
    if (peers.some((s) => s.roll_number === roll)) {
      throw { status: 400, message: `Roll number ${roll} is already taken in this class` }
    }
    const student = {
      id: `${cls.id}-s${Date.now().toString(36)}`,
      name,
      email,
      roll_number: roll,
      class_id: cls.id,
      school_id: cls.school_id,
      attendance_pct: 0,
      status: body.status === 'Inactive' ? 'Inactive' : 'Active',
    }
    DB.students.push(student)
    persist()
    return student
  },

  'school_connect.api.admin.update_student': (body) => {
    const s = DB.students.find((x) => x.id === body.id)
    if (!s) throw { status: 404, message: 'Student not found' }
    const name = body.name?.trim()
    if (!name) throw { status: 400, message: 'Student name is required' }
    const email = body.email?.trim().toLowerCase() || s.email
    if (DB.students.some((x) => x.email === email && x.id !== s.id)) {
      throw { status: 400, message: 'A student with this email already exists' }
    }
    if (body.class_id && body.class_id !== s.class_id) {
      const cls = DB.classes.find((c) => c.id === body.class_id)
      if (!cls) throw { status: 400, message: 'Unknown class' }
      s.class_id = cls.id
      s.school_id = cls.school_id
    }
    s.name = name
    s.email = email
    const roll = Number(body.roll_number)
    if (roll) {
      if (DB.students.some((x) => x.class_id === s.class_id && x.id !== s.id && x.roll_number === roll)) {
        throw { status: 400, message: `Roll number ${roll} is already taken in this class` }
      }
      s.roll_number = roll
    }
    if (body.status === 'Active' || body.status === 'Inactive') s.status = body.status
    persist()
    return s
  },

  'school_connect.api.admin.delete_student': (body) => {
    const s = DB.students.find((x) => x.id === body.id)
    if (!s) throw { status: 404, message: 'Student not found' }
    DB.students = DB.students.filter((x) => x.id !== s.id)
    persist()
    return { message: 'Student deleted', id: s.id }
  },

  'school_connect.api.admin.set_student_status': (body) => {
    const s = DB.students.find((x) => x.id === body.id)
    if (!s) throw { status: 404, message: 'Student not found' }
    s.status = body.status === 'Inactive' ? 'Inactive' : 'Active'
    persist()
    return s
  },
}

/* ---------- entry point ---------- */

export function mockRequest(path, { method: _method = 'GET', params = {}, body = {} } = {}) {
  const key = path.replace(/^\/?api\/method\//, '')
  const handler = HANDLERS[key]
  if (!handler) {
    throw { status: 404, message: `Mock endpoint not implemented: ${key}` }
  }
  return handler({ ...params, ...body })
}
