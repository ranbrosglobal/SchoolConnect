import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  AlertTriangle,
  Building2,
  ChevronDown,
  ChevronRight,
  Download,
  GraduationCap,
  Layers,
  RefreshCw,
  ShieldCheck,
  Users,
} from 'lucide-react'
import { api } from '../lib/api'
import { useFetch } from '../lib/useFetch'
import {
  buildNetworkReport,
  buildNetworkReportCsv,
  downloadCsv,
  exportFileName,
} from '../lib/reports'
import ExportModal, { SchoolPicker } from '../components/ExportModal'
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

// Token colors, used inside SVG / conic-gradient where utility classes can't reach.
const TONE_HEX = {
  green: '#007a53',
  blue: '#0284c7',
  amber: '#fdaf1e',
  red: '#ba1a1a',
  neutral: '#757685',
  primary: '#3145bb',
  indigo: '#3145bb',
}

const plural = (count, one, many) => `${count} ${count === 1 ? one : many}`

function Donut({ slices, total, centerLabel, onSelect }) {
  let cursor = 0
  const stops = slices.map((s) => {
    const from = (cursor / Math.max(1, total)) * 360
    cursor += s.count
    const to = (cursor / Math.max(1, total)) * 360
    return `${TONE_HEX[s.tone] || TONE_HEX.primary} ${from}deg ${to}deg`
  })
  return (
    <div className="flex flex-wrap items-center gap-6">
      <div
        className="relative h-36 w-36 shrink-0 rounded-full"
        style={{ background: `conic-gradient(${stops.join(', ') || `${TONE_HEX.neutral} 0deg 360deg`})` }}
        role="img"
        aria-label={slices.map((s) => `${s.label}: ${s.count}`).join(', ')}
      >
        <div className="absolute inset-[22%] flex flex-col items-center justify-center rounded-full bg-surface">
          <span className="text-2xl font-extrabold leading-none text-ink">{total}</span>
          <span className="mt-1 text-[10px] font-semibold uppercase tracking-wide text-ink-soft">
            {centerLabel}
          </span>
        </div>
      </div>
      <div className="min-w-0 flex-1 space-y-2">
        {slices.map((s) => (
          <button
            key={s.key}
            onClick={() => onSelect?.(s)}
            className="flex w-full items-center justify-between gap-3 rounded-btn px-2 py-1.5 text-left transition hover:bg-surface-low"
          >
            <span className="flex min-w-0 items-center gap-2">
              <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: TONE_HEX[s.tone] }} />
              <span className="truncate text-sm font-semibold text-ink">{s.label}</span>
            </span>
            <span className="shrink-0 text-sm font-bold text-ink">
              {s.count}
              <span className="ml-1 text-xs font-medium text-ink-soft">
                {Math.round((s.count / Math.max(1, total)) * 100)}%
              </span>
            </span>
          </button>
        ))}
      </div>
    </div>
  )
}

function Bars({ rows, emptyLabel = 'No data yet' }) {
  const max = Math.max(1, ...rows.map((r) => r.value))
  if (rows.length === 0) {
    return <p className="py-8 text-center text-sm text-ink-soft">{emptyLabel}</p>
  }
  return (
    <div className="space-y-3.5">
      {rows.map((row) => (
        <button
          key={row.key}
          type="button"
          onClick={row.onSelect}
          disabled={!row.onSelect}
          className={`block w-full rounded-btn px-1.5 py-1 text-left transition ${
            row.onSelect ? 'hover:bg-surface-low' : 'cursor-default'
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
      ))}
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
      {items.map((item, i) => (
        <li key={`${item.title}-${i}`}>
          {item.onSelect ? (
            <button
              type="button"
              onClick={item.onSelect}
              className="flex w-full items-center gap-3 px-1 py-2.5 text-left transition hover:bg-surface-low"
            >
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-ink">{item.title}</p>
                {item.subtitle && <p className="truncate text-xs text-ink-soft">{item.subtitle}</p>}
              </div>
              {item.value !== undefined && (
                <span className="shrink-0 text-sm font-semibold text-ink-soft">{item.value}</span>
              )}
            </button>
          ) : (
            <div className="flex items-center gap-3 px-1 py-2.5">
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-ink">{item.title}</p>
                {item.subtitle && <p className="truncate text-xs text-ink-soft">{item.subtitle}</p>}
              </div>
              {item.value !== undefined && (
                <span className="shrink-0 text-sm font-semibold text-ink-soft">{item.value}</span>
              )}
            </div>
          )}
        </li>
      ))}
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
  const { data, loading, error, reload } = useFetch(
    () => Promise.all([api.getOverview(), api.getSchools()]),
    [],
  )
  const [detail, setDetail] = useState(null)
  const [scopeIds, setScopeIds] = useState([])
  const [scopeOpen, setScopeOpen] = useState(false)
  const [exportOpen, setExportOpen] = useState(false)
  const [exporting, setExporting] = useState(false)
  const [exportError, setExportError] = useState('')
  const [notice, setNotice] = useState('')

  const [overview, schools] = data || [{}, []]

  const scopedSchools = useMemo(
    () => (scopeIds.length ? schools.filter((s) => scopeIds.includes(s.id)) : schools),
    [scopeIds, schools],
  )
  const report = useMemo(
    () =>
      buildNetworkReport({
        overview,
        schools: scopedSchools,
        useOverviewTotals: scopeIds.length === 0,
      }),
    [overview, scopedSchools, scopeIds.length],
  )

  const scopeLabel =
    scopeIds.length === 0
      ? 'All schools'
      : scopeIds.length === 1
        ? schools.find((s) => s.id === scopeIds[0])?.name || '1 school'
        : `${scopeIds.length} selected schools`

  function flash(message) {
    setNotice(message)
    window.setTimeout(() => setNotice(''), 2600)
  }

  async function handleExport({ scopeIds: exportIds, format }) {
    setExporting(true)
    setExportError('')
    try {
      const exportSchools = exportIds.length ? schools.filter((s) => exportIds.includes(s.id)) : schools
      const exportReport = buildNetworkReport({
        overview,
        schools: exportSchools,
        useOverviewTotals: exportIds.length === 0,
      })
      const exportScopeLabel =
        exportIds.length === 0
          ? 'Full network'
          : exportIds.length === 1
            ? exportSchools[0]?.name || '1 school'
            : `${exportIds.length} selected schools`

      const meta = {
        scopeLabel: exportScopeLabel,
        preparedBy: 'Super Admin',
        orgName: 'School Connect network',
      }
      const fileName = exportFileName({ scopeLabel: exportScopeLabel, extension: format })

      if (format === 'pdf') {
        // Loaded on demand: the PDF engine is heavy and only needed here.
        const { downloadNetworkReportPdf } = await import('../lib/report-pdf')
        downloadNetworkReportPdf(fileName, exportReport, meta)
      } else {
        downloadCsv(fileName, buildNetworkReportCsv(exportReport, meta))
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

  if (loading) return <Spinner label="Building network report…" />
  if (error) {
    return (
      <>
        <PageHeader title="Network reports" subtitle="Enrolment, staffing and school setup across the network." />
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

  if (schools.length === 0) {
    return (
      <>
        <PageHeader
          title="Network reports"
          subtitle="Enrolment, staffing and school setup across the network."
          actions={exportButton}
        />
        <EmptyState
          title="No schools on the network yet"
          hint="Register your first school and this page fills with enrolment, staffing and setup analytics."
          action={
            <Link to="/schools" className="mt-3">
              <SecondaryButton>
                <Building2 className="h-4 w-4" />
                Add school
              </SecondaryButton>
            </Link>
          }
        />
      </>
    )
  }

  const t = report.totals
  const emptySchools = report.completeness.filter((s) => s.checksDone === 0).length

  return (
    <>
      <PageHeader
        title="Network reports"
        subtitle={`${scopeLabel} · generated ${report.generatedAt.toLocaleString()}`}
        actions={exportButton}
      />

      <div className="mb-5 flex flex-wrap items-end gap-3">
        <div>
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-ink-soft">Scope</span>
          <button
            type="button"
            onClick={() => setScopeOpen(true)}
            className={`${inputClass} flex min-w-64 items-center justify-between gap-2 text-left`}
          >
            <span className="flex min-w-0 items-center gap-2">
              <Layers className="h-4 w-4 shrink-0 text-ink-soft" />
              <span className="truncate">{scopeLabel}</span>
            </span>
            <ChevronDown className="h-4 w-4 shrink-0 text-ink-soft" />
          </button>
        </div>
        <p className="pb-3 text-xs text-ink-soft">
          Showing <span className="font-semibold text-ink">{plural(t.schools, 'school', 'schools')}</span> ·{' '}
          {t.students} students · {t.teachers} teachers
        </p>
      </div>

      {notice && (
        <div className="mb-4 rounded-btn border border-success/30 bg-success-soft px-4 py-2.5 text-sm font-semibold text-success">
          {notice}
        </div>
      )}

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard
          icon={Building2}
          label="Active schools"
          value={t.activeSchools}
          accent="indigo"
          hint={`${t.disabledSchools} disabled · ${t.schools} registered`}
        />
        <StatCard
          icon={ShieldCheck}
          label="School admins"
          value={t.admins}
          accent="blue"
          hint={`${t.adminCoverage}% of schools have an admin`}
        />
        <StatCard
          icon={GraduationCap}
          label="Teachers"
          value={t.teachers}
          accent="green"
          hint={`${t.studentsPerTeacher} students each`}
        />
        <StatCard
          icon={Users}
          label="Students"
          value={t.students}
          accent="amber"
          hint={`${t.studentsPerSchool} per school · ${t.studentsPerClass} per class`}
        />
      </div>

      {emptySchools > 0 && (
        <div className="mt-4 flex items-start gap-3 rounded-btn border border-warning/30 bg-warning-soft px-4 py-3 text-sm text-warning">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>
            {plural(emptySchools, 'school has', 'schools have')} nothing setup yet — no admin, teachers, classes or
            students. Open Setup completeness below for the checklist.
          </p>
        </div>
      )}

      <div className="mt-6 grid gap-6 lg:grid-cols-[1.2fr_1fr]">
        <SectionCard
          title="School status"
          hint="Click a status to list those schools."
          action={<Badge tone="neutral">{plural(t.schools, 'school', 'schools')}</Badge>}
        >
          <Donut
            slices={report.statusSlices}
            total={t.schools}
            centerLabel="schools"
            onSelect={(slice) =>
              setDetail({
                kind: 'status',
                slice,
                items: report.ranking.filter((s) =>
                  slice.key === 'active' ? s.status === 'Active' : s.status !== 'Active',
                ),
              })
            }
          />
        </SectionCard>

        <SectionCard title="Network totals" hint="Averages across every registered school.">
          <div className="grid grid-cols-2 gap-3 text-center">
            {[
              { label: 'Students / school', value: t.studentsPerSchool },
              { label: 'Students / class', value: t.studentsPerClass },
              { label: 'Classes', value: t.classes },
              { label: 'Avg setup', value: `${t.avgCompleteness}%` },
            ].map((stat) => (
              <div key={stat.label} className="rounded-btn bg-surface-low py-3">
                <p className="text-lg font-extrabold text-ink">{stat.value}</p>
                <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">{stat.label}</p>
              </div>
            ))}
          </div>
          <p className="mt-3 text-xs text-ink-soft">
            Setup completeness averages {plural(report.completeness.length, 'school', 'schools')} across admin,
            teacher, class, student and location checks.
          </p>
        </SectionCard>
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <SectionCard
          title="Enrolment by school"
          hint="Click a school for its full breakdown."
          action={<Badge tone="neutral">{t.students} students</Badge>}
        >
          <Bars
            rows={report.ranking.map((s) => ({
              key: s.id,
              label: s.name,
              value: s.studentCount,
              display: `${s.studentCount} · ${s.share}%`,
              tone: s.status === 'Active' ? (s.studentCount ? 'green' : 'amber') : 'neutral',
              hint: `${plural(s.teacherCount, 'teacher', 'teachers')} · ${plural(s.classCount, 'class', 'classes')} · ${s.studentsPerClass} students/class`,
              onSelect: () => setDetail({ kind: 'school', school: s }),
            }))}
            emptyLabel="No schools registered"
          />
        </SectionCard>

        <SectionCard
          title="Setup completeness"
          hint="Least complete schools first."
          action={<Badge tone={t.avgCompleteness === 100 ? 'green' : 'amber'}>{t.avgCompleteness}% average</Badge>}
        >
          <div className="space-y-3">
            {report.completeness.map((s) => (
              <button
                key={s.id}
                type="button"
                onClick={() => setDetail({ kind: 'school', school: s })}
                className="block w-full rounded-btn px-1.5 py-1 text-left transition hover:bg-surface-low"
              >
                <div className="flex items-baseline justify-between gap-3">
                  <span className="min-w-0 truncate text-sm font-semibold text-ink">{s.name}</span>
                  <span className="shrink-0 text-sm font-bold text-ink">{s.completeness}%</span>
                </div>
                <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-surface-low">
                  <div
                    className={`h-full rounded-full transition-all ${
                      s.completeness === 100 ? 'bg-success' : s.completeness >= 60 ? 'bg-warning-bright' : 'bg-danger'
                    }`}
                    style={{ width: `${s.completeness}%` }}
                  />
                </div>
                <p className="mt-1 truncate text-xs text-ink-soft">
                  {s.checksDone}/{s.checksTotal} checks ·{' '}
                  {s.checks.filter((c) => !c.done).map((c) => c.label).join(', ') || 'Nothing outstanding'}
                </p>
              </button>
            ))}
          </div>
        </SectionCard>
      </div>

      <SectionCard
        title="School scorecard"
        hint="Every registered school at a glance — click a row for detail."
        className="mt-6"
        action={<Badge tone="neutral">{plural(t.schools, 'school', 'schools')}</Badge>}
      >
        <div className="-mx-2 overflow-x-auto">
          <table className="w-full min-w-[860px] border-collapse text-sm">
            <thead>
              <tr className="text-left text-xs font-bold uppercase tracking-wide text-ink-soft">
                <th className="px-2 pb-2">School</th>
                <th className="px-2 pb-2">Location</th>
                <th className="px-2 pb-2">Status</th>
                <th className="px-2 pb-2 text-right">Admins</th>
                <th className="px-2 pb-2 text-right">Teachers</th>
                <th className="px-2 pb-2 text-right">Classes</th>
                <th className="px-2 pb-2 text-right">Students</th>
                <th className="px-2 pb-2 text-right">Students / class</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-outline-soft/60">
              {report.ranking.map((s) => (
                <tr
                  key={s.id}
                  onClick={() => setDetail({ kind: 'school', school: s })}
                  className="cursor-pointer transition hover:bg-surface-low"
                >
                  <td className="px-2 py-3">
                    <p className="font-semibold text-ink">{s.name}</p>
                    <p className="text-xs text-ink-soft">
                      {s.adminNames.length > 0 ? s.adminNames.join(', ') : 'No admin yet'}
                    </p>
                  </td>
                  <td className="px-2 py-3 text-ink-soft">{s.location || '—'}</td>
                  <td className="px-2 py-3">
                    <Badge tone={s.status === 'Active' ? 'green' : 'neutral'}>{s.status}</Badge>
                  </td>
                  <td className="px-2 py-3 text-right font-semibold text-ink">{s.adminCount}</td>
                  <td className="px-2 py-3 text-right text-ink-soft">{s.teacherCount}</td>
                  <td className="px-2 py-3 text-right text-ink-soft">{s.classCount}</td>
                  <td className="px-2 py-3 text-right font-semibold text-ink">{s.studentCount}</td>
                  <td className="px-2 py-3 text-right text-ink-soft">{s.studentsPerClass}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionCard>

      <SectionCard
        title="Needs attention"
        hint="Network-level gaps worth a follow-up."
        className="mt-6"
        action={
          <Badge tone={report.needsAttention.length ? 'amber' : 'green'}>
            {report.needsAttention.length ? `${report.needsAttention.length} areas` : 'All clear'}
          </Badge>
        }
      >
        {report.needsAttention.length === 0 ? (
          <div className="rounded-btn bg-success-soft px-4 py-3 text-sm text-success">
            Every school has an admin, staff, classes and students.
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
          subtitle="Report on the whole network or pick schools — the export dialog can use a different scope."
          onClose={() => setScopeOpen(false)}
        >
          <SchoolPicker schools={schools} selected={scopeIds} onChange={setScopeIds} />
          <div className="mt-4 flex items-center justify-between">
            <button
              type="button"
              onClick={() => setScopeIds([])}
              className="text-xs font-semibold text-ink-soft underline-offset-2 hover:text-primary hover:underline"
            >
              Reset to full network
            </button>
            <PrimaryButton onClick={() => setScopeOpen(false)}>Apply</PrimaryButton>
          </div>
        </Modal>
      )}

      {exportOpen && (
        <ExportModal
          orgName="School Connect network"
          schools={schools}
          defaultScopeIds={scopeIds}
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

      {detail?.kind === 'school' && (
        <DrillModal
          title={detail.school.name}
          subtitle={`${detail.school.location || 'No location'} · ${detail.school.status}${
            detail.school.established ? ` · est. ${detail.school.established}` : ''
          }`}
          onClose={() => setDetail(null)}
        >
          <div className="mb-4 grid grid-cols-2 gap-2 text-center sm:grid-cols-4">
            {[
              { label: 'Admins', value: detail.school.adminCount },
              { label: 'Teachers', value: detail.school.teacherCount },
              { label: 'Classes', value: detail.school.classCount },
              { label: 'Students', value: detail.school.studentCount },
            ].map((stat) => (
              <div key={stat.label} className="rounded-btn bg-surface-low py-2.5">
                <p className="text-lg font-extrabold text-ink">{stat.value}</p>
                <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">{stat.label}</p>
              </div>
            ))}
          </div>
          <div className="mb-4 grid grid-cols-3 gap-2 text-center">
            <div className="rounded-btn bg-surface-low py-2.5">
              <p className="text-base font-extrabold text-ink">{detail.school.studentsPerClass}</p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Students / class</p>
            </div>
            <div className="rounded-btn bg-surface-low py-2.5">
              <p className="text-base font-extrabold text-ink">{detail.school.studentsPerTeacher}</p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Students / teacher</p>
            </div>
            <div className="rounded-btn bg-surface-low py-2.5">
              <p className="text-base font-extrabold text-ink">{detail.school.completeness}%</p>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Setup complete</p>
            </div>
          </div>
          <h3 className="mb-2 text-xs font-bold uppercase tracking-wide text-ink-soft">Setup checklist</h3>
          <ul className="space-y-1.5">
            {detail.school.checks.map((check) => (
              <li key={check.key} className="flex items-center gap-2.5 text-sm">
                <span
                  className={`inline-flex h-5 w-5 items-center justify-center rounded-full text-xs font-bold ${
                    check.done ? 'bg-success-soft text-success' : 'bg-danger-soft text-danger'
                  }`}
                >
                  {check.done ? '✓' : '!'}
                </span>
                <span className={check.done ? 'text-ink-soft' : 'font-semibold text-ink'}>{check.label}</span>
              </li>
            ))}
          </ul>
          <h3 className="mb-2 mt-4 text-xs font-bold uppercase tracking-wide text-ink-soft">School admins</h3>
          {detail.school.adminNames.length === 0 ? (
            <p className="text-sm text-ink-soft">No school admin assigned yet.</p>
          ) : (
            <div className="flex flex-wrap gap-1.5">
              {detail.school.adminNames.map((name) => (
                <span
                  key={name}
                  className="inline-flex items-center gap-1 rounded-full bg-primary-soft px-2.5 py-0.5 text-xs font-semibold text-primary"
                >
                  <ShieldCheck className="h-3 w-3" />
                  {name}
                </span>
              ))}
            </div>
          )}
          <div className="mt-4 flex justify-end">
            <Link to="/schools">
              <SecondaryButton>
                Manage school
                <ChevronRight className="h-4 w-4" />
              </SecondaryButton>
            </Link>
          </div>
        </DrillModal>
      )}

      {detail?.kind === 'status' && (
        <DrillModal
          title={`${detail.slice.label} schools`}
          subtitle={`${plural(detail.slice.count, 'school', 'schools')} on the network`}
          onClose={() => setDetail(null)}
        >
          <RowList
            items={detail.items.map((s) => ({
              title: s.name,
              subtitle: `${s.location || 'No location'} · ${plural(s.adminCount, 'admin', 'admins')}`,
              value: `${plural(s.studentCount, 'student', 'students')}`,
              onSelect: () => setDetail({ kind: 'school', school: s }),
            }))}
          />
        </DrillModal>
      )}

      {detail?.kind === 'attention' && (
        <DrillModal
          title={detail.group.label}
          subtitle={`${detail.group.count} ${detail.group.count === 1 ? 'school' : 'schools'} · ${detail.group.detail}`}
          onClose={() => setDetail(null)}
        >
          <RowList
            items={detail.group.rows.map((row) => ({
              ...row,
              onSelect: () => {
                const school = report.completeness.find((s) => s.id === row.id)
                if (school) setDetail({ kind: 'school', school })
              },
            }))}
          />
        </DrillModal>
      )}
    </>
  )
}
