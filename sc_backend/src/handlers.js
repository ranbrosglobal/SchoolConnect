/**
 * API endpoint handlers for both schooladmin and superadmin consoles.
 *
 * Each handler receives (db, params) and returns a value (which gets wrapped
 * in { message: value } by the server). Throw { status, message } for errors.
 */

import crypto from 'node:crypto'
import { getOne, getAll, getById, insert, updateById, deleteById, deleteWhere, count, genId } from './db.js'
import { verifyPassword, hashPassword, storeFileBlob } from './seed.js'

// ─── Session helpers ────────────────────────────────────────────────

const SESSION_TTL_MS = 24 * 60 * 60 * 1000 // 24 hours

function createSession(db, userId) {
  const sid = crypto.randomBytes(32).toString('hex')
  const expiresAt = Date.now() + SESSION_TTL_MS
  db.prepare('INSERT INTO sessions (sid, user_id, expires_at) VALUES (?, ?, ?)').run(sid, userId, expiresAt)
  return sid
}

function getSessionUser(db, sid) {
  if (!sid) return null
  // Validate session ID format: must be a 64-char hex string (32 bytes)
  if (typeof sid !== 'string' || !/^[0-9a-f]{64}$/.test(sid)) return null
  const row = db.prepare('SELECT * FROM sessions WHERE sid = ? AND expires_at > ?').get(sid, Date.now())
  if (!row) return null
  return getById(db, 'users', row.user_id)
}

function destroySession(db, sid) {
  if (sid && typeof sid === 'string' && /^[0-9a-f]{64}$/.test(sid)) {
    db.prepare('DELETE FROM sessions WHERE sid = ?').run(sid)
  }
}

function publicUser(user, schoolName) {
  return {
    name: user.id,
    email: user.email,
    full_name: user.full_name,
    role: user.role,
    roles: user.role === 'Administrator' ? ['Administrator', 'System Manager'] : [user.role],
    school: user.school_id,
    school_name: schoolName || null,
  }
}

// Max base64 payload accepted for file uploads (~10 MB decoded)
const MAX_UPLOAD_B64 = 14 * 1024 * 1024

// ─── Lockout & Rate Limiter ────────────────────────────────────────

const MAX_FAILURES = 5
const LOCKOUT_MS = 5 * 60 * 1000 // 5 minutes
const RATE_LIMIT = 20 // per window (generous for multiple tabs/admin use)
const RATE_WINDOW_MS = 60 * 1000 // 1 minute

const failures = new Map() // email → { count, lockedUntil }
const ipAttempts = new Map() // ip → [timestamp, ...]

function recordFailure(email) {
  const f = failures.get(email) || { count: 0, lockedUntil: 0 }
  f.count++
  if (f.count >= MAX_FAILURES) f.lockedUntil = Date.now() + LOCKOUT_MS
  failures.set(email, f)
}

function clearFailures(email) {
  failures.delete(email)
}

function isLocked(email) {
  const f = failures.get(email)
  if (!f) return false
  // Only clear expired lockouts — never wipe failure counts that haven't reached the threshold yet
  if (f.lockedUntil > 0 && Date.now() > f.lockedUntil) { failures.delete(email); return false }
  return f.count >= MAX_FAILURES
}

function checkRateLimit(ip) {
  if (!ip) return true
  const now = Date.now()
  const attempts = ipAttempts.get(ip) || []
  const recent = attempts.filter(t => now - t < RATE_WINDOW_MS)
  ipAttempts.set(ip, recent)
  if (recent.length >= RATE_LIMIT) return false
  recent.push(now)
  return true
}

// ─── CSRF ───────────────────────────────────────────────────────────

function checkCsrf(req, user, path) {
  // GET requests don't need CSRF
  if (req.method === 'GET') return true
  // No session → no CSRF needed (login)
  if (!user) return true
  // Mobile-app endpoints are exempt: the native app cannot hold CSRF tokens.
  // The session cookie is SameSite=Lax, which already blocks cross-site
  // browser requests, so this does not weaken protection for the consoles.
  if (typeof path === 'string' && path.startsWith('school_connect.api.mobile.')) return true
  const token = req.headers['x-csrf-token']
  return token === user.id
}

// ─── School Admin handlers ──────────────────────────────────────────

// Max input lengths
const MAX_NAME = 200
const MAX_EMAIL = 254
const MAX_PASSWORD = 128
const MAX_TEXT = 1000

function schoolAdminLogin(db, params) {
  const { usr, pwd } = params
  if (!usr || !pwd) throw { status: 400, message: 'Email and password are required' }
  if (String(usr).length > MAX_EMAIL || String(pwd).length > MAX_PASSWORD) {
    throw { status: 400, message: 'Input too long' }
  }

  const user = getOne(db, 'users', 'email', usr)
  if (!user || !verifyPassword(pwd, user.password)) {
    throw { status: 401, message: 'Invalid email or password' }
  }
  if (user.role !== 'School Admin') {
    throw { status: 403, message: 'Access denied. This console is for School Admins only.' }
  }
  if (user.status === 'Inactive') {
    throw { status: 403, message: 'This account is disabled. Contact your super admin.' }
  }
  const school = getById(db, 'schools', user.school_id)
  if (school && school.status === 'Disabled') {
    throw { status: 403, message: 'This school is disabled. Contact your super admin.' }
  }

  clearFailures(usr)
  const sid = createSession(db, user.id)
  const result = publicUser(user, school?.name)
  return { ...result, _sid: sid }
}

/**
 * Mobile app login - accepts email and password for any user role (teacher, student, admin).
 * This is used by the Flutter mobile app for direct login without Firebase Auth.
 */
function mobileLogin(db, params) {
  const { email, password } = params
  if (!email || !password) throw { status: 400, message: 'Email and password are required' }
  if (String(email).length > MAX_EMAIL || String(password).length > MAX_PASSWORD) {
    throw { status: 400, message: 'Input too long' }
  }

  const normalizedEmail = email.trim().toLowerCase()
  
  // First check users table (teachers, admins)
  let user = getOne(db, 'users', 'email', normalizedEmail)
  
  if (user) {
    // Verify password against the stored hash
    if (!verifyPassword(password, user.password)) {
      throw { status: 401, message: 'Invalid email or password' }
    }
    if (user.status === 'Inactive') {
      throw { status: 403, message: 'This account is disabled. Contact your administrator.' }
    }
    if (user.school_id) {
      const school = getById(db, 'schools', user.school_id)
      if (school && school.status === 'Disabled') {
        throw { status: 403, message: 'Your school has been disabled. Contact support.' }
      }
    }
    
    const sid = createSession(db, user.id)
    const school = user.school_id ? getById(db, 'schools', user.school_id) : null
    return { ...publicUser(user, school?.name), _sid: sid }
  }
  
  // Check students table
  const student = getOne(db, 'students', 'email', normalizedEmail)
  if (student) {
    // For students, we need to verify password. If student has no password set,
    // we allow login with any password (backward compatibility).
    // If student has a password, verify it.
    if (student.password && !verifyPassword(password, student.password)) {
      throw { status: 401, message: 'Invalid email or password' }
    }
    
    if (student.status === 'Inactive') {
      throw { status: 403, message: 'This student account is disabled.' }
    }
    
    // Auto-create in users table if not exists, so session works
    try {
      insert(db, 'users', {
        id: student.id,
        email: student.email,
        password: password ? hashPassword(password) : '',
        full_name: student.name,
        role: 'Student',
        school_id: student.school_id || '',
        class_ids: JSON.stringify(student.class_id ? [student.class_id] : []),
        subjects: '[]',
        status: student.status || 'Active',
      })
    } catch (_e) { /* already exists */ }
    
    const syntheticUser = {
      id: student.id,
      email: student.email,
      full_name: student.name,
      role: 'Student',
      school_id: student.school_id,
      class_ids: JSON.stringify(student.class_id ? [student.class_id] : []),
      subjects: '[]',
      status: student.status || 'Active',
    }
    
    const sid = createSession(db, syntheticUser.id)
    const school = syntheticUser.school_id ? getById(db, 'schools', syntheticUser.school_id) : null
    return { ...publicUser(syntheticUser, school?.name), _sid: sid }
  }
  
  throw { status: 404, message: 'No account found with this email. Contact your administrator.' }
}

function schoolAdminGetSession(db, _params, user, sid) {
  if (!user) return { message: 'Not logged in', isLoggedIn: false }
  const school = user.school_id ? getById(db, 'schools', user.school_id) : null
  return { message: 'Logged in', isLoggedIn: true, ...publicUser(user, school?.name), _sid: sid }
}

function schoolAdminLogout(db, _params, _user, sid) {
  destroySession(db, sid)
  return { message: 'Logged out' }
}

function schoolAdminUpdateProfile(db, params, user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  const name = params.full_name?.trim()
  if (!name || name.length < 2) throw { status: 400, message: 'Name must be at least 2 characters long' }
  updateById(db, 'users', user.id, { full_name: name })
  const school = user.school_id ? getById(db, 'schools', user.school_id) : null
  return publicUser({ ...user, full_name: name }, school?.name)
}

function schoolAdminChangePassword(db, params, user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  if (!verifyPassword(params.current_password, user.password)) {
    throw { status: 400, message: 'Current password is incorrect' }
  }
  if (!params.new_password || params.new_password.length < 6) {
    throw { status: 400, message: 'New password must be at least 6 characters long' }
  }
  if (params.new_password === params.current_password) {
    throw { status: 400, message: 'New password must be different from the current password' }
  }
  updateById(db, 'users', user.id, { password: hashPassword(params.new_password) })
  return { message: 'Password updated successfully' }
}

function schoolAdminDashboard(db, params, user) {
  const school = params.school || user?.school_id
  const classes = getAll(db, 'classes', 'school_id = ?', school)
  const students = getAll(db, 'students', 'school_id = ?', school)
  const teachers = getAll(db, 'users', "role = 'Teacher' AND school_id = ?", school)

  const recentClasses = classes.slice(0, 4).map(c => {
    const classStudents = getAll(db, 'students', 'class_id = ?', c.id)
    const tIds = JSON.parse(c.teacher_ids || '[]')
    const teacherNames = tIds.map(tid => { const t = getById(db, 'users', tid); return t?.full_name }).filter(Boolean)
    return { id: c.id, name: c.name, program: c.program, room: c.room, student_count: classStudents.length, teachers: teacherNames }
  })

  return {
    school_count: 1,
    school_admin_count: count(db, 'users', "role = 'School Admin' AND school_id = ?", school),
    teacher_count: teachers.length,
    class_count: classes.length,
    student_count: students.length,
    attendance_avg: students.length
      ? Math.round(students.reduce((a, s) => a + (s.attendance_pct || 0), 0) / students.length)
      : 0,
    recent_classes: recentClasses,
  }
}

function schoolAdminTeachers(db, params, user) {
  const school = params.school || user?.school_id
  const users = getAll(db, 'users', "role = 'Teacher' AND school_id = ?", school)
  return users.map(u => {
    const classIds = JSON.parse(u.class_ids || '[]')
    const classNames = classIds.map(cid => { const c = getById(db, 'classes', cid); return c?.name }).filter(Boolean)
    return {
      id: u.id, name: u.full_name, email: u.email,
      subjects: JSON.parse(u.subjects || '["General"]'),
      subject: (JSON.parse(u.subjects || '["General"]'))[0],
      school_id: u.school_id, classes: classNames, class_ids: classIds,
      status: u.status || 'Active',
    }
  })
}

function schoolAdminCreateTeacher(db, params) {
  const name = params.name?.trim()
  const email = params.email?.trim().toLowerCase()
  if (!name) throw { status: 400, message: 'Name is required' }
  if (!email) throw { status: 400, message: 'Email is required' }
  if (!params.password) throw { status: 400, message: 'Password is required' }
  if (name.length > MAX_NAME) throw { status: 400, message: 'Name is too long' }
  if (email.length > MAX_EMAIL) throw { status: 400, message: 'Email is too long' }
  if (String(params.password).length > MAX_PASSWORD) throw { status: 400, message: 'Password is too long' }
  if (getOne(db, 'users', 'email', email)) throw { status: 400, message: 'An account with this email already exists' }

  const id = genId('t-')
  const subjects = Array.isArray(params.subjects) ? params.subjects : [params.subject || 'General']
  const classIds = Array.isArray(params.class_ids) ? params.class_ids : []

  insert(db, 'users', {
    id, email, password: hashPassword(params.password), full_name: name,
    role: 'Teacher', school_id: params.school || '', class_ids: JSON.stringify(classIds),
    subjects: JSON.stringify(subjects), status: 'Active',
  })

  return { name: id, email, full_name: name, role: 'Teacher', roles: ['Teacher'],
    school: params.school, subjects, class_ids: classIds, status: 'Active' }
}

function schoolAdminUpdateTeacher(db, params) {
  const user = getById(db, 'users', params.id)
  if (!user || user.role !== 'Teacher') throw { status: 404, message: 'Teacher not found' }
  const name = params.name?.trim()
  const email = params.email?.trim().toLowerCase()
  if (!name) throw { status: 400, message: 'Name is required' }
  if (!email) throw { status: 400, message: 'Email is required' }

  const updates = { full_name: name, email }
  if (Array.isArray(params.subjects)) updates.subjects = JSON.stringify(params.subjects)
  if (params.password) updates.password = hashPassword(params.password)
  if (Array.isArray(params.class_ids)) updates.class_ids = JSON.stringify(params.class_ids)
  updateById(db, 'users', params.id, updates)

  const subjects = params.subjects || JSON.parse(user.subjects || '["General"]')
  return { name: params.id, email, full_name: name, role: 'Teacher', roles: ['Teacher'],
    school: user.school_id, subjects, subject: subjects[0],
    class_ids: params.class_ids || JSON.parse(user.class_ids || '[]'), status: user.status }
}

function schoolAdminSetTeacherStatus(db, params) {
  const user = getById(db, 'users', params.id)
  if (!user || user.role !== 'Teacher') throw { status: 404, message: 'Teacher not found' }
  const status = params.status === 'Inactive' ? 'Inactive' : 'Active'
  updateById(db, 'users', params.id, { status })
  return { name: params.id, email: user.email, full_name: user.full_name, role: 'Teacher', status }
}

function schoolAdminClasses(db, params, user) {
  const school = params.school || user?.school_id
  const classes = getAll(db, 'classes', 'school_id = ?', school)
  return classes.map(c => {
    const classStudents = getAll(db, 'students', 'class_id = ?', c.id)
    const tIds = JSON.parse(c.teacher_ids || '[]')
    const teacherNames = tIds.map(tid => { const t = getById(db, 'users', tid); return t?.full_name }).filter(Boolean)
    return { id: c.id, name: c.name, program: c.program, room: c.room, school_id: c.school_id,
      student_count: classStudents.length, teachers: teacherNames }
  })
}

function schoolAdminClassDetail(db, params) {
  const c = getById(db, 'classes', params.id)
  if (!c) throw { status: 404, message: 'Class not found' }
  const students = getAll(db, 'students', 'class_id = ?', c.id)
    .sort((a, b) => (a.roll_number || 0) - (b.roll_number || 0))
  const tIds = JSON.parse(c.teacher_ids || '[]')
  const teacherNames = tIds.map(tid => { const t = getById(db, 'users', tid); return t?.full_name }).filter(Boolean)
  return { id: c.id, name: c.name, program: c.program, room: c.room, school_id: c.school_id,
    teachers: teacherNames, students }
}

function schoolAdminCreateClass(db, params) {
  const name = params.name?.trim()
  if (!name) throw { status: 400, message: 'Class name is required' }
  const id = genId('c-')
  const teacherIds = Array.isArray(params.teacher_ids) ? params.teacher_ids : []
  insert(db, 'classes', { id, name, program: params.program || '', school_id: params.school || '',
    room: params.room || '', teacher_ids: JSON.stringify(teacherIds) })
  return { id, name, program: params.program || '', room: params.room || '',
    school_id: params.school, teacher_ids: teacherIds }
}

function schoolAdminUpdateClass(db, params) {
  const c = getById(db, 'classes', params.id)
  if (!c) throw { status: 404, message: 'Class not found' }
  const name = params.name?.trim()
  if (!name) throw { status: 400, message: 'Class name is required' }
  const updates = { name }
  if (params.program) updates.program = params.program
  if (params.room) updates.room = params.room
  if (Array.isArray(params.teacher_ids)) updates.teacher_ids = JSON.stringify(params.teacher_ids)
  updateById(db, 'classes', params.id, updates)
  return { ...c, ...updates, teacher_ids: params.teacher_ids || JSON.parse(c.teacher_ids || '[]') }
}

function schoolAdminDeleteClass(db, params) {
  const c = getById(db, 'classes', params.id)
  if (!c) throw { status: 404, message: 'Class not found' }
  // Cascade: remove students in this class
  deleteWhere(db, 'students', 'class_id', params.id)
  // Unassign class from teachers
  const teachers = getAll(db, 'users', "role = 'Teacher'")
  for (const t of teachers) {
    const ids = JSON.parse(t.class_ids || '[]').filter(cid => cid !== params.id)
    if (ids.length !== JSON.parse(t.class_ids || '[]').length) {
      updateById(db, 'users', t.id, { class_ids: JSON.stringify(ids) })
    }
  }
  deleteById(db, 'classes', params.id)
  return { message: 'Class deleted', id: params.id }
}

function schoolAdminStudents(db, params, user) {
  const school = params.school || user?.school_id
  let students = getAll(db, 'students', 'school_id = ?', school)
  if (params.class) students = students.filter(s => s.class_id === params.class)
  return students.map(s => {
    const cls = getById(db, 'classes', s.class_id)
    return { ...s, class_name: cls?.name || null }
  })
}

function schoolAdminStudentDetail(db, params) {
  const s = getById(db, 'students', params.id)
  if (!s) throw { status: 404, message: 'Student not found' }
  const cls = getById(db, 'classes', s.class_id)
  const tIds = JSON.parse(cls?.teacher_ids || '[]')
  const teacherNames = tIds.map(tid => { const t = getById(db, 'users', tid); return t?.full_name }).filter(Boolean)
  return { ...s, class_name: cls?.name, room: cls?.room, teachers: teacherNames }
}

function schoolAdminCreateStudent(db, params) {
  const name = params.name?.trim()
  if (!name) throw { status: 400, message: 'Student name is required' }
  if (name.length > MAX_NAME) throw { status: 400, message: 'Name is too long' }
  if (params.email && String(params.email).length > MAX_EMAIL) throw { status: 400, message: 'Email is too long' }
  if (params.password && String(params.password).length > MAX_PASSWORD) throw { status: 400, message: 'Password is too long' }
  const cls = getById(db, 'classes', params.class_id)
  if (!cls) throw { status: 400, message: 'Unknown class' }
  const id = genId('stu-')
  const peers = getAll(db, 'students', 'class_id = ?', cls.id)
  const roll = Number(params.roll_number) || (peers.length ? Math.max(...peers.map(s => s.roll_number || 0)) + 1 : 1)
  const hashedPw = params.password ? hashPassword(params.password) : ''
  insert(db, 'students', { id, name, email: params.email || '', password: hashedPw,
    roll_number: roll, class_id: cls.id, school_id: cls.school_id,
    parent_name: params.parent_name || '', parent_phone: params.parent_phone || '',
    parent_email: params.parent_email || '', address: params.address || '',
    attendance_pct: 0,
    status: params.status === 'Inactive' ? 'Inactive' : 'Active' })
  return { id, name, email: params.email || '', roll_number: roll, class_id: cls.id,
    school_id: cls.school_id, parent_name: params.parent_name || '',
    parent_phone: params.parent_phone || '', parent_email: params.parent_email || '',
    address: params.address || '', attendance_pct: 0, status: params.status || 'Active' }
}

function schoolAdminUpdateStudent(db, params) {
  const s = getById(db, 'students', params.id)
  if (!s) throw { status: 404, message: 'Student not found' }
  const name = params.name?.trim()
  if (!name) throw { status: 400, message: 'Student name is required' }
  const updates = { name }
  if (params.email) updates.email = params.email
  if (params.class_id) updates.class_id = params.class_id
  if (params.roll_number) updates.roll_number = Number(params.roll_number)
  if (params.status) updates.status = params.status
  if (params.parent_name != null) updates.parent_name = params.parent_name
  if (params.parent_phone != null) updates.parent_phone = params.parent_phone
  if (params.parent_email != null) updates.parent_email = params.parent_email
  if (params.address != null) updates.address = params.address
  updateById(db, 'students', params.id, updates)
  return { ...s, ...updates }
}

function schoolAdminDeleteStudent(db, params) {
  const s = getById(db, 'students', params.id)
  if (!s) throw { status: 404, message: 'Student not found' }
  deleteById(db, 'students', params.id)
  return { message: 'Student deleted', id: params.id }
}

function schoolAdminSetStudentStatus(db, params) {
  const s = getById(db, 'students', params.id)
  if (!s) throw { status: 404, message: 'Student not found' }
  const status = params.status === 'Inactive' ? 'Inactive' : 'Active'
  updateById(db, 'students', params.id, { status })
  return { ...s, status }
}

function schoolAdminTimetable(db, params, user) {
  const school = params.school || user?.school_id
  const classId = params.class
  let entries
  if (classId) entries = getAll(db, 'timetable', 'class_id = ?', classId)
  else if (school) entries = getAll(db, 'timetable', 'school_id = ?', school)
  else entries = getAll(db, 'timetable')

  const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
  const enriched = entries.map(e => {
    const cls = getById(db, 'classes', e.class_id)
    const teacher = getById(db, 'users', e.teacher_id)
    return { id: e.id, school_id: e.school_id, class_id: e.class_id,
      class_name: cls?.name || null, day: e.day, period: e.period,
      teacher_id: e.teacher_id, teacher_name: teacher?.full_name || 'Unknown',
      subject: e.subject || 'General', teacher_status: teacher?.status || 'Active' }
  })
  enriched.sort((a, b) => {
    const d = DAYS.indexOf(a.day) - DAYS.indexOf(b.day)
    return d !== 0 ? d : a.period - b.period
  })

  const schoolRow = school ? getById(db, 'schools', school) : null
  const periods = schoolRow?.periods ? JSON.parse(schoolRow.periods) : undefined
  return { periods, entries: enriched }
}

function schoolAdminSetTimetableEntry(db, params) {
  const cls = getById(db, 'classes', params.class_id)
  if (!cls) throw { status: 404, message: 'Class not found' }
  const teacher = getById(db, 'users', params.teacher_id)
  if (!teacher) throw { status: 400, message: 'Teacher not found' }
  const subject = params.subject?.trim()
  if (!subject) throw { status: 400, message: 'A subject is required' }

  // Check for clash (same teacher, same day+period, different class)
  const clash = getAll(db, 'timetable', 'teacher_id = ? AND day = ? AND period = ?',
    params.teacher_id, params.day, params.period)
    .find(e => e.class_id !== cls.id)
  if (clash) {
    const other = getById(db, 'classes', clash.class_id)
    throw { status: 400, message: `${teacher.full_name} already teaches ${other?.name || 'another class'} on ${params.day} period ${params.period}` }
  }

  // Upsert: check for existing entry in same slot
  const existing = getAll(db, 'timetable', 'class_id = ? AND day = ? AND period = ?',
    cls.id, params.day, params.period)[0]

  if (existing) {
    updateById(db, 'timetable', existing.id, { teacher_id: params.teacher_id, subject })
  } else {
    insert(db, 'timetable', {
      id: genId('tt-'), school_id: cls.school_id || '', class_id: cls.id,
      day: params.day, period: params.period, teacher_id: params.teacher_id, subject,
    })
  }
  return { message: 'Timetable updated' }
}

function schoolAdminUpdateTimetablePeriods(db, params) {
  const school = getById(db, 'schools', params.school)
  if (!school) throw { status: 404, message: 'School not found' }
  const periods = Array.isArray(params.periods) ? params.periods : []
  updateById(db, 'schools', params.school, { periods: JSON.stringify(periods) })
  return { message: 'Periods updated', periods }
}

function schoolAdminRemoveTimetableEntry(db, params) {
  deleteById(db, 'timetable', params.id)
  return { message: 'Timetable entry removed' }
}

// ─── Mobile App handlers ───────────────────────────────────────────

/**
 * Social login — used by the Flutter mobile app after Firebase Auth.
 * The client authenticates via Firebase (Google/Apple/Email), then calls
 * this endpoint with the email to create a backend session.
 */
function mobileSocialLogin(db, params) {
  const email = params.email?.trim().toLowerCase()
  if (!email) throw { status: 400, message: 'Email is required' }

  // First check the users table (teachers, admins)
  let user = getOne(db, 'users', 'email', email)
  let role = null

  if (user) {
    role = user.role
    if (user.status === 'Inactive') throw { status: 403, message: 'This account is disabled.' }
    if (user.school_id && user.role !== 'Administrator') {
      const school = getById(db, 'schools', user.school_id)
      if (school && school.status === 'Disabled') {
        throw { status: 403, message: 'Your school has been disabled. Contact support.' }
      }
    }
  } else {
    // Check the students table
    const student = getOne(db, 'students', 'email', email)
    if (student) {
      if (student.status === 'Inactive') throw { status: 403, message: 'This student account is disabled.' }
      // Create a synthetic user-like object for session purposes
      user = {
        id: student.id,
        email: student.email,
        full_name: student.name,
        role: 'Student',
        school_id: student.school_id,
        class_ids: '[]',
        subjects: '[]',
        status: student.status,
      }
      role = 'Student'
      // Auto-create in users table so session works
      try {
        insert(db, 'users', {
          id: student.id,
          email: student.email,
          password: '',
          full_name: student.name,
          role: 'Student',
          school_id: student.school_id || '',
          class_ids: JSON.stringify(student.class_id ? [student.class_id] : []),
          subjects: '[]',
          status: student.status || 'Active',
        })
      } catch (_e) { /* already exists */ }
    }
  }

  if (!user) throw { status: 404, message: 'User not found. Ask your admin to create an account.' }

  const sid = createSession(db, user.id)
  const school = user.school_id ? getById(db, 'schools', user.school_id) : null
  return { ...publicUser(user, school?.name), _sid: sid }
}

/** Mobile: get my profile */
function mobileGetProfile(db, params, user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  const school = user.school_id ? getById(db, 'schools', user.school_id) : null
  return publicUser(user, school?.name)
}

/** Mobile: get teacher's classes with student counts */
function mobileGetTeacherClasses(db, params, user) {
  if (!user || (user.role !== 'Teacher' && user.role !== 'School Admin')) {
    throw { status: 403, message: 'Access denied' }
  }
  const classIds = JSON.parse(user.class_ids || '[]')
  const classes = classIds.map(cid => getById(db, 'classes', cid)).filter(Boolean)

  return classes.map(c => {
    const students = getAll(db, 'students', 'class_id = ?', c.id)
    const tIds = JSON.parse(c.teacher_ids || '[]')
    const teacherNames = tIds.map(tid => { const t = getById(db, 'users', tid); return t?.full_name }).filter(Boolean)
    return {
      id: c.id, name: c.name, program: c.program, room: c.room,
      school_id: c.school_id, student_count: students.length, teachers: teacherNames,
    }
  })
}

/** Mobile: get students in a class */
function mobileGetClassStudents(db, params) {
  if (!params.class_id) throw { status: 400, message: 'class_id is required' }
  const students = getAll(db, 'students', 'class_id = ?', params.class_id)
    .sort((a, b) => (a.roll_number || 0) - (b.roll_number || 0))
  const cls = getById(db, 'classes', params.class_id)
  return { class_name: cls?.name || null, students }
}

/** Mobile: get teacher's timetable */
function mobileGetTeacherSchedule(db, params, user) {
  if (!user || (user.role !== 'Teacher' && user.role !== 'School Admin')) {
    throw { status: 403, message: 'Access denied' }
  }
  const entries = getAll(db, 'timetable', 'teacher_id = ?', user.id)
  const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
  const enriched = entries.map(e => {
    const cls = getById(db, 'classes', e.class_id)
    return { id: e.id, class_id: e.class_id, class_name: cls?.name || null,
      day: e.day, period: e.period, subject: e.subject || 'General' }
  })
  enriched.sort((a, b) => {
    const d = DAYS.indexOf(a.day) - DAYS.indexOf(b.day)
    return d !== 0 ? d : a.period - b.period
  })
  return enriched
}

/** Mobile: get student's schedule */
function mobileGetStudentSchedule(db, params, user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  // Find the student record matching this user
  const student = getOne(db, 'students', 'email', user.email)
  if (!student) {
    // Try by id
    const byId = getById(db, 'students', user.id)
    if (!byId) return { entries: [] }
    const entries = getAll(db, 'timetable', 'class_id = ?', byId.class_id)
    return entries
  }
  const entries = getAll(db, 'timetable', 'class_id = ?', student.class_id)
  const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
  const enriched = entries.map(e => {
    const cls = getById(db, 'classes', e.class_id)
    const teacher = getById(db, 'users', e.teacher_id)
    return { id: e.id, class_id: e.class_id, class_name: cls?.name || null,
      day: e.day, period: e.period, subject: e.subject || 'General',
      teacher_name: teacher?.full_name || 'Unknown' }
  })
  enriched.sort((a, b) => {
    const d = DAYS.indexOf(a.day) - DAYS.indexOf(b.day)
    return d !== 0 ? d : a.period - b.period
  })
  return enriched
}

// ─── Assignment / submission helpers ─────────────────────────────────

/** Serialize a submission row in the shape the mobile app expects. */
function serializeSubmission(db, sub) {
  const student = getById(db, 'students', sub.student_id)
  const assignment = getById(db, 'assignments', sub.assignment_id)
  const grade = sub.score !== '' && sub.score != null ? Number(sub.score) : null
  return {
    name: sub.id,
    assignment: sub.assignment_id,
    assignment_title: assignment?.title || null,
    student: sub.student_id,
    student_name: student?.name || null,
    student_email_id: student?.email || null,
    roll_number: student?.roll_number ?? null,
    file: sub.file_id || null,
    file_name: sub.file_name || null,
    submitted_at: sub.submitted_at || null,
    grade: Number.isFinite(grade) ? grade : null,
    feedback: sub.feedback || null,
    status: sub.status || 'Submitted',
  }
}

/**
 * Serialize an assignment row. When `student` is given, embeds that
 * student's submission under `submission` (student view). Otherwise adds
 * class/student/graded counts (teacher view).
 */
function serializeAssignment(db, row, student = null) {
  const cls = getById(db, 'classes', row.class_id)
  const teacher = row.created_by ? getById(db, 'users', row.created_by) : null
  const base = {
    name: row.id,
    id: row.id,
    title: row.title,
    description: row.description || null,
    course: row.course || null,
    student_group: row.class_id || null,
    student_group_name: cls?.name || null,
    instructor: row.created_by || null,
    instructor_name: teacher?.full_name || null,
    due_date: row.due_date || null,
    creation: row.created_at || null,
    attachment: row.attachment_id || null,
    attachment_name: row.attachment_name || null,
  }
  if (student) {
    const subs = getAll(db, 'submissions', 'assignment_id = ? AND student_id = ?', row.id, student.id)
    const sub = subs.length ? serializeSubmission(db, subs[subs.length - 1]) : null
    return {
      ...base,
      submitted: !!(sub && sub.status !== 'Returned'),
      submission: sub,
    }
  }
  const subs = getAll(db, 'submissions', 'assignment_id = ?', row.id)
  const students = row.class_id ? getAll(db, 'students', 'class_id = ?', row.class_id) : []
  return {
    ...base,
    total_students: students.length,
    submitted_count: subs.filter(s => s.status !== 'Returned').length,
    graded_count: subs.filter(s => s.status === 'Graded').length,
  }
}

function assertTeacherOrAdmin(user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  if (user.role !== 'Teacher' && user.role !== 'School Admin') {
    throw { status: 403, message: 'Access denied' }
  }
}

function assertOwnsAssignment(db, user, assignmentId) {
  const row = getById(db, 'assignments', assignmentId)
  if (!row) throw { status: 404, message: 'Assignment not found' }
  if (user.role === 'School Admin') return row
  const classIds = JSON.parse(user.class_ids || '[]')
  if (!classIds.includes(row.class_id)) throw { status: 403, message: 'This assignment belongs to another class' }
  return row
}

/** Mobile: get student's assignments (with their submission + grade) */
function mobileGetStudentAssignments(db, params, user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  const student = getOne(db, 'students', 'email', user.email) || getById(db, 'students', user.id)
  if (!student) return []

  const assignments = getAll(db, 'assignments', 'class_id = ?', student.class_id)
  return assignments.map(a => serializeAssignment(db, a, student))
}

/** Mobile: get my attendance */
function mobileGetMyAttendance(db, params, user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  const student = getOne(db, 'students', 'email', user.email) || getById(db, 'students', user.id)
  if (!student) return { records: [], summary: { overall: 0, total: 0, present: 0 } }

  const records = getAll(db, 'attendance_log', 'student_id = ?', student.id)
  const present = records.filter(r => r.status === 'Present').length
  return {
    records,
    summary: { overall: records.length ? Math.round(present / records.length * 100) : 0, total: records.length, present },
  }
}

/** Mobile: teacher marks attendance */
function mobileMarkAttendance(db, params, user) {
  if (!user || (user.role !== 'Teacher' && user.role !== 'School Admin')) {
    throw { status: 403, message: 'Access denied' }
  }
  const { class_id, date, records } = params
  if (!class_id || !date || !Array.isArray(records)) {
    throw { status: 400, message: 'class_id, date, and records array are required' }
  }
  for (const r of records) {
    const existing = getAll(db, 'attendance_log', 'student_id = ? AND date = ?', r.student_id, date)
    const existingInClass = existing.find(e => e.class_id === class_id)
    if (existingInClass) {
      updateById(db, 'attendance_log', existingInClass.id, { status: r.status })
    } else {
      insert(db, 'attendance_log', {
        id: genId('att-'),
        student_id: r.student_id, class_id, school_id: user.school_id || '',
        date, status: r.status, recorded_by: user.id, course: params.course || '',
      })
    }
  }
  return { message: 'Attendance marked', count: records.length }
}

/** Mobile: teacher creates assignment (optionally with an uploaded attachment) */
function mobileCreateAssignment(db, params, user) {
  assertTeacherOrAdmin(user)
  const { title, class_id, due_date, description, course, file_name, file_data } = params
  if (!title || !class_id) throw { status: 400, message: 'title and class_id are required' }

  let attachmentId = null
  let attachmentName = null
  if (file_data) {
    if (file_data.length > MAX_UPLOAD_B64) throw { status: 413, message: 'File too large (max 10 MB)' }
    attachmentId = storeFileBlob(db, { name: file_name, data: file_data, uploadedBy: user.id })
    attachmentName = file_name || 'attachment'
  }

  const id = genId('asgn-')
  insert(db, 'assignments', {
    id, title, course: course || '', class_id, school_id: user.school_id || '',
    due_date: due_date || '', description: description || '',
    attachment_id: attachmentId, attachment_name: attachmentName,
    created_by: user.id, created_at: new Date().toISOString(),
  })
  return { id, title, course, class_id, due_date, description, attachment: attachmentId, attachment_name: attachmentName }
}

/** Mobile: teacher updates an assignment */
function mobileUpdateAssignment(db, params, user) {
  assertTeacherOrAdmin(user)
  const row = assertOwnsAssignment(db, user, params.id)

  const updates = {}
  if (params.title) updates.title = params.title
  if (params.course != null) updates.course = params.course
  if (params.class_id) updates.class_id = params.class_id
  if (params.due_date != null) updates.due_date = params.due_date
  if (params.description != null) updates.description = params.description

  if (params.clear_attachment) {
    updates.attachment_id = null
    updates.attachment_name = null
  } else if (params.file_data) {
    if (params.file_data.length > MAX_UPLOAD_B64) throw { status: 413, message: 'File too large (max 10 MB)' }
    updates.attachment_id = storeFileBlob(db, { name: params.file_name, data: params.file_data, uploadedBy: user.id })
    updates.attachment_name = params.file_name || 'attachment'
  }

  updateById(db, 'assignments', row.id, updates)
  return { id: row.id, ...updates }
}

/** Mobile: teacher deletes an assignment (and its submissions) */
function mobileDeleteAssignment(db, params, user) {
  assertTeacherOrAdmin(user)
  const row = assertOwnsAssignment(db, user, params.id)
  deleteWhere(db, 'submissions', 'assignment_id', row.id)
  deleteById(db, 'assignments', row.id)
  return { id: row.id, deleted: true }
}

/** Mobile: student submits (or resubmits) an assignment with an uploaded file */
function mobileSubmitAssignment(db, params, user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  const { assignment_id, file_name, file_data, file_id } = params
  if (!assignment_id) throw { status: 400, message: 'assignment_id is required' }
  const assignment = getById(db, 'assignments', assignment_id)
  if (!assignment) throw { status: 404, message: 'Assignment not found' }

  const student = getOne(db, 'students', 'email', user.email) || getById(db, 'students', user.id)
  if (!student) throw { status: 404, message: 'Student profile not found' }

  let storedFileId = file_id || null
  if (!storedFileId && file_data) {
    if (file_data.length > MAX_UPLOAD_B64) throw { status: 413, message: 'File too large (max 10 MB)' }
    storedFileId = storeFileBlob(db, { name: file_name, data: file_data, uploadedBy: student.id })
  }

  const existing = getAll(db, 'submissions', 'assignment_id = ? AND student_id = ?', assignment_id, student.id)
  if (existing.length) {
    // Resubmit (e.g. after a teacher returned it): replace file and reset status
    const prev = existing[existing.length - 1]
    updateById(db, 'submissions', prev.id, {
      file_id: storedFileId,
      file_name: file_name || prev.file_name || '',
      score: '', feedback: '', status: 'Submitted',
      submitted_at: new Date().toISOString(),
    })
    return { id: prev.id, assignment_id, status: 'Submitted' }
  }

  const id = genId('sub-')
  insert(db, 'submissions', {
    id, assignment_id, student_id: student.id, file_id: storedFileId,
    file_name: file_name || '', score: '', feedback: '', status: 'Submitted',
    submitted_at: new Date().toISOString(),
  })
  return { id, assignment_id, status: 'Submitted' }
}

/** Mobile: teacher lists all submissions for one assignment */
function mobileGetAssignmentSubmissions(db, params, user) {
  assertTeacherOrAdmin(user)
  const row = assertOwnsAssignment(db, user, params.assignment_id || params.id)
  const subs = getAll(db, 'submissions', 'assignment_id = ?', row.id)
  return subs.map(s => serializeSubmission(db, s))
}

/** Mobile: teacher grades a submission (0-100) */
function mobileGradeSubmission(db, params, user) {
  assertTeacherOrAdmin(user)
  const sub = getById(db, 'submissions', params.submission_id || params.id)
  if (!sub) throw { status: 404, message: 'Submission not found' }
  assertOwnsAssignment(db, user, sub.assignment_id)

  const grade = Number(params.grade)
  if (!Number.isFinite(grade) || grade < 0 || grade > 100) {
    throw { status: 400, message: 'Grade must be a number between 0 and 100' }
  }
  updateById(db, 'submissions', sub.id, {
    score: String(grade),
    feedback: params.feedback ?? sub.feedback ?? '',
    status: 'Graded',
  })
  return serializeSubmission(db, getById(db, 'submissions', sub.id))
}

/** Mobile: teacher returns a submission so the student can revise and resubmit */
function mobileUnsubmitSubmission(db, params, user) {
  assertTeacherOrAdmin(user)
  const sub = getById(db, 'submissions', params.submission_id || params.id)
  if (!sub) throw { status: 404, message: 'Submission not found' }
  assertOwnsAssignment(db, user, sub.assignment_id)
  updateById(db, 'submissions', sub.id, { status: 'Returned', score: '', feedback: '' })
  return serializeSubmission(db, getById(db, 'submissions', sub.id))
}

/** Mobile: teacher deletes a submission (student can resubmit fresh) */
function mobileDeleteSubmission(db, params, user) {
  assertTeacherOrAdmin(user)
  const sub = getById(db, 'submissions', params.submission_id || params.id)
  if (!sub) throw { status: 404, message: 'Submission not found' }
  assertOwnsAssignment(db, user, sub.assignment_id)
  deleteById(db, 'submissions', sub.id)
  return { id: sub.id, deleted: true }
}

/** Mobile: download an uploaded file (assignment attachment or submission) */
function mobileGetFile(db, params, user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  const id = params.file_id || params.id
  if (!id) throw { status: 400, message: 'file_id is required' }
  const row = db.prepare('SELECT * FROM file_blobs WHERE id = ?').get(id)
  if (!row) throw { status: 404, message: 'File not found' }
  return { id: row.id, name: row.name, mime_type: row.mime_type, size: row.size, data: row.data }
}

/** Mobile: get teacher's assignments (with submission stats) */
function mobileGetTeacherAssignments(db, params, user) {
  assertTeacherOrAdmin(user)
  const classIds = JSON.parse(user.class_ids || '[]')
  if (classIds.length === 0) return []
  let all = []
  for (const cid of classIds) {
    all = all.concat(getAll(db, 'assignments', 'class_id = ?', cid))
  }
  // Dedupe (a class could theoretically appear twice) and enrich
  const seen = new Set()
  return all.filter(a => (seen.has(a.id) ? false : (seen.add(a.id), true)))
    .map(a => serializeAssignment(db, a))
}

/** Mobile: get school profile */
function mobileGetSchoolProfile(db, params, user) {
  if (!user || !user.school_id) throw { status: 400, message: 'No school associated' }
  const school = getById(db, 'schools', user.school_id)
  if (!school) throw { status: 404, message: 'School not found' }
  return school
}

/** Mobile: admin dashboard stats */
function mobileGetAdminStats(db, params, user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  const school = user.school_id
  if (!school) return { teachers: 0, students: 0, classes: 0, assignments: 0 }
  return {
    teachers: count(db, 'users', "role = 'Teacher' AND school_id = ?", school),
    students: count(db, 'students', 'school_id = ?', school),
    classes: count(db, 'classes', 'school_id = ?', school),
    assignments: count(db, 'assignments', 'school_id = ?', school),
  }
}

// ─── Super Admin handlers ───────────────────────────────────────────

function superAdminLogin(db, params) {
  const { usr, pwd } = params
  if (!usr || !pwd) throw { status: 400, message: 'Email and password are required' }
  if (String(usr).length > MAX_EMAIL || String(pwd).length > MAX_PASSWORD) {
    throw { status: 400, message: 'Input too long' }
  }

  const user = getOne(db, 'users', 'email', usr)
  if (!user || !verifyPassword(pwd, user.password)) {
    throw { status: 401, message: 'Invalid email or password' }
  }
  if (user.role !== 'Administrator') {
    throw { status: 403, message: 'Access denied. This console is for the Super Admin only.' }
  }
  if (user.status === 'Inactive') {
    throw { status: 403, message: 'This account is disabled.' }
  }

  clearFailures(usr)
  const sid = createSession(db, user.id)
  const school = user.school_id ? getById(db, 'schools', user.school_id) : null
  return { ...publicUser(user, school?.name), _sid: sid }
}

function superAdminGetSession(db, _params, user, sid) {
  if (!user) return { message: 'Not logged in', isLoggedIn: false }
  return { message: 'Logged in', isLoggedIn: true, ...publicUser(user), _sid: sid }
}

function superAdminLogout(db, _params, _user, sid) {
  destroySession(db, sid)
  return { message: 'Logged out' }
}

function superAdminUpdateProfile(db, params, user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  const name = params.full_name?.trim()
  if (!name || name.length < 2) throw { status: 400, message: 'Name must be at least 2 characters long' }
  updateById(db, 'users', user.id, { full_name: name })
  return publicUser({ ...user, full_name: name })
}

function superAdminChangePassword(db, params, user) {
  if (!user) throw { status: 401, message: 'Not signed in' }
  if (!verifyPassword(params.current_password, user.password)) {
    throw { status: 400, message: 'Current password is incorrect' }
  }
  if (!params.new_password || params.new_password.length < 6) {
    throw { status: 400, message: 'New password must be at least 6 characters long' }
  }
  if (params.new_password === params.current_password) {
    throw { status: 400, message: 'New password must be different from the current password' }
  }
  updateById(db, 'users', user.id, { password: hashPassword(params.new_password) })
  return { message: 'Password updated successfully' }
}

function superAdminOverview(db, params, user, sid, bothDbs) {
  const schools = getAll(db, 'schools').map(s => ({
    ...s,
    admin_names: getAll(db, 'users', "role = 'School Admin' AND school_id = ?", s.id).map(a => a.full_name),
  }))

  // Pull live counts from the schooladmin database if available
  let totalTeachers = 0, totalClasses = 0, totalStudents = 0
  if (bothDbs?.sa) {
    try {
      totalTeachers = count(bothDbs.sa, 'users', "role = 'Teacher'")
      totalClasses = count(bothDbs.sa, 'classes')
      totalStudents = count(bothDbs.sa, 'students')
    } catch (_e) {
      // Fall back to stored counts
      totalTeachers = schools.reduce((a, s) => a + (s.teacher_count || 0), 0)
      totalClasses = schools.reduce((a, s) => a + (s.class_count || 0), 0)
      totalStudents = schools.reduce((a, s) => a + (s.student_count || 0), 0)
    }
  } else {
    totalTeachers = schools.reduce((a, s) => a + (s.teacher_count || 0), 0)
    totalClasses = schools.reduce((a, s) => a + (s.class_count || 0), 0)
    totalStudents = schools.reduce((a, s) => a + (s.student_count || 0), 0)
  }

  return {
    school_count: schools.filter(s => s.status === 'Active').length,
    disabled_school_count: schools.filter(s => s.status === 'Disabled').length,
    school_admin_count: count(db, 'users', "role = 'School Admin'"),
    teacher_count: totalTeachers,
    class_count: totalClasses,
    student_count: totalStudents,
    recent_schools: schools.slice(0, 4),
  }
}

function superAdminSchools(db, params, user, sid, bothDbs) {
  return getAll(db, 'schools').map(s => {
    // Pull live counts from schooladmin.db if available
    let teacherCount = s.teacher_count || 0
    let classCount = s.class_count || 0
    let studentCount = s.student_count || 0
    if (bothDbs?.sa) {
      try {
        teacherCount = count(bothDbs.sa, 'users', "role = 'Teacher' AND school_id = ?", s.id)
        classCount = count(bothDbs.sa, 'classes', 'school_id = ?', s.id)
        studentCount = count(bothDbs.sa, 'students', 'school_id = ?', s.id)
      } catch (_e) {}
    }
    return {
      ...s,
      teacher_count: teacherCount,
      class_count: classCount,
      student_count: studentCount,
      admin_names: getAll(db, 'users', "role = 'School Admin' AND school_id = ?", s.id).map(a => a.full_name),
    }
  })
}

function superAdminCreateSchool(db, params, user, sid, bothDbs) {
  const name = params.name?.trim()
  if (!name) throw { status: 400, message: 'School name is required' }
  if (name.length > MAX_NAME) throw { status: 400, message: 'School name is too long' }
  const id = genId('s-')
  insert(db, 'schools', { id, name, location: params.location || '',
    status: params.status || 'Active', established: Number(params.established) || new Date().getFullYear(),
    teacher_count: 0, class_count: 0, student_count: 0 })

  // Sync: also create the school in the schooladmin database
  if (bothDbs?.sa) {
    try {
      insert(bothDbs.sa, 'schools', { id, name, location: params.location || '',
        status: params.status || 'Active', established: Number(params.established) || new Date().getFullYear(),
        periods: '[]' })
    } catch (_e) { /* may already exist */ }
  }

  return { id, name, location: params.location || '', status: params.status || 'Active',
    established: Number(params.established) || new Date().getFullYear(), teacher_count: 0,
    class_count: 0, student_count: 0, admin_names: [] }
}

function superAdminUpdateSchool(db, params, user, sid, bothDbs) {
  const s = getById(db, 'schools', params.id)
  if (!s) throw { status: 404, message: 'School not found' }
  const name = params.name?.trim()
  if (!name) throw { status: 400, message: 'School name is required' }
  const updates = { name }
  if (params.location) updates.location = params.location
  if (params.established) updates.established = Number(params.established)
  if (params.status) updates.status = params.status
  updateById(db, 'schools', params.id, updates)

  // Sync: also update in the schooladmin database
  if (bothDbs?.sa) {
    const saUpdates = { name }
    if (params.location) saUpdates.location = params.location
    if (params.established) saUpdates.established = Number(params.established)
    if (params.status) saUpdates.status = params.status
    try { updateById(bothDbs.sa, 'schools', params.id, saUpdates) } catch (_e) {}
  }

  return { ...s, ...updates }
}

function superAdminSetSchoolStatus(db, params, user, sid, bothDbs) {
  const s = getById(db, 'schools', params.id)
  if (!s) throw { status: 404, message: 'School not found' }
  const status = params.status === 'Disabled' ? 'Disabled' : 'Active'
  updateById(db, 'schools', params.id, { status })

  // Sync: also update in the schooladmin database
  if (bothDbs?.sa) {
    try { updateById(bothDbs.sa, 'schools', params.id, { status }) } catch (_e) {}
  }

  return { ...s, status }
}

function superAdminDeleteSchool(db, params, user, sid, bothDbs) {
  const s = getById(db, 'schools', params.id)
  if (!s) throw { status: 404, message: 'School not found' }
  // Cascade: remove school admins from superadmin db
  const admins = getAll(db, 'users', "role = 'School Admin' AND school_id = ?", params.id)
  for (const a of admins) deleteById(db, 'users', a.id)
  deleteById(db, 'schools', params.id)

  // Sync: also remove from the schooladmin database
  if (bothDbs?.sa) {
    try {
      const saAdmins = getAll(bothDbs.sa, 'users', "role = 'School Admin' AND school_id = ?", params.id)
      for (const a of saAdmins) deleteById(bothDbs.sa, 'users', a.id)
      // Also cascade: remove teachers, students, classes for this school
      const teachers = getAll(bothDbs.sa, 'users', "role = 'Teacher' AND school_id = ?", params.id)
      for (const t of teachers) deleteById(bothDbs.sa, 'users', t.id)
      const classes = getAll(bothDbs.sa, 'classes', 'school_id = ?', params.id)
      for (const c of classes) {
        deleteWhere(bothDbs.sa, 'students', 'class_id', c.id)
        deleteById(bothDbs.sa, 'classes', c.id)
      }
      deleteWhere(bothDbs.sa, 'students', 'school_id', params.id)
      deleteById(bothDbs.sa, 'schools', params.id)
    } catch (_e) {}
  }

  return { message: 'School deleted', id: params.id }
}

function superAdminSchoolAdmins(db, params) {
  let users = getAll(db, 'users', "role = 'School Admin'")
  if (params.school) users = users.filter(u => u.school_id === params.school)
  return users.map(u => ({
    id: u.id, name: u.full_name, email: u.email, role: u.role,
    school_id: u.school_id, status: u.status || 'Active',
  }))
}

function superAdminCreateSchoolAdmin(db, params, user, sid, bothDbs) {
  const name = params.name?.trim()
  const email = params.email?.trim().toLowerCase()
  if (!name) throw { status: 400, message: 'Name is required' }
  if (!email) throw { status: 400, message: 'Email is required' }
  if (!params.password) throw { status: 400, message: 'Password is required' }
  if (name.length > MAX_NAME) throw { status: 400, message: 'Name is too long' }
  if (email.length > MAX_EMAIL) throw { status: 400, message: 'Email is too long' }
  if (String(params.password).length > MAX_PASSWORD) throw { status: 400, message: 'Password is too long' }
  if (getOne(db, 'users', 'email', email)) throw { status: 400, message: 'An account with this email already exists' }
  if (!getById(db, 'schools', params.school)) throw { status: 400, message: 'Unknown school' }

  const id = genId('u-')
  const hashedPw = hashPassword(params.password)
  insert(db, 'users', { id, email, password: hashedPw, full_name: name,
    role: 'School Admin', school_id: params.school, status: 'Active' })

  // Sync: also create the school admin in the schooladmin database
  if (bothDbs?.sa) {
    try {
      insert(bothDbs.sa, 'users', { id, email, password: hashedPw, full_name: name,
        role: 'School Admin', school_id: params.school, class_ids: '[]', subjects: '[]', status: 'Active' })
    } catch (_e) { /* may already exist */ }
  }

  return { id, name, email, role: 'School Admin', school_id: params.school, status: 'Active' }
}

function superAdminUpdateSchoolAdmin(db, params, user, sid, bothDbs) {
  const u = getById(db, 'users', params.id)
  if (!u || u.role !== 'School Admin') throw { status: 404, message: 'School admin not found' }
  const name = params.name?.trim()
  const email = params.email?.trim().toLowerCase()
  if (!name) throw { status: 400, message: 'Name is required' }
  if (!email) throw { status: 400, message: 'Email is required' }

  const existing = getOne(db, 'users', 'email', email)
  if (existing && existing.id !== params.id) throw { status: 400, message: 'An account with this email already exists' }

  const updates = { full_name: name, email }
  if (params.school) updates.school_id = params.school
  if (params.password) updates.password = hashPassword(params.password)
  updateById(db, 'users', params.id, updates)

  // Sync: also update in the schooladmin database
  if (bothDbs?.sa) {
    const saUpdates = { full_name: name, email }
    if (params.school) saUpdates.school_id = params.school
    if (params.password) saUpdates.password = hashPassword(params.password)
    try { updateById(bothDbs.sa, 'users', params.id, saUpdates) } catch (_e) {}
  }

  return { id: params.id, name, email, role: 'School Admin',
    school_id: params.school || u.school_id, status: u.status }
}

function superAdminSetSchoolAdminStatus(db, params, user, sid, bothDbs) {
  const u = getById(db, 'users', params.id)
  if (!u || u.role !== 'School Admin') throw { status: 404, message: 'School admin not found' }
  const status = params.status === 'Inactive' ? 'Inactive' : 'Active'
  updateById(db, 'users', params.id, { status })

  // Sync: also update in the schooladmin database
  if (bothDbs?.sa) {
    try { updateById(bothDbs.sa, 'users', params.id, { status }) } catch (_e) {}
  }

  return { id: params.id, name: u.full_name, email: u.email, role: 'School Admin',
    school_id: u.school_id, status }
}

// ─── Handler registry ───────────────────────────────────────────────

const SA_HANDLERS = {
  'school_connect.api.auth.login': schoolAdminLogin,
  'school_connect.api.auth.get_session': schoolAdminGetSession,
  'school_connect.api.auth.logout': schoolAdminLogout,
  'school_connect.api.auth.update_profile': schoolAdminUpdateProfile,
  'school_connect.api.auth.change_password': schoolAdminChangePassword,
  'school_connect.api.mobile.login': mobileLogin,
  'school_connect.api.admin.get_admin_dashboard': schoolAdminDashboard,
  'school_connect.api.admin.get_admin_teachers': schoolAdminTeachers,
  'school_connect.api.admin.create_teacher': schoolAdminCreateTeacher,
  'school_connect.api.admin.update_teacher': schoolAdminUpdateTeacher,
  'school_connect.api.admin.set_teacher_status': schoolAdminSetTeacherStatus,
  'school_connect.api.admin.get_admin_classes': schoolAdminClasses,
  'school_connect.api.admin.get_admin_class': schoolAdminClassDetail,
  'school_connect.api.admin.create_class': schoolAdminCreateClass,
  'school_connect.api.admin.update_class': schoolAdminUpdateClass,
  'school_connect.api.admin.delete_class': schoolAdminDeleteClass,
  'school_connect.api.admin.get_admin_students': schoolAdminStudents,
  'school_connect.api.admin.get_admin_student': schoolAdminStudentDetail,
  'school_connect.api.admin.create_student': schoolAdminCreateStudent,
  'school_connect.api.admin.update_student': schoolAdminUpdateStudent,
  'school_connect.api.admin.delete_student': schoolAdminDeleteStudent,
  'school_connect.api.admin.set_student_status': schoolAdminSetStudentStatus,
  'school_connect.api.admin.get_timetable': schoolAdminTimetable,
  'school_connect.api.admin.set_timetable_entry': schoolAdminSetTimetableEntry,
  'school_connect.api.admin.update_timetable_periods': schoolAdminUpdateTimetablePeriods,
  'school_connect.api.admin.remove_timetable_entry': schoolAdminRemoveTimetableEntry,
  // Mobile app endpoints
  'school_connect.api.auth.social_login': mobileSocialLogin,
  'school_connect.api.mobile.get_profile': mobileGetProfile,
  'school_connect.api.mobile.get_teacher_classes': mobileGetTeacherClasses,
  'school_connect.api.mobile.get_class_students': mobileGetClassStudents,
  'school_connect.api.mobile.get_teacher_schedule': mobileGetTeacherSchedule,
  'school_connect.api.mobile.get_student_schedule': mobileGetStudentSchedule,
  'school_connect.api.mobile.get_student_assignments': mobileGetStudentAssignments,
  'school_connect.api.mobile.get_my_attendance': mobileGetMyAttendance,
  'school_connect.api.mobile.mark_attendance': mobileMarkAttendance,
  'school_connect.api.mobile.create_assignment': mobileCreateAssignment,
  'school_connect.api.mobile.update_assignment': mobileUpdateAssignment,
  'school_connect.api.mobile.delete_assignment': mobileDeleteAssignment,
  'school_connect.api.mobile.submit_assignment': mobileSubmitAssignment,
  'school_connect.api.mobile.get_teacher_assignments': mobileGetTeacherAssignments,
  'school_connect.api.mobile.get_assignment_submissions': mobileGetAssignmentSubmissions,
  'school_connect.api.mobile.grade_submission': mobileGradeSubmission,
  'school_connect.api.mobile.unsubmit_submission': mobileUnsubmitSubmission,
  'school_connect.api.mobile.delete_submission': mobileDeleteSubmission,
  'school_connect.api.mobile.get_file': mobileGetFile,
  'school_connect.api.mobile.get_school_profile': mobileGetSchoolProfile,
  'school_connect.api.mobile.get_admin_stats': mobileGetAdminStats,
}

const SU_HANDLERS = {
  'school_connect.api.auth.login': superAdminLogin,
  'school_connect.api.auth.get_session': superAdminGetSession,
  'school_connect.api.auth.logout': superAdminLogout,
  'school_connect.api.auth.social_login': mobileSocialLogin,
  'school_connect.api.auth.update_profile': superAdminUpdateProfile,
  'school_connect.api.auth.change_password': superAdminChangePassword,
  'school_connect.api.admin.overview': superAdminOverview,
  'school_connect.api.admin.get_admin_dashboard': superAdminOverview, // alias
  'school_connect.api.admin.get_schools': superAdminSchools,
  'school_connect.api.admin.create_school': superAdminCreateSchool,
  'school_connect.api.admin.update_school': superAdminUpdateSchool,
  'school_connect.api.admin.set_school_status': superAdminSetSchoolStatus,
  'school_connect.api.admin.delete_school': superAdminDeleteSchool,
  'school_connect.api.admin.get_school_admins': superAdminSchoolAdmins,
  'school_connect.api.admin.create_school_admin': superAdminCreateSchoolAdmin,
  'school_connect.api.admin.update_school_admin': superAdminUpdateSchoolAdmin,
  'school_connect.api.admin.set_school_admin_status': superAdminSetSchoolAdminStatus,
}

/**
 * List all endpoint names for a console.
 * @param {'schooladmin'|'superadmin'} consoleName
 */
export function listEndpoints(consoleName) {
  return consoleName === 'schooladmin' ? Object.keys(SA_HANDLERS) : Object.keys(SU_HANDLERS)
}

/**
 * Handle an API request.
 * @param {'schooladmin'|'superadmin'} consoleName
 * @param {{ sa: DatabaseSync, su: DatabaseSync }} bothDbs
 * @param {string} path — API method path
 * @param {object} req — { method, params, body, headers, ip }
 * @returns {{ data: any, _sid?: string }}
 */
export function handleRequest(consoleName, bothDbs, path, req) {
  const handlers = consoleName === 'schooladmin' ? SA_HANDLERS : SU_HANDLERS
  const db = consoleName === 'schooladmin' ? bothDbs.sa : bothDbs.su
  const handler = handlers[path]
  if (!handler) throw { status: 404, message: 'Not found' }

  const allParams = { ...req.params, ...req.body }

  // Get session user
  const sid = req.sid
  const user = getSessionUser(db, sid)

  // CSRF check
  if (!checkCsrf(req, user, path)) {
    throw { status: 403, message: 'CSRF token missing or invalid', exc_type: 'CSRFError' }
  }

  // Rate limiting (only for login)
  const isLogin = path === 'school_connect.api.auth.login' || path === 'school_connect.api.mobile.login'
  if (isLogin) {
    const loginEmail = allParams.usr || allParams.email
    if (loginEmail && isLocked(loginEmail)) {
      throw { status: 429, message: 'Account temporarily locked due to too many failed attempts', exc_type: 'LockoutError' }
    }
    if (!checkRateLimit(req.ip)) {
      throw { status: 429, message: 'Too many requests', exc_type: 'RateLimitError' }
    }
  }

  try {
    const result = handler(db, allParams, user, sid, bothDbs)
    const sidOut = result?._sid
    if (sidOut) delete result._sid

    // Record login failures
    if (isLogin) {
      // If we got here without throwing, login succeeded
      // Failures are cleared in the login handlers
    }

    return { data: result, _sid: sidOut }
  } catch (err) {
    // Record failure for login attempts
    if (isLogin && (!err.status || err.status === 401 || err.status === 403)) {
      recordFailure(allParams.usr || allParams.email)
    }
    throw err
  }
}

export { recordFailure, checkRateLimit, failures, ipAttempts }
