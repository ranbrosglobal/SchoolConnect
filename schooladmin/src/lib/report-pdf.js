/**
 * School Admin executive report → PDF.
 *
 * Turns the report model built by reports.js into the declarative spec the
 * shared PDF engine renders: cover, KPI tiles, attendance bars, the daily
 * timeline, scorecards, class rosters and notes.
 */

import { buildReportPdf, downloadReportPdf, formatDay, thousands } from '../../../shared/report-pdf.js'
import { LOW_ATTENDANCE, rankClasses, timelineSummary } from './reports.js'

const pct = (value) => `${value}%`

function healthFor(cls) {
  if (!cls.recordedCount) return 'No data'
  if (cls.attendanceAvg >= 85) return 'Strong'
  if (cls.attendanceAvg >= LOW_ATTENDANCE) return 'Watch'
  return 'At risk'
}

function studentAttendance(student) {
  if (student.range_total !== undefined) {
    return student.range_total > 0 ? `${student.attendance_pct}%` : 'Not recorded'
  }
  return Number(student.attendance_pct) > 0 ? `${student.attendance_pct}%` : 'Not recorded'
}

function studentSessions(student) {
  if (student.range_total === undefined) return '—'
  return student.range_total > 0 ? `${student.range_present}/${student.range_total}` : '0'
}

/**
 * @param {ReturnType<typeof import('./reports.js').buildSchoolReport>} report
 * @param {{ schoolName?: string, scopeLabel?: string, periodLabel?: string, preparedBy?: string, rosters?: object[] }} meta
 */
export function buildSchoolPdfSpec(report, meta = {}) {
  const t = report.totals
  const generatedAt = report.generatedAt instanceof Date ? report.generatedAt : new Date()
  const period = report.range?.period || meta.periodLabel || 'All time'
  const inRange = Boolean(report.range?.from && report.timeline)
  const timeline = inRange ? report.timeline : []

  const kpis = [
    {
      label: 'Students',
      value: thousands(t.students),
      hint: `${t.activeStudents} active · ${t.studentsPerClass} per class`,
      tone: 'blue',
    },
    {
      label: 'Teachers',
      value: thousands(t.teachers),
      hint: `${t.activeTeachers} active · ${t.studentsPerTeacher} per teacher`,
      tone: 'green',
    },
    {
      label: 'Classes',
      value: thousands(t.classes),
      hint: `${t.programs} ${t.programs === 1 ? 'program' : 'programs'}`,
      tone: 'amber',
    },
    {
      label: 'Avg attendance',
      value: t.recordedCount ? pct(t.attendanceAvg) : '—',
      hint: `${t.recordedCount}/${t.students} students recorded`,
      tone: 'indigo',
    },
  ]

  const glance = [
    ['Students', thousands(t.students)],
    ['Active students', thousands(t.activeStudents)],
    ['Teachers', thousands(t.teachers)],
    ['Active teachers', thousands(t.activeTeachers)],
    ['Classes', thousands(t.classes)],
    ['Programs', thousands(t.programs)],
    ['Average attendance (%)', t.recordedCount ? pct(t.attendanceAvg) : '—'],
    ['Attendance coverage (%)', pct(t.attendanceCoverage)],
    ['Students per class', t.studentsPerClass],
    ['Students per teacher', t.studentsPerTeacher],
  ]

  if (inRange) {
    glance.push(
      ['Attendance in period (%)', pct(timeline.length ? timelineRate(timeline) : 0)],
      ['Recorded school days', thousands(timeline.length)],
    )
  }

  const sections = [
    {
      type: 'table',
      title: 'At a glance',
      hint: `Figures for ${meta.scopeLabel || 'the full school'} · ${period}`,
      head: ['Metric', 'Value'],
      rows: glance,
      align: ['left', 'right'],
    },
    {
      type: 'bars',
      title: 'Attendance distribution',
      hint: inRange
        ? 'Students grouped by their attendance inside the selected period'
        : 'Students grouped by cumulative attendance percentage',
      rows: report.attendance.map((b) => ({
        label: b.label,
        value: b.count,
        display: `${thousands(b.count)} · ${b.share}%`,
        tone: b.tone,
        hint:
          b.key === 'unrecorded'
            ? 'No attendance recorded for these students'
            : `${b.count} of ${t.students} students`,
      })),
      emptyLabel: 'No students in this selection.',
    },
  ]

  if (inRange) {
    sections.push({
      type: 'timeline',
      title: 'Daily attendance',
      hint: `Rate for each recorded day (${formatDay(timeline[0]?.date)} – ${formatDay(
        timeline[timeline.length - 1]?.date,
      )})`,
      rows: timeline,
      summary: timelineSummary({ totals: periodTotals(timeline) }),
      emptyLabel: 'No attendance was recorded in this period.',
    })
  }

  sections.push(
    {
      type: 'table',
      title: 'Class scorecard',
      hint: 'Ranked by recorded attendance',
      head: ['Class', 'Program', 'Students', 'Teachers', 'Attendance', 'Health'],
      rows: rankClasses(report.byClass).map((c) => [
        c.name,
        c.program || '—',
        c.studentCount,
        c.teachers.length,
        c.recordedCount ? pct(c.attendanceAvg) : '—',
        healthFor(c),
      ]),
      align: ['left', 'left', 'right', 'right', 'right', 'right'],
      emptyLabel: 'No classes with students yet.',
    },
    {
      type: 'table',
      title: 'Enrolment by program',
      hint: 'Classes, students and attendance grouped by program',
      head: ['Program', 'Classes', 'Students', 'Attendance'],
      rows: report.byProgram.map((p) => [p.name, p.classes, p.studentCount, pct(p.attendanceAvg)]),
      align: ['left', 'right', 'right', 'right'],
      emptyLabel: 'No programs yet.',
    },
    {
      type: 'table',
      title: 'Teacher workload',
      hint: 'Classes and students each teacher is responsible for',
      head: ['Teacher', 'Subjects', 'Classes', 'Students', 'Attendance', 'Status'],
      rows: report.teacherWorkload.map((teach) => [
        teach.name,
        teach.subjects.join(', ') || '—',
        teach.classCount,
        teach.studentCount,
        teach.recordedCount ? pct(teach.attendanceAvg) : '—',
        teach.status,
      ]),
      align: ['left', 'left', 'right', 'right', 'right', 'left'],
      emptyLabel: 'No teachers yet.',
    },
  )

  if (report.needsAttention.length) {
    sections.push({
      type: 'table',
      title: 'Needs attention',
      hint: 'Gaps the school admin should act on',
      head: ['Area', 'Items', 'What it means'],
      rows: report.needsAttention.map((g) => [g.label, g.count, g.detail]),
      align: ['left', 'right', 'left'],
    })
  }

  const rosters = meta.rosters || []
  rosters.forEach((cls) => {
    const head = inRange
      ? ['Roll', 'Student', 'Sessions', 'Attendance', 'Status']
      : ['Roll', 'Student', 'Attendance', 'Status']
    const rows = cls.students.map((s) =>
      inRange
        ? [s.roll_number ?? '—', s.name, studentSessions(s), studentAttendance(s), s.status || 'Active']
        : [s.roll_number ?? '—', s.name, studentAttendance(s), s.status || 'Active'],
    )
    sections.push({
      type: 'table',
      title: `${cls.name} — register`,
      hint: [cls.program, cls.room, cls.teachers.join(', ')].filter(Boolean).join(' · '),
      head,
      rows,
      align: inRange ? ['right', 'left', 'right', 'right', 'left'] : ['right', 'left', 'right', 'left'],
      emptyLabel: 'This class has no students yet.',
    })
  })

  const notes = []
  if (inRange) {
    notes.push(
      `Attendance covers ${period} and is calculated from the daily register submitted by teachers (${timeline.length} recorded ${
        timeline.length === 1 ? 'day' : 'days'
      }).`,
    )
    notes.push(
      'Days on which a class was never marked are closed as absent by the automatic end-of-day sweep, so they are included in the figures above.',
    )
  } else {
    notes.push('Attendance is the cumulative percentage stored on each student record.')
  }
  if (t.recordedCount < t.students) {
    notes.push(
      `${t.students - t.recordedCount} of ${t.students} students in this selection have no attendance recorded; they are listed as "Not recorded" instead of 0%.`,
    )
  }
  notes.push(
    `Prepared for ${meta.schoolName || 'the school'}${meta.preparedBy ? ` by ${meta.preparedBy}` : ''} on ${generatedAt.toLocaleString(
      'en-GB',
      { dateStyle: 'medium', timeStyle: 'short' },
    )}.`,
  )

  sections.push({ type: 'notes', title: 'Notes', items: notes })

  return {
    eyebrow: 'Executive report',
    title: meta.schoolName || 'School report',
    subtitle: 'Attendance, enrolment and staffing',
    meta: [
      { label: 'Scope', value: meta.scopeLabel || 'Full school' },
      { label: 'Period', value: period },
      { label: 'Students', value: thousands(t.students) },
    ],
    kpis,
    sections,
    generatedAt,
    preparedBy: meta.preparedBy || '',
    footerLeft: 'School Connect · Executive report',
    period,
  }
}

function timelineRate(rows) {
  const present = rows.reduce((a, d) => a + d.present, 0)
  const total = rows.reduce((a, d) => a + d.total, 0)
  return total ? Math.round((present / total) * 100) : 0
}

function periodTotals(rows) {
  return {
    present: rows.reduce((a, d) => a + d.present, 0),
    absent: rows.reduce((a, d) => a + d.absent, 0),
    total: rows.reduce((a, d) => a + d.total, 0),
    percentage: timelineRate(rows),
    sessions: rows.length,
  }
}

/** Build the document (tests + previews). */
export function buildSchoolReportPdf(report, meta = {}) {
  return buildReportPdf(buildSchoolPdfSpec(report, meta))
}

/** Build and download the PDF in the browser. */
export function downloadSchoolReportPdf(fileName, report, meta = {}) {
  return downloadReportPdf(fileName, buildSchoolPdfSpec(report, meta))
}
