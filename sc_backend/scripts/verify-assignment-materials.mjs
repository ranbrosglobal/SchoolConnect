/**
 * Verifies assignment materials end-to-end against the dev SQLite database:
 * multi-file creation (PDF, image, video, voice), teacher + student visibility,
 * scoped downloads, add/remove/clear updates, the file cap, deletion, and the
 * HTTP body-size allowance that real uploads depend on.
 *
 * Run: node --experimental-sqlite sc_backend/scripts/verify-assignment-materials.mjs
 */
import { openDatabases, createServer } from '../src/server.js'
import { seedSchooladmin } from '../src/seed.js'
import { handleRequest } from '../src/handlers.js'

const { sa, su } = openDatabases()
// Idempotent: creates any missing tables (including assignment_files) and
// seeds only when the database is empty.
seedSchooladmin(sa)
const dbs = { sa, su }

let pass = 0
let fail = 0
const check = (name, cond, extra = '') => {
  if (cond) { pass++; console.log(`  PASS  ${name} ${extra}`) }
  else { fail++; console.log(`  FAIL  ${name} ${extra}`) }
}

function call(path, { method = 'GET', params = {}, body = {}, sid = null } = {}) {
  try {
    const res = handleRequest('schooladmin', dbs, path, {
      method, params, body, headers: {}, ip: '127.0.0.1', sid,
    })
    return { ok: true, data: res.data, sid: res._sid }
  } catch (err) {
    return { ok: false, status: err.status, error: err.message || String(err) }
  }
}

const login = (email, password) => call('school_connect.api.mobile.login', {
  method: 'POST', body: { email, password },
})

const b64 = (text) => Buffer.from(text).toString('base64')

// Distinct-looking payloads so a byte-for-byte download check is meaningful.
const PDF = b64('%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF')
const IMAGE = b64('\x89PNG\r\n\x1a\nassignment-diagram-bytes')
const AUDIO = b64('voice-note: please listen to the pronunciation drill')
const VIDEO = b64('video-clip: photosynthesis demonstration frames')

// ── Teacher login ────────────────────────────────────────────────────
const teacher = login('anita.sharma@springfield.edu', 'admin123')
check('teacher login', teacher.ok, teacher.ok ? teacher.data?.role : teacher.error)
const tsid = teacher.sid

// A teacher must not be able to upload into a class they do not teach.
const crossClass = call('school_connect.api.mobile.create_assignment', {
  method: 'POST',
  sid: tsid,
  body: { title: 'Cross-class upload', class_id: 'c-9a' },
})
check('teacher cannot upload to another class',
  !crossClass.ok && crossClass.status === 403,
  crossClass.ok ? 'unexpectedly allowed' : `${crossClass.status} ${crossClass.error}`)

// ── Create with four material types ─────────────────────────────────
const title = `Materials verification ${Date.now()}`
const created = call('school_connect.api.mobile.create_assignment', {
  method: 'POST',
  sid: tsid,
  body: {
    title,
    course: 'Mathematics',
    class_id: 'c-8a',
    due_date: new Date(Date.now() + 7 * 864e5).toISOString().split('T')[0],
    description: 'Attached worksheet, diagram, voice note and video clip.',
    files: [
      { file_name: 'worksheet.pdf', file_data: PDF },
      { file_name: 'diagram.png', file_data: IMAGE },
      { file_name: 'pronunciation.m4a', file_data: AUDIO },
      { file_name: 'lesson-clip.mp4', file_data: VIDEO },
    ],
  },
})
check('create assignment with 4 materials', created.ok, created.ok ? '' : created.error)
const assignment = created.data
const files = assignment?.files || []
check('response carries all four files', files.length === 4, `(${files.length})`)
check('kinds are derived from extensions',
  JSON.stringify(files.map(f => f.kind)) === JSON.stringify(['pdf', 'image', 'audio', 'video']),
  JSON.stringify(files.map(f => f.kind)))
check('mime types are correct',
  files[0]?.mime_type === 'application/pdf' &&
  files[1]?.mime_type === 'image/png' &&
  files[2]?.mime_type === 'audio/mp4' &&
  files[3]?.mime_type === 'video/mp4',
  files.map(f => f.mime_type).join(', '))
check('decoded sizes are reported', files[0]?.size > 0 && files[3]?.size === Buffer.from('video-clip: photosynthesis demonstration frames').length,
  files.map(f => f.size).join('/'))
check('material_count matches', assignment?.material_count === 4, String(assignment?.material_count))
check('legacy attachment mirrors the first file',
  assignment?.attachment === files[0]?.id && assignment?.attachment_name === 'worksheet.pdf')

// ── Teacher list sees the same materials ────────────────────────────
const teacherList = call('school_connect.api.mobile.get_teacher_assignments', { sid: tsid })
const listed = (teacherList.data || []).find(a => a.id === assignment?.id)
check('teacher list includes the assignment', !!listed)
check('teacher list includes all four files', listed?.files?.length === 4, `(${listed?.files?.length})`)

// ── Student sees exactly the material the teacher uploaded ──────────
// The dev database was seeded by the admin fixtures; these students have a
// blank password, which mobileLogin treats as "any password is accepted".
const student = login('kunal.singh2@student.edu', 'Student@123')
check('student login', student.ok, student.ok ? student.data?.role : student.error)
const ssid = student.sid

const studentList = call('school_connect.api.mobile.get_student_assignments', { sid: ssid })
const studentCopy = (studentList.data || []).find(a => a.id === assignment?.id)
check('assignment appears for the enrolled student', !!studentCopy)
check('student sees all four materials', studentCopy?.files?.length === 4, `(${studentCopy?.files?.length})`)
check('student sees the same file ids',
  JSON.stringify((studentCopy?.files || []).map(f => f.id)) ===
  JSON.stringify(files.map(f => f.id)))
check('student sees teacher, class and due date',
  studentCopy?.instructor_name === 'Anita Sharma' &&
  studentCopy?.student_group_name === 'Grade 8 - A' &&
  !!studentCopy?.due_date,
  `${studentCopy?.instructor_name} / ${studentCopy?.student_group_name}`)

// ── Downloads are byte-exact and scoped ─────────────────────────────
const studentPdf = call('school_connect.api.mobile.get_file', {
  sid: ssid, params: { file_id: files[0]?.id },
})
check('student downloads the PDF', studentPdf.ok && studentPdf.data?.data === PDF,
  studentPdf.ok ? studentPdf.data?.mime_type : studentPdf.error)
check('download reports the right filename and mime',
  studentPdf.data?.name === 'worksheet.pdf' && studentPdf.data?.mime_type === 'application/pdf')

const studentAudio = call('school_connect.api.mobile.get_file', {
  sid: ssid, params: { file_id: files[2]?.id },
})
check('student downloads the voice note', studentAudio.ok && studentAudio.data?.data === AUDIO,
  studentAudio.ok ? studentAudio.data?.mime_type : studentAudio.error)

const teacherVideo = call('school_connect.api.mobile.get_file', {
  sid: tsid, params: { file_id: files[3]?.id },
})
check('teacher downloads the video', teacherVideo.ok && teacherVideo.data?.data === VIDEO)

const admin = login('priya@springfield.edu', 'admin123')
const adminDownload = call('school_connect.api.mobile.get_file', {
  sid: admin.sid, params: { file_id: files[1]?.id },
})
check('school admin can download school materials', adminDownload.ok && adminDownload.data?.data === IMAGE)

const outsider = login('aarav.sharma1@student.edu', 'Student@123')
const outsiderDownload = call('school_connect.api.mobile.get_file', {
  sid: outsider.sid, params: { file_id: files[0]?.id },
})
check('student in another class is denied', !outsiderDownload.ok && outsiderDownload.status === 403,
  outsiderDownload.ok ? 'unexpectedly allowed' : `${outsiderDownload.status} ${outsiderDownload.error}`)

const anonymous = call('school_connect.api.mobile.get_file', { params: { file_id: files[0]?.id } })
check('anonymous download is denied', !anonymous.ok && anonymous.status === 401,
  anonymous.ok ? 'unexpectedly allowed' : String(anonymous.status))

// ── Updating: remove one, add one ───────────────────────────────────
const updated = call('school_connect.api.mobile.update_assignment', {
  method: 'POST',
  sid: tsid,
  body: {
    id: assignment.id,
    title: `${title} (revised)`,
    remove_file_ids: [files[2]?.id],
    files: [{ file_name: 'recap.mov', file_data: VIDEO }],
  },
})
check('update accepts remove + add', updated.ok, updated.ok ? '' : updated.error)
const updatedFiles = updated.data?.files || []
check('removed file is gone', !updatedFiles.some(f => f.id === files[2]?.id))
check('three remaining files plus the new video',
  updatedFiles.length === 4 && updatedFiles.some(f => f.name === 'recap.mov' && f.kind === 'video'),
  updatedFiles.map(f => f.name).join(', '))
check('legacy attachment follows the first file after removal',
  updated.data?.attachment === updatedFiles[0]?.id && updated.data?.attachment_name === updatedFiles[0]?.name)

// The removed blob is no longer readable even by the teacher.
const removedBlob = call('school_connect.api.mobile.get_file', {
  sid: tsid, params: { file_id: files[2]?.id },
})
check('removed material is deleted from storage', !removedBlob.ok && removedBlob.status === 404,
  removedBlob.ok ? 'still present' : String(removedBlob.status))

// ── File cap ────────────────────────────────────────────────────────
const tooMany = call('school_connect.api.mobile.create_assignment', {
  method: 'POST',
  sid: tsid,
  body: {
    title: 'Too many files',
    class_id: 'c-8a',
    files: [1, 2, 3, 4, 5].map(n => ({ file_name: `f${n}.pdf`, file_data: PDF })),
  },
})
check('more than four materials is rejected', !tooMany.ok && tooMany.status === 400,
  tooMany.ok ? 'accepted' : `${tooMany.status} ${tooMany.error}`)

const tooBig = call('school_connect.api.mobile.create_assignment', {
  method: 'POST',
  sid: tsid,
  body: {
    title: 'Oversized file',
    class_id: 'c-8a',
    files: [{ file_name: 'huge.mp4', file_data: 'A'.repeat(28 * 1024 * 1024 + 4) }],
  },
})
check('over-20MB material is rejected with 413', !tooBig.ok && tooBig.status === 413,
  tooBig.ok ? 'accepted' : `${tooBig.status} ${tooBig.error}`)

// ── Clearing and deleting ───────────────────────────────────────────
const cleared = call('school_connect.api.mobile.update_assignment', {
  method: 'POST', sid: tsid, body: { id: assignment.id, clear_attachments: true },
})
check('clear_attachments removes every material',
  cleared.ok && (cleared.data?.files || []).length === 0 && cleared.data?.attachment === null,
  `(files=${cleared.data?.files?.length}, attachment=${cleared.data?.attachment})`)

const deleted = call('school_connect.api.mobile.delete_assignment', {
  method: 'POST', sid: tsid, body: { id: assignment.id },
})
check('delete assignment succeeds', deleted.ok, deleted.ok ? '' : deleted.error)
const afterDelete = call('school_connect.api.mobile.get_teacher_assignments', { sid: tsid })
check('deleted assignment is gone from the list',
  !(afterDelete.data || []).some(a => a.id === assignment.id))

// ── Transport: a >1MB upload must pass the HTTP body limit ──────────
const server = createServer({ consoleName: 'schooladmin', port: 0, seed: null })
await new Promise(resolve => server.once('listening', resolve))
const port = server.address().port
const base = `http://127.0.0.1:${port}`

try {
  const loginRes = await fetch(`${base}/api/mobile/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'anita.sharma@springfield.edu', password: 'admin123' }),
  })
  const cookie = (loginRes.headers.get('set-cookie') || '').split(';')[0]
  check('HTTP login returns a session cookie', loginRes.status === 200 && cookie.startsWith('sid='))

  // ~2.8MB of JSON: comfortably above the old 1MB API body cap.
  const bigFile = Buffer.alloc(2 * 1024 * 1024, 7).toString('base64')
  const transportTitle = `Transport upload ${Date.now()}`
  const createRes = await fetch(`${base}/api/method/school_connect.api.mobile.create_assignment`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Cookie: cookie },
    body: JSON.stringify({
      title: transportTitle,
      class_id: 'c-8a',
      files: [{ file_name: 'transport-audio.m4a', file_data: bigFile }],
    }),
  })
  const createJson = await createRes.json()
  const transportAssignment = createJson.message
  check('2MB upload succeeds over HTTP', createRes.status === 200,
    `status=${createRes.status} ${createRes.status === 200 ? '' : JSON.stringify(createJson)}`)
  check('transport upload stores an audio material',
    transportAssignment?.files?.length === 1 && transportAssignment.files[0].kind === 'audio',
    transportAssignment?.files?.[0]?.kind)

  if (transportAssignment?.id) {
    await fetch(`${base}/api/method/school_connect.api.mobile.delete_assignment`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Cookie: cookie },
      body: JSON.stringify({ id: transportAssignment.id }),
    })
  }
} catch (err) {
  check('HTTP upload transport', false, err.message || String(err))
} finally {
  await new Promise(resolve => server.close(resolve))
}

console.log(`\n${pass} passed, ${fail} failed`)
process.exit(fail ? 1 : 0)
