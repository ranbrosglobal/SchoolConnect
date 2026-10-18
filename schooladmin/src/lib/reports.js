/**
 * Executive report builder for the School Admin console.
 *
 * Everything here is a pure function over the data the console already loads
 * (teachers, classes, students), so the reports need no extra backend
 * endpoints and stay identical between live and mock mode.
 */

export const ATTENDANCE_BUCKETS = [
  { key: 'excellent', label: '90–100%', min: 90, max: 101, tone: 'green' },
  { key: 'good', label: '75–89%', min: 75, max: 90, tone: 'blue' },
  { key: 'watch', label: '50–74%', min: 50, max: 75, tone: 'amber' },
  { key: 'critical', label: 'Below 50%', min: 0, max: 50, tone: 'red', exclusiveMin: true },
  { key: 'unrecorded', label: 'Not recorded', min: null, max: null, tone: 'neutral' },
]

/** Low attendance threshold used across the report (percent). */
export const LOW_ATTENDANCE = 75

const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0)

/* ---------- reporting periods ---------- */

/**
 * Attendance can be reported cumulatively (the per-student percentage) or over
 * a date window built from the daily register. These presets cover both.
 */
export const RANGE_PRESETS = [
  { key: 'all', label: 'All time' },
  { key: '7d', label: 'Last 7 days', days: 7 },
  { key: '15d', label: 'Last 15 days', days: 15 },
  { key: '30d', label: 'Last 30 days', days: 30 },
  { key: 'mtd', label: 'Month to date' },
  { key: 'term', label: 'Term to date (90 days)', days: 90 },
  { key: 'custom', label: 'Custom dates' },
]

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const DAY_MS = 86400000
const ISO_DAY = /^\d{4}-\d{2}-\d{2}$/
const MAX_RANGE_DAYS = 366

/** Local calendar day as YYYY-MM-DD (never shifts across a timezone). */
export function dayStamp(date = new Date()) {
  const d = date instanceof Date ? date : new Date(date)
  if (Number.isNaN(d.getTime())) return ''
  return `${d.getFullYear()}-${`${d.getMonth() + 1}`.padStart(2, '0')}-${`${d.getDate()}`.padStart(2, '0')}`
}

function shiftDays(date, delta) {
  const d = new Date(date.getTime())
  d.setDate(d.getDate() + delta)
  return d
}

/** "2026-10-03" -> "3 Oct 2026" */
export function formatDay(stamp) {
  const [y, m, d] = String(stamp || '').slice(0, 10).split('-').map(Number)
  if (!y || !m || !d || m < 1 || m > 12) return String(stamp || '')
  return `${d} ${MONTHS[m - 1]} ${y}`
}

/** Inclusive day count, or 0 when the stamps are unusable. */
export function daysBetween(from, to) {
  if (!ISO_DAY.test(from || '') || !ISO_DAY.test(to || '')) return 0
  const a = new Date(`${from}T00:00:00`)
  const b = new Date(`${to}T00:00:00`)
  if (Number.isNaN(a.getTime()) || Number.isNaN(b.getTime())) return 0
  return Math.round((b - a) / DAY_MS) + 1
}

export function rangeLabel(from, to) {
  if (!from && !to) return 'All time'
  if (from && to && from === to) return formatDay(from)
  return `${formatDay(from)} – ${formatDay(to)}`
}

/**
 * Resolve a preset (plus custom dates) into a concrete reporting window.
 * `from`/`to` are null for the cumulative "All time" view.
 */
export function resolveRange(preset = 'all', { today = new Date(), from = '', to = '' } = {}) {
  const key = RANGE_PRESETS.some((p) => p.key === preset) ? preset : 'all'
  if (key === 'all') {
    return { key, label: 'All time', period: 'All time', from: null, to: null, isRange: false, days: null }
  }

  const end = dayStamp(today)

  if (key === 'custom') {
    const start = ISO_DAY.test(from) ? from : ''
    const finish = ISO_DAY.test(to) ? to : ''
    const base = { key, label: 'Custom dates', period: rangeLabel(start, finish), from: start || null, to: finish || null }
    if (!start || !finish) {
      return { ...base, isRange: false, days: null, error: 'Choose a start and end date.' }
    }
    if (start > finish) {
      return { ...base, isRange: false, days: null, error: 'The start date must be on or before the end date.' }
    }
    if (daysBetween(start, finish) > MAX_RANGE_DAYS) {
      return { ...base, isRange: false, days: null, error: `Choose a range of ${MAX_RANGE_DAYS} days or less.` }
    }
    return { ...base, label: rangeLabel(start, finish), isRange: true, days: daysBetween(start, finish) }
  }

  const presetDef = RANGE_PRESETS.find((p) => p.key === key)
  const start =
    key === 'mtd'
      ? dayStamp(new Date(today.getFullYear(), today.getMonth(), 1))
      : dayStamp(shiftDays(today, -(presetDef.days - 1)))

  return {
    key,
    label: presetDef.label,
    period: rangeLabel(start, end),
    from: start,
    to: end,
    isRange: true,
    days: daysBetween(start, end),
  }
}

/** A recorded session always has a row, even when the student was absent. */
const hasRange = (student) => student && student.range_total !== undefined

function isRecorded(student) {
  if (!student) return false
  return hasRange(student) ? num(student.range_total) > 0 : num(student.attendance_pct) > 0
}

/**
 * Normalise the `get_admin_attendance` payload into something the report and
 * the PDF can both consume: ascending days, per-class series, per-student
 * totals and an overall summary.
 */
export function buildAttendanceWindow(history, range = {}) {
  if (!history) return null
  const from = range.from || history.from || null
  const to = range.to || history.to || null

  const days = (history.days || [])
    .filter((d) => d && d.date)
    .map((d) => ({
      date: String(d.date).slice(0, 10),
      total: num(d.total),
      present: num(d.present),
      absent: num(d.absent),
      late: num(d.late),
      percentage: num(d.total) ? Math.round((num(d.present) / num(d.total)) * 100) : 0,
    }))
    .filter((d) => (!from || d.date >= from) && (!to || d.date <= to))
    .sort((a, b) => a.date.localeCompare(b.date))

  const byStudent = new Map()
  for (const row of history.students || []) {
    const total = num(row.total)
    const present = num(row.present)
    if (!row.student_id) continue
    byStudent.set(row.student_id, {
      present,
      total,
      absent: Math.max(0, total - present),
      percentage: total ? Math.round((present / total) * 100) : 0,
    })
  }

  const byClass = new Map()
  for (const row of history.classes || []) {
    if (!row.class_id) continue
    const total = num(row.total)
    const present = num(row.present)
    byClass.set(row.class_id, {
      id: row.class_id,
      name: row.name || '',
      present,
      total,
      percentage: total ? Math.round((present / total) * 100) : 0,
      days: (row.days || [])
        .map((d) => ({ date: String(d.date || '').slice(0, 10), present: num(d.present), total: num(d.total) }))
        .sort((a, b) => a.date.localeCompare(b.date)),
    })
  }

  const present = days.reduce((a, d) => a + d.present, 0)
  const absent = days.reduce((a, d) => a + d.absent, 0)
  const late = days.reduce((a, d) => a + d.late, 0)
  const total = days.reduce((a, d) => a + d.total, 0)

  return {
    from,
    to,
    days,
    byStudent,
    byClass,
    totals: {
      present,
      absent,
      late,
      total,
      percentage: total ? Math.round((present / total) * 100) : 0,
      sessions: days.length,
      studentsMarked: [...byStudent.values()].filter((s) => s.total > 0).length,
    },
  }
}

/**
 * Replace each student's cumulative percentage with their percentage inside the
 * window. Students with no sessions keep 0% but are flagged `range_total = 0`,
 * so they report as *not recorded* instead of a misleading 0%.
 */
export function applyRangeAttendance(students, attendanceWindow) {
  return students.map((s) => {
    const rec = attendanceWindow?.byStudent?.get(s.id)
    const total = rec?.total || 0
    const present = rec?.present || 0
    return {
      ...s,
      attendance_pct: total ? Math.round((present / total) * 100) : 0,
      range_present: present,
      range_total: total,
      range_recorded: total > 0,
    }
  })
}

/** One-line summary used under the on-screen and PDF timelines. */
export function timelineSummary(attendanceWindow) {
  if (!attendanceWindow?.totals?.total) return 'No attendance was recorded in this period.'
  const t = attendanceWindow.totals
  const fmt = (n) => Number(n).toLocaleString('en-US')
  return `${fmt(t.present)} present · ${fmt(t.absent)} absent · ${t.percentage}% attendance rate across ${fmt(
    t.total,
  )} student-days (${t.sessions} ${t.sessions === 1 ? 'day' : 'days'})`
}

function average(values) {
  if (!values.length) return 0
  return Math.round(values.reduce((a, b) => a + b, 0) / values.length)
}

function percent(part, whole) {
  if (!whole) return 0
  return Math.round((part / whole) * 100)
}

export function bucketFor(pct, recorded = num(pct) > 0) {
  const value = Math.max(0, num(pct))
  if (!recorded) return ATTENDANCE_BUCKETS[4]
  return ATTENDANCE_BUCKETS.find((b) => value >= b.min && value < b.max) || ATTENDANCE_BUCKETS[3]
}

function sortByCountThenName(a, b, key = 'studentCount') {
  return b[key] - a[key] || a.name.localeCompare(b.name)
}

/** Average of the students who actually have attendance recorded. */
function recordedAverage(students) {
  return average(students.filter(isRecorded).map((s) => num(s.attendance_pct)))
}

/**
 * Build the whole school report.
 *
 * @param {{ teachers?: object[], classes?: object[], students?: object[], generatedAt?: Date, range?: object, timeline?: object[] }} input
 */
export function buildSchoolReport({
  teachers = [],
  classes = [],
  students = [],
  generatedAt = new Date(),
  range = null,
  timeline = null,
} = {}) {
  const classById = new Map(classes.map((c) => [c.id, c]))

  const byClass = classes
    .map((c) => {
      const roster = students
        .filter((s) => s.class_id === c.id)
        .sort((a, b) => num(a.roll_number) - num(b.roll_number) || (a.name || '').localeCompare(b.name || ''))
      return {
        id: c.id,
        name: c.name,
        program: c.program || '',
        room: c.room || '',
        teachers: c.teachers || [],
        teacherIds: c.teacher_ids || [],
        studentCount: roster.length,
        activeCount: roster.filter((s) => s.status !== 'Inactive').length,
        attendanceAvg: recordedAverage(roster),
        recordedCount: roster.filter(isRecorded).length,
        students: roster,
      }
    })
    .sort((a, b) => sortByCountThenName(a, b))

  const programMap = new Map()
  for (const c of byClass) {
    const key = c.program.trim() || 'Unassigned program'
    const entry = programMap.get(key) || { name: key, classes: 0, studentCount: 0, attendanceValues: [] }
    entry.classes += 1
    entry.studentCount += c.studentCount
    entry.attendanceValues.push(...c.students.filter(isRecorded).map((s) => num(s.attendance_pct)))
    programMap.set(key, entry)
  }
  const byProgram = [...programMap.values()]
    .map((p) => ({
      name: p.name,
      classes: p.classes,
      studentCount: p.studentCount,
      attendanceAvg: average(p.attendanceValues),
    }))
    .sort((a, b) => b.studentCount - a.studentCount || a.name.localeCompare(b.name))

  const teacherWorkload = teachers
    .map((t) => {
      const ids = (t.class_ids || t.classIds || []).filter((id) => classById.has(id))
      const taught = ids.map((id) => byClass.find((c) => c.id === id)).filter(Boolean)
      const roster = taught.flatMap((c) => c.students)
      return {
        id: t.id,
        name: t.name || t.full_name || 'Unnamed teacher',
        email: t.email || '',
        subjects: t.subjects || [t.subject].filter(Boolean),
        status: t.status || 'Active',
        classes: taught.map((c) => c.name),
        classCount: taught.length,
        studentCount: roster.length,
        attendanceAvg: recordedAverage(roster),
        recordedCount: roster.filter(isRecorded).length,
      }
    })
    .sort((a, b) => b.studentCount - a.studentCount || a.name.localeCompare(b.name))

  const attendance = ATTENDANCE_BUCKETS.map((b) => {
    const roster = students.filter((s) => bucketFor(s.attendance_pct, isRecorded(s)).key === b.key)
    return {
      key: b.key,
      label: b.label,
      tone: b.tone,
      count: roster.length,
      share: percent(roster.length, students.length),
      students: roster.sort((a, b2) => num(a.attendance_pct) - num(b2.attendance_pct)),
    }
  })

  const unrecorded = students.filter((s) => !isRecorded(s))
  const lowAttendance = students.filter((s) => isRecorded(s) && num(s.attendance_pct) < LOW_ATTENDANCE)
  const inactiveStudents = students.filter((s) => s.status === 'Inactive')
  const unstaffedClasses = byClass.filter((c) => c.teachers.length === 0)
  const emptyClasses = byClass.filter((c) => c.studentCount === 0)
  const idleTeachers = teacherWorkload.filter((t) => t.classCount === 0)

  const needsAttention = [
    {
      key: 'unrecorded',
      label: 'Attendance never recorded',
      detail: 'Students whose attendance has not been marked yet.',
      tone: 'amber',
      count: unrecorded.length,
      rows: unrecorded.map((s) => ({
        title: s.name,
        subtitle: [s.class_name || classById.get(s.class_id)?.name, s.roll_number ? `Roll ${s.roll_number}` : '']
          .filter(Boolean)
          .join(' · '),
        value: '—',
      })),
    },
    {
      key: 'low',
      label: `Below ${LOW_ATTENDANCE}% attendance`,
      detail: 'Students who need an attendance follow-up.',
      tone: 'red',
      count: lowAttendance.length,
      rows: lowAttendance.map((s) => ({
        title: s.name,
        subtitle: s.class_name || classById.get(s.class_id)?.name || 'No class',
        value: `${num(s.attendance_pct)}%`,
      })),
    },
    {
      key: 'unstaffed',
      label: 'Classes without a teacher',
      detail: 'Classes that have no teacher assigned.',
      tone: 'amber',
      count: unstaffedClasses.length,
      rows: unstaffedClasses.map((c) => ({
        title: c.name,
        subtitle: c.program || 'No program',
        value: `${c.studentCount} students`,
      })),
    },
    {
      key: 'empty',
      label: 'Classes without students',
      detail: 'Classes with an empty roster.',
      tone: 'blue',
      count: emptyClasses.length,
      rows: emptyClasses.map((c) => ({
        title: c.name,
        subtitle: c.program || 'No program',
        value: c.teachers.join(', ') || 'No teacher',
      })),
    },
    {
      key: 'idle',
      label: 'Teachers without a class',
      detail: 'Teachers not assigned to any class yet.',
      tone: 'blue',
      count: idleTeachers.length,
      rows: idleTeachers.map((t) => ({
        title: t.name,
        subtitle: t.subjects.join(', ') || 'No subject',
        value: '0 classes',
      })),
    },
    {
      key: 'inactive',
      label: 'Inactive students',
      detail: 'Students currently marked inactive.',
      tone: 'neutral',
      count: inactiveStudents.length,
      rows: inactiveStudents.map((s) => ({
        title: s.name,
        subtitle: s.class_name || classById.get(s.class_id)?.name || 'No class',
        value: 'Inactive',
      })),
    },
  ].filter((group) => group.count > 0)

  const recordedCount = students.filter(isRecorded).length

  return {
    generatedAt,
    range,
    timeline,
    totals: {
      students: students.length,
      activeStudents: students.filter((s) => s.status !== 'Inactive').length,
      teachers: teachers.length,
      activeTeachers: teachers.filter((t) => (t.status || 'Active') !== 'Inactive').length,
      classes: classes.length,
      programs: byProgram.length,
      attendanceAvg: recordedAverage(students),
      recordedCount,
      attendanceCoverage: percent(recordedCount, students.length),
      studentsPerClass: classes.length ? Math.round((students.length / classes.length) * 10) / 10 : 0,
      studentsPerTeacher: teachers.length ? Math.round((students.length / teachers.length) * 10) / 10 : 0,
      sessions: range?.from && timeline ? timeline.length : null,
    },
    byClass,
    byProgram,
    teacherWorkload,
    attendance,
    needsAttention,
  }
}

/** Class scorecard, best attendance first (classes with a roster only). */
export function rankClasses(byClass) {
  return [...byClass]
    .filter((c) => c.studentCount > 0)
    .sort((a, b) => b.attendanceAvg - a.attendanceAvg || b.studentCount - a.studentCount)
}

/* ---------- CSV ---------- */

export function csvEscape(value) {
  const text = value === null || value === undefined ? '' : String(value)
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text
}

function csvRows(rows) {
  return rows.map((row) => row.map(csvEscape).join(',')).join('\n')
}

/**
 * Multi-section CSV so one export covers the whole report.
 * @param {ReturnType<typeof buildSchoolReport>} report
 * @param {{ schoolName?: string }} [meta]
 */
export function buildReportCsv(report, meta = {}) {
  const timeline = report.range?.from && report.timeline ? report.timeline : null
  const periodRows = timeline
    ? [
        [
          'Attendance in period (%)',
          timeline.length
            ? Math.round(
                (timeline.reduce((a, d) => a + d.present, 0) /
                  Math.max(1, timeline.reduce((a, d) => a + d.total, 0))) *
                  100,
              )
            : 0,
        ],
        ['Recorded school days', timeline.length],
      ]
    : []

  const rows = [
    ['School Connect — Executive report'],
    ['School', meta.schoolName || ''],
    ['Scope', meta.scopeLabel || 'Full school'],
    ['Period', report.range?.period || meta.periodLabel || 'All time'],
    ['Generated', report.generatedAt.toISOString()],
    [],
    ['Summary'],
    ['Metric', 'Value'],
    ['Students', report.totals.students],
    ['Active students', report.totals.activeStudents],
    ['Teachers', report.totals.teachers],
    ['Active teachers', report.totals.activeTeachers],
    ['Classes', report.totals.classes],
    ['Programs', report.totals.programs],
    ['Average attendance (%)', report.totals.attendanceAvg],
    ['Students with attendance recorded', report.totals.recordedCount],
    ['Attendance coverage (%)', report.totals.attendanceCoverage],
    ['Students per class', report.totals.studentsPerClass],
    ['Students per teacher', report.totals.studentsPerTeacher],
    ...periodRows,
    [],
    ['Attendance distribution'],
    ['Band', 'Students', 'Share (%)'],
    ...report.attendance.map((b) => [b.label, b.count, b.share]),
    [],
    ...(timeline
      ? [
          ['Daily attendance'],
          ['Date', 'Present', 'Absent', 'Attendance (%)'],
          ...timeline.map((d) => [d.date, d.present, d.absent, d.percentage]),
          [],
        ]
      : []),
    ['Class scorecard'],
    ['Class', 'Program', 'Room', 'Students', 'Teachers', 'Avg attendance (%)'],
    ...report.byClass.map((c) => [
      c.name,
      c.program,
      c.room,
      c.studentCount,
      c.teachers.join('; '),
      c.attendanceAvg,
    ]),
    [],
    ['Programs'],
    ['Program', 'Classes', 'Students', 'Avg attendance (%)'],
    ...report.byProgram.map((p) => [p.name, p.classes, p.studentCount, p.attendanceAvg]),
    [],
    ['Teacher workload'],
    ['Teacher', 'Email', 'Subjects', 'Classes', 'Students', 'Avg attendance (%)', 'Status'],
    ...report.teacherWorkload.map((t) => [
      t.name,
      t.email,
      t.subjects.join('; '),
      t.classCount,
      t.studentCount,
      t.attendanceAvg,
      t.status,
    ]),
    [],
    ['Needs attention'],
    ['Area', 'Count'],
    ...report.needsAttention.map((g) => [g.label, g.count]),
  ]
  return csvRows(rows)
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

/**
 * Export file name that carries the scope and period, e.g.
 * springfield-elementary-grade-8-a-2026-10-01-to-2026-10-18-2026-10-18.pdf
 */
export function exportFileName({ schoolName, scopeLabel, from, to, extension = 'pdf', date = new Date() }) {
  const slug = (value) =>
    String(value || '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '')
  const period = from && to ? `${from}_to_${to}` : 'all-time'
  const parts = [slug(schoolName) || 'school', slug(scopeLabel) || 'full-school', period, dayStamp(date)]
  return `${parts.filter(Boolean).join('-')}.${extension}`
}

/** Filesystem-safe file name for exports. */
export function reportFileName(prefix, date = new Date(), extension = 'csv') {
  const stamp = dayStamp(date)
  const slug = (prefix || 'school')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
  return `${slug || 'school'}-report-${stamp}.${extension}`
}
