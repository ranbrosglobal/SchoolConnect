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

function average(values) {
  if (!values.length) return 0
  return Math.round(values.reduce((a, b) => a + b, 0) / values.length)
}

function percent(part, whole) {
  if (!whole) return 0
  return Math.round((part / whole) * 100)
}

export function bucketFor(pct) {
  const value = num(pct)
  if (value <= 0) return ATTENDANCE_BUCKETS[4]
  return ATTENDANCE_BUCKETS.find((b) => value >= b.min && value < b.max) || ATTENDANCE_BUCKETS[3]
}

function sortByCountThenName(a, b, key = 'studentCount') {
  return b[key] - a[key] || a.name.localeCompare(b.name)
}

/** Average of the students who actually have attendance recorded. */
function recordedAverage(students) {
  return average(students.map((s) => num(s.attendance_pct)).filter((v) => v > 0))
}

/**
 * Build the whole school report.
 *
 * @param {{ teachers?: object[], classes?: object[], students?: object[], generatedAt?: Date }} input
 */
export function buildSchoolReport({ teachers = [], classes = [], students = [], generatedAt = new Date() } = {}) {
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
        recordedCount: roster.filter((s) => num(s.attendance_pct) > 0).length,
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
    entry.attendanceValues.push(
      ...c.students.map((s) => num(s.attendance_pct)).filter((v) => v > 0),
    )
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
        recordedCount: roster.filter((s) => num(s.attendance_pct) > 0).length,
      }
    })
    .sort((a, b) => b.studentCount - a.studentCount || a.name.localeCompare(b.name))

  const attendance = ATTENDANCE_BUCKETS.map((b) => {
    const roster = students.filter((s) => bucketFor(s.attendance_pct).key === b.key)
    return {
      key: b.key,
      label: b.label,
      tone: b.tone,
      count: roster.length,
      share: percent(roster.length, students.length),
      students: roster.sort((a, b2) => num(a.attendance_pct) - num(b2.attendance_pct)),
    }
  })

  const unrecorded = students.filter((s) => num(s.attendance_pct) <= 0)
  const lowAttendance = students.filter((s) => {
    const pct = num(s.attendance_pct)
    return pct > 0 && pct < LOW_ATTENDANCE
  })
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

  const recordedCount = students.filter((s) => num(s.attendance_pct) > 0).length

  return {
    generatedAt,
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
  const rows = [
    ['School Connect — Executive report'],
    ['School', meta.schoolName || ''],
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
    [],
    ['Attendance distribution'],
    ['Band', 'Students', 'Share (%)'],
    ...report.attendance.map((b) => [b.label, b.count, b.share]),
    [],
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

/** Filesystem-safe file name for exports. */
export function reportFileName(prefix, date = new Date()) {
  const stamp = date.toISOString().slice(0, 10)
  const slug = (prefix || 'school')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
  return `${slug || 'school'}-report-${stamp}.csv`
}
