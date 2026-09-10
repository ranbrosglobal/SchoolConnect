import { useState } from 'react'
import { Loader2, Plus, ShieldCheck, UserCog } from 'lucide-react'
import { api } from '../lib/api'
import { useFetch } from '../lib/useFetch'
import {
  Avatar,
  Badge,
  Field,
  Modal,
  PrimaryButton,
  SecondaryButton,
  Spinner,
  inputClass,
} from './ui'

const EMPTY = { name: '', email: '', password: '' }

export default function SchoolAdminsModal({ school, onClose, onChanged }) {
  const { data: admins, loading, error, reload } = useFetch(() => api.getSchoolAdmins(school.id), [school.id])
  const [form, setForm] = useState(null) // null = list view | { mode: 'add' } | { mode: 'edit', admin }
  const [fields, setFields] = useState(EMPTY)
  const [busy, setBusy] = useState(false)
  const [formError, setFormError] = useState(null)

  function openAdd() {
    setFields(EMPTY)
    setFormError(null)
    setForm({ mode: 'add' })
  }

  function openEdit(admin) {
    setFields({ name: admin.name, email: admin.email, password: '' })
    setFormError(null)
    setForm({ mode: 'edit', admin })
  }

  async function save(e) {
    e.preventDefault()
    setFormError(null)
    if (!fields.name.trim() || !fields.email.trim()) {
      setFormError('Name and email are required.')
      return
    }
    if (form.mode === 'add' && !fields.password) {
      setFormError('A password is required for new accounts.')
      return
    }
    setBusy(true)
    try {
      if (form.mode === 'add') {
        await api.createSchoolAdmin({ ...fields, school: school.id })
      } else {
        await api.updateSchoolAdmin({
          id: form.admin.id,
          name: fields.name,
          email: fields.email,
          school: school.id,
          password: fields.password || undefined,
        })
      }
      setForm(null)
      reload()
      onChanged()
    } catch (err) {
      setFormError(err.message || 'Could not save the admin.')
    } finally {
      setBusy(false)
    }
  }

  async function toggleStatus(admin) {
    const next = admin.status === 'Active' ? 'Inactive' : 'Active'
    try {
      await api.setSchoolAdminStatus(admin.id, next)
      reload()
      onChanged()
    } catch {
      /* keep the list as-is on failure */
    }
  }

  return (
    <Modal
      title="School admins"
      subtitle={school.name}
      onClose={onClose}
      wide
    >
      {loading ? (
        <Spinner label="Loading admins…" />
      ) : error ? (
        <p className="py-4 text-center text-sm font-semibold text-danger">{error}</p>
      ) : form ? (
        /* ---------- Add / Edit form ---------- */
        <form onSubmit={save} className="space-y-4">
          {formError && (
            <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-2.5 text-sm font-medium text-danger">
              {formError}
            </div>
          )}
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Full name">
              <input
                autoFocus
                required
                value={fields.name}
                onChange={(e) => setFields({ ...fields, name: e.target.value })}
                placeholder="e.g. Meera Joshi"
                className={inputClass}
              />
            </Field>
            <Field label="Email">
              <input
                type="email"
                required
                value={fields.email}
                onChange={(e) => setFields({ ...fields, email: e.target.value })}
                placeholder="admin@school.edu"
                className={inputClass}
              />
            </Field>
          </div>
          <Field label={form.mode === 'add' ? 'Password' : 'New password (leave blank to keep)'}>
            <input
              type="text"
              value={fields.password}
              onChange={(e) => setFields({ ...fields, password: e.target.value })}
              placeholder={form.mode === 'add' ? "Set the admin's sign-in password" : '••••••••'}
              className={inputClass}
            />
          </Field>
          {form.mode === 'add' && (
            <p className="-mt-2 text-xs text-ink-soft">
              Initial sign-in password — the admin can change it anytime from their Settings page.
            </p>
          )}
          <div className="flex justify-end gap-2 pt-2">
            <SecondaryButton type="button" onClick={() => setForm(null)}>
              Cancel
            </SecondaryButton>
            <PrimaryButton type="submit" disabled={busy}>
              {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
              {busy ? 'Saving…' : form.mode === 'add' ? 'Create admin' : 'Save changes'}
            </PrimaryButton>
          </div>
        </form>
      ) : (
        /* ---------- List view ---------- */
        <>
          <div className="mb-4 flex items-center justify-between">
            <p className="text-sm text-ink-soft">
              {admins.length === 0
                ? 'No admins for this school yet.'
                : `${admins.length} admin${admins.length === 1 ? '' : 's'} manage this school.`}
            </p>
            <PrimaryButton onClick={openAdd}>
              <Plus className="h-4 w-4" />
              Add admin
            </PrimaryButton>
          </div>

          {admins.length === 0 ? (
            <div className="flex flex-col items-center gap-2 rounded-btn border border-dashed border-outline-soft py-10 text-center">
              <ShieldCheck className="h-7 w-7 text-outline" />
              <p className="text-sm text-ink-soft">Create the first school admin to get started.</p>
            </div>
          ) : (
            <ul className="divide-y divide-outline-soft/60 rounded-btn border border-outline-soft/60">
              {admins.map((a) => (
                <li key={a.id} className="flex items-center gap-3 px-4 py-3">
                  <Avatar name={a.name} />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-ink">{a.name}</p>
                    <p className="truncate text-xs text-ink-soft">{a.email}</p>
                  </div>
                  <Badge tone={a.status === 'Active' ? 'green' : 'neutral'}>{a.status}</Badge>
                  <SecondaryButton onClick={() => openEdit(a)} className="!px-3 !py-1.5 text-xs">
                    Edit
                  </SecondaryButton>
                  <button
                    onClick={() => toggleStatus(a)}
                    className={`rounded-btn border px-3 py-1.5 text-xs font-semibold transition active:scale-[0.97] ${
                      a.status === 'Active'
                        ? 'border-danger/30 bg-white text-danger hover:bg-danger-soft'
                        : 'border-success/30 bg-white text-success hover:bg-success-soft'
                    }`}
                  >
                    {a.status === 'Active' ? 'Disable' : 'Enable'}
                  </button>
                </li>
              ))}
            </ul>
          )}

          <p className="mt-3 flex items-center gap-1.5 text-xs text-ink-soft">
            <UserCog className="h-3.5 w-3.5" />
            Disabled admins and disabled schools can't sign in.
          </p>
        </>
      )}
    </Modal>
  )
}
