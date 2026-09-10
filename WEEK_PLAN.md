# Week Plan: Production Ready (Mon - Sat)

> Goal: All admin pages, mobile app, and backend fully production-ready.
> Zero errors, real security, real UX polish, deployable.

---

## Monday - Security Fixes (Critical + High)

Fix every security blocker before anything else.

- [ ] **C-1:** Create release signing keystore, wire it into `android/app/build.gradle.kts`
- [ ] **H-1:** Add `INTERNET` permission to main `AndroidManifest.xml`, set `allowBackup=false`, `usesCleartextTraffic=false`
- [ ] **H-2:** Make `api_config.dart` base URL env-driven (`--dart-define`), default to HTTPS for release
- [ ] **H-3:** Add `com.apple.security.network.client` entitlement to both macOS entitlements files
- [ ] **H-4:** Shorten JWT to 60min, handle 401 centrally in API service, auto-navigate to login on expiry
- [ ] **H-5:** Gate demo mode behind `kDebugMode` compile-time flag, hide demo panel in release builds
- [ ] **H-6:** Generate real JWT signing secret, ensure no hardcoded defaults anywhere

**Done when:** `flutter build apk --release` works, no debug keystore, no cleartext, no demo leak.

---

## Tuesday - Auth, Session & UX Hardening

Make auth bulletproof and fix every UX rough edge.

- [ ] Add refresh token flow (or short-lived session + auto-extend)
- [ ] Auto-logout on inactivity (15 min timer)
- [ ] Centralized error handling: sanitize all server errors, never show stack traces to users
- [ ] Loading states on every screen (skeleton or shimmer, not blank)
- [ ] Offline banner when no network detected
- [ ] Pull-to-refresh on all list screens (student assignments, teacher roster, admin lists)
- [ ] Remove `shared_preferences` unused dependency
- [ ] Run `flutter pub upgrade` to latest stable (Dart >= 3.11 for CVE fix)
- [ ] Update `file_picker` to latest (path-traversal fix), sanitize picked filenames
- [ ] Update `flutter_secure_storage` to latest (Keystore+DataStore migration)

**Done when:** auth feels solid, no blank screens, no raw error messages, deps current.

---

## Wednesday - School Admin Web Dashboard (schooladmin)

Make the admin dashboard complete and production-ready.

- [ ] **Overview page:** real stats (students, teachers, classes, attendance rate)
- [ ] **Teachers page:** list all teachers, view assigned classes, contact info
- [ ] **Students page:** list all students, filter by class, view profile
- [ ] **Classes page:** list classes with student count, rosters (roll-number sorted)
- [ ] **Class detail:** student list with attendance %, click to student detail
- [ ] **School profile editor:** name, logo upload, contact email, phone, website, address
- [ ] **Change password:** for the school admin
- [ ] **Responsive layout:** works on tablet and desktop
- [ ] **Error states:** loading skeletons, empty states, error toasts
- [ ] **Remove demo/mock mode entirely** from live builds

**Done when:** every admin page works against live backend, no dead UI, no placeholder data.

---

## Thursday - Super Admin Portal + Multi-Tenant Polish

Super admin portal fully functional, multi-tenant flow rock solid.

- [ ] **School list:** all registered schools with status, admin email
- [ ] **Add school:** name, base URL, site name, DB name, admin email -> provisions user on that school's site
- [ ] **Edit school:** update registry details
- [ ] **Delete school:** with confirmation dialog
- [ ] **Reset admin password:** cross-site password reset (writes to school's DB)
- [ ] **School admin provisioning:** auto-create user with School Admin role on new school site
- [ ] **Login auto-detect:** verify probe order works correctly across multiple schools
- [ ] **Mobile super admin:** all CRUD operations work from Flutter app
- [ ] **Seed script:** update `seed_data.py` for multi-school setup (Sunrise + Oakridge)

**Done when:** can create a school, provision admin, login as that admin, see real data.

---

## Friday - Mobile App Polish + Flutter Builds

Every screen in the mobile app production-quality, builds clean on all platforms.

- [ ] **Student dashboard:** attendance % correct, calendar real, assignments real, no decorative text
- [ ] **Student attendance:** month navigation works, tap-a-day shows real data, future dates neutral
- [ ] **Student assignments:** submit with file, resubmit after return, graded results show
- [ ] **Student timetable:** weekly grid with real schedule data, 12h time format
- [ ] **Student profile:** real school name/logo, real class, contact info, change password
- [ ] **Teacher dashboard:** class name prominent, roll-number sorted roster, attendance markable
- [ ] **Teacher attendance:** mark P/A/L, save updates existing records (not skip)
- [ ] **Teacher assignments:** create/edit/delete, submissions list, grade with score+feedback
- [ ] **Teacher student detail:** filtered to that teacher's subject only
- [ ] **Admin redirect screen:** clean message with web URL, no dead buttons
- [ ] **All exports:** PDF, Excel, CSV from roster and attendance screens work
- [ ] **`flutter build apk --release --obfuscate --split-debug-info=build/symbols`** clean
- [ ] **`flutter build macos --release`** clean
- [ ] **`flutter build web --release`** clean

**Done when:** every screen verified against live backend, release builds succeed on Android/macOS/web.

---

## Saturday - Final Smoke Test + Documentation + Cleanup

Everything works end-to-end, docs match reality, repo is clean.

- [ ] **Cold boot test:** restart everything from scratch, run full checklist
  - MariaDB up, bench serve on :8000/:8001/:8002, web admin on :5173, Flutter app
- [ ] **Login as every role:**
  - Super Admin (`super.admin@school.com` / `Super@12345`)
  - School Admin (`sunrise.admin@school.com` / `Admin@12345`)
  - Teacher (`robert.johnson@school.com` / `Teacher@123`)
  - Student (`alex.smith@school.com` / `Student@123`)
- [ ] **Full E2E walkthrough:** signup new student, login, see dashboard, submit assignment, teacher grades, student sees grade
- [ ] **Delete demo files:** `demoapp/` if not shipping, dead `fastapi_backend/` references
- [ ] **Clean `pubspec.yaml`:** remove unused deps, all versions latest stable
- [ ] **Update `DOCUMENTATION.md`:** architecture, API reference, running instructions
- [ ] **Update `README.md`:** quick start, screenshots description, build instructions
- [ ] **Update `TESTING.md`:** mark all rows final status
- [ ] **One-command startup:** `start.sh` brings up MariaDB + bench + web admin
- [ ] **Git cleanup:** commit everything, clear any debug/test files

**Done when:** a fresh clone, `start.sh`, and login as each role passes the full checklist with zero errors.

---

## What ships Saturday

| Component | Status |
|-----------|--------|
| Android release APK | Signed, obfuscated, network-enabled |
| macOS release build | Signed, sandboxed, network-enabled |
| Web release build | PWA-ready, no demo mode |
| School Admin dashboard | Full CRUD, responsive |
| Super Admin portal | Multi-tenant CRUD, provisioning |
| Mobile app (all roles) | Every screen against live backend |
| Backend (sc_auth + Frappe) | Auth, data, superadmin APIs |
| Security | Keystore, HTTPS-ready, token expiry, rate limiting |
| Documentation | Matches current architecture |
