import test from 'node:test'
import assert from 'node:assert/strict'
import {
  ATTENDANCE_BUCKETS,
  LOW_ATTENDANCE,
  RANGE_PRESETS,
  applyRangeAttendance,
  bucketFor,
  buildAttendanceWindow,
  buildReportCsv,
  buildSchoolReport,
  csvEscape,
  dayStamp,
  exportFileName,
  formatDay,
  rankClasses,
  reportFileName,
  resolveRange,
} from '../src/lib/reports.js'

const TEACHERS = [
  { id: 't-1', name: 'Kawaljit Singh', email: 'k@example.com', subjects: ['Robotics'], class_ids: ['c-1', 'c-2'], status: 'Active' },
  { id: 't-2', name: 'Meera, "M" Rao', email: 'm@example.com', subjects: ['Maths'], class_ids: [], status: 'Active' },
]

const CLASSES = [
  { id: 'c-1', name: 'Robotics class', program: 'Robotics', room: 'Lab 1', teachers: ['Kawaljit Singh'], teacher_ids: ['t-1'] },
  { id: 'c-2', name: 'Science 101', program: 'Science', room: 'Room 4', teachers: ['Kawaljit Singh'], teacher_ids: ['t-1'] },
  { id: 'c-3', name: 'Empty class', program: '', room: '', teachers: [], teacher_ids: [] },
]

const STUDENTS = [
  { id: 's-1', name: 'Aarav', class_id: 'c-1', class_name: 'Robotics class', roll_number: 1, attendance_pct: 96, status: 'Active' },
  { id: 's-2', name: 'Bhavna', class_id: 'c-1', class_name: 'Robotics class', roll_number: 2, attendance_pct: 64, status: 'Active' },
  { id: 's-3', name: 'Chirag', class_id: 'c-2', class_name: 'Science 101', roll_number: 1, attendance_pct: 0, status: 'Active' },
  { id: 's-4', name: 'Divya', class_id: 'c-2', class_name: 'Science 101', roll_number: 2, attendance_pct: 82, status: 'Inactive' },
]

const report = buildSchoolReport({ teachers: TEACHERS, classes: CLASSES, students: STUDENTS })

test('attendance buckets split 0% out as "not recorded"', () => {
  assert.equal(bucketFor(0).key, 'unrecorded')
  assert.equal(bucketFor(null).key, 'unrecorded')
  assert.equal(bucketFor(1).key, 'critical')
  assert.equal(bucketFor(49).key, 'critical')
  assert.equal(bucketFor(50).key, 'watch')
  assert.equal(bucketFor(74).key, 'watch')
  assert.equal(bucketFor(75).key, 'good')
  assert.equal(bucketFor(89).key, 'good')
  assert.equal(bucketFor(90).key, 'excellent')
  assert.equal(bucketFor(100).key, 'excellent')
  assert.equal(ATTENDANCE_BUCKETS.length, 5)
})

test('totals describe the school and ignore unrecorded attendance in the average', () => {
  assert.equal(report.totals.students, 4)
  assert.equal(report.totals.activeStudents, 3)
  assert.equal(report.totals.teachers, 2)
  assert.equal(report.totals.classes, 3)
  assert.equal(report.totals.recordedCount, 3)
  assert.equal(report.totals.attendanceCoverage, 75)
  // (96 + 64 + 82) / 3 = 80.67 → 81
  assert.equal(report.totals.attendanceAvg, 81)
  assert.equal(report.totals.studentsPerClass, 1.3)
  assert.equal(report.totals.studentsPerTeacher, 2)
})

test('classes carry roster, teacher and attendance detail for drill-downs', () => {
  const robotics = report.byClass.find((c) => c.id === 'c-1')
  assert.equal(robotics.studentCount, 2)
  assert.equal(robotics.recordedCount, 2)
  assert.equal(robotics.attendanceAvg, 80)
  assert.deepEqual(robotics.students.map((s) => s.name), ['Aarav', 'Bhavna'])

  const science = report.byClass.find((c) => c.id === 'c-2')
  assert.equal(science.attendanceAvg, 82) // 0% student excluded from the average
  assert.equal(science.recordedCount, 1)

  // Largest class first
  assert.equal(report.byClass[0].name, 'Robotics class')
})

test('program roll-up groups classes', () => {
  const names = report.byProgram.map((p) => p.name)
  assert.ok(names.includes('Robotics'))
  assert.ok(names.includes('Science'))
  assert.ok(names.includes('Unassigned program'))
  const robotics = report.byProgram.find((p) => p.name === 'Robotics')
  assert.equal(robotics.classes, 1)
  assert.equal(robotics.studentCount, 2)
})

test('teacher workload counts only classes that still exist', () => {
  const kawaljit = report.teacherWorkload.find((t) => t.id === 't-1')
  assert.equal(kawaljit.classCount, 2)
  assert.equal(kawaljit.studentCount, 4)
  assert.deepEqual(kawaljit.classes, ['Robotics class', 'Science 101'])

  const idle = report.teacherWorkload.find((t) => t.id === 't-2')
  assert.equal(idle.classCount, 0)
  assert.equal(idle.studentCount, 0)
})

test('attendance distribution covers every student exactly once', () => {
  const total = report.attendance.reduce((sum, b) => sum + b.count, 0)
  assert.equal(total, STUDENTS.length)
  assert.equal(report.attendance.find((b) => b.key === 'unrecorded').count, 1) // Chirag, 0%
  assert.equal(report.attendance.find((b) => b.key === 'critical').count, 0)
  assert.equal(report.attendance.find((b) => b.key === 'watch').count, 1) // Bhavna, 64%
  assert.equal(report.attendance.find((b) => b.key === 'good').count, 1) // Divya, 82%
  assert.equal(report.attendance.find((b) => b.key === 'excellent').count, 1) // Aarav, 96%
})

test('needs attention surfaces the real problems', () => {
  const keys = report.needsAttention.map((g) => g.key)
  assert.deepEqual(keys.sort(), ['empty', 'idle', 'inactive', 'low', 'unrecorded', 'unstaffed'])

  const low = report.needsAttention.find((g) => g.key === 'low')
  assert.equal(low.count, 1)
  assert.equal(low.rows[0].title, 'Bhavna')
  assert.equal(low.rows[0].value, `${64}%`)
  assert.ok(LOW_ATTENDANCE === 75)

  const unstaffed = report.needsAttention.find((g) => g.key === 'unstaffed')
  assert.equal(unstaffed.rows[0].title, 'Empty class')

  const unrecorded = report.needsAttention.find((g) => g.key === 'unrecorded')
  assert.equal(unrecorded.rows[0].title, 'Chirag')
})

test('empty school produces a zeroed, non-crashing report', () => {
  const empty = buildSchoolReport({})
  assert.equal(empty.totals.students, 0)
  assert.equal(empty.totals.attendanceAvg, 0)
  assert.equal(empty.byClass.length, 0)
  assert.equal(empty.needsAttention.length, 0)
  assert.ok(buildReportCsv(empty, { schoolName: 'Test' }).includes('Summary'))
})

test('class scorecard ranks by attendance with a roster', () => {
  const ranked = rankClasses(report.byClass)
  assert.deepEqual(ranked.map((c) => c.name), ['Science 101', 'Robotics class'])
})

test('csv escapes separators and quotes', () => {
  assert.equal(csvEscape('plain'), 'plain')
  assert.equal(csvEscape('Meera, "M" Rao'), '"Meera, ""M"" Rao"')
  assert.equal(csvEscape(null), '')
})

test('csv export contains every report section', () => {
  const csv = buildReportCsv(report, { schoolName: 'Ranbro institute' })
  for (const heading of [
    'School Connect — Executive report',
    'Ranbro institute',
    'Summary',
    'Attendance distribution',
    'Class scorecard',
    'Programs',
    'Teacher workload',
    'Needs attention',
  ]) {
    assert.ok(csv.includes(heading), `missing section: ${heading}`)
  }
  assert.ok(csv.includes('Robotics class,Robotics,Lab 1,2,Kawaljit Singh,80'))
  assert.ok(csv.includes('"Meera, ""M"" Rao"'))
  assert.ok(csv.includes('Below 75% attendance,1'))
})

test('export file names are filesystem safe', () => {
  assert.equal(
    reportFileName('Ranbro institute', new Date('2026-10-18T00:00:00Z')),
    'ranbro-institute-report-2026-10-18.csv',
  )
  assert.equal(reportFileName('', new Date('2026-01-02T00:00:00Z')), 'school-report-2026-01-02.csv')
  assert.equal(
    reportFileName('Ranbro institute', new Date('2026-10-18T00:00:00Z'), 'pdf'),
    'ranbro-institute-report-2026-10-18.pdf',
  )
})

test('export names carry the scope and period', () => {
  assert.equal(
    exportFileName({
      schoolName: 'Ranbro Institute',
      scopeLabel: 'Grade 8 - A',
      from: '2026-10-01',
      to: '2026-10-18',
      extension: 'pdf',
      date: new Date('2026-10-18T12:00:00Z'),
    }),
    'ranbro-institute-grade-8-a-2026-10-01_to_2026-10-18-2026-10-18.pdf',
  )
  assert.equal(
    exportFileName({
      schoolName: 'Ranbro Institute',
      scopeLabel: 'Full school',
      extension: 'csv',
      date: new Date('2026-10-18T12:00:00Z'),
    }),
    'ranbro-institute-full-school-all-time-2026-10-18.csv',
  )
})

/* ---------- reporting periods ---------- */

test('period presets resolve to inclusive calendar windows', () => {
  const today = new Date(2026, 9, 18) // 18 Oct 2026

  const all = resolveRange('all', { today })
  assert.equal(all.from, null)
  assert.equal(all.to, null)
  assert.equal(all.isRange, false)
  assert.equal(all.period, 'All time')

  const week = resolveRange('7d', { today })
  assert.equal(week.from, '2026-10-12')
  assert.equal(week.to, '2026-10-18')
  assert.equal(week.days, 7)
  assert.equal(week.label, 'Last 7 days')
  assert.equal(week.period, '12 Oct 2026 – 18 Oct 2026')

  const fortnight = resolveRange('15d', { today })
  assert.equal(fortnight.from, '2026-10-04')
  assert.equal(fortnight.days, 15)

  const month = resolveRange('mtd', { today })
  assert.equal(month.from, '2026-10-01')
  assert.equal(month.to, '2026-10-18')
  assert.equal(month.days, 18)

  const term = resolveRange('term', { today })
  assert.equal(term.days, 90)
  assert.equal(RANGE_PRESETS.length, 7)
})

test('custom periods validate their dates', () => {
  const ok = resolveRange('custom', { from: '2026-09-01', to: '2026-09-30' })
  assert.equal(ok.isRange, true)
  assert.equal(ok.days, 30)
  assert.equal(ok.period, '1 Sep 2026 – 30 Sep 2026')
  assert.equal(ok.error, undefined)

  assert.match(resolveRange('custom', { from: '2026-09-01' }).error, /start and end/i)
  assert.match(resolveRange('custom', { from: '2026-10-10', to: '2026-10-01' }).error, /on or before/i)
  assert.match(resolveRange('custom', { from: '2020-01-01', to: '2026-10-01' }).error, /366 days/i)

  // A single day is a valid window.
  const oneDay = resolveRange('custom', { from: '2026-10-18', to: '2026-10-18' })
  assert.equal(oneDay.days, 1)
  assert.equal(oneDay.period, '18 Oct 2026')
})

test('day stamps and labels use local calendar days', () => {
  assert.equal(dayStamp(new Date(2026, 0, 5)), '2026-01-05')
  assert.equal(formatDay('2026-10-03'), '3 Oct 2026')
  assert.equal(formatDay(''), '')
})

/* ---------- attendance windows ---------- */

function historyFor({ students, days }) {
  const rows = []
  const studentTotals = new Map()
  const classDays = new Map()
  for (const day of days) {
    for (const s of students) {
      const present = s.presentOn?.includes(day)
      rows.push({ date: day, present: present ? 1 : 0 })
      const entry = studentTotals.get(s.id) || { student_id: s.id, class_id: s.class_id, present: 0, total: 0 }
      entry.total += 1
      if (present) entry.present += 1
      studentTotals.set(s.id, entry)

      const cd = classDays.get(s.class_id) || new Map()
      const d = cd.get(day) || { date: day, present: 0, total: 0 }
      d.total += 1
      if (present) d.present += 1
      cd.set(day, d)
      classDays.set(s.class_id, cd)
    }
  }
  const dayTotals = new Map()
  for (const r of rows) {
    const d = dayTotals.get(r.date) || { date: r.date, present: 0, absent: 0, late: 0, total: 0 }
    d.total += 1
    if (r.present) d.present += 1
    else d.absent += 1
    dayTotals.set(r.date, d)
  }
  const dayRows = [...dayTotals.values()]
    .map((d) => ({ ...d, percentage: Math.round((d.present / d.total) * 100) }))
    .sort((a, b) => a.date.localeCompare(b.date))
  return {
    from: days[0],
    to: days[days.length - 1],
    days: dayRows,
    classes: [...classDays.entries()].map(([class_id, map]) => ({
      class_id,
      name: class_id,
      present: [...map.values()].reduce((a, d) => a + d.present, 0),
      total: [...map.values()].reduce((a, d) => a + d.total, 0),
      days: [...map.values()].sort((a, b) => a.date.localeCompare(b.date)),
    })),
    students: [...studentTotals.values()],
  }
}

test('attendance windows aggregate days, classes and students', () => {
  const history = historyFor({
    days: ['2026-10-12', '2026-10-13', '2026-10-14'],
    students: [
      { id: 's-1', class_id: 'c-1', presentOn: ['2026-10-12', '2026-10-13', '2026-10-14'] },
      { id: 's-2', class_id: 'c-1', presentOn: ['2026-10-12'] },
    ],
  })

  const window = buildAttendanceWindow(history, { from: '2026-10-12', to: '2026-10-14' })
  assert.equal(window.days.length, 3)
  assert.deepEqual(window.days.map((d) => d.percentage), [100, 50, 50])
  assert.equal(window.totals.present, 4)
  assert.equal(window.totals.absent, 2)
  assert.equal(window.totals.total, 6)
  assert.equal(window.totals.percentage, 67)
  assert.equal(window.totals.studentsMarked, 2)

  assert.equal(window.byStudent.get('s-1').percentage, 100)
  assert.equal(window.byStudent.get('s-2').percentage, 33)
  const c1 = window.byClass.get('c-1')
  assert.equal(c1.present, 4)
  assert.equal(c1.total, 6)
  assert.equal(c1.percentage, 67)
  assert.deepEqual(c1.days.map((d) => d.date), ['2026-10-12', '2026-10-13', '2026-10-14'])
})

test('attendance windows clip to the requested range on both ends', () => {
  const history = historyFor({
    days: ['2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04'],
    students: [{ id: 's-1', class_id: 'c-1', presentOn: ['2026-10-02'] }],
  })
  const window = buildAttendanceWindow(history, { from: '2026-10-02', to: '2026-10-03' })
  assert.deepEqual(window.days.map((d) => d.date), ['2026-10-02', '2026-10-03'])
  assert.equal(window.totals.total, 2)
  assert.equal(window.totals.present, 1)
  assert.equal(window.totals.sessions, 2)
})

test('a range replaces cumulative attendance and separates absent from unrecorded', () => {
  const window = buildAttendanceWindow(
    {
      from: '2026-10-12',
      to: '2026-10-14',
      days: [
        { date: '2026-10-12', present: 0, absent: 3, late: 0, total: 3 },
        { date: '2026-10-13', present: 2, absent: 1, late: 1, total: 3 },
      ],
      classes: [],
      students: [
        { student_id: 's-1', class_id: 'c-1', present: 0, total: 2 }, // all absent
        { student_id: 's-2', class_id: 'c-1', present: 2, total: 2 },
        // s-3 has no sessions at all
      ],
    },
    { from: '2026-10-12', to: '2026-10-14' },
  )

  const students = applyRangeAttendance(
    [
      { id: 's-1', name: 'Always away', class_id: 'c-1', attendance_pct: 92, status: 'Active' },
      { id: 's-2', name: 'Always here', class_id: 'c-1', attendance_pct: 40, status: 'Active' },
      { id: 's-3', name: 'New student', class_id: 'c-1', attendance_pct: 0, status: 'Active' },
    ],
    window,
  )

  assert.equal(students[0].attendance_pct, 0)
  assert.equal(students[0].range_total, 2) // recorded, even though 0%
  assert.equal(students[1].attendance_pct, 100)
  assert.equal(students[2].range_total, 0)

  const scoped = buildSchoolReport({
    teachers: [],
    classes: [{ id: 'c-1', name: 'Class 1', program: 'P', teacher_ids: [], teachers: [] }],
    students,
    range: { from: '2026-10-12', to: '2026-10-14' },
    timeline: [{ date: '2026-10-12', present: 0, absent: 3, total: 3, percentage: 0 }],
  })

  // All-absent students belong to the lowest band, not "not recorded".
  const critical = scoped.attendance.find((b) => b.key === 'critical')
  const unrecorded = scoped.attendance.find((b) => b.key === 'unrecorded')
  assert.equal(critical.count, 1)
  assert.equal(critical.students[0].name, 'Always away')
  assert.equal(unrecorded.count, 1)
  assert.equal(unrecorded.students[0].name, 'New student')
  assert.equal(scoped.totals.recordedCount, 2)
  assert.equal(scoped.totals.attendanceAvg, 50)
  assert.equal(scoped.totals.sessions, 1)
  assert.equal(scoped.timeline.length, 1)
  assert.equal(scoped.range.from, '2026-10-12')
})

test('csv exports the period and daily timeline', () => {
  const scoped = buildSchoolReport({
    teachers: TEACHERS,
    classes: CLASSES,
    students: STUDENTS,
    range: { from: '2026-10-12', to: '2026-10-14', period: '12 Oct 2026 – 14 Oct 2026' },
    timeline: [
      { date: '2026-10-12', present: 3, absent: 1, total: 4, percentage: 75 },
      { date: '2026-10-13', present: 4, absent: 0, total: 4, percentage: 100 },
    ],
  })
  const csv = buildReportCsv(scoped, { schoolName: 'Test', scopeLabel: 'Full school' })
  assert.ok(csv.includes('Period,12 Oct 2026 – 14 Oct 2026'))
  assert.ok(csv.includes('Scope,Full school'))
  assert.ok(csv.includes('Attendance in period (%)'))
  assert.ok(csv.includes('Daily attendance'))
  assert.ok(csv.includes('2026-10-12,3,1,75'))
  assert.ok(csv.includes('2026-10-13,4,0,100'))
})
