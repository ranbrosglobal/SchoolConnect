import { useEffect, useRef, useCallback, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from './auth'

const INACTIVITY_MS = 10 * 60 * 1000 // 10 minutes
const WARNING_MS = 9 * 60 * 1000     // show warning at 9 minutes
const ACTIVITY_EVENTS = ['mousemove', 'keydown', 'scroll', 'touchstart', 'click']

/**
 * Auto-logout hook — logs the user out after `INACTIVITY_MS` of no activity.
 * Shows a warning toast 1 minute before logout.
 * Only active when the user is logged in.
 */
export function useInactivityLogout() {
  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const timerRef = useRef(null)
  const warningRef = useRef(null)
  const [showWarning, setShowWarning] = useState(false)

  const doLogout = useCallback(async () => {
    setShowWarning(false)
    try { await logout() } catch {}
    navigate('/login', { replace: true })
  }, [logout, navigate])

  const resetTimer = useCallback(() => {
    setShowWarning(false)
    if (timerRef.current) clearTimeout(timerRef.current)
    if (warningRef.current) clearTimeout(warningRef.current)

    // Show warning 1 minute before auto-logout
    warningRef.current = setTimeout(() => setShowWarning(true), WARNING_MS)
    // Auto-logout after full inactivity period
    timerRef.current = setTimeout(() => doLogout(), INACTIVITY_MS)
  }, [doLogout])

  useEffect(() => {
    if (!user) return

    resetTimer()

    function onActivity() {
      resetTimer()
    }

    for (const evt of ACTIVITY_EVENTS) {
      window.addEventListener(evt, onActivity, { passive: true })
    }

    return () => {
      if (timerRef.current) clearTimeout(timerRef.current)
      if (warningRef.current) clearTimeout(warningRef.current)
      for (const evt of ACTIVITY_EVENTS) {
        window.removeEventListener(evt, onActivity)
      }
    }
  }, [user, resetTimer])

  return { showWarning, logoutNow: doLogout, resetTimer }
}
