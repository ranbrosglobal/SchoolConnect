import { useState } from 'react'
import { GraduationCap, Loader2, Plus, Search } from 'lucide-react'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { useFetch } from '../lib/useFetch'
import {
  Avatar,
  Badge,
  Card,
  EmptyState,
  Field,
  Modal,
  PageHeader,
  PrimaryButton,
  SecondaryButton,
  Spinner,
  inputClass,
} from '../components/ui'

const SUBJECTS = ['Mathematics', 'Science', 'English', 'History', 'Geography', 'Physics', 'Chemistry', 'Biology', 'Computer Science', 'Physical Education']

const EMPTY_FORM = { name: '', email: '', password: '', subjects: [SUBJECTS[0]], class_ids: [] }

function TeacherModal({ teacher, school, allTeachers, onClose, onSaved }) {
  // Merge predefined subjects with every subject already in use by any teacher
  const allSubjects = [...new Set([...SUBJECTS, ...allTeachers.flatMap((t) => t.subjects || [])])]
  const { data: classes, loading: classesLoading } = useFetch(() => api.getClasses(school), [school])
  const [fields, setFields] = useState(
    teacher
      ? {
          name: teacher.name,
          email: teacher.email,
          password: '',
          subjects: teacher.subjects?.length ? teacher.subjects : [teacher.subject].filter(Boolean),
          class_ids: teacher.class_ids,
        }
      : EMPTY_FORM,
  )
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)
  const [customSubject, setCustomSubject] = useState('')

  function toggleClass(cid) {
    setFields((f) => ({
      ...f,
      class_ids: f.class_ids.includes(cid) ? f.class_ids.filter((x) => x !== cid) : [...f.class_ids, cid],
    }))
  }

  function toggleSubject(s) {
    setFields((f) => ({
      ...f,
      subjects: f.subjects.includes(s) ? f.subjects.filter((x) => x !== s) : [...f.subjects, s],
    }))
  }

  async function save(e) {
    e.preventDefault()
    setError(null)
    if (!fields.name.trim() || !fields.email.trim()) {
      setError('Name and email are required.')
      return
    }
    if (!teacher && !fields.password) {
      setError('A password is required for new accounts.')
      return
    }
    setBusy(true)
    try {
      if (teacher) {
        await api.updateTeacher({
          id: teacher.id,
          name: fields.name,
          email: fields.email,
          subjects: fields.subjects,
          class_ids: fields.class_ids,
          password: fields.password || undefined,
        })
      } else {
        await api.createTeacher({ ...fields, school })
      }
      onSaved()
    } catch (err) {
      setError(err.message || 'Could not save the teacher.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal title={teacher ? `Edit ${teacher.name}` : 'Add teacher'}      subtitle="Assign teachers to classes and manage subjects." onClose={onClose}>
      <form onSubmit={save} className="space-y-4">
        {error && (
          <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-2.5 text-sm font-medium text-danger">
            {error}
          </div>
        )}
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Full name">
            <input
              autoFocus
              required
              value={fields.name}
              onChange={(e) => setFields({ ...fields, name: e.target.value })}
              placeholder="e.g. Anita Sharma"
              className={inputClass}
            />
          </Field>
          <Field label="Email">
            <input
              type="email"
              required
              value={fields.email}
              onChange={(e) => setFields({ ...fields, email: e.target.value })}
              placeholder="teacher@school.edu"
              className={inputClass}
            />
          </Field>
        </div>
        <div>
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-ink-soft">Subjects</span>
          <div className="flex flex-wrap gap-2">
            {allSubjects.map((s) => {
              const on = fields.subjects.includes(s)
              const isCustom = !SUBJECTS.includes(s)
              return (
                <button
                  key={s}
                  type="button"
                  onClick={() => toggleSubject(s)}
                  className={`rounded-full border px-3 py-1.5 text-xs font-semibold transition active:scale-[0.97] ${
                    on
                      ? isCustom
                        ? 'border-primary/40 bg-primary/10 text-primary'
                        : 'border-primary bg-primary text-white'
                      : 'border-outline-soft bg-white text-ink-soft hover:border-primary/40'
                  }`}
                >
                  {s}{isCustom && on ? ' ✕' : ''}
                </button>
              )
            })}
            <div className="flex items-center gap-1.5">
              <input
                type="text"
                value={customSubject}
                onChange={(e) => setCustomSubject(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault()
                    const v = customSubject.trim()
                    if (v && !fields.subjects.includes(v)) {
                      setFields((f) => ({ ...f, subjects: [...f.subjects, v] }))
                    }
                    setCustomSubject('')
                  }
                }}
                placeholder="Add custom…"
                className="w-32 rounded-full border border-outline-soft px-3 py-1.5 text-xs text-ink placeholder:text-ink-faint focus:border-primary focus:outline-none"
              />
              {customSubject.trim() && !fields.subjects.includes(customSubject.trim()) && (
                <button
                  type="button"
                  onClick={() => {
                    const v = customSubject.trim()
                    if (v) setFields((f) => ({ ...f, subjects: [...f.subjects, v] }))
                    setCustomSubject('')
                  }}
                  className="rounded-full bg-primary px-2.5 py-1.5 text-xs font-semibold text-white transition hover:bg-primary/90 active:scale-[0.97]"
                >
                  + Add
                </button>
              )}
            </div>
          </div>
          <p className="mt-1.5 text-xs text-ink-soft">
            {fields.subjects.length === 0 ? 'Pick at least one subject this teacher can teach.' : `${fields.subjects.join(', ')} — these appear when scheduling the timetable.`}
          </p>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={teacher ? 'New password (blank = keep)' : 'Password'}>
            <input
              type="text"
              value={fields.password}
              onChange={(e) => setFields({ ...fields, password: e.target.value })}
              placeholder={teacher ? '••••••••' : 'Temporary password'}
              className={inputClass}
            />
          </Field>
        </div>

        <div>
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-ink-soft">Assigned classes</span>
          {classesLoading ? (
            <p className="text-sm text-ink-soft">Loading classes…</p>
          ) : (
            <div className="flex flex-wrap gap-2">
              {(classes || []).map((c) => {
                const on = fields.class_ids.includes(c.id)
                return (
                  <button
                    key={c.id}
                    type="button"
                    onClick={() => toggleClass(c.id)}
                    className={`rounded-full border px-3 py-1.5 text-xs font-semibold transition active:scale-[0.97] ${
                      on
                        ? 'border-primary bg-primary text-white'
                        : 'border-outline-soft bg-white text-ink-soft hover:border-primary/40'
                    }`}
                  >
                    {c.name}
                  </button>
                )
              })}
              {(classes || []).length === 0 && <p className="text-sm text-ink-soft">No classes yet in this school.</p>}
            </div>
          )}
        </div>

        <div className="flex justify-end gap-2 pt-2">
          <SecondaryButton type="button" onClick={onClose}>
            Cancel
          </SecondaryButton>
          <PrimaryButton type="submit" disabled={busy}>
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
            {busy ? 'Saving…' : teacher ? 'Save changes' : 'Add teacher'}
          </PrimaryButton>
        </div>
      </form>
    </Modal>
  )
}

export default function TeachersPage() {
  const { user } = useAuth()
  const scope = user.school
  const { data: teachers, loading, error, reload } = useFetch(() => api.getTeachers(scope), [scope])
  const [query, setQuery] = useState('')
  const [modal, setModal] = useState(null) // { teacher: null } = add | { teacher } = edit

  const q = query.trim().toLowerCase()
  const filtered = (teachers || []).filter(
    (t) =>
      !q ||
      t.name.toLowerCase().includes(q) ||
      t.email.toLowerCase().includes(q) ||
      (t.subjects || []).some((s) => s.toLowerCase().includes(q)),
  )

  async function toggleStatus(t) {
    const next = t.status === 'Active' ? 'Inactive' : 'Active'
    try {
      await api.setTeacherStatus(t.id, next)
      reload()
    } catch {
      /* keep list as-is */
    }
  }

  return (
    <>
      <PageHeader
        title="Teachers"
        subtitle="Manage teacher accounts and class assignments."
        actions={
          <PrimaryButton onClick={() => setModal({ teacher: null })}>
            <Plus className="h-4 w-4" />
            Add teacher
          </PrimaryButton>
        }
      />

      <div className="relative mb-5 max-w-sm">
        <Search className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-outline" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search by name, email or subject…"
          className={`${inputClass} pl-10`}
        />
      </div>

      {loading ? (
        <Spinner label="Loading teachers…" />
      ) : error ? (
        <Card className="p-8 text-center">
          <p className="font-semibold text-danger">{error}</p>
        </Card>
      ) : filtered.length === 0 ? (
        <EmptyState
          title={q ? 'No teachers match your search' : 'No teachers yet'}
          hint={q ? 'Try a different name, email or subject.' : 'Add your first teacher to get started.'}
          action={
            !q && (
              <PrimaryButton onClick={() => setModal({ teacher: null })} className="mt-3">
                <Plus className="h-4 w-4" />
                Add teacher
              </PrimaryButton>
            )
          }
        />
      ) : (
        <Card className="overflow-hidden">
          <ul className="divide-y divide-outline-soft/60">
            {filtered.map((t) => (
              <li key={t.id} className="flex flex-wrap items-center gap-x-4 gap-y-2 px-5 py-3.5">
                <Avatar name={t.name} />
                <div className="min-w-0 flex-1 basis-40">
                  <p className="truncate text-sm font-semibold text-ink">{t.name}</p>
                  <p className="truncate text-xs text-ink-soft">{t.email}</p>
                </div>
                <Badge tone="indigo">
                  <GraduationCap className="h-3 w-3" />
                  {(t.subjects || [t.subject]).slice(0, 2).join(' · ')}
                  {(t.subjects || []).length > 2 ? ` +${t.subjects.length - 2}` : ''}
                </Badge>
                <div className="flex max-w-52 flex-wrap gap-1">
                  {t.classes.length > 0 ? (
                    t.classes.map((c) => (
                      <span key={c} className="rounded-full bg-surface-low px-2 py-0.5 text-xs font-medium text-ink-soft">
                        {c}
                      </span>
                    ))
                  ) : (
                    <span className="text-xs italic text-ink-soft">No classes</span>
                  )}
                </div>
                <Badge tone={t.status === 'Active' ? 'green' : 'neutral'}>{t.status}</Badge>
                <div className="flex gap-2">
                  <SecondaryButton onClick={() => setModal({ teacher: t })} className="!px-3 !py-1.5 text-xs">
                    Edit
                  </SecondaryButton>
                  <button
                    onClick={() => toggleStatus(t)}
                    className={`rounded-btn border px-3 py-1.5 text-xs font-semibold transition active:scale-[0.97] ${
                      t.status === 'Active'
                        ? 'border-danger/30 bg-white text-danger hover:bg-danger-soft'
                        : 'border-success/30 bg-white text-success hover:bg-success-soft'
                    }`}
                  >
                    {t.status === 'Active' ? 'Disable' : 'Enable'}
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </Card>
      )}

      {modal && (
        <TeacherModal
          teacher={modal.teacher}
          school={scope}
          allTeachers={teachers || []}
          onClose={() => setModal(null)}
          onSaved={() => {
            setModal(null)
            reload()
          }}
        />
      )}
    </>
  )
}
