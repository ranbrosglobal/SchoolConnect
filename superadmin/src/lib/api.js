/**
 * API client for Super Admin console.
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

const MODE = import.meta.env.VITE_APP_MODE || 'live'
const API_BASE = (import.meta.env.VITE_API_URL || '').replace(/\/$/, '')

export const isMockMode = MODE === 'mock'
export const isSheetsMode = MODE === 'sheets' || MODE === 'live'

// ─── Sheets mode helpers ─────────────────────────────────────────────

let currentSchoolId = null
let currentUser = null

function parseRole(roleStr) {
  const r = (roleStr || '').toLowerCase()
  if (r === 'super admin' || r === 'administrator') return 'Administrator'
  if (r === 'school admin') return 'School Admin'
  return 'Student'
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

export function request(path, opts = {}) {
  if (isMockMode) return mockRequestWrapper(path, opts)
  if (isSheetsMode) return sheetsRequestWrapper(path, opts)
  return liveRequest(path, opts)
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

// ─── Google Sheets API handlers (superadmin) ─────────────────────────

const SHEETS_HANDLERS = {
  // ── Auth ──────────────────────────────────────────────────────────
  'school_connect.api.auth.login': async (params) => {
    const user = await sheets.findOne('Users', 'email', params.usr)
    if (!user) throw { status: 401, message: 'Invalid email or password' }
    if (user.password !== params.pwd) throw { status: 401, message: 'Invalid email or password' }
    if (user.role !== 'Administrator') {
      throw { status: 403, message: 'Access denied. This console is for the Super Admin only.' }
    }
    if (user.status === 'Inactive') throw { status: 403, message: 'This account is disabled.' }

    currentUser = { ...user, role: parseRole(user.role) }
    currentSchoolId = user.school_id

    const school = user.school_id ? await sheets.findOne('Schools', 'id', user.school_id) : null
    return {
      name: user.id,
      email: user.email,
      full_name: user.name,
      role: 'Administrator',
      roles: ['Administrator', 'System Manager'],
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
      role: 'Administrator',
      roles: ['Administrator', 'System Manager'],
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

  // ── Overview (network-wide) ───────────────────────────────────────
  'school_connect.api.admin.overview': async () => {
    const schools = await sheets.readTab('Schools')
    const users = await sheets.readTab('Users')
    const classes = await sheets.readTab('Classes')
    const students = await sheets.readTab('Students')

    const schoolViews = schools.map(s => ({
      ...s,
      admin_names: users
        .filter(u => u.role === 'School Admin' && u.school_id === s.id)
        .map(a => a.name),
      teacher_count: users.filter(u => u.role === 'Teacher' && u.school_id === s.id).length,
      class_count: classes.filter(c => c.school_id === s.id).length,
      student_count: students.filter(st => st.school_id === s.id).length,
    }))

    return {
      school_count: schoolViews.filter(s => s.status === 'Active').length,
      disabled_school_count: schoolViews.filter(s => s.status === 'Disabled').length,
      school_admin_count: users.filter(u => u.role === 'School Admin').length,
      teacher_count: users.filter(u => u.role === 'Teacher').length,
      class_count: classes.length,
      student_count: students.length,
      recent_schools: schoolViews.slice(0, 4),
    }
  },

  // ── Alias for overview ────────────────────────────────────────────
  'school_connect.api.admin.get_admin_dashboard': async () => {
    return SHEETS_HANDLERS['school_connect.api.admin.overview']()
  },

  // ── Schools ───────────────────────────────────────────────────────
  'school_connect.api.admin.get_schools': async () => {
    const schools = await sheets.readTab('Schools')
    const users = await sheets.readTab('Users')

    return schools.map(s => ({
      ...s,
      admin_names: users
        .filter(u => u.role === 'School Admin' && u.school_id === s.id)
        .map(a => a.name),
      teacher_count: users.filter(u => u.role === 'Teacher' && u.school_id === s.id).length,
    }))
  },

  'school_connect.api.admin.create_school': async (params) => {
    const name = params.name?.trim()
    if (!name) throw { status: 400, message: 'School name is required' }
    const id = sheets.genId('s-')
    await sheets.appendRow('Schools', [
      id, name, params.location?.trim() || '', params.status || 'Active',
      Number(params.established) || new Date().getFullYear(),
    ])
    return {
      id, name, location: params.location || '', status: params.status || 'Active',
      established: Number(params.established) || new Date().getFullYear(),
      teacher_count: 0, class_count: 0, student_count: 0, admin_names: [],
    }
  },

  'school_connect.api.admin.update_school': async (params) => {
    const s = await sheets.findOne('Schools', 'id', params.id)
    if (!s) throw { status: 404, message: 'School not found' }
    const name = params.name?.trim()
    if (!name) throw { status: 400, message: 'School name is required' }

    const updates = { name }
    if (params.location) updates.location = params.location.trim()
    if (params.established) updates.established = Number(params.established).toString()
    if (params.status) updates.status = params.status

    await sheets.updateWhere('Schools', 'id', params.id, updates)
    return { ...s, ...updates }
  },

  'school_connect.api.admin.set_school_status': async (params) => {
    const s = await sheets.findOne('Schools', 'id', params.id)
    if (!s) throw { status: 404, message: 'School not found' }
    const status = params.status === 'Disabled' ? 'Disabled' : 'Active'
    await sheets.updateWhere('Schools', 'id', params.id, { status })
    return { ...s, status }
  },

  'school_connect.api.admin.delete_school': async (params) => {
    const s = await sheets.findOne('Schools', 'id', params.id)
    if (!s) throw { status: 404, message: 'School not found' }
    // Cascade: remove school admins for this school
    const admins = await sheets.findMany('Users', 'school_id', params.id)
    for (const a of admins) {
      if (a.role === 'School Admin') {
        await sheets.deleteWhere('Users', 'id', a.id)
      }
    }
    await sheets.deleteWhere('Schools', 'id', params.id)
    return { message: 'School deleted', id: params.id }
  },

  // ── School Admins ─────────────────────────────────────────────────
  'school_connect.api.admin.get_school_admins': async (params) => {
    let users = await sheets.readTab('Users')
    users = users.filter(u => u.role === 'School Admin')
    if (params.school) users = users.filter(u => u.school_id === params.school)

    return users.map(u => ({
      id: u.id,
      name: u.name,
      email: u.email,
      role: u.role,
      school_id: u.school_id,
      status: u.status || 'Active',
    }))
  },

  'school_connect.api.admin.create_school_admin': async (params) => {
    const name = params.name?.trim()
    const email = params.email?.trim().toLowerCase()
    if (!name) throw { status: 400, message: 'Name is required' }
    if (!email) throw { status: 400, message: 'Email is required' }
    if (!params.password) throw { status: 400, message: 'Password is required' }

    const existing = await sheets.findOne('Users', 'email', email)
    if (existing) throw { status: 400, message: 'An account with this email already exists' }

    const school = await sheets.findOne('Schools', 'id', params.school)
    if (!school) throw { status: 400, message: 'Unknown school' }

    const id = sheets.genId('u-')
    await sheets.appendRow('Users', [
      id, email, name, 'School Admin', params.school, '', '', '', params.password, 'Active',
    ])

    return {
      id, name: name, email, role: 'School Admin',
      school_id: params.school, status: 'Active',
    }
  },

  'school_connect.api.admin.update_school_admin': async (params) => {
    const user = await sheets.findOne('Users', 'id', params.id)
    if (!user || user.role !== 'School Admin') throw { status: 404, message: 'School admin not found' }

    const name = params.name?.trim()
    const email = params.email?.trim().toLowerCase()
    if (!name) throw { status: 400, message: 'Name is required' }
    if (!email) throw { status: 400, message: 'Email is required' }

    const existing = await sheets.findOne('Users', 'email', email)
    if (existing && existing.id !== params.id) {
      throw { status: 400, message: 'An account with this email already exists' }
    }

    const updates = { name, email }
    if (params.school) updates.school_id = params.school
    if (params.password) updates.password = params.password

    await sheets.updateWhere('Users', 'id', params.id, updates)
    return { id: params.id, name, email, role: 'School Admin', school_id: updates.school_id || user.school_id, status: user.status }
  },

  'school_connect.api.admin.set_school_admin_status': async (params) => {
    const user = await sheets.findOne('Users', 'id', params.id)
    if (!user || user.role !== 'School Admin') throw { status: 404, message: 'School admin not found' }
    const status = params.status === 'Inactive' ? 'Inactive' : 'Active'
    await sheets.updateWhere('Users', 'id', params.id, { status })
    return { id: params.id, name: user.name, email: user.email, role: 'School Admin', school_id: user.school_id, status }
  },
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
  async getOverview() {
    return request('school_connect.api.admin.overview', { method: 'GET' })
  },
  async getSchools() {
    return request('school_connect.api.admin.get_schools', { method: 'GET' })
  },
  async createSchool(payload) {
    return request('school_connect.api.admin.create_school', { method: 'POST', body: payload })
  },
  async updateSchool(payload) {
    return request('school_connect.api.admin.update_school', { method: 'POST', body: payload })
  },
  async setSchoolStatus(id, status) {
    return request('school_connect.api.admin.set_school_status', { method: 'POST', body: { id, status } })
  },
  async deleteSchool(id) {
    return request('school_connect.api.admin.delete_school', { method: 'POST', body: { id } })
  },
  async getSchoolAdmins(school) {
    return request('school_connect.api.admin.get_school_admins', { method: 'GET', params: { school } })
  },
  async createSchoolAdmin(payload) {
    return request('school_connect.api.admin.create_school_admin', { method: 'POST', body: payload })
  },
  async updateSchoolAdmin(payload) {
    return request('school_connect.api.admin.update_school_admin', { method: 'POST', body: payload })
  },
  async setSchoolAdminStatus(id, status) {
    return request('school_connect.api.admin.set_school_admin_status', { method: 'POST', body: { id, status } })
  },
}
