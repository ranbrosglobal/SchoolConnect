# School Connect

School Attendance & Management System — **multi-tenant** school management built on
**Frappe Framework v17 + ERPNext Education**, with a **Flutter mobile app**,
a **React web admin console**, and a fully offline **SQLite demo replica**.

## Architecture

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

- **One Frappe site + one MariaDB database per school** — no data mixing between schools.
- **Super admin has its own site + database** holding only the school registry.
- **Custom email/password auth** (`sc_auth.api.auth`): login, signup, me, logout,
  change password — returns a real Frappe session sid **and** a signed JWT.
- **No Google Sign-In, no Google Sheets** in the live build. The earlier
  Google-Sheets serverless prototype was replaced by the Frappe backend.
- **The mobile app auto-detects the school at login** — no school picker;
it probes the known endpoints and logs the user into the site that
  authenticates them.

## Quick Start (live backend)

### 1. Start the Frappe bench

```bash
# One-command startup (backend + web admin):
./start.sh

# Or manually:
cd ~/Documents/frappe/frappe-bench
bench serve --port 8000 --site library.localhost   # school site
bench serve --port 8002 --site superadmin.localhost # super-admin registry
```

### 2. Run the web admin

```bash
cd schooladmin
npm run dev    # → http://localhost:5173
```

### 3. Run the Flutter mobile app

```bash
cd school_connect_app
flutter pub get
flutter run -d macos     # or any device/emulator
```

### 4. Seed demo data (first time / rebuild)

```bash
python3 seed_data.py   # run with the bench venv's python
```

Creates a full school: academic year, term, holidays, grading scales, rooms,
2 programs, 6 courses, 10 students, 2 instructors, 3 student groups, 15 course
schedules, 50 attendance records, 15 assessment plans, 35 assessment results.
Idempotent — re-runs skip existing records.

## Test Accounts (seeded)

| Role | Email | Password | Site / port |
|------|-------|----------|-------------|
| Super Admin | super.admin@school.com | Super@12345 | :8002 |
| School Admin (Sunrise) | sunrise.admin@school.com | Admin@12345 | :8000 |
| Teacher | robert.johnson@school.com | Teacher@123 | :8000 |
| Student | alex.smith@school.com | Student@123 | :8000 |

## Project Structure

```
├── school_connect_app/      # Flutter mobile app (students, teachers, super admin)
│   ├── lib/
│   │   ├── config/api_config.dart        # env-driven backend URLs
│   │   ├── services/frappe_api_service.dart  # live data layer (sc_auth.api.*)
│   │   ├── services/export_service.dart  # PDF / CSV / Excel / share / print
│   │   ├── state/                        # Riverpod providers (auth, student, teacher, school)
│   │   ├── screens/                      # login, student dashboard, teacher dashboard,
│   │   │                                  #  super admin portal, assignments, attendance...
│   │   ├── models/                       # user, student, instructor, attendance, assignment...
│   │   └── widgets/                      # school header, export sheet, ...
│   └── pubspec.yaml
├── schooladmin/             # School Admin web console (React + Vite)
├── sc_auth/                 # Frappe custom app (auth + data API + doctypes)
│   └── sc_auth/api/
│       ├── auth.py          # login / signup_student / me / logout / change_password
│       ├── data.py          # student/teacher/admin data endpoints
│       └── superadmin.py    # registry: schools CRUD + admin provisioning
├── demoapp/                 # Offline replica of the mobile app (SQLite only)
├── seed_data.py             # idempotent demo-data seeder for the bench
├── start.sh                 # one-command startup (backend + web admin)
├── scripts/bench_backup.sh  # Frappe backup + restore helpers
├── README.md
├── DOCUMENTATION.md
├── TESTING.md
└── SCHOOL_CONNECT_STATUS.md
```

## What's working

- Custom email/password auth with JWT + session (no Frappe Desk login)
- Student dashboard: attendance %, subject-wise attendance, assignments, timetable,
  calendar with month navigation + tap-a-day assignments sheet
- Teacher dashboard: classes, attendance marking (roll-number sorted), assignments
  (create/edit/delete), grading with feedback, student detail scoped to the teacher's
  subject
- Assignment submission with real file upload to Frappe's file store + download/
  share of submitted files
- School admin web dashboard: overview, teachers, classes, students, school profile
  editing (name, logo, contact info)
- Super admin portal (in the mobile app): registry, school CRUD, admin provisioning,
  password reset across sites
- Offline demo app (`demoapp/`) — exact replica on local SQLite, no backend needed
- Teacher exports: PDF (download / share / print), Excel, CSV — with school branding

## Secrets & config

- The JWT signing key is a **Frappe site-config value** (`sc_auth_jwt_secret`),
  set per site — never shipped in the app bundle.
- The app reads backend URLs from environment variables:
  `SC_BACKEND_URL`, `SC_BACKEND_PORT`, `SC_SUPERADMIN_URL`, `SC_SUPERADMIN_PORT`,
  `SC_WEB_ADMIN_URL`. Defaults: localhost:8000 / localhost:8002 / localhost:5173.
- No plaintext passwords are stored in the app or the repo.

## Tests / checklist

See `TESTING.md` for the feature-by-feature E2E checklist (every screen/button per
role, tested against the live backend).
