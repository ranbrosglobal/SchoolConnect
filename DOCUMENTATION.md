# 🎓 School Connect — Complete Project Documentation

> **Current state (final):** the project now runs a **live, multi-tenant** school
> management system with custom auth. Each school has its **own Frappe site +
> own MariaDB database**, there is a separate **super-admin registry** database,
> and a **local SQLite-only demo replica** (`demoapp/`) that runs fully offline
> with no backend at all.
>
> Everything is in the actual production phase: the Flutter app talks directly to
> the live Frappe backend via the `sc_auth` custom app's endpoints, every feature
> has been clicked through as each role with real writes hitting the database, the
> app no longer falls back to demo mode, assignment upload/download work end-to-end,
> and a Study Assistant chatbot (Messages tab) is wired to the student's real data.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Technology Stack](#2-technology-stack)
3. [System Architecture (multi-tenant)](#3-system-architecture-multi-tenant)
4. [Repository Structure](#4-repository-structure)
5. [Authentication & Roles](#5-authentication--roles)
6. [Multi-Tenant Data Model](#6-multi-tenant-data-model)
7. [School Profile & Branding](#7-school-profile--branding)
8. [Mobile App — Screens & Features](#8-mobile-app--screens--features)
9. [Backend API Reference (sc_auth)](#9-backend-api-reference-sc_auth)
10. [Web Admin Dashboard (schooladmin)](#10-web-admin-dashboard-schooladmin)
11. [Super Admin Portal](#11-super-admin-portal)
12. [The Demo App (demoapp — offline SQLite replica)](#12-the-demo-app-demoapp--offline-sqlite-replica)
13. [Running the Full Stack](#13-running-the-full-stack)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Project Overview

School Connect is a complete school management system:

- **Mobile app** (Flutter, `school_connect_app/`) for **students** and
  **teachers** — attendance, assignments, timetable, results, school info.
- **Web admin dashboard** (React/Vite, `schooladmin/`) for **school admins** —
  school data, teachers, classes, students, and school profile editing.
- **Super Admin portal** (inside the mobile app) — a registry site that creates
  schools, provisions school-admins, and manages their passwords.
- **Custom email/password authentication** — no Frappe Desk login for users.
  The app auto-detects which school database a user belongs to at login.
- **Demo app** (`demoapp/`) — an exact offline replica of the mobile app that
  runs entirely on a local on-device SQLite database (no API, no backend).

---

## 2. Technology Stack

| Layer | Technology |
|-------|-----------|
| Backend | Frappe Framework v17 + Education + ERPNext (`sc_auth` custom app) |
| Databases | One MariaDB **per school** (Frappe site), plus one for the super-admin registry |
| Auth | Custom `sc_auth.api.auth` — email/password, session `sid` + JWT |
| Mobile | Flutter (Riverpod state management) |
| Web admin | React + Vite (`schooladmin/`) |
| Demo app | Flutter + `sqflite` (on-device SQLite, `demoapp/`) |
| Cache | Redis (bench cache :13000, queue :11000) |

---

## 3. System Architecture (multi-tenant)

```
                        ┌─────────────────────────────────────┐
                        │      Super Admin site (:8002)       │
                        │   superadmin.localhost              │
                        │   DB: superadmin_db                 │
                        │   - School registry (all schools)   │
                        │   - School Admin provisioning       │
                        └───────────┬─────────────────────────┘
                                    │ registry (public_schools)
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
┌───────▼────────┐         ┌────────▼────────┐         ┌────────▼────────┐
│  Sunrise (:8000)│         │ Oakridge (:8001)│         │  School 3...    │
│ library.localhost│        │ oakridge.localhost│       │ own site + DB   │
│ DB _cc9646d2…  │         │ DB: oakridge_db │         │                 │
│ Students,      │         │ Students,      │         │                 │
│ Teachers,      │         │ Teachers,      │         │                 │
│ classes, etc.  │         │ classes, etc.  │         │                 │
└───────┬────────┘         └────────┬────────┘         └─────────────────┘
        │                           │
        └─────────── Flutter mobile app (auto-detects school at login)
                    + web admin dashboard (schooladmin, :5173)
```

**Key design decisions:**

- **One site + one database per school.** All of a school's data (school
  admin, teachers, students, classes, schedules, attendance, assignments) lives
  in that school's own Frappe site/database. No data is ever mixed across
  schools.
- **Super admin has its own site + database** (`superadmin.localhost`,
  `superadmin_db`) holding only the registry: schools, their admin emails, and
  provisioning info. It never contains student/teacher data.
- **Each site runs on its own port locally** (`bench serve --port <n>`):
  8000 = Sunrise, 8001 = Oakridge, 8002 = Super Admin.
- **The mobile app finds the right school automatically** — the login screen no
  longer asks the user to pick a school/server. It probes the known school
  endpoints in order (with the super-site registry as the source of truth) and
  logs the user into the site that authenticates them. The school's name +
  logo then appear on the home screen and settings.

---

## 4. Repository Structure

```
schoolmanage/
├── school_connect_app/      # Flutter mobile app (students, teachers, super admin)
├── schooladmin/             # React/Vite web admin dashboard (school admins)
├── demoapp/                 # Offline replica of the mobile app (SQLite only)
├── sc_auth/                 # Frappe custom app (auth + data API + doctypes)
├── seed_data.py             # idempotent demo-data seeder for the bench
├── DOCUMENTATION.md         # this file
├── commands.md              # every command: bench, builds, emulators, logins
└── TESTING.md               # feature-by-feature E2E checklist
```

### sc_auth (Frappe app)

```
sc_auth/sc_auth/
├── api/
│   ├── auth.py              # login / signup_student / me / logout / change_password
│   ├── data.py              # all student/teacher/admin data endpoints
│   └── superadmin.py        # super-admin endpoints: schools CRUD, admin provisioning,
│                            #   reset passwords, public_schools registry feed
└── school_connect_auth/
    ├── doctype/
    │   ├── school/          # registry entry (super site only)
    │   ├── school_profile/  # single doc per school site: name, logo, contact, address
    │   └── student_submission/  # assignment submissions (submit/return/grade)
    └── ...
```

### Mobile app structure

```
school_connect_app/lib/
├── config/api_config.dart       # base URLs, known schools, web admin URL
├── models/                      # user, school, student, instructor, groups,
│                                #   schedules, attendance, assignments,
│                                #   submissions, school_profile, timetable, ...
├── services/frappe_api_service.dart  # the single data layer (live build)
├── state/                       # Riverpod providers (auth, school, teacher, student)
├── screens/                     # login, student dashboard, teacher dashboard,
│                                #   student profile/settings, student timetable,
│                                #   super_admin_portal, admin_web_redirect, ...
└── widgets/school_header.dart   # school logo + name header (dashboards)
```

---

## 5. Authentication & Roles

### Custom email/password auth (sc_auth)

Users never log in via Frappe Desk. Our own flow:

| Endpoint | Purpose |
|----------|---------|
| `POST /api/method/sc_auth.api.auth.login` | `{email, password}` → profile + `sid` + JWT |
| `POST /api/method/sc_auth.api.auth.signup_student` | self-registration (creates Student + User + auto-login) |
| `GET /api/method/sc_auth.api.auth.me` | session profile |
| `POST /api/method/sc_auth.api.auth.logout` | end session |
| `POST /api/method/sc_auth.api.auth.change_password` | `{current_password, new_password}` (old → new → confirm flow in the app) |

### Auto-detect school at login

The login screen has **no school/server picker**. On submit the app:

1. Asks the super site (`:8002`) for the public school list (`public_schools`).
2. Probes each school's login endpoint until one authenticates the credentials
   (each school's DB is queried; wrong-school logins fail fast).
3. Switches `ApiConfig.activeBaseUrl` to that school and stores the session.
4. From then on, the **school name + logo** (from that school's
   `School Profile`) show on the home dashboard and in settings.

### Roles

| Role | Where they live | What they can do |
|------|-----------------|------------------|
| **Super Admin** | super-admin site DB | registry: create schools, provision school admins, reset their passwords |
| **School Admin** | their school's DB | web admin dashboard (school data, profile editing); mobile shows a redirect |
| **Instructor** | their school's DB | teacher app: classes, attendance, assignments, grading |
| **Student** | their school's DB | student app: attendance, assignments, timetable, results, school info |
| **System Manager** | any site | Frappe Desk / everything (dev use) |

**Password reset (school admin):** the school admin can change their own
password in the app (Settings → Change Password) with the exact
old-password → new-password → confirm-new flow. The **Super Admin** can reset
any school admin's password from the portal (works across sites, verified E2E).

---

## 6. Multi-Tenant Data Model

### Per-school site (library.localhost / oakridge.localhost / …)

Everything for a school lives in its own DB:

- `User` (school admin, instructors, students) — with `sc_auth` role tags
- `Student`, `Instructor`, `Student Group` (classes), `Program`
- `Course Schedule` (class-subject slots with teacher, room, time)
- `Assessment Plan` (assignments) + `Student Submission` (sc_auth doctype)
- `Student Attendance` (per student per schedule per date)
- `School Profile` — **single doc**: school name, motto, logo, contact email,
  contact number, website, address

### Super-admin site (superadmin.localhost)

- `School` registry doc: name, `base_url`, `site`, `db_name`,
  school-admin email (and password when provisioned), status

### Demo app (SQLite)

The demo app mirrors this shape in one local DB file on the device:

```
users, groups, students, instructors, schedules, attendance,
plans (assignments), submissions, school_profile
```

---

## 7. School Profile & Branding

The **School Profile** (single doc on each school site) drives branding across
the app:

- **Student & teacher dashboards** show the school **logo + name** in the
  header (`widgets/school_header.dart`).
- **Settings / Profile** shows School Information: logo, name, contact email,
  contact number, website, address.
- **School Admin** edits all of this from the web admin dashboard (logo via
  file upload). Changes reflect immediately in the mobile app (fetched live).

Endpoints:

| Endpoint | Purpose |
|----------|---------|
| `GET /api/method/sc_auth.api.data.school_profile` | guest-readable profile for the site |
| `POST /api/method/sc_auth.api.data.update_school_profile` | school admin / instructor / system manager |
| `POST /api/method/sc_auth.api.data.upload_school_logo` | multipart logo upload → stored URL |

---

## 8. Mobile App — Screens & Features

### Login (`6_login_screen.dart`)

- Email + password only (**no school/server selector** — auto-detect).
- Sign up (student) → email, name, password, gender, class.
- Super Admin Portal entry point (dropdown switch), demo-account quick logins.

### Student

- **Home dashboard**: school header, attendance %, assignments, upcoming
  classes. Data loads immediately at login (no blank-until-tab-switch bug).
- **Attendance**: monthly calendar, **previous months** navigable, tap any date
  → assignments scheduled that day. Future dates are never marked absent.
- **Assignments**: list with status, detail, submit with file, resubmit after
  return, graded results.
- **Timetable**: weekly grid — every subject, its teacher, room, time (12-hour
  `hh:mm AM/PM`, no seconds).
- **Results**: averages + subject-wise.
- **Profile/Settings**: school name + logo, school contact info (email, phone,
  address), change password.

### Teacher

- **My Classes** (`teacher_dashboard_my_classes.dart`): class name is the main
  highlight — bigger + bolder, no background box (transparent).
- **Class box** → Attendance: student list **ordered by roll number** as
  entered by the admin, indexed 1, 2, 3… with names.
- **Class roster**: students sorted/optimized by roll number.
- **Student detail** (tap a student in the roster): shows **only that
  teacher's subject** — e.g. a Science teacher sees Science attendance, tests,
  grades only — not other subjects.
- **Times** displayed in 12-hour format (`hh:mm AM/PM`, no seconds).
- **Assignments**: create / edit / delete, filter & sort, progress.
- **Submissions**: grade (0–100) + feedback, re-grade, return, delete.

### School Admin (mobile)

- Mobile shows a redirect screen: **"Admin dashboard is on the web"** with the
  web URL (`http://localhost:5173`) and a logout button. The dashboard itself
  lives in the `schooladmin/` web app.
- Settings → **Change Password** (old → new → confirm).

### Super Admin (mobile)

Full portal (`super_admin_portal.dart`):

- List all registered schools with their admins.
- **Add school** (name, base URL, site, DB, admin email) → provisions the
  school-admin user on that school's site.
- **Edit school** details.
- **Reset school admin password** — applies on the school's own DB; the admin
  then logs in with the new password (verified E2E).
- **Delete school** from the registry.

---

## 9. Backend API Reference (sc_auth)

All endpoints are JSON (except file uploads), session auth via
`Cookie: sid=…` or `Authorization: Bearer <jwt>` from `login`.

### auth.py

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `sc_auth.api.auth.login` | email/password → profile + sid + JWT |
| POST | `sc_auth.api.auth.signup_student` | self-registration |
| GET | `sc_auth.api.auth.me` | session profile |
| POST | `sc_auth.api.auth.logout` | end session |
| POST | `sc_auth.api.auth.change_password` | old → new |

### data.py

| Endpoint | Purpose |
|----------|---------|
| `my_classes` | teacher's course schedules |
| `class_students` | roster for a schedule's group |
| `teacher_assignments` | teacher assignment list + stats |
| `create_assignment` / `update_assignment` / `delete_assignment` | assignment lifecycle |
| `mark_attendance` | mark P/A/L |
| `assignment_submissions` / `grade_submission` / `unsubmit_submission` / `delete_submission` | submissions + grading |
| `my_attendance_summary` / `my_attendance` / `my_assignments` / `submit_assignment` / `submit_with_file` / `course_attendance` | student views (summary excludes future dates) |
| `my_attendance_month` | one month of attendance for the calendar |
| `assignments_on_date` | assignments for a tapped date |
| `admin_dashboard` | school/teachers/students/classes (school-admin scoped) |
| `programs` / `student_groups` | signup pickers (guest) |
| `student_detail` | student detail with optional `course` filter (subject-scoped for teachers) |
| `school_profile` / `update_school_profile` / `upload_school_logo` | school branding + contact info |
| `my_timetable` | weekly timetable with teachers + subjects |

### superadmin.py

| Endpoint | Purpose |
|----------|---------|
| `public_schools` | registry feed for login auto-detect (guest) |
| `schools` | list all registered schools |
| `create_school` | register school + provision admin on its site |
| `update_school` | edit registry entry |
| `reset_school_admin_password` | reset admin password on the school's DB |
| `delete_school` | remove from registry |

> School-admin endpoints elevate to a read scope for the education doctypes
> inside the role-gated functions (`_require_role("School Admin", …)`) so the
> admin dashboard can see students/teachers/classes without owning per-doctype
> permissions.

---

## 10. Web Admin Dashboard (schooladmin)

The `schooladmin/` folder is a **React + Vite** web app — the real home of the
school admin dashboard. It proxies `/api` to the bench (`:8000`).

- Run: `npm run dev` in `schooladmin/` → `http://localhost:5173`
- Features: overview stats, teachers + their classes, classes + rosters
  (roll-number sorted), students, and **school profile editing** (name, logo,
  contact email/number, website, address).
- Mobile: school admins are redirected here (`admin_web_redirect.dart` shows
  the URL).

---

## 11. Super Admin Portal

Inside the mobile app (Super Admin role). It talks to the super site
(`:8002`, own database):

- Schools CRUD + per-school admin provisioning.
- Admin password reset (cross-site, writes to the school's DB).
- The login screen's auto-detect uses this site's `public_schools` to know
  which school endpoints to probe.

---

## 12. The Demo App (demoapp — offline SQLite replica)

`demoapp/` is an **exact replica of the mobile app** with **no API and no
backend**: every screen works against a **local SQLite database stored on the
device**.

### How it works

- `lib/services/local_db.dart` — schema + seeding. Tables mirror the Frappe
  model: `users`, `groups`, `students`, `instructors`, `schedules`,
  `attendance`, `plans`, `submissions`, `school_profile`.
  - Android/iOS: native `sqflite` (real on-device `.db` file).
  - macOS/Linux/Windows: `sqflite_common_ffi`.
  - Web: in-memory SQLite via `sqflite_common_ffi_web` (wasm).
- `lib/services/frappe_api_service.dart` — rewritten as the **offline data
  layer**: same class name, same method signatures, same models as the live
  app, so **every screen works unchanged**. Zero `http` calls; the database IS
  the backend.
- `lib/state/` providers are identical — `auth_provider` etc. all resolve
  against the local service.

### Seeded demo accounts

| Email | Password | Role | Classes |
|-------|----------|------|---------|
| `alex.smith@school.com` (10 students, `*@school.com`) | `Student@123` | Student | Class 8-B, 9-A, 11-C |
| `robert.johnson@school.com` | `Teacher@123` | Instructor | Maths: Class 8-B + Class 9-A |
| `sarah.mitchell@school.com` | `Teacher@123` | Instructor | Physics: Class 11-C |

Seed data includes: Sunrise Public School profile (with a bundled logo,
contact email/number, website, address), 3 realistic classes (**Class 8 - B**,
**Class 9 - A**, **Class 11 - C**), 10 students with roll numbers, 2 teachers
(Mathematics ×2, Physics ×1), 6 weeks of schedules (Mon–Fri per class),
attendance history (past dates only, varied Present/Absent/Leave/Half Day),
and per-class assignments (2 graded in the past, 1 due soon, 1 upcoming) with
submissions, scores and feedback. The DB is created and seeded automatically
on first launch; the schema version is bumped on seed changes so existing
installs refresh automatically.

### Demo app — login & exports

- **Clean login** — no Google/Apple/Facebook social buttons (removed); only
  email/password, signup, and the Try-Demo-Account quick login.
- **Teacher exports** (share icon on the **class roster** screen and on
  **Mark Attendance**):
  - **PDF** — download (to the system Downloads folder on desktop / browser
    download on web), **share**, or **print** directly (system print dialog).
    **Share opens the full OS share sheet** with every installed app that
    accepts files — WhatsApp, Gmail, Drive, Files, mail clients, etc. On
    mobile that's the native sheet (`share_plus`); on web it uses the
    **Web Share API** (`navigator.canShare`/`share` with the file attached,
    e.g. mobile Chrome/Edge/Safari, desktop Chrome & Edge), falling back to a
    browser download only where the API isn't supported (e.g. desktop Safari).
  - **Excel (.xlsx)** and **CSV** — share to any app.
  - Report contents: **school name, logo, phone, email, website and address**
    (from the local School Profile), class name, subject, teacher, room,
    date, per-student table (roll no, name, + status for attendance sheets),
    summary (total/present/absent/half-day/leave + % for attendance).
  - Backed by `lib/services/export_service.dart` (`pdf`, `printing`,
    `share_plus`, `csv`, `excel`, `path_provider` packages) and the shared
    `lib/widgets/export_sheet.dart` sheet.

### Run the demo app

```bash
cd demoapp
flutter pub get
flutter run -d macos        # or any device — no backend needed
flutter build apk --release # Android APK
```

> The demo app is fully self-contained: **no bench, no Docker, no network**.

---

## 13. Running the Full Stack

See **`commands.md`** for the complete command reference. Summary:

| Service | Command | URL |
|---------|---------|-----|
| MariaDB | `brew services start mariadb` (system service) | :3306 |
| Bench (Sunrise) | `cd ~/Documents/frappe/frappe-bench && bench serve --port 8000` | :8000 |
| Bench (Oakridge) | `bench --site oakridge.localhost serve --port 8001` | :8001 |
| Bench (Super Admin) | `bench --site superadmin.localhost serve --port 8002` | :8002 |

> `bench serve` serves one site per process (it uses `default_site` unless
> `--site` is passed). **One `bench --site <site> serve --port <n>` process per
> school** — that's how each school gets its own port + own database.
| Web admin | `cd schooladmin && npm run dev` | :5173 |
| Flutter app | `cd school_connect_app && flutter run -d macos` | — |
| Demo app | `cd demoapp && flutter run -d macos` | — (no backend) |

Login accounts (full table in `commands.md` §3):
- Super Admin: `super.admin@school.com` / `Super@12345` (:8002)
- School Admins: `sunrise.admin@school.com` / `oakridge.admin@school.com` / `Admin@12345`
- Teacher: `robert.johnson@school.com` / `Teacher@123`
- Student: `alex.smith@school.com` / `Student@123`

---

## 14. Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| Login fails on a school site | Wrong school? Auto-detect probes each site in order; a user only authenticates on their own school's DB. |
| Admin dashboard empty (0 students/teachers/classes) | The `School Admin` role needs the elevation path inside `data.py` (`_require_role` + scoped `ignore_permissions`) — re-migrate if the app was upgraded. |
| Bench doesn't route by Host header | `bench serve` pins one site (`default_site`). Run **one `bench serve --port <n> --site <site>` per site** instead. |
| School profile shows placeholder | Run `bench --site <school> migrate` (School Profile is a single doc; old rows with hash names are legacy). |
| Demo app blank on first launch | First launch creates + seeds the SQLite DB; give it a moment. On web the DB is in-memory (resets on reload). |
| `flutter test` can't find `flutter_tester` | Engine artifact missing in the local Flutter cache (`bin/cache/artifacts/engine/darwin-x64/flutter_tester`) — re-run `flutter doctor` / re-download artifacts. Not a code issue. |
| Demo-mode legacy screens still compile | `api_service.dart` / `demo_data_service.dart` are legacy dead files (pre-existing analyze errors, same in both apps) — not on the live data path. |
| Web admin can't reach the bench | `schooladmin/vite.config` proxies `/api` → :8000; ensure the Sunrise bench is running and CORS (`allow_cors`) is set in `site_config.json`. |

---

*Generated for the School Connect project — multi-tenant Flutter + Frappe
Education, plus the offline SQLite demo replica.*
