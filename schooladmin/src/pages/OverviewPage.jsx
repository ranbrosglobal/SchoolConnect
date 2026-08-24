import { Link } from 'react-router-dom'
import { BookOpen, ChevronRight, GraduationCap, Plus, Sparkles, Users } from 'lucide-react'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { useFetch } from '../lib/useFetch'
import { Badge, Card, Spinner, StatCard } from '../components/ui'

export default function OverviewPage() {
  const { user } = useAuth()
  const scope = user.school
  const { data, loading, error } = useFetch(() => api.getOverview(scope), [scope])

  if (loading) return <Spinner label="Loading dashboard…" />
  if (error || !data) {
    return (
      <Card className="p-8 text-center">
        <p className="font-semibold text-danger">{error || 'Could not load the dashboard.'}</p>
      </Card>
    )
  }

  return (
    <>
      {/* Hero */}
      <div className="relative mb-6 overflow-hidden rounded-card bg-gradient-to-br from-[#1e2d8a] to-primary p-6 text-white shadow-card sm:p-8">
        <div className="pointer-events-none absolute -right-12 -top-12 h-40 w-40 rounded-full bg-white/[0.07] blur-3xl" />
        <div className="relative flex flex-wrap items-end justify-between gap-4">
          <div>
            <p className="text-xs font-bold uppercase tracking-wider text-white/70">My school</p>
            <h1 className="mt-1 text-3xl font-extrabold tracking-tight">{user.school_name}</h1>
            <p className="mt-1 text-sm text-white/80">
              You manage {data.teacher_count} teachers, {data.class_count} classes and {data.student_count}{' '}
              students
            </p>
          </div>

        </div>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard icon={Users} label="Students" value={data.student_count} accent="blue" />
        <StatCard icon={GraduationCap} label="Teachers" value={data.teacher_count} accent="green" />
        <StatCard icon={BookOpen} label="Classes" value={data.class_count} accent="amber" />
        <StatCard icon={Sparkles} label="Avg attendance" value={`${data.attendance_avg}%`} accent="indigo" />
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-[1fr_1.6fr]">
        <Card className="p-5">
          <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-ink-soft">Quick actions</h2>
          <div className="space-y-2">
            {[
              { to: '/teachers', label: 'Add teacher' },
              { to: '/classes', label: 'Create class' },
              { to: '/students', label: 'Add student' },
            ].map((a) => (
              <Link
                key={a.label}
                to={a.to}
                className="group flex items-center justify-between rounded-btn border border-outline-soft bg-white px-4 py-3 text-sm font-semibold text-ink transition hover:border-primary/40 hover:bg-primary-soft"
              >
                <span className="flex items-center gap-2.5">
                  <Plus className="h-4 w-4 text-primary" />
                  {a.label}
                </span>
                <ChevronRight className="h-4 w-4 text-ink-soft transition group-hover:translate-x-0.5" />
              </Link>
            ))}
          </div>
        </Card>

        <Card className="overflow-hidden">
          <div className="flex items-center justify-between border-b border-outline-soft/60 px-5 py-4">
            <h2 className="text-sm font-bold uppercase tracking-wide text-ink-soft">Recent classes</h2>
            <Link to="/classes" className="text-xs font-semibold text-primary hover:underline">
              View all
            </Link>
          </div>
          {data.recent_classes.length === 0 ? (
            <p className="px-5 py-8 text-center text-sm text-ink-soft">No classes yet.</p>
          ) : (
            <ul className="divide-y divide-outline-soft/60">
              {data.recent_classes.map((c) => (
                <li key={c.id}>
                  <Link
                    to={`/classes/${c.id}`}
                    className="flex items-center justify-between gap-4 px-5 py-3.5 transition hover:bg-surface-low"
                  >
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold text-ink">
                        {c.name} <span className="font-normal text-ink-soft">· {c.room}</span>
                      </p>
                      <p className="mt-0.5 truncate text-xs text-ink-soft">
                        {c.teachers.join(', ') || 'No teacher assigned'}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      {c.school_name && <Badge tone="indigo">{c.school_name}</Badge>}
                      <Badge tone="neutral">{c.student_count} students</Badge>
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </>
  )
}
