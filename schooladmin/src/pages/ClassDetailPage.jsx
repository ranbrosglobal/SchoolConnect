import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowLeft, CalendarDays, Loader2, Plus, Trash2 } from 'lucide-react'
import { api } from '../lib/api'
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
} from '../components/ui'

export default function ClassDetailPage() {
  const { id } = useParams()
  const { data: klass, loading, error, reload } = useFetch(() => api.getClass(id), [id])
  const [studentModal, setStudentModal] = useState(null) // { student: null } = add | { student } = edit
  const [confirmDelete, setConfirmDelete] = useState(null)
  const [deleting, setDeleting] = useState(false)

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

  if (loading) return <Spinner label="Loading class…" />
  if (error || !klass) {
    return (
      <Card className="p-8 text-center">
        <p className="font-semibold text-danger">{error || 'Class not found.'}</p>
        <Link to="/classes" className="mt-3 inline-block text-sm font-semibold text-primary hover:underline">
          ← Back to classes
        </Link>
      </Card>
    )
  }

  const students = klass.students || []
  const active = students.filter((s) => s.status === 'Active').length
  const attendance = students.length
    ? Math.round(students.reduce((a, s) => a + (s.attendance_pct || 0), 0) / students.length)
    : 0

  return (
    <>
      <Link to="/classes" className="mb-4 inline-flex items-center gap-1.5 text-sm font-semibold text-primary hover:underline">
        <ArrowLeft className="h-4 w-4" />
        Back to classes
      </Link>

      <PageHeader
        title={klass.name}
        subtitle={`${klass.program} · ${klass.room || 'No room'}${klass.school_name ? ` · ${klass.school_name}` : ''}`}
        actions={
          <>
            <Link
              to={`/timetable?class=${klass.id}`}
              className="inline-flex items-center justify-center gap-2 rounded-btn border border-primary/30 bg-white px-4 py-2.5 text-sm font-semibold text-primary transition hover:bg-primary-soft"
            >
              <CalendarDays className="h-4 w-4" />
              Timetable
            </Link>
            <PrimaryButton onClick={() => setStudentModal({ student: null })}>
              <Plus className="h-4 w-4" />
              Add student
            </PrimaryButton>
          </>
        }
      />

      <div className="mb-6 flex flex-wrap gap-2">
        {klass.teachers.length > 0 ? (
          klass.teachers.map((t) => (
            <span key={t} className="rounded-full bg-primary-soft px-3 py-1 text-xs font-semibold text-primary">
              {t}
            </span>
          ))
        ) : (
          <span className="text-xs italic text-ink-soft">No teacher assigned</span>
        )}
      </div>

      <div className="mb-6 grid grid-cols-3 gap-4">
        <Card className="p-4 text-center">
          <p className="text-2xl font-extrabold text-ink">{students.length}</p>
          <p className="text-xs font-semibold uppercase tracking-wide text-ink-soft">Students</p>
        </Card>
        <Card className="p-4 text-center">
          <p className="text-2xl font-extrabold text-success">{active}</p>
          <p className="text-xs font-semibold uppercase tracking-wide text-ink-soft">Active</p>
        </Card>
        <Card className="p-4 text-center">
          <p className="text-2xl font-extrabold text-primary">{attendance}%</p>
          <p className="text-xs font-semibold uppercase tracking-wide text-ink-soft">Attendance</p>
        </Card>
      </div>

      {students.length === 0 ? (
        <EmptyState
          title="No students in this class yet"
          hint="Add students with roll numbers to build the roster."
          action={
            <PrimaryButton onClick={() => setStudentModal({ student: null })} className="mt-3">
              <Plus className="h-4 w-4" />
              Add student
            </PrimaryButton>
          }
        />
      ) : (
        <Card className="overflow-hidden">
          <ul className="divide-y divide-outline-soft/60">
            {students.map((s) => (
              <li key={s.id} className="flex flex-wrap items-center gap-x-4 gap-y-2 px-5 py-3">
                <span className="w-8 shrink-0 text-center text-sm font-extrabold text-ink-soft">#{s.roll_number}</span>
                <Avatar name={s.name} size="sm" />
                <div className="min-w-0 flex-1 basis-40">
                  <p className="truncate text-sm font-semibold text-ink">{s.name}</p>
                  <p className="truncate text-xs text-ink-soft">{s.email}</p>
                </div>
                <span className="text-xs font-semibold text-ink-soft">{s.attendance_pct}%</span>
                <Badge tone={s.status === 'Active' ? 'green' : 'neutral'}>{s.status}</Badge>
                <div className="flex gap-2">
                  <SecondaryButton onClick={() => setStudentModal({ student: s })} className="!px-3 !py-1.5 text-xs">
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

      {studentModal && (
        <StudentModal
          student={studentModal.student}
          school={klass.school_id}
          onClose={() => setStudentModal(null)}
          onSaved={() => {
            setStudentModal(null)
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
                  #{confirmDelete.roll_number} · {klass.name}
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
