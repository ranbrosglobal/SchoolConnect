/**
 * API client.
 *
 * Two modes, flipped by env var:
 *   VITE_APP_MODE=mock  — in-browser mock backend (lib/mock.js)
 *   VITE_APP_MODE=live  — real SQLite backend via sc_backend server
 */

import { mockRequest } from './mock'
import { CSRF_KEY } from './keys'
import { DAYS } from './timetable'

const MODE = import.meta.env.VITE_APP_MODE || 'live'
const API_BASE = (import.meta.env.VITE_API_URL || '').replace(/\/$/, '')

export const isMockMode = MODE === 'mock'
const isLiveMode = MODE === 'live'

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
    if (csrf) headers['X-CSRF-Token'] = csrf
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

export function request(path, opts = {}) {
  if (isMockMode) return mockRequestWrapper(path, opts)
  return liveRequest(path, opts)
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
