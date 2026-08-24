/*
 * In-browser mock backend for the Super Admin console.
 *
 * This console has its OWN mock database (own localStorage key, own seed
 * data) — it is deliberately separate from the School Admin console's
 * database. Schools and school admins are managed here; the per-school
 * teacher/class/student figures are aggregate counts for the network
 * overview (the School Admin console holds the actual records).
 *
 * Mirrors the shape and endpoints of the real Frappe API
 * (school_connect.api.*). This console is for Super Admins only — school
 * admin accounts are rejected at login.
 */

import { DB_KEY, SESSION_KEY, LEGACY_SESSION_KEY, LEGACY_DB_KEY, LEGACY_CSRF_KEY } from './keys'

// Aggregate counts per school let the network overview stay meaningful
// without duplicating the School Admin console's full records.
const SCHOOLS = [
  { id: 'springfield', name: 'Springfield Elementary', location: 'Springfield', status: 'Active', established: 1998, teacher_count: 4, class_count: 3, student_count: 55 },
  { id: 'riverside', name: 'Riverside Academy', location: 'Riverside', status: 'Active', established: 2005, teacher_count: 2, class_count: 2, student_count: 37 },
  { id: 'sunrise', name: 'Sunrise International School', location: 'Sunrise City', status: 'Active', established: 2011, teacher_count: 2, class_count: 2, student_count: 35 },
  { id: 'maple', name: 'Maple Grove Public School', location: 'Maple Hill', status: 'Disabled', established: 2001, teacher_count: 0, class_count: 0, student_count: 0 },
]

// The Super Admin plus the school admins it manages across the network.
// Only the Administrator can sign in to this console.
const USERS = [
  { id: 'u-admin', email: 'admin@schoolconnect.app', password: 'admin123', full_name: 'Alex Morgan', role: 'Administrator', school_id: null, status: 'Active' },
  { id: 'u-priya', email: 'priya@springfield.edu', password: 'admin123', full_name: 'Priya Sharma', role: 'School Admin', school_id: 'springfield', status: 'Active' },
  { id: 'u-ravi', email: 'ravi@riverside.edu', password: 'admin123', full_name: 'Ravi Menon', role: 'School Admin', school_id: 'riverside', status: 'Active' },
  { id: 'u-aman', email: 'aman@sunrise.edu', password: 'admin123', full_name: 'Aman Kapoor', role: 'School Admin', school_id: 'sunrise', status: 'Active' },
]

function buildFreshDb() {
  return {
    schools: SCHOOLS.map((s) => ({ ...s })),
    users: USERS.map((u) => ({ ...u })),
  }
}

// Persist the mock DB in localStorage so mutations (schools, admins, name /
// password changes) survive page reloads, mirroring how a real backend keeps
// state.
function loadDb() {
  try {
    // Drop leftover shared-namespace keys from older builds (see keys.js). This
    // console has its own DB and session, so nothing is adopted from them.
    localStorage.removeItem(LEGACY_SESSION_KEY)
    localStorage.removeItem(LEGACY_DB_KEY)
    localStorage.removeItem(LEGACY_CSRF_KEY)
    const raw = localStorage.getItem(DB_KEY)
    if (raw) {
      const parsed = JSON.parse(raw)
      if (parsed && Array.isArray(parsed.users) && Array.isArray(parsed.schools)) return parsed
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

function publicUser(u) {
  return {
    name: u.id,
    email: u.email,
    full_name: u.full_name,
    role: u.role,
    roles: u.role === 'Administrator' ? ['Administrator', 'System Manager'] : [u.role],
    school: u.school_id,
    school_name: u.school_id ? DB.schools.find((s) => s.id === u.school_id)?.name : null,
  }
}

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

// Schools with the aggregate counts + admin names shown across the console.
function schoolView(s) {
  return {
    ...s,
    admin_names: DB.users
      .filter((u) => u.role === 'School Admin' && u.school_id === s.id)
      .map((a) => a.full_name),
    teacher_count: s.teacher_count || 0,
    class_count: s.class_count || 0,
    student_count: s.student_count || 0,
  }
}

function adminView(u) {
  return {
    id: u.id,
    name: u.full_name,
    email: u.email,
    role: u.role,
    school_id: u.school_id,
    school_name: u.school_id ? DB.schools.find((s) => s.id === u.school_id)?.name : null,
    status: u.status || 'Active',
  }
}

function overview() {
  const schools = DB.schools.map(schoolView)
  return {
    school_count: schools.filter((s) => s.status === 'Active').length,
    disabled_school_count: schools.filter((s) => s.status === 'Disabled').length,
    school_admin_count: DB.users.filter((u) => u.role === 'School Admin').length,
    teacher_count: schools.reduce((a, s) => a + s.teacher_count, 0),
    class_count: schools.reduce((a, s) => a + s.class_count, 0),
    student_count: schools.reduce((a, s) => a + s.student_count, 0),
    recent_schools: schools.slice(0, 4),
  }
}

/* ---------- handlers ---------- */

const HANDLERS = {
  'school_connect.api.auth.login': (body) => {
    const user = DB.users.find((u) => u.email === body.usr && u.password === body.pwd)
    if (!user) {
      throw { status: 401, message: 'Invalid email or password' }
    }
    if (user.role !== 'Administrator') {
      throw { status: 403, message: 'Access denied. This console is for the Super Admin only.' }
    }
    if (user.status === 'Inactive') {
      throw { status: 403, message: 'This account is disabled.' }
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

  'school_connect.api.admin.overview': () => ({ data: overview() }),

  'school_connect.api.admin.get_schools': () => ({
    data: DB.schools.map(schoolView),
  }),

  'school_connect.api.admin.create_school': (body) => {
    const name = body.name?.trim()
    if (!name) throw { status: 400, message: 'School name is required' }
    const school = {
      id: `s-${Date.now().toString(36)}`,
      name,
      location: body.location?.trim() || '—',
      established: Number(body.established) || new Date().getFullYear(),
      status: body.status === 'Disabled' ? 'Disabled' : 'Active',
      teacher_count: 0,
      class_count: 0,
      student_count: 0,
    }
    DB.schools.push(school)
    persist()
    return schoolView(school)
  },

  'school_connect.api.admin.update_school': (body) => {
    const s = DB.schools.find((x) => x.id === body.id)
    if (!s) throw { status: 404, message: 'School not found' }
    const name = body.name?.trim()
    if (!name) throw { status: 400, message: 'School name is required' }
    s.name = name
    s.location = body.location?.trim() || s.location
    s.established = Number(body.established) || s.established
    s.status = body.status === 'Disabled' ? 'Disabled' : 'Active'
    persist()
    return schoolView(s)
  },

  'school_connect.api.admin.set_school_status': (body) => {
    const s = DB.schools.find((x) => x.id === body.id)
    if (!s) throw { status: 404, message: 'School not found' }
    s.status = body.status === 'Disabled' ? 'Disabled' : 'Active'
    persist()
    return schoolView(s)
  },

  'school_connect.api.admin.delete_school': (body) => {
    const s = DB.schools.find((x) => x.id === body.id)
    if (!s) throw { status: 404, message: 'School not found' }
    // cascade: remove the school and its school admins
    DB.users = DB.users.filter((u) => !(u.role === 'School Admin' && u.school_id === s.id))
    DB.schools = DB.schools.filter((x) => x.id !== s.id)
    persist()
    return { message: 'School deleted', id: s.id }
  },

  'school_connect.api.admin.get_school_admins': (params) => ({
    data: DB.users
      .filter((u) => u.role === 'School Admin')
      .filter((u) => !params.school || u.school_id === params.school)
      .map(adminView),
  }),

  'school_connect.api.admin.create_school_admin': (body) => {
    const name = body.name?.trim()
    const email = body.email?.trim().toLowerCase()
    if (!name) throw { status: 400, message: 'Name is required' }
    if (!email) throw { status: 400, message: 'Email is required' }
    if (!body.password) throw { status: 400, message: 'Password is required' }
    if (DB.users.some((u) => u.email === email)) throw { status: 400, message: 'An account with this email already exists' }
    if (!DB.schools.some((s) => s.id === body.school)) throw { status: 400, message: 'Unknown school' }
    const user = {
      id: `u-${Date.now().toString(36)}`,
      email,
      password: body.password,
      full_name: name,
      role: 'School Admin',
      school_id: body.school,
      status: 'Active',
    }
    DB.users.push(user)
    persist()
    return adminView(user)
  },

  'school_connect.api.admin.update_school_admin': (body) => {
    const u = DB.users.find((x) => x.id === body.id && x.role === 'School Admin')
    if (!u) throw { status: 404, message: 'School admin not found' }
    const name = body.name?.trim()
    const email = body.email?.trim().toLowerCase()
    if (!name) throw { status: 400, message: 'Name is required' }
    if (!email) throw { status: 400, message: 'Email is required' }
    if (DB.users.some((x) => x.email === email && x.id !== u.id)) {
      throw { status: 400, message: 'An account with this email already exists' }
    }
    if (body.school && !DB.schools.some((s) => s.id === body.school)) throw { status: 400, message: 'Unknown school' }
    u.full_name = name
    u.email = email
    if (body.school) u.school_id = body.school
    if (body.password) u.password = body.password
    persist()
    return adminView(u)
  },

  'school_connect.api.admin.set_school_admin_status': (body) => {
    const u = DB.users.find((x) => x.id === body.id && x.role === 'School Admin')
    if (!u) throw { status: 404, message: 'School admin not found' }
    u.status = body.status === 'Inactive' ? 'Inactive' : 'Active'
    persist()
    return adminView(u)
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
