# 📋 School Connect — Working Document

> **Project:** SchoolConnect — Multi-tenant school management system  
> **Period:** August 8 – August 21, 2026  
> **Generated:** August 21, 2026

---

## Table of Contents

1. [Project Summary](#1-project-summary)
2. [Day-by-Day Work Log](#2-day-by-day-work-log)
3. [Architecture & Components](#3-architecture--components)
4. [Major Milestones](#4-major-milestones)
5. [Technology Stack](#5-technology-stack)
6. [Key Technical Decisions](#6-key-technical-decisions)
7. [Current Status](#7-current-status)

---

## 1. Project Summary

**School Connect** is a complete, multi-tenant school management system:

| Component | Location | What it does |
|-----------|----------|-------------|
| **Flutter Mobile App** | `school_connect_app/` | Student, teacher, and super admin mobile app |
| **Demo App** | `demoapp/` | Fully offline replica using local SQLite — no backend needed |
| **School Admin Web** | `schooladmin/` | React + Vite dashboard for school admins |
| **Super Admin Web** | `superadmin/` | React + Vite console for system-level management |
| **Frappe Backend** | `school_connect/` | Custom Frappe app with ERPNext Education |
| **SQLite Backend** | `sc_backend/` | Lightweight Node.js API for web consoles |
| **FastAPI Bridge** | `fastapi_backend/` | Optional REST bridge to Frappe (replaced by direct REST) |
| **Custom Frappe App** | `sc_auth/` | Auth + data APIs for Frappe Education |

**Roles supported:** Students (attendance, assignments, timetable, results), teachers (class management, grading, attendance marking), school admins (school profile, teacher/student oversight via web), and super admins (multi-school registry, admin provisioning).

---

## 2. Day-by-Day Work Log

> *Days 1–3 (Aug 8–10) had no git commits — work was completed locally and pushed as a single batch on Aug 11.*

### Day 1 — Aug 8: Backend Foundation

- Set up Frappe Framework v15 + ERPNext Education with MariaDB and Redis
- Created custom Frappe app `school_connect` with 3 doctypes: **School**, **Assignment**, **Assignment Submission**
- Built the full API layer: `auth.py`, `teacher.py`, `student.py`, `admin.py`, `permissions.py`
- Custom email/password auth with JWT + session tokens
- Docker Compose setup with MariaDB, Redis, and Frappe containers

### Day 2 — Aug 9: Flutter Mobile App

- Scaffolded the Flutter project for all 6 platforms (Android, iOS, macOS, Windows, Linux, Web)
- Built the architecture: Screens → Riverpod Providers → API Services → Models
- Created all data models mirroring the Frappe JSON schema
- Built student screens: dashboard, attendance, assignments, results, timetable, profile
- Built teacher screens: dashboard, classes, attendance marking, assignments, grading
- Built auth screens: login + 4-step student signup

### Day 3 — Aug 10: Super Admin, Widgets, Documentation

- Built the super admin portal: school registry, admin provisioning, password resets
- Created shared widgets: `AppShell` (bottom nav / NavigationRail), `AuthScaffold`, school header
- Extended models: timetable, school profile, instructor
- Wrote `DOCUMENTATION.md` (940 lines) and `seed_data.py` demo seeder

### Day 4 — Aug 11: First GitHub Push

- Pushed the entire project to GitHub — 370 files, 75K+ lines
- Configured and verified iOS and Android builds

### Day 5 — Aug 12: FastAPI Bridge, Web Consoles, UI Redesign

- Integrated FastAPI as a REST bridge between Flutter and Frappe
- **Created `schooladmin/`** — React + Vite dashboard for school admins with 8 pages:
  - Overview (school stats, recent classes, quick actions)
  - Teachers (list, search, add/edit modal with subject multi-select and class assignment)
  - Classes (card grid, add/edit, delete with cascade warning)
  - Class Detail (student roster with roll numbers, attendance %)
  - Students (list, search, add/edit modal)
  - Student Detail (profile card, teachers, class info)
  - Settings (account details, password change)
  - Login (split layout, demo quick-login buttons)
  - Shared UI components: Avatar, Badge, Card, Modal, StatCard, EmptyState, PageHeader
  - Mock mode with in-browser localStorage backend
- **Created `superadmin/`** — React + Vite console for super admins with 4 pages:
  - Overview (network-wide stats: schools, admins, teachers, students)
  - Schools (card grid with search, add/edit/disable/delete, manage admins modal)
  - Settings (account details, password change)
  - Login (split layout, demo quick-login)
  - SchoolAdminsModal component for managing admin accounts per school
- Completely redesigned the Flutter UI: responsive layout, glassmorphism login, animated signup, custom SVG illustrations

### Day 6 — Aug 13: REST Migration, Settings, Login UX

- **Replaced FastAPI with direct REST** — Flutter now talks to Frappe directly, simplifying architecture
- Overhauled login/signup UX with better validation and visual feedback
- **Web console Settings pages** — both schooladmin and superadmin got full Settings pages:
  - Account details card (editable name, read-only email, role badge)
  - Change password card (current/new/confirm with validation)
  - Inline success/error banners after actions
- Repo hygiene: cleaned up database files, gitignore, package-lock

### Day 7 — Aug 14: Weekly Timetable

- Added complete weekly timetable system with per-school periods
- Backend: new `School Timetable Entry` doctype, 3 DB patches, timetable CRUD endpoints
- **Frontend: TimetablePage** — the most complex page in the web admin:
  - Weekly grid with periods as rows (P1–P8) and days as columns (Mon–Fri)
  - View toggle: "By class" (grid) | "By teacher" (teacher × day matrix)
  - Class selector dropdown (pre-selectable from class detail page)
  - Periods editor modal (add/remove periods, edit times)
  - Entry modal for add/edit (day, period, teacher, subject selectors)
  - Subject pinning — subjects stored on entries so teacher subject changes don't break past schedules
  - Stat cards: periods filled, free slots, teachers used
  - Delete confirmation with full context (subject, teacher, class, day, period)

### Day 8 — Aug 15: Demo App, Web App Separation

- **Created the full demo app** — an exact offline replica of the mobile app using SQLite
  - All screens: auth, student, teacher, super admin
  - On-device PDF, Excel, CSV export with school branding
  - Rich seed data: 3 classes, 10 students, 2 teachers, 6 weeks of schedules
- Separated `schooladmin/` and `superadmin/` into independently deployable apps

### Day 9 — Aug 16: Rest Day

### Day 10 — Aug 17: SQLite Backend, Cross-Sync

- **Created `sc_backend/`** — Node.js SQLite backend for web consoles
  - Two SQLite databases: `schooladmin.db` + `superadmin.db`
  - Two servers: School Admin (:8090) + Super Admin (:8091)
  - Frappe-style RPC contract — 30+ endpoints matching `school_connect.api.*` paths
  - Session-based auth (cookie + CSRF token), scrypt password hashing
  - `requireOwnSchool()` enforcement — school admins locked to their own school
  - Cross-backend sync: school CRUD + admin provisioning flows between servers with exponential backoff retry and boot reconciliation
  - Seed data: 3 schools (Springfield, Riverside, Sunrise) with admins, classes, students, timetable
- Built conformance test suite — boots both servers, tests endpoint surface, auth enforcement, school scoping, cross-sync, health checks
- Added teacher student management to the demo app

### Days 11–12 — Aug 18–19: Rest Days

### Day 13 — Aug 20: Demo App Finalized

- Major overhaul making all demo app features fully functional
- New teacher class management screen (add, edit, delete classes, view rosters)
- Refactored demo API service — clean separation from live API
- Updated all state providers, login, and profile screens

### Day 14 — Aug 21: Documentation

- Compiled this working document from all project history

---

## 3. Architecture & Components

### Multi-Tenant System

```
              ┌──────────────────────────────────┐
              │    Super Admin site (:8002)       │
              │  School registry + admin mgmt     │
              └──────────┬───────────────────────┘
                         │
     ┌───────────────────┼───────────────────┐
     │                   │                   │
┌────▼─────┐     ┌───────▼──────┐    ┌──────▼──────┐
│ School A │     │  School B    │    │  School N   │
│ (:8000)  │     │  (:8001)     │    │  own site   │
│ its DB   │     │  its DB      │    │  its DB     │
└────┬─────┘     └───────┬──────┘    └──────┬──────┘
     │                   │                   │
     └─────── Flutter mobile app + web dashboards
```

Each school gets its own Frappe site + MariaDB — no data mixing.

### Component Summary

| Component | Tech | Purpose |
|-----------|------|---------|
| Mobile App | Flutter + Riverpod | Students, teachers, super admin |
| Demo App | Flutter + SQLite | Fully offline replica, zero backend |
| School Admin Web | React + Vite | School admin dashboard |
| Super Admin Web | React + Vite | System-level management |
| Frappe Backend | Python + ERPNext Education | Multi-tenant school backend |
| SQLite Backend | Node.js + SQLite | Lightweight API for web consoles |

---

## 4. Major Milestones

| # | Milestone | Date |
|---|-----------|------|
| 1 | ✅ Frappe backend + custom app scaffolded | Aug 8 |
| 2 | ✅ Flutter mobile app core built (all screens, models, providers) | Aug 9 |
| 3 | ✅ Super admin portal + documentation + seed data | Aug 10 |
| 4 | ✅ First GitHub push — 370 files, 75K+ lines | Aug 11 |
| 5 | ✅ iOS + Android builds verified | Aug 11 |
| 6 | ✅ FastAPI bridge integrated (Flutter ↔ Frappe) | Aug 12 |
| 7 | ✅ Web admin consoles created (schooladmin + superadmin) | Aug 12 |
| 8 | ✅ Flutter UI completely redesigned (responsive, playful) | Aug 12 |
| 9 | ✅ Security audit completed | Aug 12 |
| 10 | ✅ Postman collection for API testing | Aug 12 |
| 11 | ✅ FastAPI replaced with direct REST API | Aug 13 |
| 12 | ✅ Login/Signup UX overhaul | Aug 13 |
| 13 | ✅ Phase 6 Settings for both web consoles | Aug 13 |
| 14 | ✅ Weekly timetable management with per-school periods | Aug 14 |
| 15 | ✅ Demo app created with full offline SQLite backend | Aug 15 |
| 16 | ✅ Demo app export functionality (PDF, Excel, CSV, Share) | Aug 15 |
| 17 | ✅ Web apps separated into independent deployable units | Aug 15 |
| 18 | ✅ SQLite backend for web consoles with cross-sync | Aug 17 |
| 19 | ✅ Conformance test suite for backend | Aug 18 |
| 20 | ✅ Teacher student management in demo app | Aug 19 |
| 21 | ✅ Demo app fully working with all teacher editing features | Aug 20 |

---

## 5. Technology Stack

| Layer | Technology | Details |
|-------|-----------|---------|
| **Mobile App** | Flutter 3.35.7 (Dart 3.9.2) | Android, iOS, macOS, Windows, Linux, Web |
| **State Management** | Riverpod | StateNotifier + immutable state with copyWith |
| **Demo App DB** | SQLite (sqflite) | On-device, platform-specific implementations |
| **Web Dashboards** | React + Vite | schooladmin + superadmin |
| **Web Backend** | Node.js + SQLite | sc_backend — lightweight API for web consoles |
| **Frappe Backend** | Frappe Framework v15 | Custom app + ERPNext Education module |
| **Database** | MariaDB 10.11 | One DB per school (multi-tenant) |
| **Cache/Queue** | Redis | Cache :13000, queue :11000 |
| **Auth** | Custom email/password | JWT + session (sid) tokens |
| **API Contract** | Frappe-style RPC | `/api/method/school_connect.api.*` |
| **Export** | On-device | PDF/Excel/CSV via share_plus + printing |

---

## 6. Key Technical Decisions

1. **Multi-tenant via separate databases** — Each school gets its own Frappe site + MariaDB. No data mixing between schools.

2. **Offline-first demo app** — Uses the same class names and method signatures as the live app, so every screen works unchanged against local SQLite.

3. **FastAPI → Direct REST** — Started with a FastAPI bridge, then simplified to direct REST calls to Frappe.

4. **Unified API contract** — Both the Frappe backend and the SQLite backend implement the same endpoint pattern, so web consoles need zero changes to switch between mock and live.

5. **On-device export** — The demo app generates PDFs, Excel, and CSVs entirely on-device with full school branding.

6. **Auto-detect school at login** — The mobile app probes known endpoints to find which school a user belongs to — no manual school selection.

7. **Cross-console sync** — School admin and super admin backends stay in sync via HTTP events with retry and boot reconciliation.

---

## 7. Current Status

### What's Working

| Feature | Mobile | Demo | Web |
|---------|--------|------|-----|
| Student login/signup | ✅ | ✅ | — |
| Teacher login | ✅ | ✅ | — |
| Admin login | — | — | ✅ |
| Super admin login | ✅ | ✅ | ✅ |
| Student dashboard | ✅ | ✅ | — |
| Teacher dashboard | ✅ | ✅ | — |
| Attendance (view + mark) | ✅ | ✅ | — |
| Assignments (CRUD + submit) | ✅ | ✅ | — |
| Grading & feedback | ✅ | ✅ | — |
| Timetable (view + manage) | ✅ | ✅ | ✅ |
| Results / grades | ✅ | ✅ | — |
| Profiles + change password | ✅ | ✅ | ✅ |
| School profile/branding | ✅ | ✅ | ✅ |
| Super admin portal | ✅ | ✅ | ✅ |
| School CRUD + admin provisioning | ✅ | ✅ | ✅ |
| Cross-console sync | — | — | ✅ |
| PDF / Excel / CSV export | ✅ | ✅ | — |
| Teacher student management | — | ✅ | ✅ |
| All 6 platform builds | ✅ | ✅ | — |
| Security audit | ✅ | — | — |
| Conformance tests | — | — | ✅ |

### Web Console Details (from ADMINWORK.md)

**School Admin Console** (`schooladmin/` — 8 pages):
- Overview: school stats, recent classes, quick actions
- Teachers: list with search, add/edit with subject multi-select + class assignment
- Classes: card grid, add/edit/delete with cascade warnings
- Class Detail: student roster with roll numbers, attendance %
- Students: list with search, add/edit, student detail profile
- Timetable: full weekly scheduling grid (class view + teacher view, period management, subject pinning)
- Settings: account details + password change
- Login: split layout with 3 demo quick-login buttons

**Super Admin Console** (`superadmin/` — 4 pages):
- Overview: network-wide stats (schools, admins, teachers, students), recent schools table
- Schools: card grid with search, add/edit/disable/delete, SchoolAdminsModal for managing admin accounts
- Settings: account details + password change
- Login: split layout with demo quick-login

**Shared:** Mock mode (no backend needed), session-based auth, Tailwind CSS, Lucide icons, `useFetch` hook

### By the Numbers

- **36 commits** over 10 active days (out of 14)
- **500+ files** changed, **80K+ lines** added
- **5 new components** created: demoapp, schooladmin, superadmin, sc_backend, fastapi_backend

---

*Working document for SchoolConnect — August 8–21, 2026.*
