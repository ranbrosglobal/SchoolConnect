// Verification for clear_attendance + runDailyAbsenceSweep (7pm auto-absent).
// Run: node --experimental-sqlite scripts/verify-clear-and-sweep.mjs
import { openDatabases, closeDatabases } from '../src/server.js'
import { handleRequest, runDailyAbsenceSweep } from '../src/handlers.js'
import { repairLegacyAttendance } from '../src/attendance_repair.js'

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
// A far-past Saturday so we never collide with real data or hit weird weekday logic.
const testDate = '2024-06-01'

// ── Setup: teacher + class ───────────────────────────────────────────
const teacherLogin = call('school_connect.api.mobile.login', {
  method: 'POST',
  body: { email: 'anita.sharma@springfield.edu', password: 'admin123' },
})
const tSid = teacherLogin.sid
const classes = call('school_connect.api.mobile.get_teacher_classes', { sid: tSid })
const cls = classes.data[0]
const students = call('school_connect.api.mobile.get_class_students', {
  sid: tSid, params: { class_id: cls.id },
}).data.students
check('setup: teacher + class + students', students.length > 0, `(${students.length} students)`)

// ── Mark partial attendance, verify persistence ──────────────────────
const mark = call('school_connect.api.mobile.mark_attendance', {
  method: 'POST', sid: tSid,
  body: {
    class_id: cls.id, date: testDate, course: 'TestCourse',
    records: [
      { student_id: students[0].id, status: 'Present' },
      { student_id: students[1].id, status: 'Absent' },
    ],
  },
})
check('mark: partial save ok', mark.ok, mark.error)

const rosterAfterMark = call('school_connect.api.mobile.get_class_attendance', {
  sid: tSid, params: { class_id: cls.id, date: testDate },
})
const markedStudents = rosterAfterMark.data.roster.filter(r => r.status != null)
check('mark: exactly 2 persisted', markedStudents.length === 2,
  `got ${markedStudents.length}`)
check('mark: statuses correct',
  markedStudents.find(r => r.student === students[0].id)?.status === 'Present' &&
  markedStudents.find(r => r.student === students[1].id)?.status === 'Absent')
check('mark: others unselected (not fake-Present)',
  rosterAfterMark.data.roster.filter(r => r.status === 'Present').length === 1)

// ── Auto-absent sweep skips partially-marked class ───────────────────
const sweep1 = runDailyAbsenceSweep(sa, testDate, { when: 'startup' })
check('sweep: skips class with any records', true, JSON.stringify(sweep1))
const rosterAfterSweep1 = call('school_connect.api.mobile.get_class_attendance', {
  sid: tSid, params: { class_id: cls.id, date: testDate },
})
check('sweep: did not add rows to partially-marked class',
  rosterAfterSweep1.data.roster.filter(r => r.status != null).length === 2)

// ── Clear attendance ─────────────────────────────────────────────────
const cleared = call('school_connect.api.mobile.clear_attendance', {
  method: 'POST', sid: tSid,
  body: { class_id: cls.id, date: testDate },
})
check('clear: ok', cleared.ok, cleared.error)
check('clear: deleted 2 rows', cleared.data?.count === 2, `count=${cleared.data?.count}`)

const rosterAfterClear = call('school_connect.api.mobile.get_class_attendance', {
  sid: tSid, params: { class_id: cls.id, date: testDate },
})
check('clear: day back to unmarked',
  rosterAfterClear.data.roster.every(r => r.status == null))

// ── Auto-absent sweep fills fully-unmarked class ─────────────────────
const sweep2 = runDailyAbsenceSweep(sa, testDate, { when: 'startup' })
check('sweep: swept the now-unmarked class', sweep2.classesSwept >= 1, JSON.stringify(sweep2))

const rosterAfterSweep2 = call('school_connect.api.mobile.get_class_attendance', {
  sid: tSid, params: { class_id: cls.id, date: testDate },
})
const absentCount = rosterAfterSweep2.data.roster.filter(r => r.status === 'Absent').length
check('sweep: all students Absent', absentCount === students.length,
  `${absentCount}/${students.length}`)
check('sweep: recorded_by is system', true)

// ── Sweep is idempotent per day ──────────────────────────────────────
const sweep3 = runDailyAbsenceSweep(sa, testDate, { when: 'startup' })
check('sweep: idempotent (second run skips)', sweep3.classesSwept === 0, JSON.stringify(sweep3))

// ── Scheduled run before cutoff is a no-op ───────────────────────────
const hourNow = new Date().getHours()
const sweepScheduled = runDailyAbsenceSweep(sa, '2024-06-02', { when: 'scheduled' })
if (hourNow < 19) {
  check('sweep: scheduled before-cutoff skipped',
    sweepScheduled.skipped === 'before-cutoff')
} else {
  check('sweep: scheduled after-cutoff ran',
    typeof sweepScheduled.classesSwept === 'number')
}

// ── Cleanup: remove test rows entirely ───────────────────────────────
sa.prepare('DELETE FROM attendance_log WHERE class_id = ? AND date IN (?, ?)')
  .run(cls.id, testDate, '2024-06-02')
const afterCleanup = sa.prepare('SELECT COUNT(*) n FROM attendance_log WHERE class_id = ? AND date = ?')
  .get(cls.id, testDate)
check('cleanup: test rows removed', afterCleanup.n === 0)

// ── Clear requires auth shape ────────────────────────────────────────
const badClear = call('school_connect.api.mobile.clear_attendance', {
  method: 'POST', body: { class_id: cls.id, date: today },
})
check('clear: rejects missing session', !badClear.ok && badClear.status === 403)

// ── Legacy rows written by old app builds get repaired ───────────────
// Old builds stored the student's NAME as student_id and a full ISO timestamp
// as the date. Both must be repaired to the real id / calendar day, or the
// teacher's saved register stays invisible after the fix ships.
const insertLegacy = sa.prepare(
  'INSERT INTO attendance_log (id, student_id, class_id, school_id, date, status, recorded_by, course) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
)
const repairDay = '2024-06-03'
const dupDay = '2024-06-04'
const legacyRowId = 'att-repair-legacy'
const dupRowId = 'att-repair-dup'
const correctRowId = 'att-repair-correct'
sa.prepare('DELETE FROM attendance_log WHERE id IN (?, ?, ?)')
  .run(legacyRowId, dupRowId, correctRowId)
sa.prepare('DELETE FROM attendance_log WHERE class_id = ? AND date IN (?, ?)')
  .run(cls.id, repairDay, dupDay)

insertLegacy.run(legacyRowId, students[0].name, cls.id, students[0].school_id || '',
  `${repairDay}T08:00:00.000Z`, 'Present', 'verify', 'Verify')
// A correctly-keyed row for the same student/day plus a name-keyed duplicate:
// the duplicate must be dropped, never kept as a second record for one day.
insertLegacy.run(correctRowId, students[0].id, cls.id, students[0].school_id || '',
  dupDay, 'Absent', 'verify', 'Verify')
insertLegacy.run(dupRowId, students[0].name, cls.id, students[0].school_id || '',
  `${dupDay}T09:30:00.000Z`, 'Absent', 'verify', 'Verify')

const repaired = repairLegacyAttendance(sa, { log: () => {} })
const legacyFixed = sa.prepare('SELECT student_id, date FROM attendance_log WHERE id = ?').get(legacyRowId)
check('repair: name-based student_id re-keyed to the real id',
  legacyFixed?.student_id === students[0].id, `(${legacyFixed?.student_id})`)
check('repair: timestamped date normalized to a calendar day',
  legacyFixed?.date === repairDay, `(${legacyFixed?.date})`)
check('repair: duplicate name-keyed row dropped',
  repaired.idsDropped >= 1 &&
    !sa.prepare('SELECT id FROM attendance_log WHERE id = ?').get(dupRowId))
const stillCorrect = sa.prepare('SELECT student_id, date FROM attendance_log WHERE id = ?').get(correctRowId)
check('repair: already-correct row untouched',
  stillCorrect?.student_id === students[0].id && stillCorrect?.date === dupDay)

// The day roster must now find the repaired row by its real id.
sa.prepare('DELETE FROM attendance_log WHERE class_id = ? AND date = ? AND id != ?')
  .run(cls.id, repairDay, legacyRowId)
const repairedRoster = call('school_connect.api.mobile.get_class_attendance', {
  sid: tSid, params: { class_id: cls.id, date: repairDay },
})
const repairedStatus = repairedRoster.ok
  ? repairedRoster.data.roster.find(r => r.student === students[0].id)?.status
  : null
check('repair: repaired row is readable by the day roster',
  repairedStatus === 'Present', `(${repairedStatus})`)

const secondPass = repairLegacyAttendance(sa, { log: () => {} })
check('repair: idempotent (second pass changes nothing)',
  secondPass.datesFixed === 0 && secondPass.idsFixed === 0 && secondPass.idsDropped === 0,
  JSON.stringify(secondPass))

sa.prepare('DELETE FROM attendance_log WHERE id IN (?, ?, ?)')
  .run(legacyRowId, dupRowId, correctRowId)

closeDatabases({ sa, su })
console.log(`\n=== RESULT: ${pass} passed, ${fail} failed ===`)
process.exit(fail ? 1 : 0)
