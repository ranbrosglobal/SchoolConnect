import { useState } from 'react'
import { Loader2, Plus } from 'lucide-react'
import { api } from '../lib/api'
import { useFetch } from '../lib/useFetch'
import { Field, Modal, PrimaryButton, SecondaryButton, inputClass } from './ui'

/* 
 * Add / edit a student. `student` = null → add mode.
 * On add, roll_number is optional — the backend assigns the next free roll.
 */
export default function StudentModal({ student, school, onClose, onSaved }) {
  const { data: classes, loading: classesLoading } = useFetch(() => api.getClasses(school), [school])
  const [fields, setFields] = useState(
    student
      ? {
          name: student.name,
          email: student.email,
          password: '',
          class_id: student.class_id,
          roll_number: student.roll_number,
          status: student.status,
          parent_name: student.parent_name || '',
          parent_phone: student.parent_phone || '',
          parent_email: student.parent_email || '',
          address: student.address || '',
        }
      : { name: '', email: '', password: '', class_id: '', roll_number: '', status: 'Active',
          parent_name: '', parent_phone: '', parent_email: '', address: '' },
  )
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)

  async function save(e) {
    e.preventDefault()
    setError(null)
    if (!fields.name.trim() || !fields.email.trim()) {
      setError('Name and email are required.')
      return
    }
    if (!fields.class_id) {
      setError('Please pick a class.')
      return
    }
    if (!student && !fields.password) {
      setError('A password is required for new student accounts.')
      return
    }
    setBusy(true)
    try {
      if (student) {
        await api.updateStudent({
          id: student.id,
          name: fields.name,
          email: fields.email,
          class_id: fields.class_id,
          roll_number: Number(fields.roll_number) || undefined,
          status: fields.status,
          parent_name: fields.parent_name,
          parent_phone: fields.parent_phone,
          parent_email: fields.parent_email,
          address: fields.address,
        })
      } else {
        await api.createStudent({
          name: fields.name,
          email: fields.email,
          password: fields.password,
          class_id: fields.class_id,
          roll_number: Number(fields.roll_number) || undefined,
          school,
          parent_name: fields.parent_name,
          parent_phone: fields.parent_phone,
          parent_email: fields.parent_email,
          address: fields.address,
        })
      }
      onSaved()
    } catch (err) {
      setError(err.message || 'Could not save the student.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal
      title={student ? `Edit ${student.name}` : 'Add student'}
      subtitle="Add a student to a class."
      onClose={onClose}
    >
      <form onSubmit={save} className="space-y-4">
        {error && (
          <div className="rounded-btn border border-danger/20 bg-danger-soft px-4 py-2.5 text-sm font-medium text-danger">
            {error}
          </div>
        )}

        {/* Name + Email */}
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Full name">
            <input
              autoFocus
              required
              value={fields.name}
              onChange={(e) => setFields({ ...fields, name: e.target.value })}
              placeholder="e.g. Aarav Sharma"
              className={inputClass}
            />
          </Field>
          <Field label="Email">
            <input
              type="email"
              required
              value={fields.email}
              onChange={(e) => setFields({ ...fields, email: e.target.value })}
              placeholder="student@school.edu"
              className={inputClass}
            />
          </Field>
        </div>

        {/* Password (required for new, optional for edit) */}
        <Field label={student ? 'New password (blank = keep)' : 'Password'}>
          <input
            type="text"
            required={!student}
            value={fields.password}
            onChange={(e) => setFields({ ...fields, password: e.target.value })}
            placeholder={student ? '••••••••' : 'Temporary password'}
            className={inputClass}
          />
        </Field>

        {/* Class + Roll */}
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Class">
            <select
              value={fields.class_id}
              onChange={(e) => setFields({ ...fields, class_id: e.target.value })}
              className={inputClass}
              disabled={classesLoading}
            >
              <option value="">{classesLoading ? 'Loading classes…' : 'Choose a class'}</option>
              {(classes || []).map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Roll number">
            <input
              type="number"
              min={1}
              value={fields.roll_number}
              onChange={(e) => setFields({ ...fields, roll_number: e.target.value })}
              placeholder={student ? String(student.roll_number) : 'Next free roll'}
              className={inputClass}
            />
          </Field>
        </div>

        {/* Parent info */}
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Parent / Guardian name">
            <input
              value={fields.parent_name}
              onChange={(e) => setFields({ ...fields, parent_name: e.target.value })}
              placeholder="e.g. Rajesh Sharma"
              className={inputClass}
            />
          </Field>
          <Field label="Parent phone">
            <input
              type="tel"
              value={fields.parent_phone}
              onChange={(e) => setFields({ ...fields, parent_phone: e.target.value })}
              placeholder="e.g. 9876543210"
              className={inputClass}
            />
          </Field>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Parent email">
            <input
              type="email"
              value={fields.parent_email}
              onChange={(e) => setFields({ ...fields, parent_email: e.target.value })}
              placeholder="parent@email.com"
              className={inputClass}
            />
          </Field>
          <Field label="Address">
            <input
              value={fields.address}
              onChange={(e) => setFields({ ...fields, address: e.target.value })}
              placeholder="Home address"
              className={inputClass}
            />
          </Field>
        </div>

        {student && (
          <Field label="Status">
            <select
              value={fields.status}
              onChange={(e) => setFields({ ...fields, status: e.target.value })}
              className={inputClass}
            >
              <option value="Active">Active</option>
              <option value="Inactive">Inactive</option>
            </select>
          </Field>
        )}

        <div className="flex justify-end gap-2 pt-2">
          <SecondaryButton type="button" onClick={onClose}>
            Cancel
          </SecondaryButton>
          <PrimaryButton type="submit" disabled={busy}>
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
            {busy ? 'Saving…' : student ? 'Save changes' : 'Add student'}
          </PrimaryButton>
        </div>
      </form>
    </Modal>
  )
}
