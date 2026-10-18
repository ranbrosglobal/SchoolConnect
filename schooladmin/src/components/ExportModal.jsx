import { useMemo, useState } from 'react'
import { CalendarRange, Check, Download, FileSpreadsheet, FileText, Loader2, School, Users } from 'lucide-react'
import { RANGE_PRESETS, resolveRange } from '../lib/reports'
import { Modal, PrimaryButton, SecondaryButton, inputClass } from './ui'

/**
 * Class picker shared by the page's scope filter and the export dialog.
 * `selected` is an array of class ids; an empty array means the whole school.
 */
export function ClassPicker({ classes, selected, onChange, allLabel = 'Full school' }) {
  const all = selected.length === 0
  const toggle = (id) => {
    const next = selected.includes(id) ? selected.filter((x) => x !== id) : [...selected, id]
    onChange(next)
  }

  return (
    <div className="overflow-hidden rounded-btn border border-outline-soft">
      <button
        type="button"
        onClick={() => onChange([])}
        className={`flex w-full items-center gap-2.5 border-b border-outline-soft px-3.5 py-2.5 text-left transition ${
          all ? 'bg-primary-soft' : 'bg-white hover:bg-surface-low'
        }`}
      >
        <span
          className={`flex h-4 w-4 shrink-0 items-center justify-center rounded border ${
            all ? 'border-primary bg-primary text-white' : 'border-outline-soft bg-white'
          }`}
        >
          {all && <Check className="h-3 w-3" />}
        </span>
        <School className="h-4 w-4 text-ink-soft" />
        <span className="text-sm font-semibold text-ink">{allLabel}</span>
        <span className="ml-auto text-xs text-ink-soft">{classes.length} classes</span>
      </button>

      <div className="max-h-52 overflow-y-auto bg-white">
        {classes.map((c) => {
          const on = selected.includes(c.id)
          return (
            <button
              key={c.id}
              type="button"
              onClick={() => toggle(c.id)}
              className={`flex w-full items-center gap-2.5 border-b border-outline-soft/60 px-3.5 py-2.5 text-left transition last:border-b-0 ${
                on ? 'bg-primary-soft' : 'hover:bg-surface-low'
              }`}
            >
              <span
                className={`flex h-4 w-4 shrink-0 items-center justify-center rounded border ${
                  on ? 'border-primary bg-primary text-white' : 'border-outline-soft bg-white'
                }`}
              >
                {on && <Check className="h-3 w-3" />}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-semibold text-ink">{c.name}</span>
                <span className="block truncate text-xs text-ink-soft">
                  {[c.program, c.room].filter(Boolean).join(' · ') || 'No program'}
                </span>
              </span>
            </button>
          )
        })}
        {classes.length === 0 && (
          <p className="px-3.5 py-4 text-sm text-ink-soft">No classes yet.</p>
        )}
      </div>
    </div>
  )
}

const FORMATS = [
  { key: 'pdf', label: 'PDF', hint: 'Formatted report, ready to print or share', icon: FileText },
  { key: 'csv', label: 'CSV', hint: 'Every section as rows for a spreadsheet', icon: FileSpreadsheet },
]

/**
 * Export options: what to include (full school / one or more classes), the
 * period (all time, presets or custom dates) and the file format.
 */
export default function ExportModal({
  schoolName,
  classes,
  students,
  defaultScopeIds = [],
  defaultPreset = 'all',
  defaultFrom = '',
  defaultTo = '',
  busy = false,
  onClose,
  onExport,
}) {
  const [scopeIds, setScopeIds] = useState(defaultScopeIds)
  const [preset, setPreset] = useState(defaultPreset)
  const [from, setFrom] = useState(defaultFrom)
  const [to, setTo] = useState(defaultTo)
  const [format, setFormat] = useState('pdf')

  const range = useMemo(() => resolveRange(preset, { from, to }), [preset, from, to])

  const pickedIds = scopeIds.length ? scopeIds : classes.map((c) => c.id)
  const studentCount = students.filter((s) => pickedIds.includes(s.class_id)).length
  const scopeLabel =
    scopeIds.length === 0
      ? 'Full school'
      : scopeIds.length === 1
        ? classes.find((c) => c.id === scopeIds[0])?.name || '1 class'
        : `${scopeIds.length} selected classes`

  const canExport = !busy && !range.error && (scopeIds.length === 0 || pickedIds.length > 0)

  return (
    <Modal title="Export report" subtitle={`${schoolName} · choose exactly what goes into the file`} onClose={onClose} wide>
      <div className="max-h-[68vh] space-y-5 overflow-y-auto pr-1">
        <section>
          <p className="mb-2 flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-ink-soft">
            <Users className="h-3.5 w-3.5" /> What to include
          </p>
          <ClassPicker classes={classes} selected={scopeIds} onChange={setScopeIds} />
          <p className="mt-2 text-xs text-ink-soft">
            {scopeLabel} · {studentCount} {studentCount === 1 ? 'student' : 'students'}
            {scopeIds.length > 1 ? ' across the selected classes' : ''}
          </p>
        </section>

        <section>
          <p className="mb-2 flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-ink-soft">
            <CalendarRange className="h-3.5 w-3.5" /> Period
          </p>
          <div className="flex flex-wrap gap-2">
            {RANGE_PRESETS.map((p) => (
              <button
                key={p.key}
                type="button"
                onClick={() => setPreset(p.key)}
                className={`rounded-full border px-3 py-1.5 text-xs font-semibold transition ${
                  preset === p.key
                    ? 'border-primary bg-primary text-white'
                    : 'border-outline-soft bg-white text-ink-soft hover:border-primary/40 hover:text-primary'
                }`}
              >
                {p.label}
              </button>
            ))}
          </div>

          {preset === 'custom' && (
            <div className="mt-3 grid gap-3 sm:grid-cols-2">
              <label className="block">
                <span className="mb-1 block text-[11px] font-bold uppercase tracking-wide text-ink-soft">From</span>
                <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} className={inputClass} />
              </label>
              <label className="block">
                <span className="mb-1 block text-[11px] font-bold uppercase tracking-wide text-ink-soft">To</span>
                <input type="date" value={to} onChange={(e) => setTo(e.target.value)} className={inputClass} />
              </label>
            </div>
          )}

          <p className={`mt-2 text-xs ${range.error ? 'font-semibold text-danger' : 'text-ink-soft'}`}>
            {range.error ? range.error : `Attendance, timelines and exports cover ${range.period}.`}
          </p>
          {preset === 'all' && (
            <p className="mt-1 text-xs text-ink-soft">
              All-time exports use the cumulative attendance stored on each student; pick a period to report
              from the daily register instead.
            </p>
          )}
        </section>

        <section>
          <p className="mb-2 text-xs font-bold uppercase tracking-wide text-ink-soft">Format</p>
          <div className="grid gap-2 sm:grid-cols-2">
            {FORMATS.map((f) => {
              const Icon = f.icon
              const on = format === f.key
              return (
                <button
                  key={f.key}
                  type="button"
                  onClick={() => setFormat(f.key)}
                  className={`flex items-start gap-3 rounded-btn border px-3.5 py-3 text-left transition ${
                    on ? 'border-primary bg-primary-soft' : 'border-outline-soft bg-white hover:border-primary/40'
                  }`}
                >
                  <Icon className={`mt-0.5 h-4 w-4 ${on ? 'text-primary' : 'text-ink-soft'}`} />
                  <span>
                    <span className="block text-sm font-semibold text-ink">{f.label}</span>
                    <span className="block text-xs text-ink-soft">{f.hint}</span>
                  </span>
                </button>
              )
            })}
          </div>
        </section>
      </div>

      <div className="mt-5 flex items-center justify-between gap-3 border-t border-outline-soft pt-4">
        <p className="text-xs text-ink-soft">
          {scopeLabel} · {range.period}
        </p>
        <div className="flex items-center gap-2">
          <SecondaryButton onClick={onClose} disabled={busy}>
            Cancel
          </SecondaryButton>
          <PrimaryButton
            onClick={() => onExport({ scopeIds, range, format })}
            disabled={!canExport}
          >
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}
            {busy ? 'Preparing…' : format === 'pdf' ? 'Export PDF' : 'Export CSV'}
          </PrimaryButton>
        </div>
      </div>
    </Modal>
  )
}
