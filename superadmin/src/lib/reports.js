/**
 * Network report builder for the Super Admin console.
 *
 * Pure functions over the registry data the console already loads
 * (overview + schools), so reports work identically in live and mock mode.
 */

const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0)

function percent(part, whole) {
  if (!whole) return 0
  return Math.round((part / whole) * 100)
}

function ratio(part, whole) {
  if (!whole) return 0
  return Math.round((part / whole) * 10) / 10
}

function plural(count, one, many) {
  return `${count} ${count === 1 ? one : many}`
}

export const COMPLETENESS_CHECKS = [
  { key: 'admins', label: 'School admin assigned' },
  { key: 'teachers', label: 'Teachers added' },
  { key: 'classes', label: 'Classes created' },
  { key: 'students', label: 'Students enrolled' },
  { key: 'location', label: 'Location set' },
]

function checksFor(school) {
  return [
    { key: 'admins', label: 'School admin assigned', done: (school.admin_names || []).length > 0 },
    { key: 'teachers', label: 'Teachers added', done: num(school.teacher_count) > 0 },
    { key: 'classes', label: 'Classes created', done: num(school.class_count) > 0 },
    { key: 'students', label: 'Students enrolled', done: num(school.student_count) > 0 },
    { key: 'location', label: 'Location set', done: Boolean((school.location || '').trim()) },
  ]
}

/**
 * Build the whole network report.
 *
 * @param {{ overview?: object, schools?: object[], generatedAt?: Date }} input
 */
export function buildNetworkReport({ overview = {}, schools = [], generatedAt = new Date() } = {}) {
  const list = schools.map((s) => {
    const students = num(s.student_count)
    const teachers = num(s.teacher_count)
    const classes = num(s.class_count)
    const checks = checksFor(s)
    const done = checks.filter((c) => c.done).length
    return {
      id: s.id,
      name: s.name || 'Unnamed school',
      location: s.location || '',
      status: s.status || 'Active',
      established: s.established,
      adminNames: s.admin_names || [],
      adminCount: (s.admin_names || []).length,
      teacherCount: teachers,
      classCount: classes,
      studentCount: students,
      studentsPerClass: ratio(students, classes),
      studentsPerTeacher: ratio(students, teachers),
      checks,
      completeness: percent(done, checks.length),
      checksDone: done,
      checksTotal: checks.length,
      empty: students === 0 && teachers === 0 && classes === 0,
    }
  })

  const active = list.filter((s) => s.status === 'Active')
  const disabled = list.filter((s) => s.status !== 'Active')
  const totalStudents = list.reduce((a, s) => a + s.studentCount, 0)
  const totalTeachers = list.reduce((a, s) => a + s.teacherCount, 0)
  const totalClasses = list.reduce((a, s) => a + s.classCount, 0)
  const totalAdmins = list.reduce((a, s) => a + s.adminCount, 0)
  const withAdmins = list.filter((s) => s.adminCount > 0).length

  const statusSlices = [
    { key: 'active', label: 'Active', count: active.length, tone: 'green' },
    { key: 'disabled', label: 'Disabled', count: disabled.length, tone: 'neutral' },
  ].filter((s) => s.count > 0)

  const ranking = [...list]
    .sort((a, b) => b.studentCount - a.studentCount || a.name.localeCompare(b.name))
    .map((s) => ({ ...s, share: percent(s.studentCount, totalStudents) }))

  // Worst setup first — the point of the ranking is to show what needs work.
  const completeness = [...list].sort(
    (a, b) => a.completeness - b.completeness || b.studentCount - a.studentCount || a.name.localeCompare(b.name),
  )

  const avgCompleteness = list.length
    ? Math.round(list.reduce((a, s) => a + s.completeness, 0) / list.length)
    : 0

  const group = (key, label, detail, tone, predicate) => {
    const rows = list.filter(predicate)
    return {
      key,
      label,
      detail,
      tone,
      count: rows.length,
      rows: rows.map((s) => ({
        id: s.id,
        title: s.name,
        subtitle: [s.location || 'No location', s.status].filter(Boolean).join(' · '),
        value: `${plural(s.studentCount, 'student', 'students')} · ${plural(s.classCount, 'class', 'classes')}`,
      })),
    }
  }

  const needsAttention = [
    group('no-admin', 'Schools without an admin', 'Nobody can sign in to manage these schools.', 'red', (s) => s.adminCount === 0),
    group('no-teachers', 'Schools without teachers', 'Active schools that have no teaching staff.', 'amber', (s) => s.teacherCount === 0),
    group('no-classes', 'Schools without classes', 'No classes have been created yet.', 'amber', (s) => s.classCount === 0),
    group('no-students', 'Schools without students', 'No students enrolled yet.', 'blue', (s) => s.studentCount === 0),
    group('disabled', 'Disabled schools', 'Schools turned off by the super admin.', 'neutral', (s) => s.status !== 'Active'),
  ].filter((g) => g.count > 0)

  return {
    generatedAt,
    totals: {
      schools: list.length,
      activeSchools: active.length,
      disabledSchools: disabled.length,
      admins: overview.school_admin_count !== undefined ? num(overview.school_admin_count) : totalAdmins,
      teachers: totalTeachers,
      classes: totalClasses,
      students: totalStudents,
      studentsPerClass: ratio(totalStudents, totalClasses),
      studentsPerTeacher: ratio(totalStudents, totalTeachers),
      studentsPerSchool: ratio(totalStudents, list.length),
      adminCoverage: percent(withAdmins, list.length),
      avgCompleteness,
    },
    statusSlices,
    ranking,
    completeness,
    needsAttention,
  }
}

/* ---------- CSV ---------- */

export function csvEscape(value) {
  const text = value === null || value === undefined ? '' : String(value)
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text
}

/**
 * Multi-section CSV so one export covers the whole network report.
 * @param {ReturnType<typeof buildNetworkReport>} report
 */
export function buildNetworkReportCsv(report) {
  const rows = [
    ['School Connect — Network report'],
    ['Scope', 'All schools'],
    ['Generated', report.generatedAt.toISOString()],
    [],
    ['Summary'],
    ['Metric', 'Value'],
    ['Schools on the network', report.totals.schools],
    ['Active schools', report.totals.activeSchools],
    ['Disabled schools', report.totals.disabledSchools],
    ['School admins', report.totals.admins],
    ['Teachers', report.totals.teachers],
    ['Classes', report.totals.classes],
    ['Students', report.totals.students],
    ['Students per class', report.totals.studentsPerClass],
    ['Students per teacher', report.totals.studentsPerTeacher],
    ['Students per school', report.totals.studentsPerSchool],
    ['Schools with an admin (%)', report.totals.adminCoverage],
    ['Average setup completeness (%)', report.totals.avgCompleteness],
    [],
    ['School status'],
    ['Status', 'Schools'],
    ...report.statusSlices.map((s) => [s.label, s.count]),
    [],
    ['Enrolment ranking'],
    ['School', 'Location', 'Status', 'Students', 'Share (%)', 'Teachers', 'Classes', 'Students/class', 'Admins'],
    ...report.ranking.map((s) => [
      s.name,
      s.location,
      s.status,
      s.studentCount,
      s.share,
      s.teacherCount,
      s.classCount,
      s.studentsPerClass,
      s.adminCount,
    ]),
    [],
    ['Setup completeness'],
    ['School', 'Checks done', 'Checks total', 'Completeness (%)', 'Outstanding'],
    ...report.completeness.map((s) => [
      s.name,
      s.checksDone,
      s.checksTotal,
      s.completeness,
      s.checks.filter((c) => !c.done).map((c) => c.label).join('; '),
    ]),
    [],
    ['Needs attention'],
    ['Area', 'Schools'],
    ...report.needsAttention.map((g) => [g.label, g.count]),
  ]
  return rows.map((row) => row.map(csvEscape).join(',')).join('\n')
}

/** Trigger a browser download for a CSV string. */
export function downloadCsv(filename, csv) {
  const blob = new Blob(['\ufeff', csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
}

/** Filesystem-safe file name for exports. */
export function reportFileName(prefix = 'network', date = new Date()) {
  const stamp = date.toISOString().slice(0, 10)
  const slug = String(prefix)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
  return `${slug || 'network'}-report-${stamp}.csv`
}
