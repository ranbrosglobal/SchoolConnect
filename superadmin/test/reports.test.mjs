import test from 'node:test'
import assert from 'node:assert/strict'
import {
  COMPLETENESS_CHECKS,
  buildNetworkReport,
  buildNetworkReportCsv,
  csvEscape,
  exportFileName,
  reportFileName,
} from '../src/lib/reports.js'

const SCHOOLS = [
  {
    id: 's-1',
    name: 'Davendra School',
    location: 'Ajnala',
    status: 'Active',
    established: 1998,
    teacher_count: 12,
    class_count: 4,
    student_count: 120,
    admin_names: ['Kawaljit Sir'],
  },
  {
    id: 's-2',
    name: 'Gurukul, "The"',
    location: '',
    status: 'Active',
    established: 2010,
    teacher_count: 0,
    class_count: 0,
    student_count: 0,
    admin_names: [],
  },
  {
    id: 's-3',
    name: 'Baba Kuma School',
    location: 'Hoshiar Nagar',
    status: 'Disabled',
    established: 2020,
    teacher_count: 3,
    class_count: 2,
    student_count: 40,
    admin_names: ['Head Sir', 'MD Sir'],
  },
]

const report = buildNetworkReport({ overview: { school_admin_count: 3 }, schools: SCHOOLS })

test('totals summarise the network', () => {
  assert.equal(report.totals.schools, 3)
  assert.equal(report.totals.activeSchools, 2)
  assert.equal(report.totals.disabledSchools, 1)
  assert.equal(report.totals.admins, 3)
  assert.equal(report.totals.teachers, 15)
  assert.equal(report.totals.classes, 6)
  assert.equal(report.totals.students, 160)
  assert.equal(report.totals.studentsPerClass, 26.7) // 160 / 6
  assert.equal(report.totals.studentsPerTeacher, 10.7) // 160 / 15
  assert.equal(report.totals.studentsPerSchool, 53.3)
  assert.equal(report.totals.adminCoverage, 67) // 2 of 3 schools have an admin
})

test('status slices only include statuses that exist', () => {
  assert.deepEqual(
    report.statusSlices.map((s) => [s.label, s.count]),
    [
      ['Active', 2],
      ['Disabled', 1],
    ],
  )
  const empty = buildNetworkReport({ schools: [] })
  assert.deepEqual(empty.statusSlices, [])
})

test('ranking is ordered by enrolment and shares add up', () => {
  assert.deepEqual(
    report.ranking.map((s) => s.name),
    ['Davendra School', 'Baba Kuma School', 'Gurukul, "The"'],
  )
  assert.equal(report.ranking[0].share, 75) // 120 of 160
  assert.equal(report.ranking[0].studentsPerClass, 30)
  assert.equal(report.ranking[0].studentsPerTeacher, 10)
})

test('setup completeness scores every school and lists what is outstanding', () => {
  assert.equal(COMPLETENESS_CHECKS.length, 5)
  const worst = report.completeness[0]
  assert.equal(worst.name, 'Gurukul, "The"')
  assert.equal(worst.checksDone, 0)
  assert.equal(worst.completeness, 0)
  assert.deepEqual(worst.checks.filter((c) => !c.done).map((c) => c.key), [
    'admins',
    'teachers',
    'classes',
    'students',
    'location',
  ])

  const best = report.completeness.find((s) => s.id === 's-1')
  assert.equal(best.completeness, 100)
  assert.equal(best.checksDone, 5)
  // Worst first; fully set-up schools tie-break by enrolment (Davendra 120 > Baba 40)
  assert.deepEqual(
    report.completeness.map((s) => s.name),
    ['Gurukul, "The"', 'Davendra School', 'Baba Kuma School'],
  )
})

test('needs attention groups the real gaps only', () => {
  const keys = report.needsAttention.map((g) => g.key)
  assert.deepEqual(keys, ['no-admin', 'no-teachers', 'no-classes', 'no-students', 'disabled'])
  const noAdmin = report.needsAttention.find((g) => g.key === 'no-admin')
  assert.equal(noAdmin.count, 1)
  assert.equal(noAdmin.rows[0].title, 'Gurukul, "The"')
  assert.equal(noAdmin.rows[0].value, '0 students · 0 classes')
})

test('empty network produces a zeroed report', () => {
  const empty = buildNetworkReport({})
  assert.equal(empty.totals.schools, 0)
  assert.equal(empty.totals.studentsPerClass, 0)
  assert.equal(empty.totals.adminCoverage, 0)
  assert.equal(empty.needsAttention.length, 0)
  assert.ok(buildNetworkReportCsv(empty).includes('Network report'))
})

test('csv escapes separators and quotes', () => {
  assert.equal(csvEscape('plain'), 'plain')
  assert.equal(csvEscape('Gurukul, "The"'), '"Gurukul, ""The"""')
  assert.equal(csvEscape(undefined), '')
})

test('csv export contains every report section', () => {
  const csv = buildNetworkReportCsv(report)
  for (const heading of [
    'School Connect — Network report',
    'Summary',
    'School status',
    'Enrolment ranking',
    'Setup completeness',
    'Needs attention',
  ]) {
    assert.ok(csv.includes(heading), `missing section: ${heading}`)
  }
  assert.ok(csv.includes('"Gurukul, ""The"""'))
  assert.ok(csv.includes('Davendra School,Ajnala,Active,120,75,12,4,30,1'))
  assert.ok(csv.includes('Schools without an admin,1'))
  assert.ok(csv.includes('School admin assigned; Teachers added'))
})

test('export file names are filesystem safe', () => {
  assert.equal(reportFileName('Network', new Date('2026-10-18T00:00:00Z')), 'network-report-2026-10-18.csv')
  assert.equal(reportFileName('', new Date('2026-01-02T00:00:00Z')), 'network-report-2026-01-02.csv')
  assert.equal(reportFileName('Network', new Date('2026-10-18T00:00:00Z'), 'pdf'), 'network-report-2026-10-18.pdf')
  assert.equal(
    exportFileName({ scopeLabel: '3 selected schools', date: new Date('2026-10-18T00:00:00Z') }),
    '3-selected-schools-report-2026-10-18.pdf',
  )
})

test('a school subset reports its own totals, not the network dashboard figures', () => {
  const subset = buildNetworkReport({
    overview: { school_admin_count: 99 },
    schools: [SCHOOLS[0], SCHOOLS[2]],
    useOverviewTotals: false,
  })
  assert.equal(subset.totals.schools, 2)
  assert.equal(subset.totals.students, 160)
  // Summed from the selected schools (1 + 2), never the network dashboard's 99.
  assert.equal(subset.totals.admins, 3)
  assert.equal(subset.ranking.length, 2)
  assert.equal(subset.statusSlices.find((s) => s.key === 'disabled').count, 1)

  const all = buildNetworkReport({ overview: { school_admin_count: 99 }, schools: SCHOOLS })
  assert.equal(all.totals.admins, 99)
})

test('csv names the exported scope', () => {
  const csv = buildNetworkReportCsv(report, { scopeLabel: '2 selected schools' })
  assert.ok(csv.includes('Scope,2 selected schools'))
})
