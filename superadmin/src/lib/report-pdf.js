/**
 * Super Admin network report → PDF.
 *
 * Network figures are a point-in-time snapshot of the registry, so the PDF has
 * no date window: it covers the schools the user selected (one, several, or the
 * whole network) and their enrolment, staffing and setup completeness.
 */

import { buildReportPdf, downloadReportPdf, thousands } from '../../../shared/report-pdf.js'

const pct = (value) => `${value}%`

/**
 * @param {ReturnType<typeof import('./reports.js').buildNetworkReport>} report
 * @param {{ scopeLabel?: string, preparedBy?: string }} meta
 */
export function buildNetworkPdfSpec(report, meta = {}) {
  const t = report.totals
  const generatedAt = report.generatedAt instanceof Date ? report.generatedAt : new Date()
  const scopeLabel = meta.scopeLabel || 'All schools'

  const kpis = [
    {
      label: 'Schools',
      value: thousands(t.schools),
      hint: `${t.activeSchools} active · ${t.disabledSchools} disabled`,
      tone: 'indigo',
    },
    {
      label: 'School admins',
      value: thousands(t.admins),
      hint: `${t.adminCoverage}% of schools covered`,
      tone: 'blue',
    },
    {
      label: 'Teachers',
      value: thousands(t.teachers),
      hint: `${t.studentsPerTeacher} students each`,
      tone: 'green',
    },
    {
      label: 'Students',
      value: thousands(t.students),
      hint: `${t.studentsPerSchool}/school · ${t.studentsPerClass}/class`,
      tone: 'amber',
    },
  ]

  const glance = [
    ['Schools in scope', thousands(t.schools)],
    ['Active schools', thousands(t.activeSchools)],
    ['Disabled schools', thousands(t.disabledSchools)],
    ['School admins', thousands(t.admins)],
    ['Teachers', thousands(t.teachers)],
    ['Classes', thousands(t.classes)],
    ['Students', thousands(t.students)],
    ['Students per school', t.studentsPerSchool],
    ['Students per class', t.studentsPerClass],
    ['Students per teacher', t.studentsPerTeacher],
    ['Schools with an admin (%)', pct(t.adminCoverage)],
    ['Average setup completeness (%)', pct(t.avgCompleteness)],
  ]

  const statusRows = report.statusSlices.map((s) => [
    s.label,
    s.count,
    pct(Math.round((s.count / Math.max(1, t.schools)) * 100)),
  ])

  const rankingRows = report.ranking.map((s) => [
    s.name,
    s.location || '—',
    s.status,
    s.studentCount,
    pct(s.share),
    s.teacherCount,
    s.classCount,
    s.studentsPerClass,
    s.adminCount,
  ])

  const completenessRows = report.completeness.map((s) => [
    s.name,
    `${s.checksDone}/${s.checksTotal}`,
    pct(s.completeness),
    s.checks.filter((c) => !c.done).map((c) => c.label).join('; ') || 'Complete',
  ])

  const sections = [
    {
      type: 'table',
      title: 'At a glance',
      hint: `Network figures for ${scopeLabel}`,
      head: ['Metric', 'Value'],
      rows: glance,
      align: ['left', 'right'],
    },
    {
      type: 'table',
      title: 'School status',
      hint: 'Schools by account status',
      head: ['Status', 'Schools', 'Share'],
      rows: statusRows,
      align: ['left', 'right', 'right'],
      emptyLabel: 'No schools in this selection.',
    },
    {
      type: 'table',
      title: 'Enrolment by school',
      hint: 'Ranked by student count',
      head: ['School', 'Location', 'Status', 'Students', 'Share', 'Teachers', 'Classes', 'Students/class', 'Admins'],
      rows: rankingRows,
      align: ['left', 'left', 'left', 'right', 'right', 'right', 'right', 'right', 'right'],
      emptyLabel: 'No schools in this selection.',
    },
    {
      type: 'table',
      title: 'Setup completeness',
      hint: 'Least complete first — what each school still needs',
      head: ['School', 'Checks done', 'Completeness', 'Outstanding'],
      rows: completenessRows,
      align: ['left', 'right', 'right', 'left'],
      emptyLabel: 'No schools in this selection.',
    },
  ]

  if (report.needsAttention.length) {
    sections.push({
      type: 'table',
      title: 'Needs attention',
      hint: 'Network-wide gaps the super admin should act on',
      head: ['Area', 'Schools', 'What it means'],
      rows: report.needsAttention.map((g) => [g.label, g.count, g.detail]),
      align: ['left', 'right', 'left'],
    })
  }

  const notes = [
    'Network reports are a point-in-time snapshot of the school registry: enrolment, staffing and setup completeness as they stand when the report is generated.',
    `${t.activeSchools} of ${t.schools} ${t.schools === 1 ? 'school is' : 'schools are'} active; disabled schools are included in totals but excluded from the active count.`,
    `Average setup completeness is ${pct(t.avgCompleteness)} across the five checks (admin, teachers, classes, students, location).`,
    `Prepared${meta.preparedBy ? ` by ${meta.preparedBy}` : ''} on ${generatedAt.toLocaleString('en-GB', {
      dateStyle: 'medium',
      timeStyle: 'short',
    })}.`,
  ]

  sections.push({ type: 'notes', title: 'Notes', items: notes })

  return {
    eyebrow: 'Network report',
    title: meta.orgName || 'School Connect network',
    subtitle: 'Enrolment, staffing and setup across the network',
    meta: [
      { label: 'Scope', value: scopeLabel },
      { label: 'Schools', value: thousands(t.schools) },
      { label: 'Students', value: thousands(t.students) },
    ],
    kpis,
    sections,
    generatedAt,
    preparedBy: meta.preparedBy || '',
    footerLeft: 'School Connect · Network report',
    period: 'Snapshot',
  }
}

/** Build the document (tests + previews). */
export function buildNetworkReportPdf(report, meta = {}) {
  return buildReportPdf(buildNetworkPdfSpec(report, meta))
}

/** Build and download the PDF in the browser. */
export function downloadNetworkReportPdf(fileName, report, meta = {}) {
  return downloadReportPdf(fileName, buildNetworkPdfSpec(report, meta))
}
