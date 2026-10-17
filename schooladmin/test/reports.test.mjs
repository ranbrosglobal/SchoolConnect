import test from 'node:test'
import assert from 'node:assert/strict'
import {
  ATTENDANCE_BUCKETS,
  LOW_ATTENDANCE,
  bucketFor,
  buildReportCsv,
  buildSchoolReport,
  csvEscape,
  rankClasses,
  reportFileName,
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
})
