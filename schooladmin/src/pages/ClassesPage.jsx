import { useState } from 'react'
import { Link } from 'react-router-dom'
import { BookOpen, DoorOpen, Loader2, Plus, Search, Trash2, Users } from 'lucide-react'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { useFetch } from '../lib/useFetch'
import {
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

const PROGRAMS = ['Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12']

function ClassModal({ klass, school, onClose, onSaved }) {
  const { data: teachers, loading: teachersLoading } = useFetch(() => api.getTeachers(school), [school])
  const [fields, setFields] = useState(
    klass
      ? { name: klass.name, program: klass.program, room: klass.room, teacher_ids: klass.teacher_ids }
      : { name: '', program: PROGRAMS[2], room: '', teacher_ids: [] },
  )
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)

  function toggleTeacher(tid) {
    setFields((f) => ({
      ...f,
      teacher_ids: f.teacher_ids.includes(tid) ? f.teacher_ids.filter((x) => x !== tid) : [...f.teacher_ids, tid],
    }))
  }

  async function save(e) {
    e.preventDefault()
    setError(null)
    if (!fields.name.trim()) {
      setError('Class name is required.')
      return
    }
    setBusy(true)
    try {
      if (klass) {
        await api.updateClass({ id: klass.id, ...fields })
      } else {
        await api.createClass({ ...fields, school })
      }
      onSaved()
    } catch (err) {
      setError(err.message || 'Could not save the class.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal title={klass ? `Edit ${klass.name}` : 'Create class'}      subtitle="Assign a name, room and teachers to this class." onClose={onClose}>
      <form onSubmit={save} className="space-y-4">
        {error && (
          <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-2.5 text-sm font-medium text-danger">
            {error}
          </div>
        )}
        <Field label="Class name">
          <input
            autoFocus
            required
            value={fields.name}
            onChange={(e) => setFields({ ...fields, name: e.target.value })}
            placeholder="e.g. Grade 8 - C"
            className={inputClass}
          />
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Program">
            <select value={fields.program} onChange={(e) => setFields({ ...fields, program: e.target.value })} className={inputClass}>
              {PROGRAMS.map((p) => (
                <option key={p} value={p}>
                  {p}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Room">
            <input
              value={fields.room}
              onChange={(e) => setFields({ ...fields, room: e.target.value })}
              placeholder="e.g. Room 301"
              className={inputClass}
            />
          </Field>
        </div>

        <div>
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-ink-soft">Assigned teachers</span>
          {teachersLoading ? (
            <p className="text-sm text-ink-soft">Loading teachers…</p>
          ) : (
            <div className="flex flex-wrap gap-2">
              {(teachers || []).map((t) => {
                const on = fields.teacher_ids.includes(t.id)
                return (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => toggleTeacher(t.id)}
                    className={`rounded-full border px-3 py-1.5 text-xs font-semibold transition active:scale-[0.97] ${
                      on ? 'border-primary bg-primary text-white' : 'border-outline-soft bg-white text-ink-soft hover:border-primary/40'
                    }`}
                  >
                    {t.name}
                  </button>
                )
              })}
              {(teachers || []).length === 0 && <p className="text-sm text-ink-soft">No teachers yet in this school.</p>}
            </div>
          )}
        </div>

        <div className="flex justify-end gap-2 pt-2">
          <SecondaryButton type="button" onClick={onClose}>
            Cancel
          </SecondaryButton>
          <PrimaryButton type="submit" disabled={busy}>
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
            {busy ? 'Saving…' : klass ? 'Save changes' : 'Create class'}
          </PrimaryButton>
        </div>
      </form>
    </Modal>
  )
}

export default function ClassesPage() {
  const { user } = useAuth()
  const scope = user.school
  const { data: classes, loading, error, reload } = useFetch(() => api.getClasses(scope), [scope])
  const [query, setQuery] = useState('')
  const [modal, setModal] = useState(null) // { klass: null } = add | { klass } = edit
  const [confirmDelete, setConfirmDelete] = useState(null)
  const [deleting, setDeleting] = useState(false)

  const q = query.trim().toLowerCase()
  const filtered = (classes || []).filter(
    (c) => !q || c.name.toLowerCase().includes(q) || c.room.toLowerCase().includes(q),
  )

  async function confirmDeleteClass() {
    setDeleting(true)
    try {
      await api.deleteClass(confirmDelete.id)
      setConfirmDelete(null)
      reload()
    } catch (err) {
      alert(err.message || 'Could not delete the class.')
    } finally {
      setDeleting(false)
    }
  }

  return (
    <>
      <PageHeader
        title="Classes"
        subtitle="Organize classes, rooms and teacher assignments."
        actions={
          <PrimaryButton onClick={() => setModal({ klass: null })}>
            <Plus className="h-4 w-4" />
            Create class
          </PrimaryButton>
        }
      />

      <div className="relative mb-5 max-w-sm">
        <Search className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-outline" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search by name or room…"
          className={`${inputClass} pl-10`}
        />
      </div>

      {loading ? (
        <Spinner label="Loading classes…" />
      ) : error ? (
        <Card className="p-8 text-center">
          <p className="font-semibold text-danger">{error}</p>
        </Card>
      ) : filtered.length === 0 ? (
        <EmptyState
          title={q ? 'No classes match your search' : 'No classes yet'}
          hint={q ? 'Try a different name or room.' : 'Create your first class to start adding students.'}
          action={
            !q && (
              <PrimaryButton onClick={() => setModal({ klass: null })} className="mt-3">
                <Plus className="h-4 w-4" />
                Create class
              </PrimaryButton>
            )
          }
        />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {filtered.map((c) => (
            <Card key={c.id} className="flex flex-col gap-3 p-5">
              <Link to={`/classes/${c.id}`} className="group">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <h3 className="truncate text-base font-bold text-ink group-hover:text-primary">{c.name}</h3>
                    <p className="mt-0.5 flex items-center gap-1.5 text-sm text-ink-soft">
                      <DoorOpen className="h-3.5 w-3.5" />
                      {c.room || 'No room'}
                    </p>
                  </div>
                  <Badge tone="indigo">{c.program}</Badge>
                </div>
              </Link>

              <div className="flex items-center justify-between rounded-btn bg-surface-low px-3 py-2.5">
                <span className="flex items-center gap-2 text-sm font-bold text-ink">
                  <Users className="h-4 w-4 text-primary" />
                  {c.student_count}
                </span>
                <span className="text-xs font-semibold uppercase tracking-wide text-ink-soft">
                  {c.student_count === 1 ? 'student' : 'students'}
                </span>
              </div>

              <div className="flex min-h-8 flex-wrap items-center gap-1.5">
                {c.teachers.length > 0 ? (
                  c.teachers.map((t) => (
                    <span key={t} className="rounded-full bg-primary-soft px-2.5 py-0.5 text-xs font-semibold text-primary">
                      {t}
                    </span>
                  ))
                ) : (
                  <span className="text-xs italic text-ink-soft">No teacher assigned</span>
                )}
              </div>

              <div className="mt-auto flex gap-2 border-t border-outline-soft/60 pt-3">
                <Link
                  to={`/classes/${c.id}`}
                  className="flex flex-1 items-center justify-center gap-1.5 rounded-btn border border-primary/30 bg-white px-4 py-2 text-sm font-semibold text-primary transition hover:bg-primary-soft"
                >
                  <BookOpen className="h-4 w-4" />
                  View
                </Link>
                <SecondaryButton onClick={() => setModal({ klass: c })} className="!px-3 !py-2 text-xs">
                  Edit
                </SecondaryButton>
                <button
                  onClick={() => setConfirmDelete(c)}
                  title="Delete class"
                  className="rounded-btn border border-outline-soft/60 p-2 text-ink-soft transition hover:border-danger/30 hover:bg-danger-soft hover:text-danger"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            </Card>
          ))}
        </div>
      )}

      {modal && (
        <ClassModal
          klass={modal.klass}
          school={scope}
          onClose={() => setModal(null)}
          onSaved={() => {
            setModal(null)
            reload()
          }}
        />
      )}

      {confirmDelete && (
        <Modal title="Delete class?" subtitle="This cannot be undone." onClose={() => setConfirmDelete(null)}>
          <div className="space-y-4">
            <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-3 text-sm text-danger">
              <p className="font-semibold">{confirmDelete.name}</p>
              <p className="mt-1 text-ink-soft">
                Deleting this class will also remove its {confirmDelete.student_count} student
                {confirmDelete.student_count === 1 ? '' : 's'} and unassign the class from its teachers.
              </p>
            </div>
            <div className="flex justify-end gap-2">
              <SecondaryButton type="button" onClick={() => setConfirmDelete(null)}>
                Cancel
              </SecondaryButton>
              <button
                onClick={confirmDeleteClass}
                disabled={deleting}
                className="inline-flex items-center justify-center gap-2 rounded-btn bg-danger px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-danger/90 disabled:opacity-60"
              >
                {deleting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                {deleting ? 'Deleting…' : 'Delete class'}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </>
  )
}
