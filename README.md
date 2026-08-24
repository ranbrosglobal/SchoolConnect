# School Connect

School Attendance & Management System — **serverless architecture** powered by Google Sheets.

## Architecture

```
┌─────────────────────┐
│   Flutter Mobile App │ ── Google Sign-In ──→ Google Sheets API
└─────────────────────┘        │                     │
                               │                     │
┌─────────────────────┐        │              ┌──────┴──────┐
│   Web Admin (React) │ ── Google Sign-In ──→│  Spreadsheet │
│   Super Admin       │                       │  (database)  │
└─────────────────────┘                       └─────────────┘
```

**No server, no Docker, no Frappe.** The teacher's Google account owns the data.

- **Authentication**: Google Sign-In (OAuth 2.0)
- **Database**: Google Sheets (the spreadsheet IS the backend)
- **Backend logic**: Client-side — apps read/write directly to Google Sheets API

## Google Sheets Tab Structure

| Tab | Columns |
|-----|---------|
| `Users` | id, email, name, role, school_id, password, status |
| `Schools` | id, name, location, status, port, periods, motto, contact_email, contact_number, website, address |
| `Classes` | id, name, program, school_id, room, teacher_ids |
| `Students` | id, name, email, roll_number, class_id, school_id, attendance_pct, status |
| `Attendance` | id, student_id, class_id, date, status, course |
| `Assignments` | id, title, course, class_id, due_date, description, created_by, created_at |
| `Submissions` | id, assignment_id, student_id, file_name, grade, feedback, status, submitted_at |
| `Timetable` | id, class_id, day, period, teacher_id, subject, school_id |

## Quick Start

### 1. Set up Google Cloud (free)

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project
3. Enable **Google Sheets API** and **Google Drive API**
4. Create **OAuth 2.0 credentials** (Web application type)
5. Add `http://localhost:5173` as authorized origin
6. Note the **Client ID**

### 2. Create the Spreadsheet

1. Create a new Google Spreadsheet
2. Create tabs with the header rows listed above
3. Share the spreadsheet with your Google account (or service account)

### 3. Run the Flutter App

```bash
cd school_connect_app
flutter pub get
flutter run
```

On the login screen, tap **"Sign in with Google"** — the app reads/writes directly to your spreadsheet.

### 4. Run the Web Admin

```bash
# Set your Google Client ID
export VITE_GOOGLE_CLIENT_ID="your-client-id.apps.googleusercontent.com"

# Start both admin consoles
npm run dev:all
```

- School Admin: http://localhost:5173
- Super Admin: http://localhost:5175

### 5. Mock Mode (no Google account needed)

```bash
npm run dev:all:mock
```

Uses `localStorage` for development — no Google account or spreadsheet required.

## Test Accounts (Mock Mode)

| Role | Email | Password |
|------|-------|----------|
| Super Admin | admin@schoolconnect.app | admin123 |
| School Admin | priya@springfield.edu | admin123 |
| Teacher | anita.sharma@springfield.edu | teacher123 |

## Project Structure

```
├── school_connect_app/    # Flutter mobile app
│   ├── lib/
│   │   ├── services/
│   │   │   ├── google_sheets_service.dart  # Core — Google Sheets API client
│   │   │   └── demo_data_service.dart      # Mock data for demo mode
│   │   ├── config/
│   │   │   └── api_config.dart             # App configuration
│   │   ├── state/                          # Riverpod providers
│   │   ├── screens/                        # UI screens
│   │   ├── models/                         # Data models
│   │   └── widgets/                        # Reusable widgets
│   └── pubspec.yaml
├── schooladmin/           # School Admin web console (React + Vite)
│   └── src/lib/
│       ├── api.js          # API client (mock + sheets modes)
│       ├── sheets.js       # Google Sheets API browser client
│       └── mock.js         # In-browser mock backend
├── superadmin/            # Super Admin web console (React + Vite)
└── demoapp/               # Standalone Flutter demo (SQLite)
```

## What Replaced What

| Before (Frappe) | After (Google Sheets) |
|-----------------|----------------------|
| Docker + MariaDB | Google Spreadsheet |
| Frappe Education | Client-side Sheets API |
| FastAPI bridge | Direct OAuth from app |
| Password auth | Google Sign-In |
| sc_backend (Node.js) | Deleted |
| sheets_backend (Node.js) | Deleted |
| fastapi_backend (Python) | Deleted |
