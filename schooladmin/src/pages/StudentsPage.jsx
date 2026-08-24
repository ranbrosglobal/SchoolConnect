import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Loader2, Plus, Search, Trash2 } from 'lucide-react'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { useFetch } from '../lib/useFetch'
import StudentModal from '../components/StudentModal'
import {
  Avatar,
  Badge,
  Card,
  EmptyState,
  Modal,
  PageHeader,
  PrimaryButton,
  SecondaryButton,
  Spinner,
  inputClass,
} from '../components/ui'

export default function StudentsPage() {
  const { user } = useAuth()
  const scope = user.school
  const { data: students, loading, error, reload } = useFetch(() => api.getStudents(scope), [scope])
  const [query, setQuery] = useState('')
  const [modal, setModal] = useState(null) // { student: null } = add | { student } = edit
  const [confirmDelete, setConfirmDelete] = useState(null)
  const [deleting, setDeleting] = useState(false)

  const q = query.trim().toLowerCase()
  const filtered = (students || []).filter(
    (s) =>
      !q ||
      s.name.toLowerCase().includes(q) ||
      s.email.toLowerCase().includes(q) ||
      (s.class_name || '').toLowerCase().includes(q),
  )

  async function confirmDeleteStudent() {
    setDeleting(true)
    try {
      await api.deleteStudent(confirmDelete.id)
      setConfirmDelete(null)
      reload()
    } catch (err) {
      alert(err.message || 'Could not delete the student.')
    } finally {
      setDeleting(false)
    }
  }

  return (
    <>
      <PageHeader
        title="Students"
        subtitle="Manage student records and attendance."
        actions={
          <PrimaryButton onClick={() => setModal({ student: null })}>
            <Plus className="h-4 w-4" />
            Add student
          </PrimaryButton>
        }
      />

      <div className="relative mb-5 max-w-sm">
        <Search className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-outline" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search by name, email or class…"
          className={`${inputClass} pl-10`}
        />
      </div>

      {loading ? (
        <Spinner label="Loading students…" />
      ) : error ? (
        <Card className="p-8 text-center">
          <p className="font-semibold text-danger">{error}</p>
        </Card>
      ) : filtered.length === 0 ? (
        <EmptyState
          title={q ? 'No students match your search' : 'No students yet'}
          hint={q ? 'Try a different name, email or class.' : 'Add your first student to get started.'}
          action={
            !q && (
              <PrimaryButton onClick={() => setModal({ student: null })} className="mt-3">
                <Plus className="h-4 w-4" />
                Add student
              </PrimaryButton>
            )
          }
        />
      ) : (
        <Card className="overflow-hidden">
          <ul className="divide-y divide-outline-soft/60">
            {filtered.map((s) => (
              <li key={s.id} className="flex flex-wrap items-center gap-x-4 gap-y-2 px-5 py-3">
                <Avatar name={s.name} />
                <div className="min-w-0 flex-1 basis-40">
                  <Link to={`/students/${s.id}`} className="truncate text-sm font-semibold text-ink hover:text-primary">
                    {s.name}
                  </Link>
                  <p className="truncate text-xs text-ink-soft">{s.email}</p>
                </div>
                <Badge tone="indigo">{s.class_name || '—'}</Badge>
                <span className="w-8 text-center text-xs font-bold text-ink-soft">#{s.roll_number}</span>
                <span className="text-xs font-semibold text-ink-soft">{s.attendance_pct}%</span>
                <Badge tone={s.status === 'Active' ? 'green' : 'neutral'}>{s.status}</Badge>
                <div className="flex gap-2">
                  <SecondaryButton onClick={() => setModal({ student: s })} className="!px-3 !py-1.5 text-xs">
                    Edit
                  </SecondaryButton>
                  <button
                    onClick={() => setConfirmDelete(s)}
                    title="Remove student"
                    className="rounded-btn border border-outline-soft/60 p-1.5 text-ink-soft transition hover:border-danger/30 hover:bg-danger-soft hover:text-danger"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </Card>
      )}

      {modal && (
        <StudentModal
          student={modal.student}
          school={scope}
          onClose={() => setModal(null)}
          onSaved={() => {
            setModal(null)
            reload()
          }}
        />
      )}

      {confirmDelete && (
        <Modal title="Remove student?" subtitle="This cannot be undone." onClose={() => setConfirmDelete(null)}>
          <div className="space-y-4">
            <div className="flex items-center gap-3 rounded-btn border border-danger/20 bg-danger-soft px-4 py-3 text-sm">
              <Avatar name={confirmDelete.name} size="sm" />
              <div>
                <p className="font-semibold text-danger">{confirmDelete.name}</p>
                <p className="text-xs text-ink-soft">
                  #{confirmDelete.roll_number} · {confirmDelete.class_name || 'No class'}
                </p>
              </div>
            </div>
            <div className="flex justify-end gap-2">
              <SecondaryButton type="button" onClick={() => setConfirmDelete(null)}>
                Cancel
              </SecondaryButton>
              <button
                onClick={confirmDeleteStudent}
                disabled={deleting}
                className="inline-flex items-center justify-center gap-2 rounded-btn bg-danger px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-danger/90 disabled:opacity-60"
              >
                {deleting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                {deleting ? 'Removing…' : 'Remove student'}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </>
  )
}
