import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  AlertTriangle,
  BookOpen,
  Download,
  GraduationCap,
  RefreshCw,
  Target,
  Users,
} from 'lucide-react'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { useFetch } from '../lib/useFetch'
import {
  LOW_ATTENDANCE,
  buildReportCsv,
  buildSchoolReport,
  downloadCsv,
  rankClasses,
  reportFileName,
} from '../lib/reports'
import {
  Badge,
  Card,
  EmptyState,
  Modal,
  PageHeader,
  SecondaryButton,
  Spinner,
  StatCard,
  inputClass,
} from '../components/ui'

const BAR_TONE = {
  green: 'bg-success',
  blue: 'bg-info',
  amber: 'bg-warning-bright',
  red: 'bg-danger',
  neutral: 'bg-outline',
}

const BADGE_TONE = { green: 'green', blue: 'blue', amber: 'amber', red: 'red', neutral: 'neutral' }

const plural = (count, one, many) => `${count} ${count === 1 ? one : many}`

/** Horizontal bar list; every row can open a drill-down. */
function Bars({ rows, emptyLabel = 'No data yet' }) {
  const max = Math.max(1, ...rows.map((r) => r.value))
  if (rows.length === 0) {
    return <p className="py-8 text-center text-sm text-ink-soft">{emptyLabel}</p>
  }
  return (
    <div className="space-y-3.5">
      {rows.map((row) => {
        const interactive = Boolean(row.onSelect)
        return (
          <button
            key={row.key}
            type="button"
            onClick={row.onSelect}
            disabled={!interactive}
            className={`block w-full rounded-btn px-1.5 py-1 text-left transition ${
              interactive ? 'hover:bg-surface-low' : 'cursor-default'
            }`}
          >
            <div className="flex items-baseline justify-between gap-3">
              <span className="min-w-0 truncate text-sm font-semibold text-ink">{row.label}</span>
              <span className="shrink-0 text-sm font-bold text-ink">{row.display ?? row.value}</span>
            </div>
            <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-surface-low">
              <div
                className={`h-full rounded-full transition-all ${BAR_TONE[row.tone] || 'bg-primary'}`}
                style={{ width: `${Math.max(row.value > 0 ? 4 : 0, Math.round((row.value / max) * 100))}%` }}
              />
            </div>
            {row.hint && <p className="mt-1 truncate text-xs text-ink-soft">{row.hint}</p>}
          </button>
        )
      })}
    </div>
  )
}

function SectionCard({ title, hint, action, className = '', children }) {
  return (
    <Card className={`flex min-w-0 flex-col ${className}`}>
      <div className="flex items-start justify-between gap-3 border-b border-outline-soft/60 px-5 py-4">
        <div>
          <h2 className="text-sm font-bold uppercase tracking-wide text-ink-soft">{title}</h2>
          {hint && <p className="mt-0.5 text-xs text-ink-soft">{hint}</p>}
        </div>
        {action}
      </div>
      <div className="flex-1 p-5">{children}</div>
    </Card>
  )
}

function RowList({ items }) {
  if (items.length === 0) {
    return <p className="py-6 text-center text-sm text-ink-soft">Nothing here.</p>
  }
  return (
    <ul className="divide-y divide-outline-soft/60">
      {items.map((item, i) => {
        const body = (
          <>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold text-ink">{item.title}</p>
              {item.subtitle && <p className="truncate text-xs text-ink-soft">{item.subtitle}</p>}
            </div>
            {item.value !== undefined && (
              <span className="shrink-0 text-sm font-semibold text-ink-soft">{item.value}</span>
            )}
          </>
        )
        return (
          <li key={`${item.title}-${i}`}>
            {item.to ? (
              <Link to={item.to} className="flex items-center gap-3 px-1 py-2.5 transition hover:bg-surface-low">
                {body}
              </Link>
            ) : item.onSelect ? (
              <button
                type="button"
                onClick={item.onSelect}
                className="flex w-full items-center gap-3 px-1 py-2.5 text-left transition hover:bg-surface-low"
              >
                {body}
              </button>
            ) : (
              <div className="flex items-center gap-3 px-1 py-2.5">{body}</div>
            )}
          </li>
        )
      })}
    </ul>
  )
}

function DrillModal({ title, subtitle, onClose, children }) {
  return (
    <Modal title={title} subtitle={subtitle} onClose={onClose} wide>
      <div className="max-h-[65vh] overflow-y-auto pr-1">{children}</div>
    </Modal>
  )
}

export default function ReportsPage() {
  const { user } = useAuth()
  const scope = user.school
  const { data, loading, error, reload } = useFetch(
    () => Promise.all([api.getTeachers(scope), api.getClasses(scope), api.getStudents(scope)]),
    [scope],
  )
  const [classFilter, setClassFilter] = useState('all')
  const [detail, setDetail] = useState(null)
  const [exported, setExported] = useState(false)

  const [teachers, classes, students] = data || [[], [], []]

  const scoped = useMemo(() => {
    if (classFilter === 'all') return { teachers, classes, students }
    const picked = classes.filter((c) => c.id === classFilter)
    const teacherIds = new Set(picked.flatMap((c) => c.teacher_ids || []))
    return {
      teachers: teachers.filter((t) => teacherIds.has(t.id)),
      classes: picked,
      students: students.filter((s) => s.class_id === classFilter),
    }
  }, [classFilter, teachers, classes, students])

  const report = useMemo(() => buildSchoolReport(scoped), [scoped])
  const ranked = useMemo(() => rankClasses(report.byClass), [report])

  function exportCsv() {
    downloadCsv(
      reportFileName(user.school_name || 'school'),
      buildReportCsv(report, { schoolName: user.school_name }),
    )
    setExported(true)
    window.setTimeout(() => setExported(false), 2200)
  }

  const scopeLabel =
    classFilter === 'all'
      ? 'All classes'
      : classes.find((c) => c.id === classFilter)?.name || 'Selected class'

  const exportButton = (
    <div className="flex items-center gap-2">
      <SecondaryButton onClick={reload} className="!px-3" title="Refresh report">
        <RefreshCw className="h-4 w-4" />
        <span className="hidden sm:inline">Refresh</span>
      </SecondaryButton>
      <SecondaryButton onClick={exportCsv} disabled={loading || Boolean(error)}>
        <Download className="h-4 w-4" />
        {exported ? 'Exported' : 'Export CSV'}
      </SecondaryButton>
    </div>
  )

  if (loading) return <Spinner label="Building report…" />
  if (error) {
    return (
      <>
        <PageHeader title="Executive reports" subtitle="Attendance, enrolment and staffing at a glance." />
        <Card className="p-8 text-center">
          <p className="font-semibold text-danger">{error}</p>
          <SecondaryButton onClick={reload} className="mt-4">
            <RefreshCw className="h-4 w-4" />
            Try again
          </SecondaryButton>
        </Card>
      </>
    )
  }

  if (teachers.length === 0 && classes.length === 0 && students.length === 0) {
    return (
      <>
        <PageHeader
          title="Executive reports"
          subtitle="Attendance, enrolment and staffing at a glance."
          actions={exportButton}
        />
        <EmptyState
          title="Nothing to report yet"
          hint="Add teachers, classes and students first — then this page fills with enrollment, attendance and workload analytics."
          action={
            <Link to="/students" className="mt-3">
              <SecondaryButton>
                <Users className="h-4 w-4" />
                Add students
              </SecondaryButton>
            </Link>
          }
        />
      </>
    )
  }

  const t = report.totals
  const noAttendance = t.students > 0 && t.recordedCount === 0

  return (
    <>
      <PageHeader
        title="Executive reports"
        subtitle={`${user.school_name} · generated ${report.generatedAt.toLocaleString()}`}
        actions={exportButton}
      />

      <div className="mb-5 flex flex-wrap items-end gap-3">
        <label className="block">
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-ink-soft">Scope</span>
          <select value={classFilter} onChange={(e) => setClassFilter(e.target.value)} className={`${inputClass} min-w-56`}>
            <option value="all">All classes</option>
            {classes.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
                {c.program ? ` · ${c.program}` : ''}
              </option>
            ))}
          </select>
        </label>
        <p className="pb-3 text-xs text-ink-soft">
          Showing <span className="font-semibold text-ink">{scopeLabel}</span> —{' '}
          {t.students} students · {t.teachers} teachers · {t.classes} classes
        </p>
      </div>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard
          icon={Users}
          label="Students"
          value={t.students}
          accent="blue"
          hint={`${t.activeStudents} active · ${t.studentsPerClass} per class`}
        />
        <StatCard
          icon={GraduationCap}
          label="Teachers"
          value={t.teachers}
          accent="green"
          hint={`${t.activeTeachers} active · ${t.studentsPerTeacher} students each`}
        />
        <StatCard
          icon={BookOpen}
          label="Classes"
          value={t.classes}
          accent="amber"
          hint={`${t.programs} programs`}
        />
        <StatCard
          icon={Target}
          label="Avg attendance"
          value={t.recordedCount ? `${t.attendanceAvg}%` : '—'}
          accent="indigo"
          hint={`${t.recordedCount}/${t.students} students recorded`}
        />
      </div>

      {noAttendance && (
        <div className="mt-4 flex items-start gap-3 rounded-btn border border-warning/30 bg-warning-soft px-4 py-3 text-sm text-warning">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>
            Attendance has not been recorded for any student yet, so attendance figures are shown as “—”. Teachers
            mark attendance from the mobile app; it will appear here automatically.
          </p>
        </div>
      )}

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <SectionCard
          title="Attendance distribution"
          hint="Click a band to see exactly which students are in it."
        >
          <Bars
            rows={report.attendance.map((b) => ({
              key: b.key,
              label: b.label,
              value: b.count,
              display: `${b.count} · ${b.share}%`,
              tone: b.tone,
              hint:
                b.key === 'unrecorded'
                  ? 'No attendance marked for these students'
                  : `${b.count} of ${t.students} students`,
              onSelect: b.count > 0 ? () => setDetail({ kind: 'bucket', bucket: b }) : undefined,
            }))}
            emptyLabel="No students in scope"
          />
        </SectionCard>

        <SectionCard
          title="Enrolment by class"
          hint="Click a class for its roster and teacher load."
          action={<Badge tone="neutral">{report.byClass.length} classes</Badge>}
        >
          <Bars
            rows={report.byClass.map((c) => ({
              key: c.id,
              label: c.name,
              value: c.studentCount,
              display: `${c.studentCount}`,
              tone: c.teachers.length === 0 ? 'amber' : 'green',
              hint:
                c.teachers.length === 0
                  ? 'No teacher assigned'
                  : `${c.teachers.join(', ')} · ${c.recordedCount ? `${c.attendanceAvg}% attendance` : 'no attendance yet'}`,
              onSelect: () => setDetail({ kind: 'class', cls: c }),
            }))}
            emptyLabel="No classes yet"
          />
        </SectionCard>
      </div>

      <SectionCard
        title="Class scorecard"
        hint={classFilter === 'all' ? 'Ranked by recorded attendance.' : 'Selected class only.'}
        className="mt-6"
      >
        <div className="-mx-2 overflow-x-auto">
          <table className="w-full min-w-[720px] border-collapse text-sm">
            <thead>
              <tr className="text-left text-xs font-bold uppercase tracking-wide text-ink-soft">
                <th className="px-2 pb-2">Class</th>
                <th className="px-2 pb-2">Program</th>
                <th className="px-2 pb-2 text-right">Students</th>
                <th className="px-2 pb-2 text-right">Teachers</th>
                <th className="px-2 pb-2 text-right">Attendance</th>
                <th className="px-2 pb-2 text-right">Health</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-outline-soft/60">
              {ranked.map((c) => (
                <tr
                  key={c.id}
                  onClick={() => setDetail({ kind: 'class', cls: c })}
                  className="cursor-pointer transition hover:bg-surface-low"
                >
                  <td className="px-2 py-3">
                    <p className="font-semibold text-ink">{c.name}</p>
                    <p className="text-xs text-ink-soft">{c.room || 'No room'}</p>
                  </td>
                  <td className="px-2 py-3 text-ink-soft">{c.program || '—'}</td>
                  <td className="px-2 py-3 text-right font-semibold text-ink">{c.studentCount}</td>
                  <td className="px-2 py-3 text-right text-ink-soft">{c.teachers.length}</td>
                  <td className="px-2 py-3 text-right font-semibold text-ink">
                    {c.recordedCount ? `${c.attendanceAvg}%` : '—'}
                  </td>
                  <td className="px-2 py-3 text-right">
                    <Badge tone={c.recordedCount === 0 ? 'neutral' : c.attendanceAvg >= 85 ? 'green' : c.attendanceAvg >= LOW_ATTENDANCE ? 'amber' : 'red'}>
                      {c.recordedCount === 0 ? 'No data' : c.attendanceAvg >= 85 ? 'Strong' : c.attendanceAvg >= LOW_ATTENDANCE ? 'Watch' : 'At risk'}
                    </Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {ranked.length === 0 && <p className="px-2 py-8 text-center text-sm text-ink-soft">No classes with students yet.</p>}
        </div>
      </SectionCard>

      <div className="mt-6 grid gap-6 lg:grid-cols-[1.3fr_1fr]">
        <SectionCard
          title="Teacher workload"
          hint="Classes and students each teacher is responsible for."
          action={<Badge tone="neutral">{report.teacherWorkload.length} teachers</Badge>}
        >
          <RowList
            items={report.teacherWorkload.map((teach) => ({
              title: teach.name,
              subtitle: `${teach.subjects.join(', ') || 'No subject'} · ${teach.classes.join(', ') || 'No classes'}`,
              value: `${plural(teach.classCount, 'class', 'classes')} · ${plural(teach.studentCount, 'student', 'students')}`,
              onSelect: () => setDetail({ kind: 'teacher', teacher: teach }),
            }))}
          />
        </SectionCard>

        <SectionCard title="Programs" hint="Enrolment and attendance by program.">
          <RowList
            items={report.byProgram.map((p) => ({
              title: p.name,
              subtitle: `${p.classes} ${p.classes === 1 ? 'class' : 'classes'}`,
              value: `${p.studentCount} students · ${p.attendanceAvg}%`,
              onSelect: () => setDetail({ kind: 'program', program: p }),
            }))}
          />
        </SectionCard>
      </div>

      <SectionCard
        title="Needs attention"
        hint="Gaps the school admin should act on."
        className="mt-6"
        action={<Badge tone={report.needsAttention.length ? 'amber' : 'green'}>{report.needsAttention.length ? `${report.needsAttention.length} areas` : 'All clear'}</Badge>}
      >
        {report.needsAttention.length === 0 ? (
          <div className="flex items-center gap-3 rounded-btn bg-success-soft px-4 py-3 text-sm text-success">
            <Target className="h-4 w-4" />
            Every class is staffed, attendance is recorded and no students need follow-up.
          </div>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            {report.needsAttention.map((group) => (
              <button
                key={group.key}
                onClick={() => setDetail({ kind: 'attention', group })}
                className="flex items-start justify-between gap-3 rounded-btn border border-outline-soft bg-white px-4 py-3 text-left transition hover:border-primary/40 hover:bg-primary-soft"
              >
                <div>
                  <p className="text-sm font-semibold text-ink">{group.label}</p>
                  <p className="mt-0.5 text-xs text-ink-soft">{group.detail}</p>
                </div>
                <Badge tone={BADGE_TONE[group.tone] || 'neutral'}>{group.count}</Badge>
              </button>
            ))}
          </div>
        )}
      </SectionCard>

      {detail?.kind === 'bucket' && (
        <DrillModal
          title={`Attendance ${detail.bucket.label}`}
          subtitle={`${detail.bucket.count} of ${t.students} students in ${scopeLabel.toLowerCase()}`}
          onClose={() => setDetail(null)}
        >
          <RowList
            items={detail.bucket.students.map((s) => ({
              title: s.name,
              subtitle: [s.class_name, s.roll_number ? `Roll ${s.roll_number}` : ''].filter(Boolean).join(' · ') || 'No class',
              value: s.attendance_pct > 0 ? `${s.attendance_pct}%` : 'Not recorded',
              to: s.id ? `/students/${s.id}` : undefined,
            }))}
          />
        </DrillModal>
      )}

      {detail?.kind === 'class' && (
        <DrillModal
          title={detail.cls.name}
          subtitle={`${detail.cls.program || 'No program'} · ${detail.cls.room || 'No room'} · ${detail.cls.teachers.join(', ') || 'No teacher assigned'}`}
          onClose={() => setDetail(null)}
        >
          <div className="mb-4 grid grid-cols-3 gap-2 text-center">
            <div className="rounded-btn bg-surface-low py-2.5">
              <p className="text-lg font-extrabold text-ink">{detail.cls.studentCount}</p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Students</p>
            </div>
            <div className="rounded-btn bg-surface-low py-2.5">
              <p className="text-lg font-extrabold text-ink">{detail.cls.teachers.length}</p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Teachers</p>
            </div>
            <div className="rounded-btn bg-surface-low py-2.5">
              <p className="text-lg font-extrabold text-ink">
                {detail.cls.recordedCount ? `${detail.cls.attendanceAvg}%` : '—'}
              </p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Attendance</p>
            </div>
          </div>
          <RowList
            items={detail.cls.students.map((s) => ({
              title: s.name,
              subtitle: `Roll ${s.roll_number || '—'}${s.status === 'Inactive' ? ' · Inactive' : ''}`,
              value: s.attendance_pct > 0 ? `${s.attendance_pct}%` : 'Not recorded',
              to: `/students/${s.id}`,
            }))}
          />
          <div className="mt-4 flex justify-end">
            <Link to={`/classes/${detail.cls.id}`}>
              <SecondaryButton>Open class</SecondaryButton>
            </Link>
          </div>
        </DrillModal>
      )}

      {detail?.kind === 'teacher' && (
        <DrillModal
          title={detail.teacher.name}
          subtitle={`${detail.teacher.subjects.join(', ') || 'No subject'} · ${detail.teacher.status}`}
          onClose={() => setDetail(null)}
        >
          <div className="mb-4 grid grid-cols-3 gap-2 text-center">
            <div className="rounded-btn bg-surface-low py-2.5">
              <p className="text-lg font-extrabold text-ink">{detail.teacher.classCount}</p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Classes</p>
            </div>
            <div className="rounded-btn bg-surface-low py-2.5">
              <p className="text-lg font-extrabold text-ink">{detail.teacher.studentCount}</p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Students</p>
            </div>
            <div className="rounded-btn bg-surface-low py-2.5">
              <p className="text-lg font-extrabold text-ink">
                {detail.teacher.recordedCount ? `${detail.teacher.attendanceAvg}%` : '—'}
              </p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Attendance</p>
            </div>
          </div>
          <RowList
            items={report.byClass
              .filter((c) => detail.teacher.classes.includes(c.name))
              .map((c) => ({
                title: c.name,
                subtitle: `${c.program || 'No program'} · ${c.room || 'No room'}`,
                value: `${c.studentCount} students`,
                onSelect: () => setDetail({ kind: 'class', cls: c }),
              }))}
          />
          {detail.teacher.email && (
            <p className="mt-4 text-xs text-ink-soft">Contact: {detail.teacher.email}</p>
          )}
        </DrillModal>
      )}

      {detail?.kind === 'program' && (
        <DrillModal
          title={detail.program.name}
          subtitle={`${detail.program.classes} ${detail.program.classes === 1 ? 'class' : 'classes'} · ${detail.program.studentCount} students · ${detail.program.attendanceAvg}% attendance`}
          onClose={() => setDetail(null)}
        >
          <RowList
            items={report.byClass
              .filter((c) => (c.program.trim() || 'Unassigned program') === detail.program.name)
              .map((c) => ({
                title: c.name,
                subtitle: `${c.teachers.join(', ') || 'No teacher'} · ${c.room || 'No room'}`,
                value: `${c.studentCount} students`,
                onSelect: () => setDetail({ kind: 'class', cls: c }),
              }))}
          />
        </DrillModal>
      )}

      {detail?.kind === 'attention' && (
        <DrillModal
          title={detail.group.label}
          subtitle={`${detail.group.count} ${detail.group.count === 1 ? 'item' : 'items'} · ${detail.group.detail}`}
          onClose={() => setDetail(null)}
        >
          <RowList items={detail.group.rows} />
        </DrillModal>
      )}
    </>
  )
}
