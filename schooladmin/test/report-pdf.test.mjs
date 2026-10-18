import test from 'node:test'
import assert from 'node:assert/strict'
import { PDFParse } from 'pdf-parse'
import { applyRangeAttendance, buildAttendanceWindow, buildSchoolReport } from '../src/lib/reports.js'
import { buildSchoolPdfSpec, buildSchoolReportPdf } from '../src/lib/report-pdf.js'

const pdfSafeText = async (doc) => {
  const parser = new PDFParse({ data: new Uint8Array(doc.output('arraybuffer')) })
  const result = await parser.getText()
  await parser.destroy?.()
  return result.text
}

const CLASSES = [
  { id: 'c-1', name: 'Grade 8 - A', program: 'Grade 8', room: 'Room 201', teachers: ['Anita Sharma'], teacher_ids: ['t-1'] },
  { id: 'c-2', name: 'Grade 9 - A', program: 'Grade 9', room: 'Room 103', teachers: ['Rajesh Iyer'], teacher_ids: ['t-2'] },
]

const TEACHERS = [
  { id: 't-1', name: 'Anita Sharma', email: 'anita@example.com', subjects: ['Mathematics'], class_ids: ['c-1'], status: 'Active' },
  { id: 't-2', name: 'Rajesh Iyer', email: 'rajesh@example.com', subjects: ['Science'], class_ids: ['c-2'], status: 'Active' },
]

function makeStudents(count, classId = 'c-1', startRoll = 1) {
  return Array.from({ length: count }, (_, i) => ({
    id: `${classId}-s${startRoll + i}`,
    name: `Student ${startRoll + i}`,
    class_id: classId,
    class_name: classId === 'c-1' ? 'Grade 8 - A' : 'Grade 9 - A',
    roll_number: startRoll + i,
    attendance_pct: 55 + ((i * 7) % 45),
    status: 'Active',
  }))
}

const STUDENTS = [...makeStudents(8, 'c-1'), ...makeStudents(6, 'c-2')]

const HISTORY = {
  from: '2026-10-12',
  to: '2026-10-16',
  days: [
    { date: '2026-10-12', present: 12, absent: 2, late: 1, total: 14, percentage: 86 },
    { date: '2026-10-13', present: 11, absent: 3, late: 0, total: 14, percentage: 79 },
    { date: '2026-10-14', present: 13, absent: 1, late: 1, total: 14, percentage: 93 },
    { date: '2026-10-15', present: 10, absent: 4, late: 0, total: 14, percentage: 71 },
    { date: '2026-10-16', present: 14, absent: 0, late: 0, total: 14, percentage: 100 },
  ],
  classes: [
    {
      class_id: 'c-1',
      name: 'Grade 8 - A',
      present: 33,
      total: 40,
      percentage: 83,
      days: [
        { date: '2026-10-12', present: 7, total: 8 },
        { date: '2026-10-13', present: 6, total: 8 },
      ],
    },
  ],
  students: STUDENTS.map((s, i) => ({
    student_id: s.id,
    class_id: s.class_id,
    present: Math.max(0, 5 - (i % 3)),
    total: 5,
  })),
  totals: { present: 60, absent: 8, late: 2, total: 68, percentage: 88, students_marked: 14, sessions: 5 },
}

const RANGE = { from: '2026-10-12', to: '2026-10-16', period: '12 Oct 2026 – 16 Oct 2026' }

function rangeReport() {
  const window = buildAttendanceWindow(HISTORY, RANGE)
  const students = applyRangeAttendance(STUDENTS, window)
  return buildSchoolReport({
    teachers: TEACHERS,
    classes: CLASSES,
    students,
    range: RANGE,
    timeline: window.days,
  })
}

test('all-time PDF renders every section with the school and scope on the cover', async () => {
  const report = buildSchoolReport({ teachers: TEACHERS, classes: CLASSES, students: STUDENTS })
  const doc = buildSchoolReportPdf(report, {
    schoolName: 'Springfield Elementary',
    scopeLabel: 'Full school',
    periodLabel: 'All time',
    preparedBy: 'Priya Sharma',
    rosters: report.byClass.map((c) => ({
      name: c.name,
      program: c.program,
      room: c.room,
      teachers: c.teachers,
      students: c.students,
    })),
  })

  const bytes = new Uint8Array(doc.output('arraybuffer'))
  assert.equal(new TextDecoder().decode(bytes.slice(0, 5)), '%PDF-')
  assert.ok(bytes.length > 4000, `PDF too small: ${bytes.length} bytes`)

  const text = await pdfSafeText(doc)
  for (const heading of [
    'Springfield Elementary',
    'Executive report',
    'SCOPE',
    'Full school',
    'PERIOD',
    'All time',
    'At a glance',
    'Attendance distribution',
    'Class scorecard',
    'Enrolment by program',
    'Teacher workload',
    'Notes',
    'Page 1 of',
  ]) {
    assert.ok(text.includes(heading), `missing: ${heading}`)
  }
  assert.ok(text.includes('Grade 8 - A'), 'class name missing')
  assert.ok(text.includes('Anita Sharma'), 'teacher name missing')
  assert.ok(text.includes('Student 1'), 'roster student missing')
  assert.ok(text.includes('Priya Sharma'), 'prepared-by note missing')
})

test('period PDF includes the daily timeline, period wording and session counts', async () => {
  const report = rangeReport()
  const spec = buildSchoolPdfSpec(report, {
    schoolName: 'Springfield Elementary',
    scopeLabel: 'Grade 8 - A',
    preparedBy: 'Priya Sharma',
    rosters: [
      {
        name: 'Grade 8 - A',
        program: 'Grade 8',
        room: 'Room 201',
        teachers: ['Anita Sharma'],
        students: report.byClass.find((c) => c.id === 'c-1').students,
      },
    ],
  })

  const timeline = spec.sections.find((s) => s.type === 'timeline')
  assert.ok(timeline, 'timeline section missing')
  assert.equal(timeline.rows.length, 5)
  assert.match(timeline.summary, /present/)
  assert.equal(spec.meta.find((m) => m.label === 'Period').value, '12 Oct 2026 – 16 Oct 2026')

  const doc = buildSchoolReportPdf(report, {
    schoolName: 'Springfield Elementary',
    scopeLabel: 'Grade 8 - A',
    preparedBy: 'Priya Sharma',
    rosters: [
      {
        name: 'Grade 8 - A',
        program: 'Grade 8',
        room: 'Room 201',
        teachers: ['Anita Sharma'],
        students: report.byClass.find((c) => c.id === 'c-1').students,
      },
    ],
  })

  const text = await pdfSafeText(doc)
  assert.ok(text.includes('Daily attendance'))
  assert.ok(text.includes('12 Oct 2026'), 'timeline date labels missing')
  assert.ok(text.includes('16 Oct 2026'))
  assert.ok(text.includes('Attendance covers 12 Oct 2026 - 16 Oct 2026'), 'period note missing')
  assert.ok(text.includes('Sessions'), 'roster session column missing')
  assert.ok(text.includes('Grade 8 - A - register'))
})

test('long reports paginate and number every page', async () => {
  const classes = [
    { id: 'c-big', name: 'Grade 10 - A', program: 'Grade 10', room: 'Hall', teachers: ['Anita Sharma'], teacher_ids: ['t-1'] },
  ]
  const students = makeStudents(90, 'c-big')
  const report = buildSchoolReport({ teachers: TEACHERS, classes, students })
  const doc = buildSchoolReportPdf(report, {
    schoolName: 'Springfield Elementary',
    scopeLabel: 'Grade 10 - A',
    rosters: [{ name: 'Grade 10 - A', program: 'Grade 10', room: 'Hall', teachers: ['Anita Sharma'], students }],
  })

  const pages = doc.getNumberOfPages()
  assert.ok(pages >= 3, `expected several pages, got ${pages}`)
  const text = await pdfSafeText(doc)
  assert.ok(text.includes(`Page 1 of ${pages}`))
  assert.ok(text.includes(`Page ${pages} of ${pages}`))
  assert.ok(text.includes('Grade 10 - A - register'))
  // Repeating headers on continuation pages keep the table readable.
  const headerCount = (text.match(/Student/g) || []).length
  assert.ok(headerCount > 1, 'expected a repeated table header')
})

test('empty selections still produce a valid PDF', async () => {
  const report = buildSchoolReport({})
  const doc = buildSchoolReportPdf(report, { schoolName: 'Empty School', scopeLabel: 'Full school' })
  const text = await pdfSafeText(doc)
  assert.ok(doc.getNumberOfPages() >= 1)
  assert.ok(text.includes('Empty School'))
  for (const heading of ['At a glance', 'Attendance distribution', 'Class scorecard', 'Teacher workload', 'Notes']) {
    assert.ok(text.includes(heading), `missing: ${heading}`)
  }
  assert.ok(text.includes('No classes with students yet.'))
  assert.ok(text.includes(`Page ${doc.getNumberOfPages()} of ${doc.getNumberOfPages()}`))
})
