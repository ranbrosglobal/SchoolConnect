import test from 'node:test'
import assert from 'node:assert/strict'
import { PDFParse } from 'pdf-parse'
import { buildNetworkReport } from '../src/lib/reports.js'
import { buildNetworkPdfSpec, buildNetworkReportPdf } from '../src/lib/report-pdf.js'

const print = async (doc) => {
  const parser = new PDFParse({ data: new Uint8Array(doc.output('arraybuffer')) })
  const result = await parser.getText()
  await parser.destroy?.()
  return result.text
}

const SCHOOLS = [
  {
    id: 's-1',
    name: 'Davendra School',
    location: 'Ajnala',
    status: 'Active',
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
    teacher_count: 3,
    class_count: 2,
    student_count: 40,
    admin_names: ['Head Sir', 'MD Sir'],
  },
]

const report = buildNetworkReport({
  overview: { school_admin_count: 3 },
  schools: SCHOOLS,
})

test('network PDF renders the cover, KPIs and every table', async () => {
  const doc = buildNetworkReportPdf(report, { scopeLabel: 'All schools', preparedBy: 'Super Admin' })
  const bytes = new Uint8Array(doc.output('arraybuffer'))
  assert.equal(new TextDecoder().decode(bytes.slice(0, 5)), '%PDF-')

  const text = await print(doc)
  for (const heading of [
    'School Connect network',
    'Network report',
    'SCOPE',
    'All schools',
    'At a glance',
    'School status',
    'Enrolment by school',
    'Setup completeness',
    'Needs attention',
    'Notes',
    'Page 1 of',
  ]) {
    assert.ok(text.includes(heading), `missing: ${heading}`)
  }
  assert.ok(text.includes('Baba Kuma School'))
  assert.ok(text.includes('School admin assigned; Teachers added'), 'outstanding checklist missing')
  assert.ok(text.includes('point-in-time snapshot'), 'snapshot note missing')
})

test('the spec names the selected schools and sums only their figures', () => {
  const subset = buildNetworkReport({
    overview: { school_admin_count: 99 },
    schools: [SCHOOLS[0]],
    useOverviewTotals: false,
  })
  const spec = buildNetworkPdfSpec(subset, { scopeLabel: 'Davendra School' })

  assert.equal(spec.meta.find((m) => m.label === 'Scope').value, 'Davendra School')
  assert.equal(spec.meta.find((m) => m.label === 'Schools').value, '1')
  assert.equal(spec.kpis[0].value, '1')
  assert.equal(spec.kpis[1].value, '1')
  const kpiTitles = spec.sections[0].rows.map((r) => r[0])
  assert.ok(kpiTitles.includes('School admins'))
  assert.ok(!spec.sections.some((s) => s.title === 'Needs attention') || subset.needsAttention.length > 0)
})

test('a subset export only lists the chosen schools', async () => {
  const subset = buildNetworkReport({
    overview: { school_admin_count: 99 },
    schools: [SCHOOLS[0]],
    useOverviewTotals: false,
  })
  const doc = buildNetworkReportPdf(subset, { scopeLabel: 'Davendra School' })
  const text = await print(doc)
  assert.ok(text.includes('Davendra School'))
  assert.ok(!text.includes('Baba Kuma School'))
  assert.ok(!text.includes('Gurukul'))
})

test('empty networks produce a valid PDF', async () => {
  const doc = buildNetworkReportPdf(buildNetworkReport({}), { scopeLabel: 'Full network' })
  const text = await print(doc)
  assert.ok(doc.getNumberOfPages() >= 1)
  assert.ok(text.includes('No schools in this selection.'))
  assert.ok(text.includes('At a glance'))
  assert.ok(text.includes('Notes'))
})
