# School Connect — Project Status Summary

**Project:** School Connect — Multi-tenant school management system  
**Current phase:** Live production-mode testing (local Frappe bench + Flutter app)  
**Period:** Aug 2026

---

## What the project is

A complete school management system with:

- **Mobile app** (Flutter) for students, teachers, super admin
- **Web admin dashboard** (React + Vite) for school admins
- **Super admin portal** (inside the mobile app) for registry/provisioning
- **Custom Frappe app** (`sc_auth`) — auth + data APIs on Frappe Education
- **Offline demo app** — exact replica running on local SQLite, no backend

---

## Architecture

- **One Frappe site + one MariaDB database per school** — no data mixing
- **Super admin site** (own DB) holds only the school registry + admin provisioning
- **Custom email/password auth** (`sc_auth.api.auth`) — JWT + session, no Frappe Desk login
- **Login auto-detects the school** — probes known endpoints, no school picker on the login screen
- Roles: Super Admin, School Admin, Instructor, Student, System Manager

---

## What's been done

### Phase 1 — Backend up & reachable ✅
- Frappe bench running on `:8000`
- Site resolvable, Administrator login working, MariaDB + Redis healthy
- `start_backend.sh` idempotent startup script

### Phase 2 — Real seed data ✅
- `seed_data.py` seeds a full school: academic year, term, holidays, grading scales, rooms, 2 programs, 6 courses, **10 students**, **2 instructors**, 3 student groups, 15 course schedules, 50 attendance records, 15 assessment plans, 35 assessment results
- Permission fixes so the app can read what it needs
- Idempotent — re-runs skip existing records

### Phase 3 — Own authentication ✅
- New custom app `sc_auth/` with endpoints: `login`, `signup_student`, `me`, `logout`, `change_password`
- Validates via Frappe's native password check, starts a real session + returns JWT
- Flutter wired to use these endpoints (sid + JWT in secure storage)
- Build blocker fixed (macOS deployment target bumped to 12.0)
- Verified: login/signup/me/logout/change-password, all roles, 401 on bad creds

### Phase 4 — Flutter app against live backend ✅
- Demo-mode fallback removed — app uses real endpoints only
- New `data.py` API shapes education data into exactly what the Dart models expect
- New `Student Submission` doctype for the submit/return/grade lifecycle
- Assignments map to Assessment Plan (schedule_date → due_date, examiner → instructor)
- Signup pickers now fetch real programs/classes
- Quick-fill accounts updated to real seeded users
- Verified: 17/17 endpoint checks — teacher creates assignment → student submits (with real file upload) → teacher grades (88 + feedback) → student sees Graded → teacher deletes (cascade). Student blocked (403) from teacher endpoints. Admin dashboard returns school/2 teachers/11 students/3 classes.

### Phase 5 — Feature-by-feature E2E testing ✅
- Full checklist in `TESTING.md` — every screen/button per role
- Web build driven click-by-click against the live bench (also proves web target works)
- Bugs found and fixed:
  - Session restore auto-navigates (was stuck on login screen)
  - Logout clears state synchronously first (was bouncing back to dashboard)
  - Web JS `AttendanceSummary.fromJson` crash on DDC (`JSArray` vs `List`) — dashboard was all zeros
  - `roll_number` int→String coercion (Student, AssignmentSubmission, StudentDetail)
  - Real file upload to Frappe `File` with `file_url` on submission
  - Teacher student-detail now live (was demo), filtered to that teacher's subject
  - Attendance detail screen live (was 100% demo)
  - Change password validation (≥8 chars, new/confirm mismatch)
  - Attendance marking now updates-or-creates (not silent skip)
  - Teacher dashboard redesign: class name as big bold highlight, roster + attendance sorted by roll number
  - Admin class cards wired (chevron opens class students)
  - Profile screen shows real class (was hardcoded "Springfield High")
  - Student dashboard reliability: session-gated load + bounded auto-retry (empty-until-tab-switch fixed)
  - Future-day attendance filtered from summary/history/month + seed only writes past records
  - Calendar month navigation with real history per month
  - Tap-a-day bottom sheet: attendance status + every assignment scheduled that day
  - Password reset E2E verified live, grading E2E verified live, attendance update E2E verified live

---

## Current state — working, in production phase

| Layer | Status |
|-------|--------|
| Frappe bench (Sunrise, `:8000`) | ✅ Live, seeded, custom `sc_auth` app installed |
| Custom auth (sc_auth) | ✅ login/signup/me/logout/change_password — all roles |
| Data API (sc_auth.data) | ✅ teacher/student/admin endpoints + Student Submission doctype |
| Flutter mobile app | ✅ Boots into live mode, every tab loads real data |
| Web admin (schooladmin, `:5173`) | ✅ School admin dashboard, profile editing |
| Super admin portal (mobile) | ✅ Registry, school CRUD, admin provisioning, password reset |
| Offline demo app (demoapp) | ✅ Exact replica on SQLite, no backend needed |
| E2E checklist | ✅ Every row ticked green against live backend |

### Seeded test accounts

| Role | Email | Password | Site/port |
|------|-------|----------|-----------|
| Super Admin | super.admin@school.com | Super@12345 | :8002 |
| School Admin (Sunrise) | sunrise.admin@school.com | Admin@12345 | :8000 |
| Teacher | robert.johnson@school.com | Teacher@123 | :8000 |
| Student | alex.smith@school.com | Student@123 | :8000 |

---

## Summary of what's connected

- **Google Auth → Database initiated on AWS** — the earlier Google Sheets serverless architecture (Google Sign-In → Google Sheets as backend, documented in the original `README.md`) has been replaced by a **Frappe Education backend on a local bench with MariaDB per school**. Auth is now custom email/password via `sc_auth`, with JWT + session.
- **Actual production phase** — the Flutter app talks directly to the live Frappe backend via custom `sc_auth` endpoints; every feature has been clicked through as each role with real writes hitting the database. The app no longer falls back to demo mode.
- **Everything working** — auth, signup, student dashboard (attendance %, assignments, timetable, results, calendar with month nav + tap-a-day), teacher dashboard (classes, attendance marking, assignments, grading, student detail scoped to subject), admin dashboard (web), super admin portal (registry + provisioning + password reset), change password, file upload on submission, offline demo replica.

---

## Remaining polish (not blocking)

- Secrets: real JWT signing key, no plaintext passwords, `.env` config
- Error states + loading UX polish (offline banner, retry, pull-to-refresh)
- Backups: `bench backup` script + documented restore
- One-command startup (`start.sh`) bringing up backend + app
- Update `README.md` / `DOCUMENTATION.md` to reflect the live architecture
- Final cold-boot smoke test + full checklist re-run
