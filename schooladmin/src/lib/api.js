/**
 * API client.
 *
 * Three modes, flipped by env var:
 *   VITE_APP_MODE=mock   — in-browser mock backend (lib/mock.js)
 *   VITE_APP_MODE=sheets — direct Google Sheets API (lib/sheets.js)
 *   VITE_APP_MODE=live   — real backend (legacy, same as sheets)
 *
 * In sheets mode, the browser talks directly to Google Sheets API using the
 * user's own Google OAuth token. No server needed.
 */

import { mockRequest } from './mock'
import * as sheets from './sheets'
import { CSRF_KEY } from './keys'
import { DAYS } from './timetable'

const MODE = import.meta.env.VITE_APP_MODE || 'live'
const API_BASE = (import.meta.env.VITE_API_URL || '').replace(/\/$/, '')

export const isMockMode = MODE === 'mock'
const isLiveMode = MODE === 'live'
export const isSheetsMode = MODE === 'sheets'

// ─── Sheets mode helpers ─────────────────────────────────────────────

function parseRole(roleStr) {
  const r = (roleStr || '').toLowerCase()
  if (r === 'super admin') return 'Super Admin'
  if (r === 'school admin') return 'School Admin'
  if (r === 'teacher' || r === 'instructor') return 'Teacher'
  if (r === 'student') return 'Student'
  return 'Student'
}

let currentSchoolId = null
let currentUser = null

async function sheetsLogin(usr, pwd) {
  // In sheets mode, we use Google Sign-In.
  // This fallback is for testing with email/password stored in the sheet.
  const user = await sheets.findOne('Users', 'email', usr)
  if (!user) throw new Error('User not found')
  if (user.password !== pwd && user.password_hash !== pwd) throw new Error('Invalid password')
  if (user.role !== 'School Admin') throw new Error('Access denied. This console is for School Admins only.')
  if (user.status === 'Inactive') throw new Error('This account is disabled.')

  currentSchoolId = user.school_id
  currentUser = { ...user, role: parseRole(user.role) }

  const school = await sheets.findOne('Schools', 'id', currentSchoolId)
  return {
    name: user.id,
    email: user.email,
    full_name: user.name,
    role: user.role,
    roles: [user.role],
    school: user.school_id,
    school_name: school?.name || null,
  }
}

async function sheetsGoogleLogin() {
  // Use the Google account's email to look up the user
  const user = await sheets.findOne('Users', 'email', currentUser?.email || '')
  if (!user) throw new Error('User not found in spreadsheet')
  if (user.role !== 'School Admin') throw new Error('Access denied.')

  currentSchoolId = user.school_id
  return {
    name: user.id,
    email: user.email,
    full_name: user.name,
    role: user.role,
    roles: [user.role],
    school: user.school_id,
  }
}

// ─── Request routing ─────────────────────────────────────────────────

function toQuery(params) {
  const q = new URLSearchParams()
  for (const [k, v] of Object.entries(params || {})) {
    if (v !== undefined && v !== null && v !== '') q.set(k, v)
  }
  const s = q.toString()
  return s ? `?${s}` : ''
}

export function getCsrf() {
  return localStorage.getItem(CSRF_KEY) || ''
}

export function setCsrf(token) {
  if (token) localStorage.setItem(CSRF_KEY, token)
}

async function liveRequest(path, { method = 'GET', params = {}, body = {} } = {}) {
  const url = `${API_BASE}/api/method/${path}${method === 'GET' ? toQuery(params) : ''}`
  const headers = { Accept: 'application/json' }
  const opts = { method, credentials: 'include', headers }

  if (method !== 'GET') {
    headers['Content-Type'] = 'application/json'
    const csrf = getCsrf()
    if (csrf) headers['X-Frappe-CSRF-Token'] = csrf
    opts.body = JSON.stringify(body)
  }

  let res
  try {
    res = await fetch(url, opts)
  } catch {
    throw new Error('Cannot reach the server. Is the backend running?')
  }

  let json = null
  try {
    json = await res.json()
  } catch {
    /* non-JSON response */
  }

  if (!res.ok || (json && json.exc)) {
    const message =
      (json && (json._server_messages?.[0] || json.exc_type || json.message)) ||
      `Request failed (${res.status})`
    const err = new Error(message)
    err.status = res.status
    throw err
  }
  return json?.message ?? json
}

function mockRequestWrapper(path, opts) {
  const ms = 250 + Math.random() * 350
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      try {
        const result = mockRequest(path, opts)
        resolve(result && 'data' in result ? result.data : result)
      } catch (e) {
        const err = new Error(e.message || 'Request failed')
        err.status = e.status || 500
        reject(err)
      }
    }, ms)
  })
}

async function sheetsRequestWrapper(path, opts = {}) {
  const key = path.replace(/^\/?api\/method\//, '')
  const handler = SHEETS_HANDLERS[key]
  if (!handler) {
    // Fall back to mock for unimplemented endpoints
    return mockRequestWrapper(path, opts)
  }
  return handler({ ...opts.params, ...opts.body })
}

// ─── Google Sheets API handlers (mirror mock.js) ───────────────────
// Each handler reads/writes directly to the spreadsheet tabs.

const SHEETS_HANDLERS = {
  // ── Auth ──────────────────────────────────────────────────────────
  'school_connect.api.auth.login': async (params) => {
    const user = await sheets.findOne('Users', 'email', params.usr)
    if (!user) throw { status: 401, message: 'Invalid email or password' }
    if (user.password !== params.pwd) throw { status: 401, message: 'Invalid email or password' }
    if (user.role !== 'School Admin') throw { status: 403, message: 'Access denied. This console is for School Admins only.' }
    if (user.status === 'Inactive') throw { status: 403, message: 'This account is disabled.' }

    currentSchoolId = user.school_id
    currentUser = { ...user, role: parseRole(user.role) }

    const school = await sheets.findOne('Schools', 'id', currentSchoolId)
    return {
      name: user.id,
      email: user.email,
      full_name: user.name,
      role: user.role,
      roles: [user.role],
      school: user.school_id,
      school_name: school?.name || null,
    }
  },

  'school_connect.api.auth.logout': () => ({ message: 'Logged out' }),

  'school_connect.api.auth.update_profile': async (params) => {
    const name = params.full_name?.trim()
    if (!name || name.length < 2) throw { status: 400, message: 'Name must be at least 2 characters long' }
    await sheets.updateWhere('Users', 'id', currentUser.id, { name })
    currentUser.name = name
    return {
      name: currentUser.id,
      email: currentUser.email,
      full_name: name,
      role: currentUser.role,
      roles: [currentUser.role],
      school: currentUser.school_id,
    }
  },

  'school_connect.api.auth.change_password': async (params) => {
    if (!currentUser) throw { status: 401, message: 'Not signed in' }
    if (params.current_password !== currentUser.password) {
      throw { status: 400, message: 'Current password is incorrect' }
    }
    if (!params.new_password || params.new_password.length < 6) {
      throw { status: 400, message: 'New password must be at least 6 characters long' }
    }
    await sheets.updateWhere('Users', 'id', currentUser.id, { password: params.new_password })
    currentUser.password = params.new_password
    return { message: 'Password updated successfully' }
  },

  // ── Dashboard ─────────────────────────────────────────────────────
  'school_connect.api.admin.get_admin_dashboard': async (params) => {
    const school = params.school || currentSchoolId
    const classes = await sheets.findMany('Classes', 'school_id', school)
    const students = await sheets.findMany('Students', 'school_id', school)
    const users = await sheets.readTab('Users')
    const teachers = users.filter(u => u.role === 'Teacher' && u.school_id === school)

    const recentClasses = classes.slice(0, 4).map(c => {
      const classStudents = students.filter(s => s.class_id === c.id)
      const teacherNames = (c.teacher_ids || '').split(',').map(tid => {
        const t = users.find(u => u.id === tid)
        return t?.name
      }).filter(Boolean)
      return {
        id: c.id, name: c.name, program: c.program, room: c.room,
        student_count: classStudents.length,
        teachers: teacherNames,
      }
    })

    return {
      school_count: 1,
      school_admin_count: users.filter(u => u.role === 'School Admin' && u.school_id === school).length,
      teacher_count: teachers.length,
      class_count: classes.length,
      student_count: students.length,
      attendance_avg: students.length
        ? Math.round(students.reduce((a, s) => a + (Number(s.attendance_pct) || 0), 0) / students.length)
        : 0,
      recent_classes: recentClasses,
    }
  },

  // ── Teachers ──────────────────────────────────────────────────────
  'school_connect.api.admin.get_admin_teachers': async (params) => {
    const school = params.school || currentSchoolId
    const users = await sheets.readTab('Users')
    const classes = await sheets.findMany('Classes', 'school_id', school)
    const schools = await sheets.readTab('Schools')
    return users
      .filter(u => u.role === 'Teacher' && (!school || u.school_id === school))
      .map(u => {
        const classIds = (u.class_ids || '').split(',').filter(Boolean)
        const classNames = classIds.map(cid => classes.find(c => c.id === cid)?.name).filter(Boolean)
        const schoolName = schools.find(s => s.id === u.school_id)?.name || null
        return {
          id: u.id,
          name: u.name,
          email: u.email,
          subjects: (u.subjects || u.subject || 'General').split(',').map(s => s.trim()).filter(Boolean),
          subject: (u.subjects || u.subject || 'General').split(',')[0].trim(),
          school_id: u.school_id,
          school_name: schoolName,
          classes: classNames,
          class_ids: classIds,
          status: u.status || 'Active',
        }
      })
  },

  'school_connect.api.admin.create_teacher': async (params) => {
    const name = params.name?.trim()
    const email = params.email?.trim().toLowerCase()
    if (!name) throw { status: 400, message: 'Name is required' }
    if (!email) throw { status: 400, message: 'Email is required' }
    if (!params.password) throw { status: 400, message: 'Password is required' }

    const existing = await sheets.findOne('Users', 'email', email)
    if (existing) throw { status: 400, message: 'An account with this email already exists' }

    const schoolId = params.school || currentSchoolId
    const id = sheets.genId('t-')
    const subjects = Array.isArray(params.subjects) ? params.subjects.join(',') : (params.subject || 'General')
    const classIds = Array.isArray(params.class_ids) ? params.class_ids.join(',') : ''

    await sheets.appendRow('Users', [
      id, email, name, 'Teacher', schoolId, '', classIds, subjects, params.password, 'Active',
    ])

    return {
      name: id, email, full_name: name, role: 'Teacher',
      roles: ['Teacher'], school: schoolId,
      subjects: subjects.split(','), subject: subjects.split(',')[0],
      classes: [], class_ids: classIds.split(',').filter(Boolean),
      status: 'Active',
    }
  },

  'school_connect.api.admin.update_teacher': async (params) => {
    const user = await sheets.findOne('Users', 'id', params.id)
    if (!user || user.role !== 'Teacher') throw { status: 404, message: 'Teacher not found' }

    const name = params.name?.trim()
    const email = params.email?.trim().toLowerCase()
    if (!name) throw { status: 400, message: 'Name is required' }
    if (!email) throw { status: 400, message: 'Email is required' }

    const updates = { name, email }
    if (Array.isArray(params.subjects)) updates.subjects = params.subjects.join(',')
    else if (params.subject) updates.subjects = params.subject
    if (params.password) updates.password = params.password
    if (Array.isArray(params.class_ids)) updates.class_ids = params.class_ids.join(',')

    await sheets.updateWhere('Users', 'id', params.id, updates)

    return {
      name: params.id, email, full_name: name, role: 'Teacher',
      roles: ['Teacher'], school: user.school_id,
      ...(updates.subjects && { subjects: updates.subjects.split(','), subject: updates.subjects.split(',')[0] }),
      ...(updates.class_ids && { class_ids: updates.class_ids.split(',').filter(Boolean) }),
    }
  },

  'school_connect.api.admin.set_teacher_status': async (params) => {
    const user = await sheets.findOne('Users', 'id', params.id)
    if (!user || user.role !== 'Teacher') throw { status: 404, message: 'Teacher not found' }
    const status = params.status === 'Inactive' ? 'Inactive' : 'Active'
    await sheets.updateWhere('Users', 'id', params.id, { status })
    return { name: params.id, email: user.email, full_name: user.name, role: 'Teacher', status }
  },

  // ── Classes ───────────────────────────────────────────────────────
  'school_connect.api.admin.get_admin_classes': async (params) => {
    const school = params.school || currentSchoolId
    const classes = await sheets.findMany('Classes', 'school_id', school)
    const students = await sheets.findMany('Students', 'school_id', school)
    const users = await sheets.readTab('Users')

    return classes.map(c => {
      const classStudents = students.filter(s => s.class_id === c.id)
      const teacherNames = (c.teacher_ids || '').split(',').map(tid => {
        const t = users.find(u => u.id === tid)
        return t?.name
      }).filter(Boolean)
      return {
        id: c.id, name: c.name, program: c.program, room: c.room,
        school_id: c.school_id, student_count: classStudents.length,
        teachers: teacherNames,
      }
    })
  },

  'school_connect.api.admin.get_admin_class': async (params) => {
    const c = await sheets.findOne('Classes', 'id', params.id)
    if (!c) throw { status: 404, message: 'Class not found' }

    const students = await sheets.findMany('Students', 'class_id', c.id)
    const users = await sheets.readTab('Users')
    const school = c.school_id ? await sheets.findOne('Schools', 'id', c.school_id) : null
    const teacherNames = (c.teacher_ids || '').split(',').map(tid => {
      const t = users.find(u => u.id === tid)
      return t?.name
    }).filter(Boolean)

    return {
      id: c.id, name: c.name, program: c.program, room: c.room,
      school_id: c.school_id, teachers: teacherNames,
      students: students
        .sort((a, b) => (Number(a.roll_number) || 0) - (Number(b.roll_number) || 0))
        .map(s => ({ ...s, school_name: school?.name || null })),
    }
  },

  'school_connect.api.admin.create_class': async (params) => {
    const name = params.name?.trim()
    if (!name) throw { status: 400, message: 'Class name is required' }
    const schoolId = params.school || currentSchoolId
    const id = sheets.genId('c-')
    const teacherIds = Array.isArray(params.teacher_ids) ? params.teacher_ids.join(',') : ''

    await sheets.appendRow('Classes', [
      id, name, params.program?.trim() || '', schoolId, params.room?.trim() || '', teacherIds,
    ])
    return { id, name, program: params.program || '', room: params.room || '', school_id: schoolId, teacher_ids: teacherIds.split(',').filter(Boolean) }
  },

  'school_connect.api.admin.update_class': async (params) => {
    const c = await sheets.findOne('Classes', 'id', params.id)
    if (!c) throw { status: 404, message: 'Class not found' }
    const name = params.name?.trim()
    if (!name) throw { status: 400, message: 'Class name is required' }

    const updates = { name }
    if (params.program) updates.program = params.program.trim()
    if (params.room) updates.room = params.room.trim()
    if (Array.isArray(params.teacher_ids)) updates.teacher_ids = params.teacher_ids.join(',')

    await sheets.updateWhere('Classes', 'id', params.id, updates)
    return { ...c, ...updates, teacher_ids: (updates.teacher_ids || c.teacher_ids || '').split(',').filter(Boolean) }
  },

  'school_connect.api.admin.delete_class': async (params) => {
    const c = await sheets.findOne('Classes', 'id', params.id)
    if (!c) throw { status: 404, message: 'Class not found' }
    // Cascade: delete students in this class
    const students = await sheets.findMany('Students', 'class_id', params.id)
    for (const s of students) {
      await sheets.deleteWhere('Students', 'id', s.id)
    }
    await sheets.deleteWhere('Classes', 'id', params.id)
    return { message: 'Class deleted', id: params.id }
  },

  // ── Students ──────────────────────────────────────────────────────
  'school_connect.api.admin.get_admin_students': async (params) => {
    const school = params.school || currentSchoolId
    let students = await sheets.findMany('Students', 'school_id', school)
    if (params.class) students = students.filter(s => s.class_id === params.class)

    const classes = await sheets.readTab('Classes')
    return students.map(s => {
      const cls = classes.find(c => c.id === s.class_id)
      return { ...s, class_name: cls?.name || null }
    })
  },

  'school_connect.api.admin.get_admin_student': async (params) => {
    const s = await sheets.findOne('Students', 'id', params.id)
    if (!s) throw { status: 404, message: 'Student not found' }
    const cls = await sheets.findOne('Classes', 'id', s.class_id)
    const users = await sheets.readTab('Users')
    const teacherNames = (cls?.teacher_ids || '').split(',').map(tid => {
      const t = users.find(u => u.id === tid)
      return t?.name
    }).filter(Boolean)
    return { ...s, class_name: cls?.name, room: cls?.room, teachers: teacherNames }
  },

  'school_connect.api.admin.create_student': async (params) => {
    const name = params.name?.trim()
    if (!name) throw { status: 400, message: 'Student name is required' }
    const cls = await sheets.findOne('Classes', 'id', params.class_id)
    if (!cls) throw { status: 400, message: 'Unknown class' }
    const email = params.email?.trim().toLowerCase() || ''
    const schoolId = cls.school_id || currentSchoolId

    const existingStudents = await sheets.findMany('Students', 'class_id', cls.id)
    const roll = Number(params.roll_number) || (existingStudents.length ? Math.max(...existingStudents.map(s => Number(s.roll_number) || 0)) + 1 : 1)

    const id = sheets.genId('stu-')
    await sheets.appendRow('Students', [
      id, name, email, roll.toString(), cls.id, schoolId, '0', params.status === 'Inactive' ? 'Inactive' : 'Active',
    ])
    return { id, name, email, roll_number: roll, class_id: cls.id, school_id: schoolId, attendance_pct: 0, status: params.status || 'Active' }
  },

  'school_connect.api.admin.update_student': async (params) => {
    const s = await sheets.findOne('Students', 'id', params.id)
    if (!s) throw { status: 404, message: 'Student not found' }
    const name = params.name?.trim()
    if (!name) throw { status: 400, message: 'Student name is required' }

    const updates = { name }
    if (params.email) updates.email = params.email.trim().toLowerCase()
    if (params.class_id) updates.class_id = params.class_id
    if (params.roll_number) updates.roll_number = params.roll_number.toString()
    if (params.status) updates.status = params.status

    await sheets.updateWhere('Students', 'id', params.id, updates)
    return { ...s, ...updates }
  },

  'school_connect.api.admin.delete_student': async (params) => {
    const s = await sheets.findOne('Students', 'id', params.id)
    if (!s) throw { status: 404, message: 'Student not found' }
    await sheets.deleteWhere('Students', 'id', params.id)
    return { message: 'Student deleted', id: params.id }
  },

  'school_connect.api.admin.set_student_status': async (params) => {
    const s = await sheets.findOne('Students', 'id', params.id)
    if (!s) throw { status: 404, message: 'Student not found' }
    const status = params.status === 'Inactive' ? 'Inactive' : 'Active'
    await sheets.updateWhere('Students', 'id', params.id, { status })
    return { ...s, status }
  },

  // ── Timetable ─────────────────────────────────────────────────────
  'school_connect.api.admin.get_timetable': async (params) => {
    const school = params.school || currentSchoolId
    const classId = params.class
    let entries = await sheets.readTab('Timetable')
    if (classId) entries = entries.filter(e => e.class_id === classId)
    else if (school) entries = entries.filter(e => e.school_id === school)

    const classes = await sheets.readTab('Classes')
    const users = await sheets.readTab('Users')
    const schools = await sheets.readTab('Schools')
    const schoolRecord = schools.find(s => s.id === school)
    const periods = schoolRecord?.periods ? JSON.parse(schoolRecord.periods) : undefined

    const enriched = entries.map(e => {
      const cls = classes.find(c => c.id === e.class_id)
      const teacher = users.find(u => u.id === e.teacher_id)
      return {
        id: e.id, school_id: e.school_id, class_id: e.class_id,
        class_name: cls?.name || null, day: e.day, period: Number(e.period),
        teacher_id: e.teacher_id, teacher_name: teacher?.name || 'Unknown',
        subject: e.subject || 'General',
        teacher_status: teacher?.status || 'Active',
      }
    })

    enriched.sort((a, b) => {
      const d = DAYS.indexOf(a.day) - DAYS.indexOf(b.day)
      return d !== 0 ? d : a.period - b.period
    })
    return { periods: periods || undefined, entries: enriched }
  },

  'school_connect.api.admin.set_timetable_entry': async (params) => {
    const cls = await sheets.findOne('Classes', 'id', params.class_id)
    if (!cls) throw { status: 404, message: 'Class not found' }
    const teacher = await sheets.findOne('Users', 'id', params.teacher_id)
    if (!teacher) throw { status: 400, message: 'Teacher not found' }
    const subject = params.subject?.trim()
    if (!subject) throw { status: 400, message: 'A subject is required' }

    // Check for existing entry in same slot
    const existing = await sheets.readTab('Timetable')
    const clash = existing.find(e => e.class_id === cls.id && e.day === params.day && Number(e.period) === Number(params.period))

    if (clash) {
      await sheets.updateWhere('Timetable', 'id', clash.id, {
        teacher_id: params.teacher_id, subject,
      })
    } else {
      const id = sheets.genId('tt-')
      await sheets.appendRow('Timetable', [
        id, cls.id, params.day, params.period, params.teacher_id, subject, cls.school_id || currentSchoolId,
      ])
    }
    return { message: 'Timetable updated' }
  },

  'school_connect.api.admin.update_timetable_periods': async (params) => {
    const school = await sheets.findOne('Schools', 'id', params.school)
    if (!school) throw { status: 404, message: 'School not found' }
    const periods = Array.isArray(params.periods) ? params.periods : []
    await sheets.updateWhere('Schools', 'id', params.school, {
      periods: JSON.stringify(periods),
    })
    return { message: 'Periods updated', periods }
  },

  'school_connect.api.admin.remove_timetable_entry': async (params) => {
    await sheets.deleteWhere('Timetable', 'id', params.id)
    return { message: 'Timetable entry removed' }
  },
}

export function request(path, opts = {}) {
  if (isMockMode) return mockRequestWrapper(path, opts)
  if (isLiveMode) return liveRequest(path, opts)
  return sheetsRequestWrapper(path, opts)
}

// ─── Exported Google Sheets helpers for direct use ────────────────────

export { sheets as sheetsApi }

export async function googleSignIn() {
  await sheets.initGoogleAuth()
  await sheets.signInWithGoogle()
}

export function googleSignOut() {
  sheets.signOutGoogle()
  currentUser = null
  currentSchoolId = null
}

export function getCurrentUser() {
  return currentUser
}

/* ---------- domain helpers (shared shape with the real API) ---------- */

export const api = {
  async login(usr, pwd) {
    return request('school_connect.api.auth.login', { method: 'POST', body: { usr, pwd } })
  },
  async logout() {
    return request('school_connect.api.auth.logout', { method: 'POST' }).catch(() => null)
  },
  async updateProfile(fullName) {
    return request('school_connect.api.auth.update_profile', { method: 'POST', body: { full_name: fullName } })
  },
  async changePassword(currentPassword, newPassword) {
    return request('school_connect.api.auth.change_password', {
      method: 'POST',
      body: { current_password: currentPassword, new_password: newPassword },
    })
  },
  async getOverview(school) {
    return request('school_connect.api.admin.get_admin_dashboard', { params: { school } })
  },
  async getTeachers(school) {
    return request('school_connect.api.admin.get_admin_teachers', { params: { school } })
  },
  async createTeacher(payload) {
    return request('school_connect.api.admin.create_teacher', { method: 'POST', body: payload })
  },
  async updateTeacher(payload) {
    return request('school_connect.api.admin.update_teacher', { method: 'POST', body: payload })
  },
  async setTeacherStatus(id, status) {
    return request('school_connect.api.admin.set_teacher_status', { method: 'POST', body: { id, status } })
  },
  async getClasses(school) {
    return request('school_connect.api.admin.get_admin_classes', { params: { school } })
  },
  async getClass(id) {
    return request('school_connect.api.admin.get_admin_class', { params: { id } })
  },
  async createClass(payload) {
    return request('school_connect.api.admin.create_class', { method: 'POST', body: payload })
  },
  async updateClass(payload) {
    return request('school_connect.api.admin.update_class', { method: 'POST', body: payload })
  },
  async deleteClass(id) {
    return request('school_connect.api.admin.delete_class', { method: 'POST', body: { id } })
  },
  async getTimetable(school, klass) {
    return request('school_connect.api.admin.get_timetable', { params: { school, class: klass } })
  },
  async setTimetableEntry(payload) {
    return request('school_connect.api.admin.set_timetable_entry', { method: 'POST', body: payload })
  },
  async updateTimetablePeriods(school, periods) {
    return request('school_connect.api.admin.update_timetable_periods', { method: 'POST', body: { school, periods } })
  },
  async removeTimetableEntry(id) {
    return request('school_connect.api.admin.remove_timetable_entry', { method: 'POST', body: { id } })
  },
  async getStudents(school, klass) {
    return request('school_connect.api.admin.get_admin_students', { params: { school, class: klass } })
  },
  async getStudent(id) {
    return request('school_connect.api.admin.get_admin_student', { params: { id } })
  },
  async createStudent(payload) {
    return request('school_connect.api.admin.create_student', { method: 'POST', body: payload })
  },
  async updateStudent(payload) {
    return request('school_connect.api.admin.update_student', { method: 'POST', body: payload })
  },
  async deleteStudent(id) {
    return request('school_connect.api.admin.delete_student', { method: 'POST', body: { id } })
  },
  async setStudentStatus(id, status) {
    return request('school_connect.api.admin.set_student_status', { method: 'POST', body: { id, status } })
  },
}
