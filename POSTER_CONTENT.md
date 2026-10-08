# SchoolConnect — Poster Content Brief

> **Purpose:** Hand this document to a designer or an AI poster generator.
> It contains every fact, number, and message needed to produce a complete
> academic/project poster about **SchoolConnect** — a smart attendance system
> with an upcoming AI-based auto-grading system.

---

## 1. Title & taglines

**Main title:** SchoolConnect

**Subtitle:** Smart Attendance + School Management Platform — with an upcoming AI-Based Auto-Grading System

**Tagline options (pick one):**
- *"One app for the whole school — smart attendance today, AI grading tomorrow."*
- *"Digitise the register. Automate the gradebook."*
- *"Attendance, assignments, grading — one platform for teachers, students and admins."*

---

## 2. The problem (use on the poster's left column)

- Paper registers are slow, get lost, and can't answer "what was the attendance
  on 12 August?" without digging through stacks of paper.
- Attendance data exists but is never **used**: no trends, no early warning for
  falling attendance, no per-student history at a tap.
- Assignment collection happens over WhatsApp/email; grading lives in separate
  spreadsheets; students never have one place to see what's due.
- Teachers lose **hours every week** to clerical work instead of teaching.

---

## 3. The solution (poster's right column / center)

**SchoolConnect is one platform with three connected surfaces:**

| Surface | Who uses it | What it does |
|---|---|---|
| 📱 Mobile app (Flutter) | Teachers & Students | Attendance, assignments, timetable, results, profile |
| 🖥️ School Admin portal (web) | School administrators | Manage teachers, students, classes, timetable, school settings |
| 🌐 Super Admin portal (web) | Trust/organization level | Manage multiple schools and their admins from one console |

All three are powered by one secure API backend with role-based access control.

---

## 4. Feature details (the poster's main grid)

### ✅ Smart Attendance System (core feature)
- **Explicit marking:** nothing is pre-selected — teachers tap P / A / H / L
  (Present, Absent, Half-Day, Leave) per student. No fake "all present" registers.
- **One-day-at-a-time model:** every day starts fresh; saving writes exactly
  what the teacher chose; the app re-reads the server so "saved" means saved.
- **Partial-save confirmation:** marking 14 of 22 students warns the teacher
  that the rest stay unmarked.
- **7 PM auto-absent sweep:** any class left completely unmarked is
  automatically recorded as Absent for all its students by the server —
  the register is never empty.
- **Edit any past day:** teachers can go back (◀ date ▶ + date picker) to
  review or correct any day's register.
- **Attendance history browser:** week / month / quarter / year / custom
  range views with percentage rings, day-by-day timeline, per-student
  breakdown sorted worst-first, and raw record lists.
- **Clear attendance:** a confirmed one-tap reset of a day's records.
- **Export:** every roster/day exports to PDF, CSV and Excel — download,
  share, or print.
- **Live counters:** Selected / Not-selected / Saved plus P-A-H-L totals
  while marking.

### 📚 Assignment upload → receive → grade loop
- **Teachers** create assignments with title, course/class, due date,
  description and file attachments (up to 10 MB per file).
- **Students** see assignments in the app and submit their work as uploaded
  files; they can resubmit if a teacher returns the work.
- **Teachers** view all submissions per assignment, then grade with a score
  and written feedback. Students see grades and feedback instantly.
- **Unsubmit / delete** tools give teachers full control of the submission
  lifecycle.

### 📅 Timetable & schedule
- School admin **uploads/edits the timetable** per class (day × period grid).
- Teachers and students get a **read-only weekly timetable** in the app with
  week navigation, room numbers and teacher names.
- **Next-class lookup** tells a student what's coming up today.

### 🏫 School admin portal
- Create/manage **teachers, students, classes and subjects**.
- Build and edit the **timetable** (periods, days, rooms).
- School-level **dashboard**: counts of students/teachers/classes, average
  attendance at a glance.
- Full CRUD with status toggles (activate/deactivate accounts).

### 🌐 Super admin portal
- **Multi-school management** — register new schools, each isolated with its
  own admin and data.
- Create/reset **school admin accounts**, monitor school counts and status,
  disable a school in one click.

### 🔔 Profile, security & support (in-app)
- **Change password** for every role — including students (a real gap in most
  school systems).
- Notification center + Help & Support sheets with FAQs.
- **Read-only settings for teachers** — class structure is admin-owned, which
  keeps the data model clean (principle of least privilege).
- Session persistence: the app reopens logged-in after a restart.

---

## 5. Under the hood (tech spec box for the poster)

| Layer | Technology | Notes |
|---|---|---|
| Mobile app | **Flutter (Dart)** | Single codebase → Android (iOS-ready); Riverpod state management |
| School Admin portal | **React (Vite)** | Role-scoped web console |
| Super Admin portal | **React (Vite)** | Multi-tenant console |
| Backend API | **Node.js** | ~75 REST-style endpoints, unified handler registry |
| Database | **SQLite** (via `node:sqlite`) | Zero-config, file-based — perfect for school-scale deployment |
| Auth | Session tokens + **scrypt** password hashing | Role-based access control on every endpoint |
| Web security | **CSRF protection** for browser clients, safe bypass for the mobile app | Defense against cross-site request forgery |
| File handling | Uploads stored as blobs in DB, size-limited | Assignment attachments + submissions |
| Exports | PDF / CSV / Excel generation | Client-side, shareable via system share sheet |

**Codebase at a glance**
- 98 Dart files · 60 screens (mobile)
- 2,100+ lines of backend handler logic · ~75 API endpoints
- 37 web portal source files · 2 databases (school + super-admin planes)

---

## 6. Architecture diagram (recreate this on the poster)

```
        ┌────────────────┐   ┌────────────────┐   ┌─────────────────┐
        │  📱 Flutter app │   │ 🖥️ School Admin │   │ 🌐 Super Admin   │
        │  Teacher/Student│   │  portal (web)   │   │  portal (web)   │
        └────────┬───────┘   └────────┬───────┘   └────────┬────────┘
                 │  HTTPS + session   │                    │
                 └────────────┬───────┴────────────────────┘
                              ▼
                 ┌─────────────────────────┐
                 │   Node.js API backend    │
                 │  ~75 endpoints · RBAC    │
                 │  CSRF guard · sessions   │
                 │  7 PM auto-absent job    │
                 └────────────┬────────────┘
                              ▼
                 ┌─────────────────────────┐
                 │  SQLite databases        │
                 │  school.db + super.db    │
                 └─────────────────────────┘
```

---

## 7. Workflow diagrams (small, optional, great for filling space)

**Attendance flow:**
`Open class → tap P/A/H/L per student → Save (confirm if partial) → server
persists → app re-reads → ✅ verified count shown → export or review any past
day → unmarked classes auto-close at 7 PM`

**Assignment loop:**
`Teacher creates + attaches → student sees & submits file → teacher grades
(score + feedback) → student sees result → resubmit if returned`

---

## 8. Impact / why it matters (stat-style callouts for the poster)

- ⏱️ **Register time cut from minutes to seconds** — one tap per student, or
  batch "All Present" then flip the absentees.
- 📊 **100% of attendance days accounted for** — the 7 PM sweep leaves no
  blank days, so monthly percentages are always trustworthy.
- 🔍 **Any student's history in 3 taps** — past week/month/quarter/year/custom.
- 📄 **Paperless exports** — PDF/CSV/Excel for any class, any day.
- 🔐 **Security-first** — hashed passwords, session auth, CSRF protection,
  role-scoped endpoints on all ~75 routes.
- 🧩 **One source of truth** — mobile app, admin portal and super-admin
  console all read/write the same live database (no more WhatsApp
  spreadsheets).

---

## 9. 🚀 Upcoming: AI-Based Auto-Grading System (the "next" banner)

Announce as the project's roadmap headline:

> **Next on the roadmap: AI-Based Auto-Grading**
> Hand-written and typed submissions will be graded automatically.

Planned capabilities (present as "coming soon" feature cards):
- **OCR + LLM pipeline** — students upload answer sheets as images/PDFs; AI
  extracts the text and evaluates answers against a rubric.
- **Automatic scoring with teacher oversight** — the model proposes a grade +
  feedback; the teacher reviews, adjusts and approves before release.
- **Rubric-aware partial credit** — not just right/wrong: step marking for
  math-style answers.
- **Consistent, bias-reduced grading** — same rubric applied identically to
  every submission; grades arrive minutes after submission instead of days.
- **Feedback that teaches** — per-question comments generated for every
  student, not just a score.
- **Fits the existing loop** — it plugs straight into today's
  upload→receive→grade flow; teachers keep final say.

---

## 10. Poster layout suggestion (for the designer/AI)

- **Top band:** title + chosen tagline + app icon (smartphone + checkmark motif).
- **Left column:** The Problem (section 2) as 3–4 pain points with icons.
- **Center:** The Solution — 3-surface diagram (section 3) above the
  architecture diagram (section 6).
- **Right column:** Feature grid (section 4) — attendance first and biggest,
  assignments second, timetable/admin portals third.
- **Bottom band left:** Impact stat callouts (section 8) as big numbers.
- **Bottom band right:** "Upcoming: AI-Based Auto-Grading" banner (section 9)
  with a subtle "roadmap arrow" leading off the poster edge.
- **Footer:** tech-stack chips (Flutter · Node.js · SQLite · React · scrypt ·
  RBAC) + team name/course + year.
- **Suggested palette:** deep blue (#1E3A8A) → blue (#2563EB) gradients on
  white, green (#16A34A) for "present/success", red (#DC2626) accents —
  matching the app's own UI.

---

## 11. Elevator pitch (if the poster needs a short abstract paragraph)

> SchoolConnect is a three-surface school management platform — a Flutter
> mobile app for teachers and students, plus web portals for school and
> super admins — built on a secure Node.js + SQLite backend with ~75
> role-protected API endpoints. Its core is a smart attendance system that
> replaces the paper register: teachers mark students explicitly
> (Present/Absent/Half-Day/Leave), the server guarantees every day is
> accounted for with a 7 PM auto-absent sweep, and any past day can be
> reviewed, corrected, cleared, or exported to PDF/Excel. The same platform
> runs the full assignment lifecycle — teachers upload work with attachments,
> students submit files from the app, and teachers grade with scores and
> feedback. The roadmap adds an AI-based auto-grading system: an OCR + LLM
> pipeline that reads student submissions, applies rubric-aware partial
> credit, and drafts grades and per-question feedback for teacher approval —
> cutting grading turnaround from days to minutes.
