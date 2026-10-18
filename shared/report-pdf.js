/**
 * Spec-driven PDF report engine — shared by the School Admin and Super Admin
 * consoles.
 *
 * Both consoles describe their report declaratively (cover fields, KPI tiles,
 * and a list of sections) and this module lays it out on A4 with the console
 * design tokens: a coloured cover band, KPI tiles, horizontal bars, a daily
 * attendance chart and paginated tables with repeating headers, plus a footer
 * on every page.
 *
 *   const doc = buildReportPdf({
 *     eyebrow: 'EXECUTIVE REPORT',
 *     title: 'Springfield Elementary',
 *     subtitle: 'Attendance, enrolment and staffing',
 *     meta: [{ label: 'Scope', value: 'All classes' }, ...],
 *     kpis: [{ label: 'Students', value: 57, hint: '54 active', tone: 'blue' }],
 *     sections: [
 *       { type: 'bars', title: 'Attendance distribution', rows: [...] },
 *       { type: 'table', title: 'Class scorecard', head: [...], rows: [...] },
 *       { type: 'timeline', title: 'Daily attendance', rows: [...] },
 *       { type: 'notes', title: 'Notes', items: ['...'] },
 *     ],
 *   })
 *   doc.save('school-report-2026-10-18.pdf')
 */

import { jsPDF } from 'jspdf'
import autoTable from 'jspdf-autotable'

const PAGE = { width: 595.28, height: 841.89 } // A4 in points
const M = 44 // page margin
const FOOTER = 56 // reserved space at the bottom of every page
const TOP = 64 // content start on continuation pages

const TONE = {
  primary: [49, 69, 187],
  primarySoft: [238, 240, 255],
  primaryContainer: [76, 95, 213],
  ink: [25, 28, 30],
  inkSoft: [69, 70, 83],
  outline: [197, 197, 214],
  outlineSoft: [226, 227, 234],
  surfaceLow: [242, 243, 246],
  background: [248, 249, 252],
  white: [255, 255, 255],
  green: [0, 122, 83],
  greenSoft: [230, 244, 238],
  red: [186, 26, 26],
  redSoft: [253, 234, 234],
  amber: [129, 86, 0],
  amberSoft: [253, 243, 224],
  amberBright: [253, 175, 30],
  blue: [2, 132, 199],
  blueSoft: [224, 242, 254],
  neutral: [117, 118, 133],
}

const TONE_FILL = {
  green: TONE.green,
  blue: TONE.blue,
  amber: TONE.amberBright,
  red: TONE.red,
  neutral: TONE.neutral,
  indigo: TONE.primary,
  primary: TONE.primary,
}

/**
 * jsPDF's bundled fonts are WinAnsi/Latin-1: map the punctuation our reports
 * use (en dashes in attendance bands, curly quotes, bullets) to safe glyphs and
 * replace anything the font cannot draw.
 */
export function pdfSafe(value) {
  if (value === null || value === undefined) return ''
  return String(value)
    .replace(/[\u2010-\u2015\u2212]/g, '-')
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201C\u201D]/g, '"')
    .replace(/\u2026/g, '...')
    .replace(/\u2022/g, '-')
    .replace(/\u00a0/g, ' ')
    .replace(/[^\x20-\x7E\xA0-\xFF]/g, '?')
    .replace(/\s+/g, ' ')
    .trim()
}

const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0)

/** Trim a single line to the available width so it can never spill or wrap. */
function fit(doc, value, width) {
  const text = pdfSafe(value)
  if (doc.getTextWidth(text) <= width) return text
  let trimmed = text
  while (trimmed.length > 1 && doc.getTextWidth(`${trimmed}...`) > width) trimmed = trimmed.slice(0, -1)
  return `${trimmed.trimEnd()}...`
}

/** 1234 -> "1,234" */
export function thousands(value) {
  const n = num(value)
  return n.toLocaleString('en-US')
}

/** "3 Oct 2026" from "2026-10-03" (or a Date). */
export function formatDay(value) {
  if (!value) return ''
  const [y, m, d] = String(value).slice(0, 10).split('-').map(Number)
  if (!y || !m || !d) return String(value)
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  return `${d} ${months[m - 1]} ${y}`
}

function setFill(doc, rgb) {
  doc.setFillColor(rgb[0], rgb[1], rgb[2])
}

function setStroke(doc, rgb) {
  doc.setDrawColor(rgb[0], rgb[1], rgb[2])
}

function setText(doc, rgb) {
  doc.setTextColor(rgb[0], rgb[1], rgb[2])
}

/** Fill colour for an attendance percentage, matching the console bands. */
export function attendanceTone(pct) {
  const v = num(pct)
  if (v >= 85) return 'green'
  if (v >= 75) return 'blue'
  if (v >= 50) return 'amber'
  return 'red'
}

function contentWidth() {
  return PAGE.width - M * 2
}

function drawCover(doc, spec) {
  const title = pdfSafe(spec.title || 'Report')
  const subtitle = pdfSafe(spec.subtitle)
  const eyebrow = pdfSafe(spec.eyebrow || 'REPORT').toUpperCase()

  setFill(doc, TONE.primary)
  // Band height depends on how many lines the title needs.
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(23)
  const titleLines = doc.splitTextToSize(title, contentWidth() - 8)
  const bandH = 96 + titleLines.length * 27 + (subtitle ? 22 : 0) + (spec.meta?.length ? 40 : 12)

  doc.rect(0, 0, PAGE.width, bandH, 'F')
  // Soft accent block so the band is not a flat slab.
  doc.setFillColor(...TONE.primaryContainer)
  doc.rect(PAGE.width - 150, 0, 150, bandH, 'F')

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(8.5)
  setText(doc, [222, 224, 255])
  doc.text('SCHOOL CONNECT', M, 38, { charSpace: 1.1 })
  doc.setFontSize(7.5)
  doc.text(eyebrow, M, 54, { charSpace: 1.2 })

  doc.setFontSize(23)
  setText(doc, TONE.white)
  let y = 84
  for (const line of titleLines) {
    doc.text(line, M, y)
    y += 27
  }

  if (subtitle) {
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(10.5)
    setText(doc, [232, 233, 252])
    doc.text(subtitle, M, y + 2)
    y += 22
  }

  // Meta chips: scope + period + generated timestamp.
  const chips = (spec.meta || []).filter((m) => m && m.value)
  if (chips.length) {
    doc.setFontSize(8)
    let cx = M
    const chipY = bandH - 30
    for (const chip of chips) {
      const text = `${pdfSafe(chip.label).toUpperCase()}  ${pdfSafe(chip.value)}`
      const w = doc.getTextWidth(text) + 16
      if (cx + w > PAGE.width - M - 10) break
      setFill(doc, [64, 82, 200])
      doc.roundedRect(cx, chipY, w, 19, 9.5, 9.5, 'F')
      setText(doc, [236, 238, 255])
      doc.text(text, cx + 8, chipY + 12.6)
      cx += w + 8
    }
  }

  return bandH + 28
}

function drawSectionHeading(doc, y, section, first = false) {
  if (!first) {
    setStroke(doc, TONE.outlineSoft)
    doc.setLineWidth(0.7)
    doc.line(M, y - 18, PAGE.width - M, y - 18)
    y += 6
  }
  setFill(doc, TONE.primary)
  doc.rect(M, y - 8, 3.4, 11, 'F')

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(10.5)
  setText(doc, TONE.ink)
  doc.text(pdfSafe(section.title), M + 11, y)

  if (section.hint) {
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(8.5)
    setText(doc, TONE.inkSoft)
    doc.text(pdfSafe(section.hint), M + 11, y + 13)
    return y + 28
  }
  return y + 20
}

function ensureSpace(doc, y, needed) {
  if (y + needed <= PAGE.height - FOOTER) return y
  doc.addPage()
  return TOP
}

function emptyNote(doc, y, text = 'No data for this selection.') {
  doc.setFont('helvetica', 'italic')
  doc.setFontSize(9)
  setText(doc, TONE.inkSoft)
  doc.text(pdfSafe(text), M, y + 4)
  return y + 20
}

function drawBars(doc, y, section) {
  const rows = (section.rows || []).filter(Boolean)
  if (!rows.length) return emptyNote(doc, y, section.emptyLabel)

  const max = Math.max(1, ...rows.map((r) => num(r.value)))
  const barW = contentWidth() - 4

  for (const row of rows) {
    const hintLines = row.hint ? 1 : 0
    const rowH = 30 + hintLines * 12
    y = ensureSpace(doc, y, rowH)

    doc.setFont('helvetica', 'bold')
    doc.setFontSize(9)
    setText(doc, TONE.ink)
    const label = pdfSafe(row.label)
    const display = pdfSafe(row.display ?? thousands(row.value))
    const displayW = doc.getTextWidth(display)
    doc.text(label, M, y, { maxWidth: barW - displayW - 16 })
    doc.text(display, PAGE.width - M, y, { align: 'right' })

    const trackY = y + 7
    setFill(doc, TONE.surfaceLow)
    doc.roundedRect(M, trackY, barW, 6, 3, 3, 'F')

    const pctWidth = (num(row.value) / max) * barW
    if (num(row.value) > 0) {
      setFill(doc, TONE_FILL[row.tone] || TONE.primary)
      doc.roundedRect(M, trackY, Math.max(3, pctWidth), 6, 3, 3, 'F')
    }

    if (row.hint) {
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(8)
      setText(doc, TONE.inkSoft)
      doc.text(pdfSafe(row.hint), M, y + 24, { maxWidth: barW })
    }
    y += rowH
  }
  return y + 4
}

function drawTable(doc, y, section) {
  const head = (section.head || []).map((cell) => pdfSafe(cell))
  const rows = (section.rows || []).map((row) => row.map((cell) => pdfSafe(cell)))
  if (!head.length) return y
  if (!rows.length) return emptyNote(doc, y, section.emptyLabel)

  // autoTable only needs enough room for the header plus a few rows to start;
  // short tables are kept whole instead of leaving an orphaned header row.
  const estimate = 26 + rows.length * 19
  y = ensureSpace(doc, y, Math.min(estimate, 220))

  const align = section.align || []
  const columnStyles = {}
  head.forEach((_, i) => {
    if (align[i]) columnStyles[i] = { halign: align[i] }
  })

  autoTable(doc, {
    startY: y,
    head: [head],
    body: rows,
    margin: { left: M, right: M, top: TOP, bottom: FOOTER },
    theme: 'grid',
    styles: {
      font: 'helvetica',
      fontSize: 8.4,
      cellPadding: { top: 5, right: 6, bottom: 5, left: 6 },
      lineColor: TONE.outlineSoft,
      lineWidth: 0.5,
      textColor: TONE.ink,
      overflow: 'linebreak',
    },
    headStyles: {
      fillColor: TONE.primary,
      textColor: TONE.white,
      fontStyle: 'bold',
      fontSize: 7.6,
      cellPadding: { top: 6, right: 6, bottom: 6, left: 6 },
      lineColor: TONE.primary,
    },
    alternateRowStyles: { fillColor: TONE.background },
    columnStyles,
    rowPageBreak: 'avoid',
    pageBreak: rows.length > 18 ? 'auto' : 'avoid',
  })

  return (doc.lastAutoTable?.finalY || y) + 20
}

function drawTimeline(doc, y, section) {
  const rows = (section.rows || []).filter((r) => r && r.date)
  if (!rows.length) return emptyNote(doc, y, section.emptyLabel)

  const chartH = 104
  const chartW = contentWidth() - 26
  y = ensureSpace(doc, y, chartH + 52)

  const top = y + 6
  const bottom = top + chartH

  // Gridlines at 0 / 50 / 100%.
  doc.setLineWidth(0.5)
  for (const pct of [0, 50, 100]) {
    const gy = bottom - (pct / 100) * chartH
    setStroke(doc, pct === 0 ? TONE.outline : TONE.outlineSoft)
    doc.line(M + 22, gy, M + 22 + chartW, gy)
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(6.5)
    setText(doc, TONE.neutral)
    doc.text(`${pct}`, M + 18, gy + 2.2, { align: 'right' })
  }

  const n = rows.length
  const slot = chartW / n
  const barW = Math.max(2, Math.min(18, slot * 0.62))

  rows.forEach((row, i) => {
    const pct = Math.max(0, Math.min(100, Math.round(num(row.percentage))))
    const h = (pct / 100) * chartH
    const x = M + 22 + slot * i + (slot - barW) / 2
    setFill(doc, TONE_FILL[attendanceTone(pct)] || TONE.primary)
    if (h > 0) doc.roundedRect(x, bottom - h, barW, h, 1.5, 1.5, 'F')
    else doc.rect(x, bottom - 1.5, barW, 1.5, 'F')
  })

  // X labels — at most 8, never closer than 48pt so dates cannot collide.
  const step = Math.max(1, Math.ceil(n / 8))
  const labelled = []
  for (let i = 0; i < n; i += step) labelled.push(i)
  if (!labelled.includes(n - 1)) {
    const last = labelled[labelled.length - 1]
    if (last === undefined || (n - 1 - last) * slot >= 48) labelled.push(n - 1)
  }
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(6.5)
  setText(doc, TONE.inkSoft)
  for (const i of labelled) {
    const x = M + 22 + slot * i + slot / 2
    doc.text(pdfSafe(formatDay(rows[i].date)), x, bottom + 12, { align: 'center' })
  }

  y = bottom + 34

  if (section.summary) {
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(8.4)
    setText(doc, TONE.inkSoft)
    const lines = doc.splitTextToSize(pdfSafe(section.summary), contentWidth())
    for (const line of lines) {
      y = ensureSpace(doc, y, 13)
      doc.text(line, M, y)
      y += 12
    }
  }
  return y + 8
}

function drawNotes(doc, y, section) {
  const items = (section.items || []).filter(Boolean)
  if (!items.length) return y

  doc.setFont('helvetica', 'normal')
  doc.setFontSize(8.6)
  for (const item of items) {
    const lines = doc.splitTextToSize(pdfSafe(item), contentWidth() - 14)
    y = ensureSpace(doc, y, lines.length * 12 + 4)
    setFill(doc, TONE.outline)
    doc.circle(M + 3, y - 3, 1.7, 'F')
    setText(doc, TONE.inkSoft)
    for (const line of lines) {
      y = ensureSpace(doc, y, 12)
      doc.text(line, M + 12, y)
      y += 11.5
    }
    y += 3.5
  }
  return y
}

function drawKpis(doc, y, kpis) {
  const tiles = (kpis || []).filter(Boolean)
  if (!tiles.length) return y

  const gap = 10
  const cols = Math.min(tiles.length, 4) >= 3 ? Math.min(tiles.length, 4) : 2
  const tileW = (contentWidth() - gap * (cols - 1)) / cols
  const tileH = 64

  let i = 0
  while (i < tiles.length) {
    const rowTiles = tiles.slice(i, i + cols)
    y = ensureSpace(doc, y, tileH + gap)
    rowTiles.forEach((tile, c) => {
      const x = M + c * (tileW + gap)
      setFill(doc, TONE.background)
      doc.roundedRect(x, y, tileW, tileH, 8, 8, 'F')
      setFill(doc, TONE_FILL[tile.tone] || TONE.primary)
      doc.roundedRect(x, y, 3.2, tileH, 1.6, 1.6, 'F')

      doc.setFont('helvetica', 'bold')
      doc.setFontSize(7.2)
      setText(doc, TONE.inkSoft)
      doc.text(fit(doc, String(tile.label).toUpperCase(), tileW - 22), x + 12, y + 17, { charSpace: 0.4 })

      doc.setFontSize(17)
      setText(doc, TONE.ink)
      doc.text(fit(doc, tile.value, tileW - 22), x + 12, y + 39)

      if (tile.hint) {
        doc.setFont('helvetica', 'normal')
        doc.setFontSize(7.4)
        setText(doc, TONE.inkSoft)
        doc.text(fit(doc, tile.hint, tileW - 22), x + 12, y + 53)
      }
    })
    y += tileH + gap
    i += cols
  }
  return y + 10
}

function drawRunningHeader(doc, spec, pageNo) {
  doc.setPage(pageNo)
  setFill(doc, TONE.white)
  doc.rect(0, 0, PAGE.width, TOP - 20, 'F')
  setFill(doc, TONE.primary)
  doc.circle(M + 2.5, 26, 2.5, 'F')
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(8)
  setText(doc, TONE.ink)
  doc.text(pdfSafe(spec.title || 'Report'), M + 10, 28.5, { maxWidth: PAGE.width - M * 2 - 90 })
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(7.5)
  setText(doc, TONE.inkSoft)
  doc.text(pdfSafe(spec.eyebrow || '').toUpperCase(), PAGE.width - M, 28.5, { align: 'right' })
  setStroke(doc, TONE.outlineSoft)
  doc.setLineWidth(0.6)
  doc.line(M, 40, PAGE.width - M, 40)
}

function drawFooter(doc, spec, pageNo, pageCount) {
  doc.setPage(pageNo)
  setStroke(doc, TONE.outlineSoft)
  doc.setLineWidth(0.6)
  doc.line(M, PAGE.height - 44, PAGE.width - M, PAGE.height - 44)

  doc.setFont('helvetica', 'normal')
  doc.setFontSize(7.4)
  setText(doc, TONE.neutral)
  const left = [pdfSafe(spec.footerLeft || 'School Connect'), pdfSafe(spec.period || '')]
    .filter(Boolean)
    .join('  ·  ')
  doc.text(left, M, PAGE.height - 30)
  doc.text(`Page ${pageNo} of ${pageCount}`, PAGE.width - M, PAGE.height - 30, { align: 'right' })

  const generated = spec.generatedAt instanceof Date ? spec.generatedAt : new Date(spec.generatedAt || Date.now())
  doc.text(
    `Generated ${pdfSafe(generated.toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' }))}`,
    PAGE.width / 2,
    PAGE.height - 30,
    { align: 'center' },
  )
}

/**
 * Build the PDF document.
 * @param {object} spec see the module docblock
 * @returns {import('jspdf').jsPDF}
 */
export function buildReportPdf(spec = {}) {
  const doc = new jsPDF({ unit: 'pt', format: 'a4', compress: true })
  const generatedAt = spec.generatedAt instanceof Date ? spec.generatedAt : new Date()

  doc.setProperties({
    title: pdfSafe(spec.title || 'Report'),
    subject: pdfSafe(spec.subtitle || ''),
    author: pdfSafe(spec.preparedBy || 'School Connect'),
    creator: 'School Connect',
  })

  let y = drawCover(doc, { ...spec, generatedAt })
  y = drawKpis(doc, y, spec.kpis)

  const sections = (spec.sections || []).filter((s) => s && s.type)
  sections.forEach((section, index) => {
    // Keep a heading together with the first rows of its content.
    const rows = section.rows?.length || 0
    const content =
      section.type === 'table'
        ? Math.min(26 + rows * 19, 200)
        : section.type === 'bars'
          ? Math.min(rows * (section.rows?.some((r) => r?.hint) ? 42 : 30), 220)
          : section.type === 'timeline'
            ? 190
            : 52
    y = ensureSpace(doc, y, 34 + content)
    y = drawSectionHeading(doc, y, section, index === 0)
    if (section.type === 'bars') y = drawBars(doc, y, section)
    else if (section.type === 'table') y = drawTable(doc, y, section)
    else if (section.type === 'timeline') y = drawTimeline(doc, y, section)
    else if (section.type === 'notes') y = drawNotes(doc, y, section)
  })

  const pageCount = doc.getNumberOfPages()
  for (let page = 2; page <= pageCount; page += 1) drawRunningHeader(doc, spec, page)
  for (let page = 1; page <= pageCount; page += 1) drawFooter(doc, spec, page, pageCount)

  return doc
}

/** PDF bytes — used by tests and by non-browser callers. */
export function reportPdfBytes(spec) {
  return new Uint8Array(buildReportPdf(spec).output('arraybuffer'))
}

/** Trigger a browser download. */
export function downloadReportPdf(fileName, spec) {
  const doc = buildReportPdf(spec)
  doc.save(fileName.endsWith('.pdf') ? fileName : `${fileName}.pdf`)
  return doc
}
