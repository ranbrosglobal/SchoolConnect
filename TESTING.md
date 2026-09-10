# 🧪 TESTING.md — Feature-by-Feature E2E Checklist

Every row is a real button/screen tested against the **live backend**
(`http://localhost:8000`, Frappe Education v17 + `sc_auth` custom app).

**How to run the app:** backend up (`bench start`) → build & serve the web app
(`flutter build web --debug --pwa-strategy none`, serve `build/web`), or
`flutter run -d macos`. Quick accounts (full table in `commands.md` §3):

> **Offline demo replica:** the same screens can be tested **without any
> backend** in `demoapp/` (`cd demoapp && flutter run -d macos`) — it runs on a
> local SQLite DB seeded with `alex.smith@school.com` / `Student@123` and
> `robert.johnson@school.com` / `Teacher@123` (see `DOCUMENTATION.md` §12).

| Role | Login |
|---|---|
| Student | `alex.smith@school.com` / `Student@123` |
| Teacher | `robert.johnson@school.com` / `Teacher@123` |
| School Admin | `sunrise.admin@school.com` / `Admin@12345` (Sunrise · library, port 8000) |
| School Admin | `oakridge.admin@school.com` / `Admin@12345` (Oakridge · port 8001) |
| Super Admin | `super.admin@school.com` / `Super@12345` (registry site, port 8002) |

Legend: ✅ passed live · ⚠️ partial / manual step · 🔧 bug found & fixed in this phase

---

## 1. Auth (all roles)

- [x] ✅ Login screen renders (toggle, email/password, show/hide, quick-fill panel)
- [x] ✅ Login as **student** → lands on Student Dashboard (live data)
- [x] ✅ Login as **teacher** → lands on Teacher Dashboard (live data)
- [x] ✅ Wrong password → 401, real error shown (no silent demo fallback)
- [x] ✅ Session **restore**: reload with a saved session auto-navigates to the role dashboard
  - 🔧 *Bug:* restored sessions left the user on the login screen → fixed (auto-navigate on restore)
- [x] ✅ **Logout** → clears state, returns to login screen
  - 🔧 *Bug:* logout bounced straight back to the dashboard (async logout raced the
    restore auto-navigation) → fixed (state cleared synchronously)
- [x] ✅ **Change password** (Profile → Change Password): wrong confirm caught by validation;
  real change works (old password 401, new 200), then reverted to the documented password
  - 🔧 *Bug:* client allowed 6-char passwords but the backend requires 8 → aligned to 8
- [x] ✅ JWT bearer auth + CORS verified from the browser (web build talks to `:8000`)

## 2. Student

- [x] ✅ Dashboard: assignment count, attendance % (real, now 90% with history), subject-wise cards, calendar
  - 🔧 *Bug:* dashboard showed **all zeros** — `AttendanceSummary.fromJson` crashed on web
    (`JSArray` not `List<MonthlyAttendance>`), swallowing the whole load → fixed parse
  - 🔧 *Bug:* calendar read the **demo data service** → now real attendance rows
  - 🔧 *Bug:* dashboard stayed **empty until the tab was re-opened** after a transient
    first-load failure (one-shot `_hasLoaded` never retried) → load is now session-gated
    and auto-retries (bounded), so the first paint has data
- [x] ✅ Calendar: **month navigation** (‹ › arrows) fetches each month from the backend
  (`my_attendance_month`) with a tiny spinner — July history shows real records
- [x] ✅ Calendar: **future days stay neutral** — no more "absent" on upcoming dates
  (backend now excludes future-dated records from summary/history/month; UI also guards)
- [x] ✅ **Tap any calendar day** → bottom sheet with that day's attendance status +
  every assignment scheduled on it (title, course, class, 12h time, submission chip);
  "No assignments on this day" when empty
- [x] ✅ Assignments tab: Pending (Overdue states correct) / Completed tabs, status chips
- [x] ✅ Assignment detail: badges (Submitted/Returned/Graded/Deadline), due date, **real file
  upload** (file name + timestamp shown), submit confirmation dialog
- [x] ✅ **File upload**: real binary upload to the Frappe file store
  (`submit_with_file`), file fetchable at its URL
- [x] ✅ Results tab: average card + grade cards (empty until a teacher grades; verified after
  grading below)
- [x] ✅ Profile: name/email, class (real student group, not "Springfield High"), settings,
  change password, notifications/help (info snackbars), logout
  - 🔧 *Bug:* profile showed hardcoded "Springfield High" → shows real class now
- [x] ⚠️ Attendance history screen (`attendance_detail_math`) rewired to real
  `course_attendance` data (verified at API level; UI smoke-tested)

## 3. Teacher

- [x] ✅ My Classes: class cards with **class name as the main highlight** (bold, larger,
  transparent — no blue pill), course + time secondary, Attendance/Students buttons
  - 🔧 *Bug:* "Attendance" label wrapped as "Attendanc e" → single-line button labels
- [x] ✅ **Mark Attendance**: students listed **roll-number order (1, 2, 3 …)**, P/A/H per
  student, All Present / All Absent, Save writes to DB
  - 🔧 *Bug:* saving attendance silently skipped everyone with an existing record → now
    **updates** the existing record ("2 created, 0 updated" verified in DB)
- [x] ✅ Class Roster: students **roll-number sorted**, name + email, tap → student detail
  - 🔧 *Bug:* roster showed "No students found" — `roll_number` came back as an **int** and
    crashed `StudentModel.fromJson` on web → coerced to String (also fixed
    `StudentDetailModel` + `AssignmentSubmissionModel`)
- [x] ✅ **Student detail from roster**: shows **only that subject** (Science class →
  Science attendance only), subject badge, attendance % + tests/grades for that course
  (backend `student_detail(student, course)` filter verified via API)
- [x] ✅ Assignments: list with course/class chips, due date, submitted/total progress,
  submission detail with stats (Total/Submitted/Graded)
- [x] ✅ Submissions: per-student status chips, grade dialog (score + feedback), return flow
- [x] ✅ **Grading round trip**: teacher graded Alex's CS submission (88 + feedback) →
  student's Results tab now shows it (verified in API; UI reads same data)
- [x] ✅ Create/edit/delete assignment → Assessment Plan lifecycle (API-verified in Phase 4)

## 4. Admin (web app — not on mobile)

The school admin dashboard **lives in the web app** (`schooladmin/`, dev at
`http://localhost:5173`), not the mobile app. Mobile users who log in as
admin/school admin land on a redirect screen pointing to the web URL.

- [x] ✅ Mobile: school admin login → `AdminWebRedirect` screen ("Admin dashboard is on the web" + URL + logout)
- [x] ✅ Super admin (mobile): registry portal — list schools, register school + provision admin,
  reset admin password (applied on the school's own DB), remove school
- [x] ✅ School admin web dashboard (via `schooladmin` app, API-verified): overview stats,
  teachers/students/classes, class student list

## 5. Signup E2E

- [x] ✅ Signup Step 1–4 flow: name/email/password (min 8), age/gender/city/state/country,
  **real school + class pickers** (from the backend, not demo), review screen
  - 🔧 *Bug:* step 3 used demo schools → real `programs`/`student_groups` endpoints
  - 🔧 *Bug:* city/state/country collected but never sent → now stored on the Student
- [x] ✅ Create Account → auto-login → student dashboard
- [x] ✅ Duplicate email → "account already exists" (verified via API in Phase 3)

## 6. Backend API suite (curl)

- [x] ✅ Auth: login / signup / me / logout / change_password (all roles, 401s on bad creds)
- [x] ✅ Data: my_classes (upcoming only), class_students, mark_attendance (create **and update**),
  course_attendance, my_attendance_summary (future-dates excluded), my_attendance,
  **my_attendance_month** (per-month calendar), **assignments_on_date** (tap-a-day),
  my_assignments, teacher_assignments, create/update/delete_assignment,
  assignment_submissions, submit/unsubmit/delete_submission, grade_submission,
  student_detail (with + without `course` filter), submit_with_file (real upload),
  admin_dashboard, programs, student_groups
- [x] ✅ Role enforcement: students blocked (403) from teacher endpoints
- [x] ✅ Guest blocked (403) from authed endpoints; guest OK on signup pickers

## Known remaining items (not regressions)

- ⚠️ File picker opens the OS/browser dialog — automated E2E covers the submit API + UI up to
  the picker; the picker itself needs a human click.
- ⚠️ `attendance_detail_math` is reachable via the route but not linked from a button yet.
- ℹ️ "5-day streak!" text on the student dashboard is still decorative copy.
- ℹ️ Social login buttons (Google/Apple/Facebook) and "Forgot Password" are decorative.
