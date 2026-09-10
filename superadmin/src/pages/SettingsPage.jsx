import { useState } from 'react'
import { CheckCircle2, Eye, EyeOff, KeyRound, Loader2, Save, UserRound } from 'lucide-react'
import { useAuth } from '../lib/auth'
import { Avatar, Badge, Card, Field, PageHeader, PrimaryButton, inputClass } from '../components/ui'

function SuccessBanner({ message }) {
  return (
    <div className="flex items-center gap-2 rounded-btn border border-success/20 bg-success-soft px-4 py-2.5 text-sm font-medium text-success">
      <CheckCircle2 className="h-4 w-4 shrink-0" />
      {message}
    </div>
  )
}

function ErrorBanner({ message }) {
  return (
    <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-2.5 text-sm font-medium text-danger">
      {message}
    </div>
  )
}

function PasswordInput({ label, value, onChange, autoComplete, placeholder }) {
  const [show, setShow] = useState(false)
  return (
    <Field label={label}>
      <div className="relative">
        <input
          type={show ? 'text' : 'password'}
          required
          autoComplete={autoComplete}
          placeholder={placeholder || '••••••••'}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className={`${inputClass} pr-10`}
        />
        <button
          type="button"
          aria-label={show ? 'Hide password' : 'Show password'}
          onClick={() => setShow((v) => !v)}
          className="absolute right-3 top-1/2 -translate-y-1/2 text-outline transition hover:text-ink"
        >
          {show ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
        </button>
      </div>
    </Field>
  )
}

function AccountDetailsCard() {
  const { user, isSuperAdmin, updateProfile } = useAuth()
  const [name, setName] = useState(user.full_name || '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)
  const [saved, setSaved] = useState(false)

  async function save(e) {
    e.preventDefault()
    setError(null)
    setSaved(false)
    const trimmed = name.trim()
    if (trimmed.length < 2) {
      setError('Name must be at least 2 characters long.')
      return
    }
    setBusy(true)
    try {
      await updateProfile(trimmed)
      setSaved(true)
    } catch (err) {
      setError(err.message || 'Could not update your profile.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Card className="p-6">
      <div className="mb-5 flex items-center gap-3">
        <span className="rounded-full bg-primary-soft p-2.5 text-primary">
          <UserRound className="h-5 w-5" />
        </span>
        <div>
          <h2 className="text-base font-bold tracking-tight text-ink">Account details</h2>
          <p className="text-sm text-ink-soft">Your profile information and how others see you.</p>
        </div>
      </div>

      <div className="mb-5 flex items-center gap-4 rounded-card border border-outline-soft bg-surface-low/60 p-4">
        <Avatar name={user.full_name} size="lg" />
        <div className="min-w-0">
          <p className="truncate text-sm font-semibold text-ink">{user.full_name}</p>
          <p className="truncate text-xs text-ink-soft">{user.email}</p>
          <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
            <Badge tone={isSuperAdmin ? 'indigo' : 'amber'}>
              {isSuperAdmin ? 'Super Admin' : 'School Admin'}
            </Badge>
            {user.school_name && <Badge tone="neutral">{user.school_name}</Badge>}
          </div>
        </div>
      </div>

      <form onSubmit={save} className="space-y-4">
        {error && <ErrorBanner message={error} />}
        {saved && <SuccessBanner message="Profile updated successfully." />}
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Full name">
            <input
              autoFocus
              value={name}
              onChange={(e) => {
                setName(e.target.value)
                setSaved(false)
              }}
              placeholder="Your full name"
              className={inputClass}
            />
          </Field>
          <Field label="Email">
            <input value={user.email} disabled className={`${inputClass} bg-surface-low text-ink-soft`} />
          </Field>
        </div>
        <p className="text-xs text-ink-soft">
          Email is your login and can’t be changed here. Contact the system administrator if you need it updated.
        </p>
        <div className="flex justify-end">
          <PrimaryButton type="submit" disabled={busy || name.trim() === user.full_name}>
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
            {busy ? 'Saving…' : 'Save changes'}
          </PrimaryButton>
        </div>
      </form>
    </Card>
  )
}

function ChangePasswordCard() {
  const { changePassword } = useAuth()
  const [current, setCurrent] = useState('')
  const [next, setNext] = useState('')
  const [confirm, setConfirm] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)
  const [saved, setSaved] = useState(false)

  async function submit(e) {
    e.preventDefault()
    setError(null)
    setSaved(false)
    if (next.length < 6) {
      setError('New password must be at least 6 characters long.')
      return
    }
    if (next === current) {
      setError('New password must be different from your current password.')
      return
    }
    if (next !== confirm) {
      setError('New password and confirmation do not match.')
      return
    }
    setBusy(true)
    try {
      await changePassword(current, next)
      setSaved(true)
      setCurrent('')
      setNext('')
      setConfirm('')
    } catch (err) {
      setError(err.message || 'Could not change your password.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Card className="p-6">
      <div className="mb-5 flex items-center gap-3">
        <span className="rounded-full bg-warning-soft p-2.5 text-warning">
          <KeyRound className="h-5 w-5" />
        </span>
        <div>
          <h2 className="text-base font-bold tracking-tight text-ink">Change password</h2>
          <p className="text-sm text-ink-soft">Keep your account secure with a strong password.</p>
        </div>
      </div>

      <form onSubmit={submit} className="space-y-4">
        {error && <ErrorBanner message={error} />}
        {saved && <SuccessBanner message="Password changed successfully." />}
        <PasswordInput
          label="Current password"
          value={current}
          onChange={setCurrent}
          autoComplete="current-password"
        />
        <PasswordInput
          label="New password"
          value={next}
          onChange={setNext}
          autoComplete="new-password"
          placeholder="At least 6 characters"
        />
        <PasswordInput
          label="Confirm new password"
          value={confirm}
          onChange={setConfirm}
          autoComplete="new-password"
        />
        <div className="flex justify-end">
          <PrimaryButton type="submit" disabled={busy}>
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <KeyRound className="h-4 w-4" />}
            {busy ? 'Updating…' : 'Update password'}
          </PrimaryButton>
        </div>
      </form>
    </Card>
  )
}

export default function SettingsPage() {
  return (
    <>
      <PageHeader title="Settings" subtitle="Manage your account details and password." />
      <div className="grid gap-6 lg:grid-cols-2">
        <AccountDetailsCard />
        <ChangePasswordCard />
      </div>
    </>
  )
}
