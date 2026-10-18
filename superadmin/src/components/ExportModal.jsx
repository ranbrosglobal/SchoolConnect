import { Check, Download, FileSpreadsheet, FileText, Loader2, Network, School } from 'lucide-react'
import { useState } from 'react'
import { Modal, PrimaryButton, SecondaryButton } from './ui'

const plural = (count, one, many) => `${count} ${count === 1 ? one : many}`

/**
 * School picker shared by the page's scope filter and the export dialog.
 * An empty selection means every school on the network.
 */
export function SchoolPicker({ schools, selected, onChange }) {
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
        <Network className="h-4 w-4 text-ink-soft" />
        <span className="text-sm font-semibold text-ink">Full network</span>
        <span className="ml-auto text-xs text-ink-soft">{plural(schools.length, 'school', 'schools')}</span>
      </button>

      <div className="max-h-56 overflow-y-auto bg-white">
        {schools.map((s) => {
          const on = selected.includes(s.id)
          return (
            <button
              key={s.id}
              type="button"
              onClick={() => toggle(s.id)}
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
              <School className="h-4 w-4 shrink-0 text-ink-soft" />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-semibold text-ink">{s.name}</span>
                <span className="block truncate text-xs text-ink-soft">
                  {[s.location || 'No location', s.status, plural(Number(s.student_count) || 0, 'student', 'students')]
                    .filter(Boolean)
                    .join(' · ')}
                </span>
              </span>
            </button>
          )
        })}
        {schools.length === 0 && <p className="px-3.5 py-4 text-sm text-ink-soft">No schools on the network yet.</p>}
      </div>
    </div>
  )
}

const FORMATS = [
  { key: 'pdf', label: 'PDF', hint: 'Formatted report, ready to print or share', icon: FileText },
  { key: 'csv', label: 'CSV', hint: 'Every section as rows for a spreadsheet', icon: FileSpreadsheet },
]

/**
 * Export options for the network report: full network, one school or several
 * schools, as a formatted PDF or a CSV.
 */
export default function ExportModal({
  orgName,
  schools,
  defaultScopeIds = [],
  busy = false,
  onClose,
  onExport,
}) {
  const [scopeIds, setScopeIds] = useState(defaultScopeIds)
  const [format, setFormat] = useState('pdf')

  const pickedIds = scopeIds.length ? scopeIds : schools.map((s) => s.id)
  const picked = schools.filter((s) => pickedIds.includes(s.id))
  const studentCount = picked.reduce((a, s) => a + (Number(s.student_count) || 0), 0)

  const scopeLabel =
    scopeIds.length === 0
      ? 'Full network'
      : scopeIds.length === 1
        ? schools.find((s) => s.id === scopeIds[0])?.name || '1 school'
        : `${scopeIds.length} selected schools`

  return (
    <Modal
      title="Export network report"
      subtitle={`${orgName} · choose exactly what goes into the file`}
      onClose={onClose}
      wide
    >
      <div className="max-h-[68vh] space-y-5 overflow-y-auto pr-1">
        <section>
          <p className="mb-2 flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-ink-soft">
            <School className="h-3.5 w-3.5" /> What to include
          </p>
          <SchoolPicker schools={schools} selected={scopeIds} onChange={setScopeIds} />
          <p className="mt-2 text-xs text-ink-soft">
            {scopeLabel} · {plural(picked.length, 'school', 'schools')} · {plural(studentCount, 'student', 'students')}
          </p>
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

        <p className="rounded-btn bg-surface-low px-3.5 py-2.5 text-xs text-ink-soft">
          Network figures are a point-in-time snapshot of enrolment, staffing and setup completeness. Attendance
          timelines live in the School Admin console, where each school's daily register is available.
        </p>
      </div>

      <div className="mt-5 flex items-center justify-between gap-3 border-t border-outline-soft pt-4">
        <p className="text-xs text-ink-soft">
          {scopeLabel} · snapshot
        </p>
        <div className="flex items-center gap-2">
          <SecondaryButton onClick={onClose} disabled={busy}>
            Cancel
          </SecondaryButton>
          <PrimaryButton onClick={() => onExport({ scopeIds, format })} disabled={busy}>
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}
            {busy ? 'Preparing…' : format === 'pdf' ? 'Export PDF' : 'Export CSV'}
          </PrimaryButton>
        </div>
      </div>
    </Modal>
  )
}
