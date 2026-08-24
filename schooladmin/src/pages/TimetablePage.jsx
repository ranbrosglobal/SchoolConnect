import { useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { CalendarDays, Check, Clock, Loader2, Plus, Trash2 } from 'lucide-react'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { DAYS, DEFAULT_PERIODS } from '../lib/timetable'
import { useFetch } from '../lib/useFetch'
import {
  Badge,
  Card,
  EmptyState,
  Field,
  Modal,
  PageHeader,
  PrimaryButton,
  SecondaryButton,
  Spinner,
  inputClass,
} from '../components/ui'

function EntryModal({ klass, teachers, periods, slot, onClose, onSaved }) {
  const entry = slot?.id ? slot : null
  const [day, setDay] = useState(slot?.day || 'Monday')
  const [period, setPeriod] = useState(slot?.period || 1)
  const [teacherId, setTeacherId] = useState(entry?.teacher_id || '')
  const [subject, setSubject] = useState(entry?.subject || '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)
  const selectedTeacher = teachers.find((t) => t.id === teacherId)

  // Subjects a teacher can teach; falls back to every subject used in the
  // school when the teacher has none recorded (legacy data).
  const teacherSubjects = selectedTeacher?.subjects?.length
    ? selectedTeacher.subjects
    : [...new Set(teachers.flatMap((t) => t.subjects || []))]
  const subjectOptions = teacherSubjects.length > 0 ? teacherSubjects : [subject].filter(Boolean)

  // The school's periods, plus the slot's own period if it's been hidden by a
  // later config change (so an orphaned entry can still be edited or moved).
  const periodOptions = periods.some((p) => p.n === period)
    ? periods
    : [...periods, { n: period, time: '' }].sort((a, b) => a.n - b.n)

  function changeTeacher(id) {
    setTeacherId(id)
    const t = teachers.find((x) => x.id === id)
    const subs = t?.subjects || []
    if (subs.length && !subs.includes(subject)) setSubject(subs[0])
  }

  async function save(e) {
    e.preventDefault()
    setError(null)
    if (!teacherId) {
      setError('Pick a teacher for this period.')
      return
    }
    if (!subject.trim()) {
      setError('Pick a subject for this period.')
      return
    }
    setBusy(true)
    try {
      await api.setTimetableEntry({ class_id: klass.id, day, period, teacher_id: teacherId, subject })
      onSaved()
    } catch (err) {
      setError(err.message || 'Could not save this period.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal
      title={entry ? `Edit ${day} period ${period}` : `Add ${day} period ${period}`}
      subtitle={`Assigns a teacher and subject to ${klass.name} for this slot. Saves over any existing entry for the same day & period.`}
      onClose={onClose}
    >
      <form onSubmit={save} className="space-y-4">
        {error && (
          <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-2.5 text-sm font-medium text-danger">
            {error}
          </div>
        )}
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Day">
            <select value={day} onChange={(e) => setDay(e.target.value)} className={inputClass}>
              {DAYS.map((d) => (
                <option key={d} value={d}>
                  {d}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Period">
            <select value={period} onChange={(e) => setPeriod(Number(e.target.value))} className={inputClass}>
              {periodOptions.map((p) => (
                <option key={p.n} value={p.n}>
                  {p.n} · {p.time || 'no time set'}
                </option>
              ))}
            </select>
          </Field>
        </div>

        <Field label="Teacher">
          <select value={teacherId} onChange={(e) => changeTeacher(e.target.value)} className={inputClass}>
            <option value="">Choose a teacher…</option>
            {teachers.map((t) => (
              <option key={t.id} value={t.id} disabled={t.status === 'Inactive'}>
                {t.name} — {(t.subjects || []).join(', ') || 'No subjects'}
                {t.status === 'Inactive' ? ' (inactive)' : ''}
              </option>
            ))}
          </select>
        </Field>

        <Field label="Subject" hint="The subject taught in this slot — it's pinned here, so changing a teacher's subjects later won't rewrite past entries.">
          <select
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
            className={inputClass}
            disabled={!teacherId || subjectOptions.length === 0}
          >
            {!teacherId ? (
              <option value="">Pick a teacher first…</option>
            ) : (
              <>
                {!subjectOptions.includes(subject) && subject && <option value={subject}>{subject}</option>}
                {subjectOptions.map((s) => (
                  <option key={s} value={s}>
                    {s}
                  </option>
                ))}
              </>
            )}
          </select>
        </Field>

        <div className="flex justify-end gap-2 pt-2">
          <SecondaryButton type="button" onClick={onClose}>
            Cancel
          </SecondaryButton>
          <PrimaryButton type="submit" disabled={busy}>
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
            {busy ? 'Saving…' : 'Save period'}
          </PrimaryButton>
        </div>
      </form>
    </Modal>
  )
}

function PeriodsModal({ school, periods, onClose, onSaved }) {
  const [rows, setRows] = useState(() => periods.map((p) => ({ n: p.n, time: p.time })))
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)

  function addPeriod() {
    const n = rows.length ? Math.max(...rows.map((r) => r.n)) + 1 : 1
    setRows((r) => [...r, { n, time: '' }])
  }

  function removePeriod(n) {
    setRows((r) => r.filter((x) => x.n !== n))
  }

  function setTime(n, time) {
    setRows((r) => r.map((x) => (x.n === n ? { ...x, time } : x)))
  }

  async function save(e) {
    e.preventDefault()
    setError(null)
    if (rows.length === 0) {
      setError('At least one period is required.')
      return
    }
    if (rows.some((r) => !r.time.trim())) {
      setError('Every period needs a time.')
      return
    }
    setBusy(true)
    try {
      await api.updateTimetablePeriods(school, rows)
      onSaved()
    } catch (err) {
      setError(err.message || 'Could not save periods.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal
      title="Timetable periods"
      subtitle="Defines this school's schedule — how many periods run each day and what time each one starts."
      onClose={onClose}
    >
      <form onSubmit={save} className="space-y-4">
        {error && (
          <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-2.5 text-sm font-medium text-danger">
            {error}
          </div>
        )}

        <div className="space-y-2">
          {rows.map((r) => (
            <div key={r.n} className="flex items-center gap-2">
              <span className="w-12 shrink-0 text-sm font-extrabold text-ink">P{r.n}</span>
              <input
                type="text"
                value={r.time}
                onChange={(e) => setTime(r.n, e.target.value)}
                placeholder="e.g. 8:30 – 9:15"
                className={inputClass}
              />
              <button
                type="button"
                onClick={() => removePeriod(r.n)}
                className="rounded-btn border border-outline-soft p-2 text-ink-soft transition hover:border-danger/40 hover:text-danger"
                title={`Remove period ${r.n}`}
              >
                <Trash2 className="h-4 w-4" />
              </button>
            </div>
          ))}
        </div>

        <button
          type="button"
          onClick={addPeriod}
          className="inline-flex items-center gap-2 rounded-btn border border-dashed border-outline-soft px-3 py-2 text-sm font-semibold text-ink-soft transition hover:border-primary/40 hover:text-primary"
        >
          <Plus className="h-4 w-4" />
          Add period
        </button>

        <p className="text-xs text-ink-soft">
          Removing a period hides its scheduled entries from the grid but keeps them in the database — adding the period back restores them.
        </p>

        <div className="flex justify-end gap-2 pt-2">
          <SecondaryButton type="button" onClick={onClose}>
            Cancel
          </SecondaryButton>
          <PrimaryButton type="submit" disabled={busy}>
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
            {busy ? 'Saving…' : 'Save periods'}
          </PrimaryButton>
        </div>
      </form>
    </Modal>
  )
}

export default function TimetablePage() {
  const { user } = useAuth()
  const [searchParams] = useSearchParams()
  const classParam = searchParams.get('class')
  const scope = user.school

  const { data: classes, loading: classesLoading } = useFetch(() => api.getClasses(scope), [scope])
  const { data: teachers } = useFetch(() => api.getTeachers(scope), [scope])
  const { data: tt, loading, error, reload } = useFetch(() => api.getTimetable(scope), [scope])

  // Period times are per-school data returned alongside the entries.
  const { periods, entries } = useMemo(
    () => ({
      periods: tt?.periods && tt.periods.length > 0 ? tt.periods : DEFAULT_PERIODS,
      entries: tt?.entries || [],
    }),
    [tt],
  )

  const [selectedClass, setSelectedClass] = useState('')
  const [view, setView] = useState('class') // 'class' | 'teacher'
  const [slot, setSlot] = useState(null) // { day, period } | { entry }
  const [confirmDelete, setConfirmDelete] = useState(null)
  const [deleting, setDeleting] = useState(false)
  const [deleteError, setDeleteError] = useState(null)
  const [editingPeriods, setEditingPeriods] = useState(false)

  // Pick the class from the URL (if it belongs to this school), else the first one.
  useEffect(() => {
    if (!classes || classes.length === 0) {
      setSelectedClass('')
      return
    }
    setSelectedClass((cur) => {
      if (cur && classes.some((c) => c.id === cur)) return cur
      if (classParam && classes.some((c) => c.id === classParam)) return classParam
      return classes[0].id
    })
  }, [classes, classParam])

  const klass = classes?.find((c) => c.id === selectedClass) || null

  const classEntries = useMemo(
    () => entries.filter((e) => e.class_id === selectedClass),
    [entries, selectedClass],
  )
  const entryMap = useMemo(() => {
    const map = {}
    for (const e of classEntries) map[`${e.day}|${e.period}`] = e
    return map
  }, [classEntries])

  const filled = classEntries.length
  const totalSlots = DAYS.length * periods.length
  const freeSlots = Math.max(0, totalSlots - filled)
  const teachersUsed = new Set(classEntries.map((e) => e.teacher_id)).size

  // Teacher view: group the school's entries by teacher.
  const byTeacher = useMemo(() => {
    const map = {}
    for (const e of entries) {
      if (!map[e.teacher_id]) {
        map[e.teacher_id] = { teacher_id: e.teacher_id, teacher_name: e.teacher_name, subjects: [], slots: [] }
      }
      if (!map[e.teacher_id].subjects.includes(e.subject)) map[e.teacher_id].subjects.push(e.subject)
      map[e.teacher_id].slots.push(e)
    }
    return Object.values(map).sort((a, b) => a.teacher_name.localeCompare(b.teacher_name))
  }, [entries])

  async function confirmDeleteEntry() {
    setDeleteError(null)
    setDeleting(true)
    try {
      await api.removeTimetableEntry(confirmDelete.id)
      setConfirmDelete(null)
      reload()
    } catch (err) {
      setDeleteError(err.message || 'Could not remove this period.')
    } finally {
      setDeleting(false)
    }
  }

  if (classesLoading) return <Spinner label="Loading classes…" />

  return (
    <>
      <PageHeader
        title="Timetable"
        subtitle="Assign teachers to classes across the weekly schedule."
        actions={
          <>
            <SecondaryButton onClick={() => setEditingPeriods(true)}>
              <Clock className="h-4 w-4" />
              Periods
            </SecondaryButton>
            <PrimaryButton onClick={() => setSlot({ day: 'Monday', period: 1 })} disabled={!klass}>
              <Plus className="h-4 w-4" />
              Add period
            </PrimaryButton>
          </>
        }
      />

      {/* Controls */}
      <div className="mb-5 flex flex-wrap items-center gap-3">
        {classes && classes.length > 0 && (
          <div className="relative w-full max-w-xs">
            <span className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-xs font-bold uppercase tracking-wide text-ink-soft">
              Class
            </span>
            <select
              value={selectedClass}
              onChange={(e) => setSelectedClass(e.target.value)}
              className={`${inputClass} pl-[3.6rem]`}
            >
              {classes.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </div>
        )}

        <div className="ml-auto flex rounded-btn border border-outline-soft bg-white p-1">
          {[
            { key: 'class', label: 'By class' },
            { key: 'teacher', label: 'By teacher' },
          ].map((t) => (
            <button
              key={t.key}
              onClick={() => setView(t.key)}
              className={`rounded-btn px-3 py-1.5 text-xs font-semibold transition ${
                view === t.key ? 'bg-primary text-white' : 'text-ink-soft hover:text-ink'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>

      {error ? (
        <Card className="p-8 text-center">
          <p className="font-semibold text-danger">{error}</p>
        </Card>
      ) : loading ? (
        <Spinner label="Loading timetable…" />
      ) : !classes || classes.length === 0 ? (
        <EmptyState
          title="No classes yet"
          hint="Create a class first, then build its weekly timetable."
          action={
            <Link to="/classes" className="mt-3 inline-flex items-center gap-2 rounded-btn bg-primary px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-primary-container">
              <CalendarDays className="h-4 w-4" />
              Go to classes
            </Link>
          }
        />
      ) : view === 'class' ? (
        <>
          {/* Stats */}
          <div className="mb-5 grid grid-cols-3 gap-4">
            <Card className="p-4 text-center">
              <p className="text-2xl font-extrabold text-primary">{filled}</p>
              <p className="text-xs font-semibold uppercase tracking-wide text-ink-soft">Periods filled</p>
            </Card>
            <Card className="p-4 text-center">
              <p className="text-2xl font-extrabold text-ink">{freeSlots}</p>
              <p className="text-xs font-semibold uppercase tracking-wide text-ink-soft">Free slots</p>
            </Card>
            <Card className="p-4 text-center">
              <p className="text-2xl font-extrabold text-success">{teachersUsed}</p>
              <p className="text-xs font-semibold uppercase tracking-wide text-ink-soft">Teachers used</p>
            </Card>
          </div>

          <Card className="overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[880px] border-collapse">
                <thead>
                  <tr className="border-b border-outline-soft/60 bg-surface-low/60">
                    <th className="w-24 px-3 py-3 text-left text-xs font-bold uppercase tracking-wide text-ink-soft">Period</th>
                    {DAYS.map((d) => (
                      <th key={d} className="px-3 py-3 text-left text-xs font-bold uppercase tracking-wide text-primary">
                        {d}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {periods.map((p, rowIdx) => (
                    <tr key={p.n} className={rowIdx % 2 ? 'bg-surface-low/40' : ''}>
                      <td className="border-r border-outline-soft/60 px-3 py-2 align-top">
                        <p className="text-sm font-extrabold text-ink">P{p.n}</p>
                        <p className="text-[11px] leading-tight text-ink-soft">{p.time}</p>
                      </td>
                      {DAYS.map((d) => {
                        const e = entryMap[`${d}|${p.n}`]
                        return (
                          <td key={d} className="border-r border-outline-soft/40 px-2 py-2 align-top last:border-r-0">
                            {e ? (
                              <div className="group relative">
                                <button
                                  onClick={() => setSlot(e)}
                                  className={`block w-full rounded-btn border px-2.5 py-2 text-left transition active:scale-[0.97] ${
                                    e.teacher_status === 'Inactive'
                                      ? 'border-warning/40 bg-warning-soft/60'
                                      : 'border-primary/25 bg-primary-soft/70 hover:border-primary/50'
                                  }`}
                                  title={`${e.day} period ${p.n} — ${e.teacher_name} (${e.subject})`}
                                >
                                  <p className="truncate text-xs font-bold text-primary">{e.subject}</p>
                                  <p className="truncate text-[11px] text-ink-soft">{e.teacher_name}</p>
                                </button>
                                <button
                                  onClick={() => {
                                    setDeleteError(null)
                                    setConfirmDelete(e)
                                  }}
                                  title="Remove period"
                                  className="absolute -right-1.5 -top-1.5 hidden rounded-full border border-outline-soft bg-white p-1 text-ink-soft shadow-card transition hover:border-danger/40 hover:text-danger group-hover:block"
                                >
                                  <Trash2 className="h-3 w-3" />
                                </button>
                              </div>
                            ) : (
                              <button
                                onClick={() => setSlot({ day: d, period: p.n })}
                                className="flex w-full items-center justify-center rounded-btn border border-dashed border-outline-soft py-2 text-ink-soft transition hover:border-primary/40 hover:bg-primary-soft/50 hover:text-primary"
                                title={`Add ${d} period ${p.n}`}
                              >
                                <Plus className="h-3.5 w-3.5" />
                              </button>
                            )}
                          </td>
                        )
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
          <p className="mt-3 text-xs text-ink-soft">
            Click a period to change the teacher or subject. A teacher can only be scheduled in one class per day & period. Period times are set per school — use the Periods button to change them.
          </p>
        </>
      ) : (
        <>
          <Card className="overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[880px] border-collapse">
                <thead>
                  <tr className="border-b border-outline-soft/60 bg-surface-low/60">
                    <th className="px-3 py-3 text-left text-xs font-bold uppercase tracking-wide text-ink-soft">Teacher</th>
                    {DAYS.map((d) => (
                      <th key={d} className="px-3 py-3 text-left text-xs font-bold uppercase tracking-wide text-primary">
                        {d}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {byTeacher.map((t, idx) => (
                    <tr key={t.teacher_id} className={idx % 2 ? 'bg-surface-low/40' : ''}>
                      <td className="border-r border-outline-soft/60 px-3 py-3 align-top">
                        <p className="text-sm font-bold text-ink">{t.teacher_name}</p>
                        <div className="mt-1 flex flex-wrap gap-1">
                          {t.subjects.map((s) => (
                            <Badge key={s} tone="indigo">
                              {s}
                            </Badge>
                          ))}
                        </div>
                      </td>
                      {DAYS.map((d) => {
                        const daySlots = t.slots
                          .filter((s) => s.day === d)
                          .sort((a, b) => a.period - b.period)
                        return (
                          <td key={d} className="border-r border-outline-soft/40 px-2 py-2 align-top last:border-r-0">
                            <div className="flex flex-col gap-1">
                              {daySlots.map((s) => (
                                <span
                                  key={s.id}
                                  className="rounded-btn bg-primary-soft/70 px-2 py-1 text-[11px] font-semibold text-primary"
                                >
                                  P{s.period} · {s.subject} · {s.class_name}
                                </span>
                              ))}
                            </div>
                          </td>
                        )
                      })}
                    </tr>
                  ))}
                  {byTeacher.length === 0 && (
                    <tr>
                      <td colSpan={DAYS.length + 1} className="px-3 py-8 text-center text-sm text-ink-soft">
                        No timetable entries yet for this school.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </Card>
          <p className="mt-3 text-xs text-ink-soft">
            Spot-check each teacher&apos;s week at a glance — no teacher should appear in two classes in the same period.
          </p>
        </>
      )}

      {slot && klass && (
        <EntryModal
          klass={klass}
          teachers={teachers || []}
          periods={periods}
          slot={slot}
          onClose={() => setSlot(null)}
          onSaved={() => {
            setSlot(null)
            reload()
          }}
        />
      )}

      {editingPeriods && (
        <PeriodsModal
          school={scope}
          periods={periods}
          onClose={() => setEditingPeriods(false)}
          onSaved={() => {
            setEditingPeriods(false)
            reload()
          }}
        />
      )}

      {confirmDelete && (
        <Modal title="Remove this period?" subtitle="This cannot be undone." onClose={() => setConfirmDelete(null)}>
          <div className="space-y-4">
            {deleteError && (
              <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-2.5 text-sm font-medium text-danger">
                {deleteError}
              </div>
            )}
            <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-3 text-sm">
              <p className="font-semibold text-danger">
                {confirmDelete.subject} — {confirmDelete.teacher_name}
              </p>
              <p className="mt-0.5 text-xs text-ink-soft">
                {klass?.name} · {confirmDelete.day} period {confirmDelete.period}
              </p>
            </div>
            <div className="flex justify-end gap-2">
              <SecondaryButton type="button" onClick={() => setConfirmDelete(null)}>
                Cancel
              </SecondaryButton>
              <button
                onClick={confirmDeleteEntry}
                disabled={deleting}
                className="inline-flex items-center justify-center gap-2 rounded-btn bg-danger px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-danger/90 disabled:opacity-60"
              >
                {deleting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                {deleting ? 'Removing…' : 'Remove period'}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </>
  )
}
