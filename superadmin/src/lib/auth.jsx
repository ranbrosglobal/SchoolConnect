import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import { api, setCsrf, getCsrf } from './api'
import { CSRF_KEY, SESSION_KEY } from './keys'

/*
 * user shape (same as the real login response):
 *   { name, email, full_name, role, roles[], school, school_name }
 */
const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  // restore session on boot (mock mode stores the user; live mode also has the cookie)
  useEffect(() => {
    try {
      const saved = localStorage.getItem(SESSION_KEY)
      if (saved) { const u = JSON.parse(saved); setUser(u); if (u?.name && !getCsrf()) setCsrf(u.name) }
    } catch {
      localStorage.removeItem(SESSION_KEY)
      localStorage.removeItem(CSRF_KEY)
    }
    setLoading(false)
  }, [])

  const login = useCallback(async (usr, pwd) => {
    const u = await api.login(usr, pwd)
    localStorage.setItem(SESSION_KEY, JSON.stringify(u))
    setCsrf(u.name)
    setUser(u)
    return u
  }, [])

  const logout = useCallback(async () => {
    try {
      await api.logout()
    } finally {
      localStorage.removeItem(SESSION_KEY)
      localStorage.removeItem(CSRF_KEY)
      setUser(null)
    }
  }, [])

  const updateProfile = useCallback(async (fullName) => {
    const updated = await api.updateProfile(fullName)
    const next = { ...user, ...updated }
    localStorage.setItem(SESSION_KEY, JSON.stringify(next))
    setCsrf(next.name)
    setUser(next)
    return next
  }, [user])

  const changePassword = useCallback(async (currentPassword, newPassword) => {
    return api.changePassword(currentPassword, newPassword)
  }, [])

  const value = useMemo(
    () => ({
      user,
      loading,
      login,
      logout,
      updateProfile,
      changePassword,
      isSuperAdmin: !!user,
    }),
    [user, loading, login, logout, updateProfile, changePassword],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>')
  return ctx
}
