/**
 * End-to-end harness for the mobile app endpoints.
 *
 * Drives the real handler registry through handleRequest() exactly the way
 * the HTTP layer does, so routing / session / handler bugs surface here.
 *
 * Usage:
 *   node --experimental-sqlite scripts/e2e-mobile.mjs [teacherEmail] [teacherPwd] [studentEmail]
 */

import { openDatabases, closeDatabases } from '../src/server.js'
import { handleRequest } from '../src/handlers.js'

const TEACHER_EMAIL = process.argv[2] || 'anita.sharma@springfield.edu'
const TEACHER_PWD = process.argv[3] || 'admin123'
const STUDENT_EMAIL = process.argv[4] || 'kunal.singh2@student.edu'

const { sa, su } = openDatabases()
const bothDbs = { sa, su }

let pass = 0
let fail = 0

function call(path, { method = 'GET', params = {}, body = {}, sid = null, role = 'anon' } = {}) {
  try {
    const res = handleRequest('schooladmin', bothDbs, path, {
      method, params, body, headers: {}, ip: '127.0.0.1', sid,
    })
    return { ok: true, data: res.data, sid: res._sid }
  } catch (err) {
    return { ok: false, status: err.status, error: err.message || String(err) }
  }
}

function report(label, res, detail) {
  if (res.ok) {
    pass++
    console.log(`  PASS  ${label}${detail ? ` — ${detail}` : ''}`)
  } else {
    fail++
    console.log(`  FAIL  ${label} — [${res.status}] ${res.error}`)
  }
}

function summarize(value) {
  if (Array.isArray(value)) return `array(${value.length})`
  if (value && typeof value === 'object') return `object{${Object.keys(value).slice(0, 6).join(',')}}`
  return String(value)
}

// ── 1. Teacher login ────────────────────────────────────────────────

console.log(`\n=== TEACHER ${TEACHER_EMAIL} ===`)
const tLogin = call('school_connect.api.mobile.login', {
  method: 'POST', body: { email: TEACHER_EMAIL, password: TEACHER_PWD },
})
report('mobile.login', tLogin, tLogin.ok ? `role=${tLogin.data.role} name=${tLogin.data.name}` : '')
if (!tLogin.ok) {
  console.log('\nCannot continue teacher flow without a session.')
  closeDatabases()
  process.exit(1)
}
const tsid = tLogin.sid

// Endpoints the teacher screens call
const tProfile = call('school_connect.api.mobile.get_profile', { sid: tsid })
report('get_profile', tProfile, tProfile.ok ? summarize(tProfile.data) : '')

const tClasses = call('school_connect.api.mobile.get_teacher_classes', { sid: tsid })
report('get_teacher_classes', tClasses, tClasses.ok ? summarize(tClasses.data) : '')
if (tClasses.ok && Array.isArray(tClasses.data)) {
  tClasses.data.forEach(c => {
    console.log(`        class ${c.id} "${c.name}" students=${c.student_count} course=${c.course_name}`)
  })
}

const tSchedule = call('school_connect.api.mobile.get_teacher_schedule', { sid: tsid })
report('get_teacher_schedule', tSchedule, tSchedule.ok ? summarize(tSchedule.data) : '')

let firstClassId = null
if (tClasses.ok && Array.isArray(tClasses.data) && tClasses.data.length) {
  firstClassId = tClasses.data[0].id
}

if (firstClassId) {
  const tStudents = call('school_connect.api.mobile.get_class_students', {
    sid: tsid, params: { class_id: firstClassId },
  })
  report(`get_class_students(${firstClassId})`, tStudents,
    tStudents.ok && tStudents.data?.students ? `${tStudents.data.students.length} students` : '')
  if (tStudents.ok && tStudents.data?.students?.length === 0) {
    console.log('        WARNING: class returned zero students')
  }

  // Mark attendance for two students
  if (tStudents.ok && tStudents.data?.students?.length) {
    const today = new Date().toISOString().split('T')[0]
    const recs = tStudents.data.students.slice(0, 2).map(s => ({ student_id: s.id, status: 'Present' }))
    const mark = call('school_connect.api.mobile.mark_attendance', {
      method: 'POST', sid: tsid,
      body: { class_id: firstClassId, date: today, course: 'Mathematics', records: recs },
    })
    report('mark_attendance', mark, mark.ok ? summarize(mark.data) : '')

    // Read-back: a saved day must come back from the day roster, or the app
    // shows "nothing saved yet" for a register the teacher just saved.
    const readBack = call('school_connect.api.mobile.get_class_attendance', {
      sid: tsid, params: { class_id: firstClassId, date: today },
    })
    const markedCount = readBack.ok
      ? (readBack.data.roster || []).filter(r => r.status != null).length
      : -1
    if (markedCount >= 2) {
      pass++; console.log(`  PASS  day roster reads back the marks just saved (${markedCount} marked)`)
    } else {
      fail++; console.log(`  FAIL  day roster shows ${markedCount} marked rows after saving ${recs.length}`)
    }

    // Legacy rows: older builds stored a full ISO timestamp as the date. Both
    // the day roster and the range history must still find that calendar day.
    const student = tStudents.data.students[0]
    const legacyId = `att-legacy-${Date.now()}`
    // Use a day that has NO records yet, so a pass can only come from the
    // timestamped row (seed data already covers the recent school days).
    let legacyDay = null
    for (let back = 3; back <= 60 && legacyDay === null; back++) {
      const probe = new Date(Date.now() - back * 864e5).toISOString().split('T')[0]
      const check = call('school_connect.api.mobile.get_class_attendance', {
        sid: tsid, params: { class_id: firstClassId, date: probe },
      })
      const marked = check.ok ? (check.data.roster || []).filter(r => r.status != null).length : -1
      if (marked === 0) legacyDay = probe
    }

    if (legacyDay === null) {
      fail++; console.log('  FAIL  no unmarked day found to plant a legacy timestamped row')
    } else {
      sa.prepare('INSERT INTO attendance_log (id, student_id, class_id, school_id, date, status, recorded_by, course) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
        .run(legacyId, student.id, firstClassId, student.school_id || '', `${legacyDay}T09:15:00.000Z`, 'Absent', 'e2e-legacy', 'E2E')

      const legacyRead = call('school_connect.api.mobile.get_class_attendance', {
        sid: tsid, params: { class_id: firstClassId, date: legacyDay },
      })
      const legacyStatus = legacyRead.ok
        ? (legacyRead.data.roster || []).find(r => r.student === student.id)?.status
        : null
      if (legacyStatus === 'Absent') {
        pass++; console.log(`  PASS  timestamped (legacy) row is found by the day roster (${legacyDay})`)
      } else {
        fail++; console.log(`  FAIL  legacy timestamped row not found by the day roster on ${legacyDay} (status=${legacyStatus})`)
      }

      // What the app falls back to on an un-redeployed backend: the class-wide
      // record list, matched by calendar-day prefix on the client.
      const courseAtt = call('school_connect.api.mobile.get_course_attendance', {
        sid: tsid, params: { schedule_id: firstClassId },
      })
      const legacyRec = courseAtt.ok
        ? (courseAtt.data.students || [])
            .flatMap(s => (s.records || []).map(r => ({ ...r, student: s.student })))
            .find(r => String(r.date || r.student_attendance_date || '').startsWith(legacyDay))
        : null
      if (legacyRec && legacyRec.student === student.id) {
        pass++; console.log('  PASS  class-wide records expose the timestamped day (app fallback match)')
      } else {
        fail++; console.log('  FAIL  class-wide records do not expose the timestamped day')
      }

      const legacyHistory = call('school_connect.api.mobile.get_attendance_history', {
        sid: tsid, params: { class_id: firstClassId, from: legacyDay, to: legacyDay },
      })
      const inHistory = legacyHistory.ok
        ? (legacyHistory.data.records || []).some(r => r.id === legacyId && r.date === legacyDay)
        : false
      if (inHistory) {
        pass++; console.log('  PASS  timestamped row appears in the range history on its calendar day')
      } else {
        fail++; console.log('  FAIL  timestamped row missing from the range history')
      }

      sa.prepare('DELETE FROM attendance_log WHERE id = ?').run(legacyId)
    }

    // A write with no class id must be refused instead of silently landing in a
    // blank class (where the teacher's roster would never find it again).
    const blankClass = call('school_connect.api.mobile.mark_attendance', {
      method: 'POST', sid: tsid,
      body: { class_id: '', date: legacyDay, records: [{ student_id: student.id, status: 'Present' }] },
    })
    if (!blankClass.ok && blankClass.status === 400) {
      pass++; console.log('  PASS  mark_attendance rejects a blank class_id')
    } else {
      fail++; console.log(`  FAIL  mark_attendance accepted a blank class_id (${JSON.stringify(blankClass)})`)
    }

    // …and a student who is not enrolled in the class must be refused too.
    const outsider = call('school_connect.api.mobile.mark_attendance', {
      method: 'POST', sid: tsid,
      body: { class_id: firstClassId, date: legacyDay, records: [{ student_id: 'st-not-in-this-class', status: 'Present' }] },
    })
    if (!outsider.ok && outsider.status === 400) {
      pass++; console.log('  PASS  mark_attendance rejects students outside the class')
    } else {
      fail++; console.log(`  FAIL  mark_attendance accepted an outsider student (${JSON.stringify(outsider)})`)
    }

    // Old APKs post the student's NAME as student_id (their model read the
    // display name out of the row's `name` column). The write must land on the
    // real id anyway — otherwise teachers on an un-updated build are simply
    // locked out of marking, and the mark stays invisible to every read.
    const nameDay = '2024-06-05'
    sa.prepare('DELETE FROM attendance_log WHERE class_id = ? AND date = ?')
      .run(firstClassId, nameDay)
    const byName = call('school_connect.api.mobile.mark_attendance', {
      method: 'POST', sid: tsid,
      body: { class_id: firstClassId, date: nameDay, records: [{ student_id: student.name, status: 'Present' }] },
    })
    const byNameRoster = call('school_connect.api.mobile.get_class_attendance', {
      sid: tsid, params: { class_id: firstClassId, date: nameDay },
    })
    const byNameStatus = byNameRoster.ok
      ? (byNameRoster.data.roster || []).find(r => r.student === student.id)?.status
      : null
    if (byName.ok && byNameStatus === 'Present') {
      pass++; console.log('  PASS  mark_attendance re-keys a legacy name-based student_id to the real id')
    } else {
      fail++; console.log(`  FAIL  name-based student_id not normalized (ok=${byName.ok}, status=${byNameStatus})`)
    }
    sa.prepare('DELETE FROM attendance_log WHERE class_id = ? AND date = ?')
      .run(firstClassId, nameDay)

  }

  // Create an assignment in that class
  const tAssign = call('school_connect.api.mobile.get_teacher_assignments', { sid: tsid })
  report('get_teacher_assignments', tAssign, tAssign.ok ? summarize(tAssign.data) : '')

  const created = call('school_connect.api.mobile.create_assignment', {
    method: 'POST', sid: tsid,
    body: {
      title: 'E2E Test Assignment', course: 'Mathematics', class_id: firstClassId,
      due_date: new Date(Date.now() + 6048e5).toISOString().split('T')[0],
      description: 'Created by the e2e harness.',
    },
  })
  report('create_assignment', created, created.ok ? summarize(created.data) : '')

  if (created.ok && created.data?.id) {
    const subs = call('school_connect.api.mobile.get_assignment_submissions', {
      sid: tsid, params: { assignment_id: created.data.id },
    })
    report('get_assignment_submissions', subs, subs.ok ? summarize(subs.data) : '')

    const upd = call('school_connect.api.mobile.update_assignment', {
      method: 'POST', sid: tsid, body: { id: created.data.id, title: 'E2E Test Assignment (updated)' },
    })
    report('update_assignment', upd, upd.ok ? summarize(upd.data) : '')

    const del = call('school_connect.api.mobile.delete_assignment', {
      method: 'POST', sid: tsid, body: { id: created.data.id },
    })
    report('delete_assignment', del, del.ok ? summarize(del.data) : '')
  }
}

const tTimetable = call('school_connect.api.mobile.get_my_timetable', { sid: tsid })
report('get_my_timetable (teacher)', tTimetable,
  tTimetable.ok ? `${tTimetable.data.timetable?.length} rows, ${tTimetable.data.subjects?.length} subjects` : '')

const tNext = call('school_connect.api.mobile.get_next_class', { sid: tsid })
report('get_next_class (teacher)', tNext, tNext.ok ? `today=${tNext.data.today} count=${tNext.data.class_count_today}` : '')

if (firstClassId) {
  const tClassAtt = call('school_connect.api.mobile.get_class_attendance', {
    sid: tsid, params: { class_id: firstClassId },
  })
  report('get_class_attendance', tClassAtt,
    tClassAtt.ok ? `roster=${tClassAtt.data.roster?.length} summary=${JSON.stringify(tClassAtt.data.summary)}` : '')

  const tCourseAtt = call('school_connect.api.mobile.get_course_attendance', {
    sid: tsid, params: { schedule_id: firstClassId },
  })
  report('get_course_attendance', tCourseAtt,
    tCourseAtt.ok ? `students=${tCourseAtt.data.students?.length} course=${tCourseAtt.data.course_name}` : '')

  const tRoster = call('school_connect.api.mobile.get_class_students', {
    sid: tsid, params: { class_id: firstClassId },
  })
  const firstStudent = tRoster.ok ? tRoster.data?.students?.[0] : null
  if (firstStudent) {
    const tDetail = call('school_connect.api.mobile.get_student_detail', {
      sid: tsid, params: { student_id: firstStudent.id },
    })
    report('get_student_detail', tDetail,
      tDetail.ok ? `${tDetail.data.student_name} attendance=${tDetail.data.overall_attendance}%` : '')
  }
}

// Admin/teacher creating a student should immediately appear to the teacher
if (firstClassId) {
  const newStudent = call('school_connect.api.admin.create_student', {
    method: 'POST', sid: tsid,
    body: {
      name: 'E2E Created Student',
      email: `e2e.student.${Date.now()}@school.com`,
      class_id: firstClassId,
    },
  })
  report('admin.create_student', newStudent,
    newStudent.ok ? `id=${newStudent.data.id} roll=${newStudent.data.roll_number}` : '')

  if (newStudent.ok) {
    const after = call('school_connect.api.mobile.get_class_students', {
      sid: tsid, params: { class_id: firstClassId },
    })
    const visible = after.ok && Array.isArray(after.data?.students)
      && after.data.students.some(s => s.id === newStudent.data.id)
    if (visible) { pass++; console.log('  PASS  new student is visible to the teacher') }
    else { fail++; console.log('  FAIL  new student NOT visible to the teacher') }

    // The new student must be able to sign in (empty password → any password)
    const sLogin2 = call('school_connect.api.mobile.login', {
      method: 'POST', body: { email: newStudent.data.email, password: 'welcome1' },
    })
    report('new student can log in', sLogin2, sLogin2.ok ? `role=${sLogin2.data.role}` : '')

    call('school_connect.api.admin.delete_student', {
      method: 'POST', sid: tsid, body: { id: newStudent.data.id },
    })
  }
}

const tAdminStats = call('school_connect.api.mobile.get_admin_stats', { sid: tsid })
report('get_admin_stats', tAdminStats, tAdminStats.ok ? summarize(tAdminStats.data) : '')

const tSchool = call('school_connect.api.mobile.get_school_profile', { sid: tsid })
report('get_school_profile', tSchool, tSchool.ok ? summarize(tSchool.data) : '')

// ── 2. Student login ────────────────────────────────────────────────

console.log(`\n=== STUDENT ${STUDENT_EMAIL} ===`)
const sLogin = call('school_connect.api.mobile.login', {
  method: 'POST', body: { email: STUDENT_EMAIL, password: 'anything' },
})
report('mobile.login', sLogin, sLogin.ok ? `role=${sLogin.data.role} name=${sLogin.data.name}` : '')
if (sLogin.ok) {
  const ssid = sLogin.sid

  const sSchedule = call('school_connect.api.mobile.get_student_schedule', { sid: ssid })
  report('get_student_schedule', sSchedule, sSchedule.ok ? summarize(sSchedule.data) : '')

  const sTimetable = call('school_connect.api.mobile.get_my_timetable', { sid: ssid })
  report('get_my_timetable (student)', sTimetable,
    sTimetable.ok ? `${sTimetable.data.timetable?.length} rows, ${sTimetable.data.teachers?.length} teachers` : '')

  const sNext = call('school_connect.api.mobile.get_next_class', { sid: ssid })
  report('get_next_class (student)', sNext, sNext.ok ? `today=${sNext.data.today} count=${sNext.data.class_count_today}` : '')

  const sAssign = call('school_connect.api.mobile.get_student_assignments', { sid: ssid })
  report('get_student_assignments', sAssign, sAssign.ok ? summarize(sAssign.data) : '')

  const sAtt = call('school_connect.api.mobile.get_my_attendance', { sid: ssid })
  report('get_my_attendance', sAtt, sAtt.ok ? summarize(sAtt.data) : '')
  if (sAtt.ok) {
    console.log('        summary:', JSON.stringify(sAtt.data?.summary))
  }

  const sProfile = call('school_connect.api.mobile.get_profile', { sid: ssid })
  report('get_profile', sProfile, sProfile.ok ? summarize(sProfile.data) : '')

  // A student with no password on file must keep working on later sign-ins
  // with a different password (the anchor row must not pin the first one).
  const sRelogin = call('school_connect.api.mobile.login', {
    method: 'POST', body: { email: STUDENT_EMAIL, password: 'a completely different password' },
  })
  report('student re-login with a different password', sRelogin,
    sRelogin.ok ? `role=${sRelogin.data.role}` : '')

  if (sAssign.ok && Array.isArray(sAssign.data) && sAssign.data.length) {
    const target = sAssign.data[0]
    const submit = call('school_connect.api.mobile.submit_assignment', {
      method: 'POST', sid: ssid,
      body: { assignment_id: target.id, file_name: 'answer.txt', file_data: Buffer.from('hello').toString('base64') },
    })
    report('submit_assignment', submit, submit.ok ? summarize(submit.data) : '')
  } else {
    console.log('  NOTE  no assignments for this student, skipping submit_assignment')
  }
}

console.log(`\n=== RESULT: ${pass} passed, ${fail} failed ===\n`)
closeDatabases()
process.exit(fail ? 1 : 0)
