/**
 * Legacy-attendance care: repairing rows that older app builds wrote wrong,
 * and resolving the identifiers those builds used.
 *
 * Two real defects shipped in past builds and both made a saved register look
 * unsaved on the teacher's screen:
 *
 *  1. `date` was posted as a full ISO timestamp (`2026-10-07T14:30:00.000Z`)
 *     instead of a calendar day, so a `date = '2026-10-07'` read never matched.
 *  2. `student_id` was posted as the student's NAME. The app's model read the
 *     `name` column (the human name) as the id, so every mark landed under a
 *     key no roster or history query could ever read back.
 *
 * The app is fixed, but old rows exist in every deployed database — and old
 * APKs still in the field keep sending names. So: normalize on write, repair
 * historical rows on startup, and keep both operations idempotent.
 */

/** Day part of an attendance date (YYYY-MM-DD). */
export function dayKey(value) {
  return String(value || '').split('T')[0]
}

/** Case/space-insensitive form of a student name, for matching. */
export function normalizeName(value) {
  return String(value || '').trim().toLowerCase().replace(/\s+/g, ' ')
}

/**
 * Map normalized student name → student id for a class roster.
 * Duplicate names inside one class are ambiguous, so they are dropped rather
 * than mapped to a guess (marking the wrong child is worse than a rejection).
 */
export function idByName(students) {
  const map = new Map()
  for (const s of students) {
    const key = normalizeName(s.name)
    if (!key) continue
    map.set(key, map.has(key) ? null : s.id)
  }
  for (const [key, id] of [...map]) if (id === null) map.delete(key)
  return map
}

/**
 * Repair attendance rows written by older app builds. Idempotent: rows that
 * are already correct are left untouched, so this is safe to run on every boot.
 *
 *  - timestamps → calendar days
 *  - student NAME → real student id (matched inside the row's class first,
 *    then school-wide when the name is unique there)
 *  - a repaired row that duplicates an already-correct row for the same
 *    student/class/day is removed instead of becoming a second record
 *
 * @returns {{datesFixed:number, idsFixed:number, idsDropped:number, unresolved:number}}
 */
export function repairLegacyAttendance(db, { log = console.log } = {}) {
  const datesFixed = repairDates(db)
  const { idsFixed, idsDropped, unresolved } = repairStudentIds(db)

  if (datesFixed || idsFixed || idsDropped) {
    log(
      `[attendance] Repaired legacy rows: ${datesFixed} date(s) normalized, ` +
        `${idsFixed} student id(s) re-keyed, ${idsDropped} duplicate(s) removed.`
    )
  } else {
    log('[attendance] Legacy check: all rows already store a calendar day and a real student id.')
  }
  if (unresolved) {
    log(`[attendance] ${unresolved} row(s) reference a student id that matches no student; left untouched.`)
  }
  return { datesFixed, idsFixed, idsDropped, unresolved }
}

function repairDates(db) {
  const legacy = db.prepare('SELECT id, date FROM attendance_log WHERE length(date) > 10').all()
  const upd = db.prepare('UPDATE attendance_log SET date = ? WHERE id = ?')
  for (const row of legacy) upd.run(dayKey(row.date), row.id)
  return legacy.length
}

function repairStudentIds(db) {
  const students = db.prepare('SELECT id, name, class_id, school_id FROM students').all()
  const knownIds = new Set(students.map(s => s.id))
  const byClass = new Map()
  const bySchool = new Map()
  const byGlobal = new Map()
  const bump = (map, key, id) => map.set(key, map.has(key) ? null : id)
  for (const s of students) {
    const key = normalizeName(s.name)
    if (!key) continue
    bump(byClass, `${s.class_id || ''}\u0000${key}`, s.id)
    bump(bySchool, `${s.school_id || ''}\u0000${key}`, s.id)
    bump(byGlobal, key, s.id)
  }
  for (const map of [byClass, bySchool, byGlobal]) {
    for (const [key, id] of [...map]) if (id === null) map.delete(key)
  }

  const rows = db.prepare('SELECT id, student_id, class_id, school_id, date FROM attendance_log').all()
  // Existing correct keys, so a re-keyed row can be dropped instead of
  // doubling the student's records for that day.
  const taken = new Set(
    rows
      .filter(r => knownIds.has(r.student_id))
      .map(r => `${r.class_id || ''}\u0000${r.student_id}\u0000${dayKey(r.date)}`)
  )

  const upd = db.prepare('UPDATE attendance_log SET student_id = ? WHERE id = ?')
  const del = db.prepare('DELETE FROM attendance_log WHERE id = ?')
  let idsFixed = 0
  let idsDropped = 0
  let unresolved = 0

  for (const row of rows) {
    if (knownIds.has(row.student_id)) continue
    const key = normalizeName(row.student_id)
    let target = byClass.get(`${row.class_id || ''}\u0000${key}`)
    if (!target) target = bySchool.get(`${row.school_id || ''}\u0000${key}`)
    if (!target) target = byGlobal.get(key)
    if (!target) {
      unresolved++
      continue
    }
    const slot = `${row.class_id || ''}\u0000${target}\u0000${dayKey(row.date)}`
    if (taken.has(slot)) {
      del.run(row.id)
      idsDropped++
      continue
    }
    upd.run(target, row.id)
    taken.add(slot)
    idsFixed++
  }

  return { idsFixed, idsDropped, unresolved }
}
