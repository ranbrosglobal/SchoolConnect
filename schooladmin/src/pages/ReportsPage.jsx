import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  AlertTriangle,
  BookOpen,
  ChevronDown,
  Download,
  GraduationCap,
  Layers,
  RefreshCw,
  Target,
  Users,
} from 'lucide-react'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { useFetch } from '../lib/useFetch'
import {
  LOW_ATTENDANCE,
  RANGE_PRESETS,
  applyRangeAttendance,
  buildAttendanceWindow,
  buildReportCsv,
  buildSchoolReport,
  dayStamp,
  downloadCsv,
  exportFileName,
  formatDay,
  rankClasses,
  resolveRange,
  timelineSummary,
} from '../lib/reports'
import ExportModal, { ClassPicker } from '../components/ExportModal'
import {
  Badge,
  Card,
  EmptyState,
  Modal,
  PageHeader,
  PrimaryButton,
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

const rateTone = (pct) =>
  pct >= 85 ? 'green' : pct >= LOW_ATTENDANCE ? 'blue' : pct >= 50 ? 'amber' : 'red'

const rateBar = (pct) =>
  pct >= 85 ? 'bg-success' : pct >= LOW_ATTENDANCE ? 'bg-info' : pct >= 50 ? 'bg-warning-bright' : 'bg-danger'

/** Daily attendance chart for the selected period. */
function Timeline({ attendanceWindow, loading, error, onRetry }) {
  const rows = attendanceWindow?.days || []
  const totals = attendanceWindow?.totals

  return (
    <SectionCard
      title="Daily attendance"
      hint={
        attendanceWindow
          ? `${formatDay(attendanceWindow.from)} – ${formatDay(attendanceWindow.to)} · rate for each recorded day`
          : 'Rate for each recorded day'
      }
      action={
        <Badge tone={rows.length ? rateTone(totals?.percentage || 0) : 'neutral'}>
          {rows.length ? `${rows.length} days` : 'No data'}
        </Badge>
      }
      className="mt-6"
    >
      {loading && <p className="py-8 text-center text-sm text-ink-soft">Loading the register…</p>}

      {!loading && error && (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-btn border border-warning/30 bg-warning-soft px-4 py-3 text-sm text-warning">
          <span className="flex items-start gap-2">
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
            <span>Timeline unavailable: {error}</span>
          </span>
          <SecondaryButton onClick={onRetry} className="!px-3 !py-1.5">
            <RefreshCw className="h-3.5 w-3.5" /> Retry
          </SecondaryButton>
        </div>
      )}

      {!loading && !error && rows.length === 0 && (
        <p className="py-8 text-center text-sm text-ink-soft">
          No attendance was recorded in this period. Teachers mark attendance from the mobile app.
        </p>
      )}

      {!loading && !error && rows.length > 0 && (
        <>
          <div className="flex h-36 items-end gap-[2px] sm:h-44">
            {rows.map((day) => (
              <div
                key={day.date}
                className="group relative flex h-full flex-1 items-end"
                title={`${formatDay(day.date)} · ${day.percentage}% · ${day.present}/${day.total} present`}
              >
                <div
                  className={`w-full rounded-t-[3px] transition-all group-hover:opacity-80 ${rateBar(day.percentage)}`}
                  style={{ height: `${Math.max(2, day.percentage)}%` }}
                />
              </div>
            ))}
          </div>
          <div className="mt-2 flex justify-between text-[11px] font-medium text-ink-soft">
            <span>{formatDay(rows[0].date)}</span>
            <span>{formatDay(rows[rows.length - 1].date)}</span>
          </div>

          <div className="mt-4 grid grid-cols-3 gap-2 text-center">
            <div className="rounded-btn bg-success-soft py-2.5">
              <p className="text-lg font-extrabold text-success">{totals.present}</p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Present</p>
            </div>
            <div className="rounded-btn bg-danger-soft py-2.5">
              <p className="text-lg font-extrabold text-danger">{totals.absent}</p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Absent</p>
            </div>
            <div className="rounded-btn bg-primary-soft py-2.5">
              <p className="text-lg font-extrabold text-primary">{totals.percentage}%</p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Rate</p>
            </div>
          </div>
          <p className="mt-3 text-xs text-ink-soft">{timelineSummary(attendanceWindow)}</p>
        </>
      )}
    </SectionCard>
  )
}

export default function ReportsPage() {
  const { user } = useAuth()
  const scope = user.school
  const { data, loading, error, reload } = useFetch(
    () => Promise.all([api.getTeachers(scope), api.getClasses(scope), api.getStudents(scope)]),
    [scope],
  )

  const [scopeIds, setScopeIds] = useState([])
  const [scopeOpen, setScopeOpen] = useState(false)
  const [preset, setPreset] = useState('all')
  const today = dayStamp()
  const [customFrom, setCustomFrom] = useState(today)
  const [customTo, setCustomTo] = useState(today)
  const [detail, setDetail] = useState(null)
  const [exportOpen, setExportOpen] = useState(false)
  const [exporting, setExporting] = useState(false)
  const [exportError, setExportError] = useState('')
  const [notice, setNotice] = useState('')

  const [teachers, classes, students] = data || [[], [], []]

  const range = useMemo(() => resolveRange(preset, { from: customFrom, to: customTo }), [preset, customFrom, customTo])
  const scopeKey = scopeIds.join(',')

  const {
    data: history,
    loading: historyLoading,
    error: historyError,
    reload: reloadHistory,
  } = useFetch(
    () => (range.from ? api.getAttendance(scope, { classes: scopeIds, from: range.from, to: range.to }) : Promise.resolve(null)),
    [scope, range.from, range.to, scopeKey],
  )

  const attendanceWindow = useMemo(
    () => (range.from ? buildAttendanceWindow(history, range) : null),
    [history, range],
  )

  const selectedClasses = useMemo(
    () => (scopeIds.length ? classes.filter((c) => scopeIds.includes(c.id)) : classes),
    [scopeIds, classes],
  )
  const classIds = useMemo(() => new Set(selectedClasses.map((c) => c.id)), [selectedClasses])
  const selectedStudents = useMemo(
    () => students.filter((s) => classIds.has(s.class_id)),
    [students, classIds],
  )
  const selectedTeachers = useMemo(
    () =>
      scopeIds.length
        ? teachers.filter((t) => (t.class_ids || []).some((id) => classIds.has(id)))
        : teachers,
    [scopeIds, teachers, classIds],
  )

  const report = useMemo(
    () =>
      buildSchoolReport({
        teachers: selectedTeachers,
        classes: selectedClasses,
        students: attendanceWindow ? applyRangeAttendance(selectedStudents, attendanceWindow) : selectedStudents,
        range: range.from ? range : null,
        timeline: attendanceWindow?.days || null,
      }),
    [selectedTeachers, selectedClasses, selectedStudents, attendanceWindow, range],
  )

  const ranked = useMemo(() => rankClasses(report.byClass), [report])

  const scopeLabel =
    scopeIds.length === 0
      ? 'Full school'
      : scopeIds.length === 1
        ? classes.find((c) => c.id === scopeIds[0])?.name || '1 class'
        : `${scopeIds.length} classes`

  function flash(message) {
    setNotice(message)
    window.setTimeout(() => setNotice(''), 2600)
  }

  async function handleExport({ scopeIds: exportIds, range: exportRange, format }) {
    setExporting(true)
    setExportError('')
    try {
      const exportClasses = exportIds.length ? classes.filter((c) => exportIds.includes(c.id)) : classes
      const exportClassIds = new Set(exportClasses.map((c) => c.id))
      let attendance = null

      if (exportRange.from) {
        const reuse =
          attendanceWindow &&
          exportRange.from === range.from &&
          exportRange.to === range.to &&
          exportIds.join(',') === scopeIds.join(',')
        const historyData = reuse
          ? history
          : await api.getAttendance(scope, { classes: exportIds, from: exportRange.from, to: exportRange.to })
        attendance = buildAttendanceWindow(historyData, exportRange)
      }

      const exportStudents = students.filter((s) => exportClassIds.has(s.class_id))
      const exportTeachers = exportIds.length
        ? teachers.filter((t) => (t.class_ids || []).some((id) => exportClassIds.has(id)))
        : teachers

      const exportReport = buildSchoolReport({
        teachers: exportTeachers,
        classes: exportClasses,
        students: attendance ? applyRangeAttendance(exportStudents, attendance) : exportStudents,
        range: attendance ? exportRange : null,
        timeline: attendance?.days || null,
      })

      const exportScopeLabel = attendance
        ? exportIds.length === 0
          ? 'Full school'
          : exportIds.length === 1
            ? exportClasses[0]?.name || '1 class'
            : `${exportIds.length} selected classes`
        : scopeLabel

      const rosters =
        exportIds.length > 0 && exportClasses.length <= 3
          ? exportReport.byClass.map((c) => ({
              name: c.name,
              program: c.program,
              room: c.room,
              teachers: c.teachers,
              students: c.students,
            }))
          : []

      const fileName = exportFileName({
        schoolName: user.school_name,
        scopeLabel: exportScopeLabel,
        from: exportRange.from,
        to: exportRange.to,
        extension: format,
      })

      const meta = {
        schoolName: user.school_name,
        scopeLabel: exportScopeLabel,
        periodLabel: exportRange.period,
        preparedBy: user.full_name || user.name || '',
        rosters,
      }

      if (format === 'pdf') {
        // Loaded on demand: the PDF engine is heavy and only needed here.
        const { downloadSchoolReportPdf } = await import('../lib/report-pdf')
        downloadSchoolReportPdf(fileName, exportReport, meta)
      } else {
        downloadCsv(fileName, buildReportCsv(exportReport, meta))
      }

      setExportOpen(false)
      flash(`${format === 'pdf' ? 'PDF' : 'CSV'} exported — ${fileName}`)
    } catch (e) {
      setExportError(e?.message || 'Export failed')
    } finally {
      setExporting(false)
    }
  }

  const exportButton = (
    <div className="flex items-center gap-2">
      <SecondaryButton onClick={reload} className="!px-3" title="Refresh report">
        <RefreshCw className="h-4 w-4" />
        <span className="hidden sm:inline">Refresh</span>
      </SecondaryButton>
      <PrimaryButton onClick={() => setExportOpen(true)} disabled={loading || Boolean(error)}>
        <Download className="h-4 w-4" />
        Export
      </PrimaryButton>
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
  const rangeEmpty = Boolean(range.from) && !historyLoading && !historyError && (attendanceWindow?.totals.total || 0) === 0

  const attendanceHint = (student) => {
    if (student.range_total !== undefined && student.range_total > 0) {
      return `${student.range_present}/${student.range_total} sessions`
    }
    return undefined
  }

  return (
    <>
      <PageHeader
        title="Executive reports"
        subtitle={`${user.school_name} · generated ${report.generatedAt.toLocaleString()}`}
        actions={exportButton}
      />

      <div className="mb-5 flex flex-wrap items-end gap-3">
        <div>
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-ink-soft">Scope</span>
          <button
            type="button"
            onClick={() => setScopeOpen(true)}
            className={`${inputClass} flex min-w-56 items-center justify-between gap-2 text-left`}
          >
            <span className="flex min-w-0 items-center gap-2">
              <Layers className="h-4 w-4 shrink-0 text-ink-soft" />
              <span className="truncate">{scopeLabel}</span>
            </span>
            <ChevronDown className="h-4 w-4 shrink-0 text-ink-soft" />
          </button>
        </div>

        <label className="block">
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-ink-soft">Period</span>
          <select
            value={preset}
            onChange={(e) => setPreset(e.target.value)}
            className={`${inputClass} min-w-52`}
          >
            {RANGE_PRESETS.map((p) => (
              <option key={p.key} value={p.key}>
                {p.label}
              </option>
            ))}
          </select>
        </label>

        {preset === 'custom' && (
          <>
            <label className="block">
              <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-ink-soft">From</span>
              <input
                type="date"
                value={customFrom}
                onChange={(e) => setCustomFrom(e.target.value)}
                className={`${inputClass} w-40`}
              />
            </label>
            <label className="block">
              <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-ink-soft">To</span>
              <input
                type="date"
                value={customTo}
                onChange={(e) => setCustomTo(e.target.value)}
                className={`${inputClass} w-40`}
              />
            </label>
          </>
        )}

        <p className="pb-3 text-xs text-ink-soft">
          Showing <span className="font-semibold text-ink">{scopeLabel}</span> ·{' '}
          <span className="font-semibold text-ink">{range.period}</span>
          {preset !== 'all' && range.label !== range.period && (
            <span className="ml-2 text-ink-soft">({range.label})</span>
          )}
          <br />
          {t.students} students · {t.teachers} teachers · {t.classes} classes
        </p>
      </div>

      {range.error && (
        <div className="mb-4 flex items-start gap-3 rounded-btn border border-danger/30 bg-danger-soft px-4 py-3 text-sm text-danger">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>{range.error} The report keeps the last valid period.</p>
        </div>
      )}

      {notice && (
        <div className="mb-4 rounded-btn border border-success/30 bg-success-soft px-4 py-2.5 text-sm font-semibold text-success">
          {notice}
        </div>
      )}

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
          hint={
            range.from
              ? `${t.recordedCount}/${t.students} students · ${t.sessions || 0} days`
              : `${t.recordedCount}/${t.students} students recorded`
          }
        />
      </div>

      {noAttendance && (
        <div className="mt-4 flex items-start gap-3 rounded-btn border border-warning/30 bg-warning-soft px-4 py-3 text-sm text-warning">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>
            {range.from
              ? `No attendance was recorded between ${formatDay(range.from)} and ${formatDay(range.to)} for this selection, so attendance shows as “—”.`
              : 'Attendance has not been recorded for any student yet, so attendance figures are shown as “—”.'}{' '}
            Teachers mark attendance from the mobile app; it will appear here automatically.
          </p>
        </div>
      )}

      {rangeEmpty && !noAttendance && (
        <div className="mt-4 flex items-start gap-3 rounded-btn border border-warning/30 bg-warning-soft px-4 py-3 text-sm text-warning">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>
            The register has no entries between {formatDay(range.from)} and {formatDay(range.to)}. Pick a wider
            period or “All time” to see cumulative attendance.
          </p>
        </div>
      )}

      {range.from && (
        <Timeline
          attendanceWindow={attendanceWindow}
          loading={historyLoading}
          error={historyError}
          onRetry={reloadHistory}
        />
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
        hint="Ranked by recorded attendance."
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

      {scopeOpen && (
        <Modal
          title="Report scope"
          subtitle="Report on the whole school or pick classes — the export dialog can use a different scope."
          onClose={() => setScopeOpen(false)}
        >
          <ClassPicker classes={classes} selected={scopeIds} onChange={setScopeIds} />
          <div className="mt-4 flex items-center justify-between">
            <button
              type="button"
              onClick={() => setScopeIds([])}
              className="text-xs font-semibold text-ink-soft underline-offset-2 hover:text-primary hover:underline"
            >
              Reset to full school
            </button>
            <PrimaryButton onClick={() => setScopeOpen(false)}>Apply</PrimaryButton>
          </div>
        </Modal>
      )}

      {exportOpen && (
        <ExportModal
          schoolName={user.school_name}
          classes={classes}
          students={students}
          defaultScopeIds={scopeIds}
          defaultPreset={preset}
          defaultFrom={customFrom}
          defaultTo={customTo}
          busy={exporting}
          onClose={() => {
            if (!exporting) {
              setExportOpen(false)
              setExportError('')
            }
          }}
          onExport={handleExport}
        />
      )}

      {exportOpen && exportError && (
        <div className="fixed bottom-5 left-1/2 z-[60] flex max-w-lg -translate-x-1/2 items-start gap-2 rounded-btn border border-danger/30 bg-danger-soft px-4 py-3 text-sm text-danger shadow-pop">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <span>Export failed: {exportError}</span>
        </div>
      )}

      {detail?.kind === 'bucket' && (
        <DrillModal
          title={`Attendance ${detail.bucket.label}`}
          subtitle={`${detail.bucket.count} of ${t.students} students in ${scopeLabel.toLowerCase()}`}
          onClose={() => setDetail(null)}
        >
          <RowList
            items={detail.bucket.students.map((s) => ({
              title: s.name,
              subtitle: [s.class_name, s.roll_number ? `Roll ${s.roll_number}` : '', attendanceHint(s)]
                .filter(Boolean)
                .join(' · ') || 'No class',
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
              subtitle: [`Roll ${s.roll_number || '—'}${s.status === 'Inactive' ? ' · Inactive' : ''}`, attendanceHint(s)]
                .filter(Boolean)
                .join(' · '),
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
