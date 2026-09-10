import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowLeft, BookOpen, CalendarCheck, DoorOpen, Hash, Mail, UserCheck } from 'lucide-react'
import { api } from '../lib/api'
import { useFetch } from '../lib/useFetch'
import StudentModal from '../components/StudentModal'
import { Avatar, Badge, Card, PageHeader, SecondaryButton, Spinner } from '../components/ui'

function InfoRow({ icon: Icon, label, value }) {
  return (
    <div className="flex items-center gap-3 py-2.5">
      <span className="rounded-full bg-primary-soft p-2 text-primary">
        <Icon className="h-4 w-4" />
      </span>
      <div className="min-w-0">
        <p className="text-xs font-semibold uppercase tracking-wide text-ink-soft">{label}</p>
        <p className="truncate text-sm font-semibold text-ink">{value || '—'}</p>
      </div>
    </div>
  )
}

export default function StudentDetailPage() {
  const { id } = useParams()
  const { data: student, loading, error, reload } = useFetch(() => api.getStudent(id), [id])
  const [editing, setEditing] = useState(false)

  if (loading) return <Spinner label="Loading student…" />
  if (error || !student) {
    return (
      <Card className="p-8 text-center">
        <p className="font-semibold text-danger">{error || 'Student not found.'}</p>
        <Link to="/students" className="mt-3 inline-block text-sm font-semibold text-primary hover:underline">
          ← Back to students
        </Link>
      </Card>
    )
  }

  return (
    <>
      <Link to="/students" className="mb-4 inline-flex items-center gap-1.5 text-sm font-semibold text-primary hover:underline">
        <ArrowLeft className="h-4 w-4" />
        Back to students
      </Link>

      <PageHeader
        title={student.name}
        subtitle={student.email}
        actions={
          <div className="flex gap-2">
            <SecondaryButton onClick={() => setEditing(true)}>Edit profile</SecondaryButton>
            <Link
              to={`/classes/${student.class_id}`}
              className="inline-flex items-center justify-center gap-2 rounded-btn bg-primary px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-primary-container active:scale-[0.97]"
            >
              <BookOpen className="h-4 w-4" />
              View class
            </Link>
          </div>
        }
      />

      <div className="grid gap-6 lg:grid-cols-[1fr_1.6fr]">
        <Card className="p-6">
          <div className="flex flex-col items-center gap-3 border-b border-outline-soft/60 pb-5 text-center">
            <Avatar name={student.name} size="lg" />
            <div>
              <p className="text-base font-bold text-ink">{student.name}</p>
              <p className="text-sm text-ink-soft">{student.email}</p>
            </div>
            <Badge tone={student.status === 'Active' ? 'green' : 'neutral'}>{student.status}</Badge>
          </div>
          <div className="mt-3 divide-y divide-outline-soft/40">
            <InfoRow icon={BookOpen} label="Class" value={student.class_name} />
            <InfoRow icon={Hash} label="Roll number" value={`#${student.roll_number}`} />
            <InfoRow icon={CalendarCheck} label="Attendance" value={`${student.attendance_pct}%`} />
            <InfoRow icon={UserCheck} label="Status" value={student.status} />
          </div>
        </Card>

        <div className="space-y-6">
          <Card className="p-6">
            <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-ink-soft">Teachers</h2>
            {student.teachers.length > 0 ? (
              <div className="flex flex-wrap gap-2">
                {student.teachers.map((t) => (
                  <span key={t} className="rounded-full bg-primary-soft px-3 py-1 text-xs font-semibold text-primary">
                    {t}
                  </span>
                ))}
              </div>
            ) : (
              <p className="text-sm text-ink-soft">No teacher assigned to this class.</p>
            )}
          </Card>
          <Card className="p-6">
            <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-ink-soft">School</h2>
            <div className="divide-y divide-outline-soft/40">
              <InfoRow icon={BookOpen} label="School" value={student.school_name} />
              <InfoRow icon={DoorOpen} label="Room" value={student.room} />
              <InfoRow icon={Mail} label="Email" value={student.email} />
            </div>
          </Card>
        </div>
      </div>

      {editing && (
        <StudentModal
          student={student}
          school={student.school_id}
          onClose={() => setEditing(false)}
          onSaved={() => {
            setEditing(false)
            reload()
          }}
        />
      )}
    </>
  )
}
