# School Connect - Attendance & Management System

A comprehensive school attendance and management system built with **Frappe Framework + ERPNext Education** for the backend and **Flutter** for the mobile app.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        School Connect                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐│
│  │  Flutter App │  │   Frappe    │  │    ERPNext Education    ││
│  │  (Mobile)    │  │   Backend   │  │       Module            ││
│  │             │  │   (REST)    │  │                         ││
│  │ - Students  │──│             │──│ - Student, Instructor   ││
│  │ - Teachers  │  │ - Auth      │  │ - Course, Program       ││
│  │             │  │ - Custom    │  │ - Student Group         ││
│  └─────────────┘  │   APIs      │  │ - Course Schedule       ││
│                   └─────────────┘  │ - Student Attendance    ││
│                                    └─────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Frappe Desk (Admin)                      ││
│  │  - School Management                                        ││
│  │  - Teacher Management                                       ││
│  │  - Student Management                                       ││
│  │  - Class Management                                         ││
│  │  - Attendance Reports                                       ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
schoolmanage/
├── school_connect_app/          # Flutter Mobile App
│   ├── lib/
│   │   ├── config/             # API configuration
│   │   ├── models/             # Data models
│   │   ├── screens/            # UI screens
│   │   │   ├── auth/           # Login, Signup
│   │   │   ├── teacher/        # Teacher dashboard
│   │   │   ├── student/        # Student dashboard
│   │   │   └── admin/          # Admin dashboard
│   │   ├── services/           # API service
│   │   ├── state/              # Riverpod state management
│   │   └── main.dart
│   └── pubspec.yaml
│
├── school_connect/              # Frappe Custom App
│   ├── school_connect/
│   │   ├── api/                # Whitelisted API endpoints
│   │   │   ├── auth.py         # Login, Signup
│   │   │   ├── teacher.py      # Teacher endpoints
│   │   │   ├── student.py      # Student endpoints
│   │   │   └── permissions.py  # RBAC hooks
│   │   ├── doctype/            # Custom doctypes
│   │   │   ├── school/
│   │   │   ├── assignment/
│   │   │   └── assignment_submission/
│   │   └── hooks.py
│   ├── docker-compose.yml      # Docker setup
│   └── requirements.txt
```

## 🚀 Quick Start

### Prerequisites

- Python 3.10+
- Node.js 16+
- MariaDB 10.6+
- Redis
- Flutter SDK 3.0+
- Docker (optional)

### Option 1: Docker Setup (Recommended)

```bash
cd school_connect

# Start the containers
docker-compose up -d

# Wait for setup to complete, then access:
# - Frappe/ERPNext: http://localhost:8000
# - Desk (Admin): http://localhost:8000/desk
# - Login: Administrator / admin
```

### Option 2: Local Setup

#### 1. Setup Frappe Bench

```bash
# Install Bench
pip3 install frappe-bench

# Initialize bench
bench init frappe-bench --version version-15
cd frappe-bench

# Get ERPNext
bench get-app erpnext --branch version-15

# Get School Connect app
bench get-app /path/to/schoolmanage/school_connect

# Create site
bench new-site site1.localhost --mariadb-root-password admin --admin-password admin

# Install apps
bench --site site1.localhost install-app erpnext
bench --site site1.localhost install-app school_connect

# Start bench
bench start
```

#### 2. Setup Flutter App

```bash
cd schoolconnect_app

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## 📱 Features

### Student Features
- ✅ Self-registration with school selection
- ✅ View attendance summary (overall & per-subject)
- ✅ Monthly attendance calendar view
- ✅ View and submit assignments
- ✅ Profile management

### Teacher Features
- ✅ View assigned classes
- ✅ Mark attendance (bulk)
- ✅ Create and manage assignments
- ✅ Grade student submissions
- ✅ View student list per class

### Admin Features
- ✅ Manage schools
- ✅ Manage teachers (Instructors)
- ✅ View all students
- ✅ Dashboard with statistics
- ✅ School admin with limited scope

## 🔐 Roles & Permissions

| Role | Created By | Access |
|------|------------|--------|
| **Super Admin** | Manual/First setup | Full control: schools, teachers, students |
| **School Admin** | Super Admin | Manage their school's data only |
| **Instructor** | Admin only | Their assigned classes, mark attendance |
| **Student** | Self-signup | Own attendance, assignments |

## 🛣️ API Endpoints

### Authentication
- `POST /api/method/school_connect.api.auth.login` - Login
- `POST /api/method/school_connect.api.auth.signup_student` - Student signup
- `GET /api/method/school_connect.api.auth.search_schools` - Search schools

### Teacher
- `GET /api/method/school_connect.api.teacher.get_my_classes` - Get assigned classes
- `GET /api/method/school_connect.api.teacher.get_class_students` - Get students in class
- `POST /api/method/school_connect.api.teacher.mark_attendance` - Mark attendance
- `GET /api/method/school_connect.api.teacher.get_attendance_report` - Get attendance report

### Student
- `GET /api/method/school_connect.api.student.get_my_attendance_summary` - Attendance summary
- `GET /api/method/school_connect.api.student.get_my_attendance` - Attendance records
- `GET /api/method/school_connect.api.student.get_my_assignments` - Assignments

## 📊 Data Model

### Core ERPNext Education Doctypes Used
- **School** - Custom doctype for multi-school support
- **Student** - Student records
- **Instructor** - Teacher records
- **Course** - Subjects
- **Student Group** - Classes (Grade + Section)
- **Course Schedule** - Teacher-Class-Subject assignment
- **Student Attendance** - Attendance records

### Custom Doctypes
- **School** - Extended school info (city, state, country)
- **Assignment** - Homework/assignments
- **Assignment Submission** - Student submissions

## 🔧 Configuration

### API Base URL (Flutter)
Edit `lib/config/api_config.dart`:
```dart
static const String baseUrl = 'http://localhost:8000';
```

### Frappe Settings
- Developer mode: `bench --site site1.localhost set-config developer_mode 1`
- Default admin: `Administrator` / `admin`

## 📝 Environment Variables

```bash
# Database
MARIADB_HOST=localhost
MARIADB_ROOT_PASSWORD=admin

# Redis
REDIS_CACHE=localhost:6379

# Frappe
FRAPPE_SITE_NAME=site1.localhost
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Documentation**: docs.schoolconnect.com
- **Issues**: GitHub Issues
- **Email**: support@schoolconnect.com
