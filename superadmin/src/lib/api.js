/**
 * API client for Super Admin console.
 *
 * Two modes, flipped by env var:
 *   VITE_APP_MODE=mock  — in-browser mock backend (lib/mock.js)
 *   VITE_APP_MODE=live  — real SQLite backend via sc_backend server
 */

import { mockRequest } from './mock'
import { CSRF_KEY } from './keys'

const MODE = import.meta.env.VITE_APP_MODE || 'live'
const API_BASE = (import.meta.env.VITE_API_URL || '').replace(/\/$/, '')

export const isMockMode = MODE === 'mock'

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
