# 🏭 Production Mode — Phased Rollout Plan

> Goal: run the **local Frappe Education bench** + the **Flutter app** together and
> test **every feature against real, live data** — real login, real signup, real
> database writes — with **our own email/password authentication**.
>
> We work **one phase at a time**. The user approves each phase ("ok") before we move on.

## Current State (baseline, Aug 2026)

| Layer | Status |
|-------|--------|
| Frappe bench (`~/Documents/frappe/frappe-bench`) | ✅ Running on `:8000` (`bench start`) |
| Site `library.localhost` | ⚠️ Exists but **not resolvable** — no `/etc/hosts` entry → 404 "does not exist" |
| Installed apps | `frappe`, `erpnext`, `education` (no custom app yet) |
| FastAPI bridge (`fastapi_backend/`) | ❌ Not running, not wired (replaced by direct REST) |
| Flutter app (`school_connect_app/`) | Points at `http://localhost:8000`, uses stock `/api/method/login` |
| Custom auth (login/signup) | ❌ Not implemented — stock Frappe login only, signup is a stub |
| Repo custom app (`school_connect/`) | Not installed on the local bench |

---

## Phase 1 — Backend Up & Reachable (Frappe Education live) ✅ DONE

**Objective:** `http://localhost:8000` serves the `library.localhost` site and we can authenticate as Administrator.

- [x] Make the site resolvable — **not needed**: `library.localhost` resolves natively on macOS; the real blocker was the legacy Docker stack (`school_connect_backend`) squatting on `:8000` over IPv6. Stopped it (`docker compose stop` in `school_connect/` — restartable).
- [x] Verify bench health: `GET /api/method/ping` → `pong`; `POST /api/method/login` → 200 `"Logged In"`
- [x] Confirm MariaDB + Redis are up (homebrew mariadbd + fresh bench Redis on 11000/13000), `bench migrate` clean, login no longer hangs
- [x] Write `start_backend.sh` (repo root) — idempotent, daemonizes `bench start` (setsid), waits for health, prints URLs
- [x] Portal loads: `/desk`, `/desk/education`, `/login` all respond (301/200)

**Fixes applied (root causes):**
1. Docker `school_connect_backend` hijacked `:8000` over IPv6 (localhost resolves `::1` first) → stopped legacy stack.
2. Login POST hung forever (0 bytes) — the ~12h-old bench had a wedged Redis connection in the login path (login is the only guest endpoint touching Redis via the login-attempt tracker); fresh servers log in instantly → restarted the bench.
3. Old bench Redis (11000/13000) blocked the new bench's Procfile Redis → killed stale instances.
4. Administrator password was unknown → reset to **`Admin@123`** (`admin` rejected by Frappe's "common password" policy).
   Reset command (v15 writes to `__Auth`, not the User doc; IPython `bench console` is unreliable for this):
   `cd ~/Documents/frappe/frappe-bench/sites && ../env/bin/python -c "import frappe; frappe.init(site='library.localhost', sites_path='.'); frappe.connect(); frappe.utils.password.update_password('Administrator', '<NewPass>'); frappe.db.commit()"`

**Done when:** `curl http://localhost:8000/api/method/ping` returns `"message": "pong"` and Administrator can log in via API. ✅

---

## Phase 2 — Real Seed Data (the "database everything") ✅ DONE

**Objective:** the database is populated with a realistic school, so every screen has live data to show.

- [x] **Custom app NOT installed** — the bench runs **frappe 17.0.0-dev**, and the repo's `school_connect` app is v15-era; forcing it in could destabilize a working bench. The Flutter app talks to education's native REST surface anyway, so Phase 2 seeds **education doctypes directly** (`seed_data.py`).
- [x] Write a **repeatable, idempotent seed script** → `seed_data.py` (repo root, run with the bench venv's python — plain Python, NOT `bench console`, which drops writes on this install)
- [x] Creates: Academic Year/Term, Holiday List, Grading Scale, Assessment Group/Criteria, Rooms, 2 Programs (Grade 8/9), 6 Courses, 10 **Students** (users + emails + `Student@123`), 2 **Instructors** (users + `Teacher@123`), 3 **Student Groups** (roll numbers), 10 **Program Enrollments**, 15 **Course Schedules** (Mon–Fri per group), 50 **Attendance** records, 15 **Assessment Plans**, 35 graded **Assessment Results**
- [x] **Permission fixes the app needs** (education defaults don't fit the Flutter app): teachers get `Academics User` role (plain `Instructor` can't read Course Schedules/Attendance/Assessment Plans), and Student gets read on Assessment Plan (app lists assignments via raw REST)
- [x] Credentials table → `commands.md` §3 (editing tools can't write `democred.md` on this setup)
- [x] Idempotent — re-runs verified to skip existing records

**Verified live:** teacher login → reads Course Schedules; student login → reads Assessment Plans + Attendance; Administrator → everything. Counts: Student 10 · Instructor 2 · Student Group 3 · Course Schedule 15 · Attendance 50 · Assessment Plan 15 · Assessment Result 35.

**Gotchas found (matter for later phases):**
1. v17 `Student Attendance` status options are `Present/Absent/Leave` only — **no Half Day** (app sends it → will fail live).
2. Attendance date is **overridden from the Course Schedule's `schedule_date`** (`set_date()` in the controller) — schedule dates must be real class days.
3. v17 `Assessment Plan` has **no `due_date`** (schedule_date + from/to time) and `Assessment Result` uses `comment` (not `comments`) + a `details` child table — the app's models expect the old shapes (wiring work for Phase 4/5).
4. `Student Group` field is `student_group_name` (app reads `group_name`); Student email is `student_email_id` (app reads `email`).

**Done when:** login as each role shows populated dashboards (real rows from MariaDB, not demo mode). ✅

---

## Phase 3 — Our Own Authentication (email/password login + signup) ✅ BACKEND DONE + APP WIRED

**Objective:** custom, first-party auth — no stock Frappe login screen, no demo-mode bypass.

- [x] **New custom app `sc_auth/`** (in this repo, symlinked + `pip install -e` into the bench, `install-app sc_auth` done). Endpoints under `/api/method/sc_auth.api.auth.*`:
  - `login(email, password)` (guest) — validates via Frappe's native `check_password` (hashed, never plaintext), starts a real Frappe session (sid cookie) **and** returns our **JWT** (`sc_auth_jwt_secret` site config) + profile with resolved role + linked ids
  - `signup_student(full_name, email, password, gender, student_group, ...)` (guest) — creates User (Student role) + Student (+ education's auto Customer) + class membership + Program Enrollment, auto-login; runs system writes as Administrator (education's `create_customer` hook needs it), restores guest afterwards
  - `me()` (session) — profile for session restore
  - `logout()`, `change_password(current, new)`
  - Role resolution: `System Manager` → admin · `Academics User`/`Instructor` → instructor · Student doc/role → student
- [x] Flutter wired: `api_config.dart` custom endpoints; `frappe_api_service.dart` login/signup/restore/logout/change-password all use our endpoints (sid + JWT stored in `flutter_secure_storage`); `auth_provider.dart` signup uses our endpoint; brittle profile-guessing (`get_user_info`/instructor-name-matching) removed
- [x] Verified live with curl: login (teacher/student/admin) 200s, wrong password 401, `me`, signup (created `nova.student@school.com` in Grade 9 - A), change-password then login with new password, logout invalidates session
- [x] **Build blocker fixed:** macOS deployment target was 10.13–10.15 but Xcode 27 requires ≥12.0 — bumped `macos/Podfile` to 12.0 + forced 12.0 on every pod target in `post_install` + pbxproj targets. `flutter build macos --debug` now succeeds
- [x] App role routing unchanged (already role-driven): our `role` payload maps to the existing `UserModel` parser (`System Manager`/`Instructor`/`Student`)

**Verified:** all five endpoints + full role matrix. Fresh user signup → auto-login → reads Assessment Plans + own attendance.

**Done when:** a fresh user can **sign up** and **log in** from the app, and each role lands on the correct dashboard backed by live data. — backend + wiring ✅; **from the app UI = Phase 4**.

---

## Phase 4 — Flutter App Running Against Live Backend ✅ DONE

**Objective:** the app runs against the live backend (no demo mode), with every data call hitting our custom endpoints.

- [x] **Killed demo-mode fallback** — `auth_provider.dart` no longer tries demo login first, no silent demo fallback on network error (login/signup/change-password fail loudly with the real error). `isDemoMode` stays in state but can never become true.
- [x] **New custom data API** (`sc_auth/sc_auth/api/data.py`) — shapes education data into the exact JSON the app's Dart models expect (so model churn was ~zero):
  - teacher: `my_classes`, `class_students`, `teacher_assignments`, `mark_attendance` (maps Half Day → Leave; v17 has no Half Day), `assignment_submissions`, `grade_submission`, `create/update/delete_assignment`
  - student: `my_attendance_summary` (real percentages per course), `my_attendance`, `my_assignments` (+ own submission), `submit_assignment`, `unsubmit_submission`
  - admin: `admin_dashboard` (school=program, teachers, students, classes)
  - signup pickers (guest): `programs`, `student_groups`
- [x] **New `Student Submission` doctype** (sc_auth app) — the app's submit/return/grade lifecycle (education v17 has no student-submission flow; Assessment Result is exam-grading only). Fields: student, assessment_plan, status (Submitted/Returned/Graded), score/100, feedback, submission_file, timestamps. `bench migrate` applied.
- [x] **Assignments map to Assessment Plan** (`schedule_date` → `due_date`, `examiner` → instructor, criteria = Total Marks/100).
- [x] **UserModel carries linked ids** — `student_id`, `student_groups`, `instructor_id` from the auth profile (providers previously used the *email* as the student/instructor id).
- [x] **Signup pickers live** — `signup_step3` fetches real programs/classes from the backend (was demo data).
- [x] **Login screen quick-fill updated** to the real seeded accounts (Student → `alex.smith@school.com`, Teacher → `robert.johnson@school.com`).
- [x] **`flutter build macos --debug` clean**; app launched from the built bundle.

**Verified live (curl, fresh sessions):** 17/17 endpoint checks — teacher creates assignment → student submits (file name) → teacher grades (88 + feedback) → student sees Graded → teacher deletes (cascade). Student blocked (403) from teacher endpoints. Admin dashboard returns school/2 teachers/11 students/3 classes.

**Also fixed:** `alex.smith@school.com`'s password had been changed during Phase 3 testing → all seeded accounts re-set to documented passwords (`Student@123` / `Teacher@123`).

**Note on file uploads:** student submission records the file *name* for now — real binary upload to Frappe `File` + download links is Phase 5.

**Done when:** the app boots straight into live mode and every tab loads real data. — backend + wiring ✅; app running on screen for the user's click-through (Phase 5).

---

## Phase 5 — Feature-by-Feature E2E Testing (all buttons) ✅ DONE

**Objective:** click through **every screen and button** as each role, with real writes hitting the DB, fixing bugs as we find them. Full checklist: `TESTING.md`.

- [x] **Full checklist written** → `TESTING.md` — every screen/button per role (student / teacher / admin / signup), ticked against the live backend
- [x] **App live in browser against the bench** — web build served + driven click-by-click (also proves the web target works)
- [x] **Web path fixed end-to-end**: bench CORS (`allow_cors`) + JWT **Bearer** auth (browsers strip the `Cookie: sid` header the app relied on — `before_request` hook in sc_auth sets the session from the JWT; `form_dict` preserved). PWA service worker disabled for the dev build (stale-SW serving old JS was causing phantom test failures)
- [x] **Session restore auto-navigates** — restored sessions were left staring at the login screen (and racing a manual login → MariaDB row-version 500s on `last_login`)
- [x] **Logout bug fixed** — logout cleared state *after* the async server call, so the login screen bounced straight back into the dashboard; now clears synchronously first + guard against post-dispose writes
- [x] **Web JS type bug fixed** — `AttendanceSummary.fromJson`'s `?? []` + `.map().toList()` crashed on DDC (`JSArray<dynamic>`), zeroing the whole student dashboard; rewritten to a plain cast
- [x] **roll_number coercion** — backend returns int, models expect String (`Student`, `AssignmentSubmission`, `StudentDetail`)
- [x] **Real file upload** — `submit_with_file` uploads binary to Frappe `File` and stores `file_url` on the submission (new doctype field); verified live, download link fetchable
- [x] **Student detail via API** — teacher's student-detail screen was demo-mode; now live with real attendance
- [x] **Calendar uses real attendance** — student dashboard calendar was reading `demoServiceProvider`; now live, unrecorded days neutral (not "Present")
- [x] **Attendance detail screen** — was 100% demo; new `course_attendance` endpoint + rewrite (per-course history)
- [x] **Change password + signup validation** — password ≥8 chars enforced client-side; new/confirm mismatch caught before any request
- [x] **Attendance marking updates-or-creates** — re-marking a student who already has a record for that class now *updates* instead of silently skipping
- [x] **Teacher dashboard redesign (user request)**: class name is the big bold highlight (transparent card, no blue pill), course secondary; roster + attendance lists sorted **roll-number order (1, 2, 3…)**; student detail filtered to **that teacher's subject only** (attendance % + tests/grades for the course, via `student_detail` `course` filter)
- [x] **Admin class cards wired** — chevron was dead UI; now opens the class's students
- [x] **Profile screen** — hardcoded "Springfield High" row replaced with the student's real class
- [x] **Change-password E2E verified live** (old → 401, new → 200, reverted), grading E2E (88 + feedback), attendance update (Sophia → Absent) — all real DB writes
- [x] **Student dashboard reliability & calendar overhaul (user request):**
  - *Empty-until-tab-switch fixed* — the dashboard load was a one-shot (`_hasLoaded`) that never retried a transient first failure; now session-gated (`_loadWhenReady`) with bounded auto-retry, so the first paint has data
  - *Future-day attendance fixed* — seed created schedules from *next Monday*, so all attendance was future-dated (and counted in % / painted on the calendar); backend now excludes `date > today` from summary/history/month, the seed only writes past records (and deletes future ones), and the UI keeps future days neutral
  - *Month navigation now real* — new `my_attendance_month(year, month)` endpoint + per-month fetch on ‹ › arrows (spinner + retry row); seed adds ~4 weeks of past schedules/attendance per group (July/August history for Alex, so previous months have data)
  - *Tap-a-day feature* — new `assignments_on_date(date)` endpoint; tapping any calendar day opens a bottom sheet with that day's attendance status and every assignment scheduled on it (title, course, class, 12h time, submission chip)
  - Seed hardening: history schedules use afternoon slots + disjoint per-group week windows (2 instructors, 3 groups — education validates instructor/room overlaps), `my_classes` now returns only upcoming classes, 3 past-dated Assessment Plans per group

**Bugs found & fixed during the walkthrough** are listed above; each was re-tested green before ticking.

**Done when:** every checklist row is ticked green with live data. ✅

---

## Phase 6 — Production Hardening & Polish

**Objective:** make the local "production mode" robust and pleasant, not just working.

- [x] Student dashboard reliability (session-gated load + auto-retry), future-date attendance filtering, calendar month navigation with real history, tap-a-day assignments sheet
- [ ] More E2E rows as features land (signup → student walkthrough is ticked; admin screens deep pass pending)
- [ ] Secrets: real JWT signing key, no plaintext passwords anywhere, `.env`-driven config
- [ ] Error states & loading UX polish (offline banner, retry, pull-to-refresh everywhere)
- [ ] Backups: `bench backup` script + documented restore
- [ ] Startup: one command brings up backend + app (`start.sh`)
- [ ] Update `README.md` / `DOCUMENTATION.md` to match the live architecture
- [ ] Final full-stack smoke test (restart everything cold, run the checklist once more)

**Done when:** a cold boot of backend + app passes the full checklist.

**Objective:** make the local "production mode" robust and pleasant, not just working.

- [ ] Secrets: real JWT signing key, no plaintext passwords anywhere, `.env`-driven config
- [ ] Error states & loading UX polish (offline banner, retry, pull-to-refresh everywhere)
- [ ] Backups: `bench backup` script + documented restore
- [ ] Startup: one command brings up backend + app (`start.sh`)
- [ ] Update `README.md` / `DOCUMENTATION.md` to match the live architecture
- [ ] Final full-stack smoke test (restart everything cold, run the checklist once more)

**Done when:** a cold boot of backend + app passes the full checklist.

---

## How we execute

1. User says **"ok"** on a phase → we do the work in that phase only.
2. We verify against the phase's **Done when** criteria before reporting back.
3. User approves the next phase (or asks for fixes) → repeat.
