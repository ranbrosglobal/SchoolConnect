import { Link } from 'react-router-dom'
import { BookOpen, Building2, ChevronRight, GraduationCap, Plus, ShieldCheck, Users } from 'lucide-react'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { useFetch } from '../lib/useFetch'
import { Badge, Card, Spinner, StatCard } from '../components/ui'

export default function OverviewPage() {
  const { user } = useAuth()
  const { data, loading, error } = useFetch(() => api.getOverview(), [])

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
            <p className="text-xs font-bold uppercase tracking-wider text-white/70">All schools</p>
            <h1 className="mt-1 text-3xl font-extrabold tracking-tight">
              Welcome back, {user.full_name.split(' ')[0]}
            </h1>
            <p className="mt-1 text-sm text-white/80">
              {data.school_count} active schools · {data.school_admin_count} school admins ·{' '}
              {data.student_count} students across the network
            </p>
          </div>

        </div>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard
          icon={Building2}
          label="Active schools"
          value={data.school_count}
          accent="indigo"
          hint={`${data.disabled_school_count} disabled`}
        />
        <StatCard icon={ShieldCheck} label="School admins" value={data.school_admin_count} accent="blue" />
        <StatCard icon={GraduationCap} label="Teachers" value={data.teacher_count} accent="green" />
        <StatCard icon={Users} label="Students" value={data.student_count} accent="amber" />
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-[1fr_1.6fr]">
        <div className="space-y-6">
          <Card className="p-5">
            <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-ink-soft">Quick actions</h2>
            <div className="space-y-2">
              <Link
                to="/schools"
                className="group flex items-center justify-between rounded-btn border border-outline-soft bg-white px-4 py-3 text-sm font-semibold text-ink transition hover:border-primary/40 hover:bg-primary-soft"
              >
                <span className="flex items-center gap-2.5">
                  <Plus className="h-4 w-4 text-primary" />
                  Add school
                </span>
                <ChevronRight className="h-4 w-4 text-ink-soft transition group-hover:translate-x-0.5" />
              </Link>
              <Link
                to="/schools"
                className="group flex items-center justify-between rounded-btn border border-outline-soft bg-white px-4 py-3 text-sm font-semibold text-ink transition hover:border-primary/40 hover:bg-primary-soft"
              >
                <span className="flex items-center gap-2.5">
                  <ShieldCheck className="h-4 w-4 text-primary" />
                  Manage school admins
                </span>
                <ChevronRight className="h-4 w-4 text-ink-soft transition group-hover:translate-x-0.5" />
              </Link>
            </div>
          </Card>

          <Card className="p-5">
            <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-ink-soft">Network totals</h2>
            <div className="grid grid-cols-3 gap-2 text-center">
              <div className="rounded-btn bg-surface-low py-3">
                <p className="text-lg font-extrabold text-ink">{data.class_count}</p>
                <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Classes</p>
              </div>
              <div className="rounded-btn bg-surface-low py-3">
                <p className="text-lg font-extrabold text-ink">{data.teacher_count}</p>
                <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Teachers</p>
              </div>
              <div className="rounded-btn bg-surface-low py-3">
                <p className="text-lg font-extrabold text-ink">
                  {data.school_count + data.disabled_school_count}
                </p>
                <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Schools</p>
              </div>
            </div>
            <p className="mt-3 flex items-center gap-1.5 text-xs text-ink-soft">
              <BookOpen className="h-3.5 w-3.5" />
              Teacher, class and student figures are aggregate counts from the network.
            </p>
          </Card>
        </div>

        <Card className="overflow-hidden">
          <div className="flex items-center justify-between border-b border-outline-soft/60 px-5 py-4">
            <h2 className="text-sm font-bold uppercase tracking-wide text-ink-soft">Schools at a glance</h2>
            <Link to="/schools" className="text-xs font-semibold text-primary hover:underline">
              Manage all
            </Link>
          </div>
          {data.recent_schools.length === 0 ? (
            <p className="px-5 py-8 text-center text-sm text-ink-soft">No schools yet.</p>
          ) : (
            <ul className="divide-y divide-outline-soft/60">
              {data.recent_schools.map((s) => (
                <li key={s.id}>
                  <Link
                    to="/schools"
                    className="flex items-center justify-between gap-4 px-5 py-3.5 transition hover:bg-surface-low"
                  >
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold text-ink">
                        {s.name} <span className="font-normal text-ink-soft">· {s.location}</span>
                      </p>
                      <p className="mt-0.5 truncate text-xs text-ink-soft">
                        {s.admin_names.length > 0 ? `Admins: ${s.admin_names.join(', ')}` : 'No school admin yet'}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      <Badge tone={s.status === 'Active' ? 'green' : 'neutral'}>{s.status}</Badge>
                      <Badge tone="neutral">{s.student_count} students</Badge>
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
