import { useState } from 'react'
import { Building2, Loader2, Plus, Search, ShieldCheck, Trash2 } from 'lucide-react'
import { api } from '../lib/api'
import { useFetch } from '../lib/useFetch'
import SchoolAdminsModal from '../components/SchoolAdminsModal'
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

const EMPTY_FORM = { name: '', location: '', established: new Date().getFullYear(), status: 'Active' }

export default function SchoolsPage() {
  const { data: schools, loading, error, reload } = useFetch(() => api.getSchools(), [])
  const [query, setQuery] = useState('')
  const [modal, setModal] = useState(null) // { mode: 'add' } | { mode: 'edit', school }
  const [manageSchool, setManageSchool] = useState(null) // school object → open admins manager
  const [confirmDelete, setConfirmDelete] = useState(null) // school object → ask before deleting
  const [deleting, setDeleting] = useState(false)
  const [form, setForm] = useState(EMPTY_FORM)
  const [busy, setBusy] = useState(false)
  const [formError, setFormError] = useState(null)

  function openAdd() {
    setForm(EMPTY_FORM)
    setFormError(null)
    setModal({ mode: 'add' })
  }

  function openEdit(school) {
    setForm({
      name: school.name,
      location: school.location,
      established: school.established,
      status: school.status,
    })
    setFormError(null)
    setModal({ mode: 'edit', school })
  }

  async function save(e) {
    e.preventDefault()
    setFormError(null)
    if (!form.name.trim()) {
      setFormError('School name is required.')
      return
    }
    setBusy(true)
    try {
      if (modal.mode === 'add') {
        await api.createSchool(form)
      } else {
        await api.updateSchool({ id: modal.school.id, ...form })
      }
      setModal(null)
      reload()
    } catch (err) {
      setFormError(err.message || 'Could not save the school.')
    } finally {
      setBusy(false)
    }
  }

  async function toggleStatus(school) {
    const next = school.status === 'Active' ? 'Disabled' : 'Active'
    try {
      await api.setSchoolStatus(school.id, next)
      reload()
    } catch {
      /* keep the list as-is on failure */
    }
  }

  async function confirmDeleteSchool() {
    setDeleting(true)
    try {
      await api.deleteSchool(confirmDelete.id)
      setConfirmDelete(null)
      reload()
    } catch (err) {
      alert(err.message || 'Could not delete the school.')
    } finally {
      setDeleting(false)
    }
  }

  const q = query.trim().toLowerCase()
  const filtered = (schools || []).filter(
    (s) => !q || s.name.toLowerCase().includes(q) || s.location.toLowerCase().includes(q),
  )

  return (
    <>
      <PageHeader
        title="Schools"
        subtitle="Manage schools across the network."
        actions={
          <PrimaryButton onClick={openAdd}>
            <Plus className="h-4 w-4" />
            Add school
          </PrimaryButton>
        }
      />

      <div className="relative mb-5 max-w-sm">
        <Search className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-outline" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search by name or location…"
          className={`${inputClass} pl-10`}
        />
      </div>

      {loading ? (
        <Spinner label="Loading schools…" />
      ) : error ? (
        <Card className="p-8 text-center">
          <p className="font-semibold text-danger">{error}</p>
        </Card>
      ) : filtered.length === 0 ? (
        <EmptyState
          title={q ? 'No schools match your search' : 'No schools yet'}
          hint={q ? 'Try a different name or location.' : 'Add your first school to get started.'}
          action={
            !q && (
              <PrimaryButton onClick={openAdd} className="mt-3">
                <Plus className="h-4 w-4" />
                Add school
              </PrimaryButton>
            )
          }
        />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {filtered.map((s) => (
            <Card key={s.id} className="flex flex-col gap-4 p-5">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <h3 className="truncate text-base font-bold text-ink">{s.name}</h3>
                  <p className="mt-0.5 flex items-center gap-1.5 text-sm text-ink-soft">
                    <Building2 className="h-3.5 w-3.5" />
                    {s.location} · Est. {s.established}
                  </p>
                </div>
                <div className="flex items-center gap-1.5">
                  <Badge tone={s.status === 'Active' ? 'green' : 'neutral'}>{s.status}</Badge>
                  <button
                    onClick={() => setConfirmDelete(s)}
                    title="Delete school"
                    className="rounded-btn border border-outline-soft/60 p-2 text-ink-soft transition hover:border-danger/30 hover:bg-danger-soft hover:text-danger"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-4 gap-1 rounded-btn bg-surface-low px-2 py-3 text-center">
                <div>
                  <p className="text-base font-extrabold text-ink">{s.admin_names.length}</p>
                  <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Admins</p>
                </div>
                <div>
                  <p className="text-base font-extrabold text-ink">{s.teacher_count}</p>
                  <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Teachers</p>
                </div>
                <div>
                  <p className="text-base font-extrabold text-ink">{s.class_count}</p>
                  <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Classes</p>
                </div>
                <div>
                  <p className="text-base font-extrabold text-ink">{s.student_count}</p>
                  <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-soft">Students</p>
                </div>
              </div>

              <div className="flex min-h-8 flex-wrap items-center gap-1.5">
                {s.admin_names.length > 0 ? (
                  s.admin_names.map((n) => (
                    <span
                      key={n}
                      className="inline-flex items-center gap-1 rounded-full bg-primary-soft px-2.5 py-0.5 text-xs font-semibold text-primary"
                    >
                      <ShieldCheck className="h-3 w-3" />
                      {n}
                    </span>
                  ))
                ) : (
                  <span className="text-xs italic text-ink-soft">No school admin yet</span>
                )}
                <button
                  onClick={() => setManageSchool(s)}
                  className="inline-flex items-center gap-1 rounded-full border border-dashed border-primary/40 px-2.5 py-0.5 text-xs font-semibold text-primary transition hover:bg-primary-soft"
                >
                  <Plus className="h-3 w-3" />
                  Manage admins
                </button>
              </div>

              <div className="mt-auto flex gap-2 border-t border-outline-soft/60 pt-4">
                <SecondaryButton onClick={() => openEdit(s)} className="flex-1">
                  Edit
                </SecondaryButton>
                <button
                  onClick={() => toggleStatus(s)}
                  className={`flex-1 rounded-btn border px-4 py-2.5 text-sm font-semibold transition active:scale-[0.97] ${
                    s.status === 'Active'
                      ? 'border-danger/30 bg-white text-danger hover:bg-danger-soft'
                      : 'border-success/30 bg-white text-success hover:bg-success-soft'
                  }`}
                >
                  {s.status === 'Active' ? 'Disable' : 'Enable'}
                </button>
              </div>
            </Card>
          ))}
        </div>
      )}

      {/* School admins manager (subset of each school) */}
      {manageSchool && (
        <SchoolAdminsModal school={manageSchool} onClose={() => setManageSchool(null)} onChanged={reload} />
      )}

      {/* Delete confirmation */}
      {confirmDelete && (
        <Modal
          title="Delete school?"
          subtitle="This cannot be undone."
          onClose={() => setConfirmDelete(null)}
        >
          <div className="space-y-4">
            <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-3 text-sm text-danger">
              <p className="font-semibold">{confirmDelete.name}</p>
              <p className="mt-1 text-ink-soft">
                Deleting this school will permanently remove it and its school admins, teachers, classes and
                students ({confirmDelete.admin_names.length} admin(s), {confirmDelete.teacher_count} teacher(s),{' '}
                {confirmDelete.class_count} class(es), {confirmDelete.student_count} student(s)) from the Super
                Admin registry and from the School Admin console's database.
              </p>
            </div>
            <div className="flex justify-end gap-2">
              <SecondaryButton type="button" onClick={() => setConfirmDelete(null)}>
                Cancel
              </SecondaryButton>
              <button
                onClick={confirmDeleteSchool}
                disabled={deleting}
                className="inline-flex items-center justify-center gap-2 rounded-btn bg-danger px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-danger/90 disabled:opacity-60"
              >
                {deleting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                {deleting ? 'Deleting…' : 'Delete school'}
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Add / Edit modal */}
      {modal && (
        <Modal
          title={modal.mode === 'add' ? 'Add school' : `Edit ${modal.school.name}`}
          subtitle="Add a school to the network."
          onClose={() => setModal(null)}
        >
          <form onSubmit={save} className="space-y-4">
            {formError && (
              <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-2.5 text-sm font-medium text-danger">
                {formError}
              </div>
            )}
            <Field label="School name">
              <input
                required
                autoFocus
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="e.g. Springfield Elementary"
                className={inputClass}
              />
            </Field>
            <div className="grid grid-cols-2 gap-4">
              <Field label="Location">
                <input
                  value={form.location}
                  onChange={(e) => setForm({ ...form, location: e.target.value })}
                  placeholder="e.g. Springfield"
                  className={inputClass}
                />
              </Field>
              <Field label="Established">
                <input
                  type="number"
                  min={1900}
                  max={2100}
                  value={form.established}
                  onChange={(e) => setForm({ ...form, established: Number(e.target.value) })}
                  className={inputClass}
                />
              </Field>
            </div>
            <Field label="Status">
              <select
                value={form.status}
                onChange={(e) => setForm({ ...form, status: e.target.value })}
                className={inputClass}
              >
                <option value="Active">Active</option>
                <option value="Disabled">Disabled</option>
              </select>
            </Field>
            <div className="flex justify-end gap-2 pt-2">
              <SecondaryButton type="button" onClick={() => setModal(null)}>
                Cancel
              </SecondaryButton>
              <PrimaryButton type="submit" disabled={busy}>
                {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
                {busy ? 'Saving…' : modal.mode === 'add' ? 'Add school' : 'Save changes'}
              </PrimaryButton>
            </div>
          </form>
        </Modal>
      )}
    </>
  )
}
