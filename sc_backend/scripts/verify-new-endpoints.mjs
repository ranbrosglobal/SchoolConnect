// Quick verification of the new endpoints: get_attendance_history +
// mobile change_password (student + teacher). Read-only against the real
// dev databases except for the temp password change, which is reverted.
// Run: node --experimental-sqlite scripts/verify-new-endpoints.mjs
import { openDatabases, closeDatabases } from '../src/server.js'
import { handleRequest } from '../src/handlers.js'

const { sa, su } = openDatabases()
const bothDbs = { sa, su }

let pass = 0
let fail = 0
const check = (name, cond, extra = '') => {
  if (cond) { pass++; console.log(`  PASS  ${name} ${extra}`) }
  else { fail++; console.log(`  FAIL  ${name} ${extra}`) }
}

function call(path, { method = 'GET', params = {}, body = {}, sid = null } = {}) {
  try {
    const res = handleRequest('schooladmin', bothDbs, path, {
      method, params, body, headers: {}, ip: '127.0.0.1', sid,
    })
    return { ok: true, data: res.data, sid: res._sid }
  } catch (err) {
    return { ok: false, status: err.status, error: err.message || String(err) }
  }
}

const iso = d => d.toISOString().split('T')[0]
const today = iso(new Date())
const monthAgo = (() => { const d = new Date(); d.setDate(d.getDate() - 30); return iso(d) })()

// ── Teacher login ────────────────────────────────────────────────────
const teacherLogin = call('school_connect.api.mobile.login', {
  method: 'POST',
  body: { email: 'anita.sharma@springfield.edu', password: 'admin123' },
})
check('teacher login', teacherLogin.ok && teacherLogin.data.role === 'Teacher', teacherLogin.data?.role)
const tSid = teacherLogin.sid

const classes = call('school_connect.api.mobile.get_teacher_classes', { sid: tSid })
const cls = classes.data[0]
check('teacher has classes', Array.isArray(classes.data) && classes.data.length > 0, `(${classes.data.length})`)

// ── Attendance history: month range ─────────────────────────────────
const history = call('school_connect.api.mobile.get_attendance_history', {
  sid: tSid,
  params: { class_id: cls.id, from: monthAgo, to: today },
})
check('history: request ok', history.ok, history.error)
check('history: class_name', history.data?.class_name === cls.name, history.data?.class_name)
check('history: from/to echoed', history.data?.from === monthAgo && history.data?.to === today)
check('history: summary shape', typeof history.data?.summary?.percentage === 'number')
check('history: days array', Array.isArray(history.data?.days), `(${history.data?.days?.length} days)`)
check('history: students array', Array.isArray(history.data?.students))
check('history: records array', Array.isArray(history.data?.records), `(${history.data?.records?.length} records)`)
console.log(`        summary: ${JSON.stringify(history.data?.summary)}`)

// History should match get_class_attendance for a single day
const todayRoster = call('school_connect.api.mobile.get_class_attendance', {
  sid: tSid, params: { class_id: cls.id, date: today },
})
const todayHist = call('school_connect.api.mobile.get_attendance_history', {
  sid: tSid, params: { class_id: cls.id, from: today, to: today },
})
const markedToday = todayRoster.data.roster.filter(r => r.status != null).length
check('history single-day consistency',
  todayHist.data.records.length === markedToday,
  `hist=${todayHist.data.records.length} roster=${markedToday}`)

// Validation guard
const badRange = call('school_connect.api.mobile.get_attendance_history', {
  sid: tSid, params: { class_id: cls.id, from: 'garbage', to: today },
})
check('history rejects bad range', !badRange.ok && badRange.status === 400)

// Access control: students cannot call it
const studentLogin = call('school_connect.api.mobile.login', {
  method: 'POST',
  body: { email: 'kunal.singh2@student.edu', password: 'student123' },
})
const studentBlocked = call('school_connect.api.mobile.get_attendance_history', {
  sid: studentLogin.sid, params: { class_id: cls.id, from: monthAgo, to: today },
})
check('history blocks students', !studentBlocked.ok && studentBlocked.status === 403)

// ── Change password: teacher ────────────────────────────────────────
const wrongPw = call('school_connect.api.mobile.change_password', {
  method: 'POST', sid: tSid,
  body: { current_password: 'wrong-password', new_password: 'newpass123' },
})
check('teacher change pw rejects wrong current', !wrongPw.ok && wrongPw.status === 400)

const changed = call('school_connect.api.mobile.change_password', {
  method: 'POST', sid: tSid,
  body: { current_password: 'admin123', new_password: 'admin1234' },
})
check('teacher change pw works', changed.ok, changed.error)

const reLogin = call('school_connect.api.mobile.login', {
  method: 'POST',
  body: { email: 'anita.sharma@springfield.edu', password: 'admin1234' },
})
check('teacher re-login with new pw', reLogin.ok && reLogin.data.role === 'Teacher')

const reverted = call('school_connect.api.mobile.change_password', {
  method: 'POST', sid: reLogin.sid,
  body: { current_password: 'admin1234', new_password: 'admin123' },
})
check('teacher pw reverted', reverted.ok)

// ── Change password: student (users + students tables) ──────────────
const sChanged = call('school_connect.api.mobile.change_password', {
  method: 'POST', sid: studentLogin.sid,
  body: { current_password: 'student123', new_password: 'student456' },
})
check('student change pw works', sChanged.ok, sChanged.error)

const sReLogin = call('school_connect.api.mobile.login', {
  method: 'POST',
  body: { email: 'kunal.singh2@student.edu', password: 'student456' },
})
check('student re-login with new pw', sReLogin.ok && sReLogin.data.role === 'Student')

const oldPw = call('school_connect.api.mobile.login', {
  method: 'POST',
  body: { email: 'kunal.singh2@student.edu', password: 'student123' },
})
check('student old pw rejected', !oldPw.ok && oldPw.status === 401)

const sRevert = call('school_connect.api.mobile.change_password', {
  method: 'POST', sid: sReLogin.sid,
  body: { current_password: 'student456', new_password: 'student123' },
})
check('student pw reverted', sRevert.ok)

// This test's change leaves a real hash behind, but this dev account's
// original state is an EMPTY password (any-password accepted). Restore it so
// other harnesses (e2e-mobile.mjs) keep their 'any password' assumptions.
sa.prepare("UPDATE students SET password = '' WHERE email = 'kunal.singh2@student.edu'").run()
sa.prepare("UPDATE users SET password = '' WHERE email = 'kunal.singh2@student.edu'").run()

closeDatabases({ sa, su })
console.log(`\n=== RESULT: ${pass} passed, ${fail} failed ===`)
process.exit(fail ? 1 : 0)
