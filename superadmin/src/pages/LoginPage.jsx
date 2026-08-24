import { useState } from 'react'
import { Navigate, useNavigate } from 'react-router-dom'
import { Eye, EyeOff, Loader2, Lock, LogIn, Mail } from 'lucide-react'
import { useAuth } from '../lib/auth'
import { Logo, Field, inputClass, PrimaryButton } from '../components/ui'

const QUICK_LOGINS = [
  { label: 'Super Admin', email: 'admin@schoolconnect.app', pwd: 'admin123' },
]

export default function LoginPage() {
  const { user, login } = useAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [pwd, setPwd] = useState('')
  const [showPwd, setShowPwd] = useState(false)
  const [error, setError] = useState(null)
  const [busy, setBusy] = useState(false)

  if (user) return <Navigate to="/" replace />

  async function submit(e) {
    e.preventDefault()
    setError(null)
    setBusy(true)
    try {
      await login(email.trim(), pwd)
      navigate('/', { replace: true })
    } catch (err) {
      setError(err.message || 'Login failed. Try again.')
    } finally {
      setBusy(false)
    }
  }

  async function quickLogin(entry) {
    setEmail(entry.email)
    setPwd(entry.pwd)
    setError(null)
    setBusy(true)
    try {
      await login(entry.email, entry.pwd)
      navigate('/', { replace: true })
    } catch (err) {
      setError(err.message || 'Login failed. Try again.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="grid min-h-screen lg:grid-cols-[1.05fr_1fr]">
      {/* Brand panel */}
      <div className="relative hidden flex-col justify-between overflow-hidden bg-gradient-to-br from-[#1e2d8a] to-primary p-10 text-white lg:flex">
        <div className="pointer-events-none absolute -right-20 -top-20 h-64 w-64 rounded-full bg-white/[0.07] blur-3xl" />

        <div className="relative flex items-center gap-3">
          <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-white/15 backdrop-blur">
            <Logo className="h-6 w-6" />
          </span>
          <div>
            <p className="text-lg font-extrabold tracking-tight">School Connect</p>
            <p className="text-xs text-white/70">Super Admin Console</p>
          </div>
        </div>

        <div className="relative max-w-md">
          <h1 className="text-4xl font-extrabold leading-tight tracking-tight">
            The network. In one place.
          </h1>
          <p className="mt-4 text-white/80">
            Add schools, assign admins and monitor the entire network from one place.
          </p>

        </div>

        <p className="relative text-xs text-white/60">
          © {new Date().getFullYear()} School Connect · Super Admin Console
        </p>
      </div>

      {/* Form panel */}
      <div className="flex items-center justify-center bg-background px-6 py-12">
        <div className="w-full max-w-md">
          <div className="mb-8 flex items-center gap-3 lg:hidden">
            <Logo />
            <div>
              <p className="text-lg font-extrabold tracking-tight text-ink">School Connect</p>
              <p className="text-xs text-ink-soft">Super Admin Console</p>
            </div>
          </div>

          <h2 className="text-2xl font-bold tracking-tight text-ink">Welcome back</h2>
          <p className="mt-1 text-sm text-ink-soft">Sign in to your super admin account to continue.</p>

          {error && (
            <div className="mt-5 rounded-btn border border-danger/20 bg-danger-soft px-4 py-3 text-sm font-medium text-danger">
              {error}
            </div>
          )}

          <form onSubmit={submit} className="mt-6 space-y-4">
            <Field label="Email">
              <div className="relative">
                <Mail className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-outline" />
                <input
                  type="email"
                  required
                  autoComplete="username"
                  placeholder="you@school.edu"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className={`${inputClass} pl-10`}
                />
              </div>
            </Field>

            <Field label="Password">
              <div className="relative">
                <Lock className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-outline" />
                <input
                  type={showPwd ? 'text' : 'password'}
                  required
                  autoComplete="current-password"
                  placeholder="••••••••"
                  value={pwd}
                  onChange={(e) => setPwd(e.target.value)}
                  className={`${inputClass} pl-10 pr-10`}
                />
                <button
                  type="button"
                  aria-label={showPwd ? 'Hide password' : 'Show password'}
                  onClick={() => setShowPwd((v) => !v)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-outline transition hover:text-ink"
                >
                  {showPwd ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </Field>

            <PrimaryButton type="submit" disabled={busy} className="w-full py-3">
              {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <LogIn className="h-4 w-4" />}
              {busy ? 'Signing in…' : 'Sign in'}
            </PrimaryButton>
          </form>

          <div className="mt-8">
            <div className="flex items-center gap-3">
              <span className="h-px flex-1 bg-outline-soft" />
              <span className="text-xs font-bold uppercase tracking-wide text-ink-soft">Demo account</span>
              <span className="h-px flex-1 bg-outline-soft" />
            </div>
            <div className="mt-4 grid gap-2">
              {QUICK_LOGINS.map((q) => (
                <button
                  key={q.email}
                  type="button"
                  disabled={busy}
                  onClick={() => quickLogin(q)}
                  className="flex items-center justify-between rounded-btn border border-outline-soft bg-white px-4 py-2.5 text-sm font-medium text-ink transition hover:border-primary/40 hover:bg-primary-soft active:scale-[0.97] disabled:opacity-60"
                >
                  <span>{q.label}</span>

                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
