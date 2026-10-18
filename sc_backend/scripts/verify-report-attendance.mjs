// Verification for get_admin_attendance — the endpoint behind the School Admin
// report timeline and period exports. Read-only against the dev databases.
// Run: node --experimental-sqlite scripts/verify-report-attendance.mjs
import { openDatabases, closeDatabases } from '../src/server.js'
import { handleRequest } from '../src/handlers.js'

const { sa, su } = openDatabases()
const bothDbs = { sa, su }

let pass = 0
let fail = 0
const check = (name, cond, extra = '') => {
  if (cond) {
    pass++
    console.log(`  PASS  ${name} ${extra}`)
  } else {
    fail++
    console.log(`  FAIL  ${name} ${extra}`)
  }
}

function call(path, { method = 'GET', params = {}, body = {}, sid = null, user = null } = {}) {
  try {
    const res = handleRequest('schooladmin', bothDbs, path, {
      method,
      params,
      body,
      headers: {},
      ip: '127.0.0.1',
      sid,
      user,
    })
    return { ok: true, data: res.data, sid: res._sid }
  } catch (err) {
    return { ok: false, status: err.status, error: err.message || String(err) }
  }
}

const iso = (d) => d.toISOString().split('T')[0]
const today = iso(new Date())
const monthAgo = (() => {
  const d = new Date()
  d.setDate(d.getDate() - 30)
  return iso(d)
})()
const longAgo = (() => {
  const d = new Date()
  d.setDate(d.getDate() - 500)
  return iso(d)
})()

// The dev database may hold either the old seed admin or the console's mock
// admin; both are valid Springfields.
let login = { ok: false }
for (const usr of ['priya@springfield.edu', 'admin@springfield.edu']) {
  login = call('school_connect.api.auth.login', {
    method: 'POST',
    body: { usr, pwd: 'admin123' },
  })
  if (login.ok) break
}
check('school admin login', login.ok && login.data.role === 'School Admin', login.error)
const sid = login.sid

const classes = call('school_connect.api.admin.get_admin_classes', { sid, params: { school: 'springfield' } })
const classIds = new Set((classes.data || []).map((c) => c.id))
check('classes load', classIds.size > 0, `(${classIds.size})`)

// ── Whole-school month range ─────────────────────────────────────────
const month = call('school_connect.api.admin.get_admin_attendance', {
  sid,
  params: { school: 'springfield', from: monthAgo, to: today },
})
check('attendance: request ok', month.ok, month.error)
check('attendance: echoes range', month.data?.from === monthAgo && month.data?.to === today)
check('attendance: days array', Array.isArray(month.data?.days), `(${month.data?.days?.length} days)`)
check('attendance: classes array', Array.isArray(month.data?.classes), `(${month.data?.classes?.length})`)
check('attendance: students array', Array.isArray(month.data?.students), `(${month.data?.students?.length})`)
check('attendance: totals shape', typeof month.data?.totals?.percentage === 'number', JSON.stringify(month.data?.totals))

const days = month.data?.days || []
const sorted = days.every((d, i) => i === 0 || days[i - 1].date < d.date)
check('attendance: days are ascending and unique', sorted)
check('attendance: every day is inside the range', days.every((d) => d.date >= monthAgo && d.date <= today))
check('attendance: day percentages are 0-100', days.every((d) => d.percentage >= 0 && d.percentage <= 100))
check(
  'attendance: day totals add up',
  days.every((d) => d.present + d.absent === d.total && d.present <= d.total),
)

const idList = [...classIds]
const raw = sa
  .prepare(
    `SELECT COUNT(*) AS n, SUM(status = 'Present') AS p FROM attendance_log WHERE class_id IN (${idList
      .map(() => '?')
      .join(', ')}) AND date >= ? AND date <= ?`,
  )
  .get(...idList, monthAgo, today)
check(
  'attendance: totals match the raw register',
  Number(month.data?.totals?.total) === Number(raw.n),
  `(api ${month.data?.totals?.total} vs db ${raw.n})`,
)

check(
  'attendance: classes only cover this school',
  (month.data?.classes || []).every((c) => classIds.has(c.class_id)),
)
check(
  'attendance: student totals are internally consistent',
  (month.data?.students || []).every((s) => s.present >= 0 && s.present <= s.total),
)

// ── Single-class scope ───────────────────────────────────────────────
const oneId = [...classIds][0]
const one = call('school_connect.api.admin.get_admin_attendance', {
  sid,
  params: { school: 'springfield', classes: oneId, from: monthAgo, to: today },
})
check('attendance: class filter returns one class', one.data?.classes?.length === 1, one.data?.classes?.[0]?.name)
check(
  'attendance: filtered totals are a subset',
  Number(one.data?.totals?.total) <= Number(month.data?.totals?.total) &&
    Number(one.data?.totals?.total) > 0,
  `(${one.data?.totals?.total})`,
)

// ── Empty range / validation ─────────────────────────────────────────
const future = call('school_connect.api.admin.get_admin_attendance', {
  sid,
  params: { from: '2099-01-01', to: '2099-01-31' },
})
check('attendance: empty range returns zeros', future.ok && future.data.totals.total === 0 && future.data.days.length === 0)

const reversed = call('school_connect.api.admin.get_admin_attendance', {
  sid,
  params: { from: today, to: monthAgo },
})
check('attendance: reversed range is rejected', !reversed.ok && reversed.status === 400, reversed.error)

const tooLong = call('school_connect.api.admin.get_admin_attendance', {
  sid,
  params: { from: longAgo, to: today },
})
check('attendance: ranges longer than 366 days are rejected', !tooLong.ok && tooLong.status === 400, tooLong.error)

const anonymous = call('school_connect.api.admin.get_admin_attendance', {
  params: { school: 'springfield', from: monthAgo, to: today },
})
check('attendance: anonymous request is rejected', !anonymous.ok, anonymous.ok ? 'returned data' : anonymous.error)

closeDatabases()
console.log(`\n${pass} passed, ${fail} failed`)
process.exit(fail === 0 ? 0 : 1)
