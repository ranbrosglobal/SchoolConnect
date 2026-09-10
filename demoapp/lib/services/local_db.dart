import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart' show databaseFactory, Database, DatabaseFactory, inMemoryDatabasePath, OpenDatabaseOptions;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' show databaseFactoryFfiWeb;

/// The demo app's entire "backend": a local SQLite database that lives on the
/// device. It mirrors the Frappe Education data model (students, teachers,
/// classes, schedules, attendance, assignments, submissions, school profile)
/// and is seeded with realistic demo data so every screen works fully offline.
///
/// Runs on:
///  - Android / iOS ......... native `sqflite` (on-device database file)
///  - macOS / Linux / Win ... `sqflite_common_ffi` (local file)
///  - web ................... in-memory SQLite (via sqlite3.wasm)
class LocalDb {
  LocalDb._();

  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final db = await _open();
    await _seedIfNeeded(db);
    _db = db;
    return db;
  }

  static DatabaseFactory _factory() {
    if (kIsWeb) return databaseFactoryFfiWeb;
    if (Platform.isAndroid || Platform.isIOS) return databaseFactory;
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }

  static Future<Database> _open() async {
    final factory = _factory();
    final path = kIsWeb
        ? inMemoryDatabasePath
        : join(await factory.getDatabasesPath(), 'school_connect_demo.db');
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        // Bump the version + clear old rows whenever the seed changes, so
        // existing installs get the fresh demo data on next launch.
        onUpgrade: (db, oldV, newV) async {
          // Schema v3: students gained age / gender columns.
          if (oldV < 3) {
            final cols = await db.rawQuery('PRAGMA table_info(students)');
            final names = cols.map((c) => c['name']).toSet();
            if (!names.contains('age')) {
              await db.execute('ALTER TABLE students ADD COLUMN age INTEGER');
            }
            if (!names.contains('gender')) {
              await db.execute('ALTER TABLE students ADD COLUMN gender TEXT');
            }
          }
          for (final t in [
            'users', 'groups', 'students', 'instructors', 'schedules',
            'attendance', 'plans', 'submissions', 'school_profile',
          ]) {
            await db.execute('DELETE FROM $t');
          }
        },
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE users(
              id TEXT PRIMARY KEY,
              email TEXT UNIQUE NOT NULL,
              full_name TEXT NOT NULL,
              role TEXT NOT NULL,
              password TEXT NOT NULL,
              student_id TEXT,
              instructor_id TEXT
            )''');
          await db.execute('''
            CREATE TABLE groups(
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              program TEXT
            )''');
          await db.execute('''
            CREATE TABLE students(
              id TEXT PRIMARY KEY,
              student_name TEXT NOT NULL,
              email TEXT,
              group_id TEXT,
              roll_number INTEGER,
              age INTEGER,
              gender TEXT
            )''');
          await db.execute('''
            CREATE TABLE instructors(
              id TEXT PRIMARY KEY,
              instructor_name TEXT NOT NULL,
              email TEXT
            )''');
          await db.execute('''
            CREATE TABLE schedules(
              id TEXT PRIMARY KEY,
              course TEXT NOT NULL,
              course_name TEXT NOT NULL,
              group_id TEXT NOT NULL,
              instructor TEXT NOT NULL,
              instructor_name TEXT,
              room TEXT,
              from_time TEXT,
              to_time TEXT,
              schedule_date TEXT NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE attendance(
              id TEXT PRIMARY KEY,
              schedule_id TEXT,
              student_id TEXT NOT NULL,
              date TEXT NOT NULL,
              status TEXT NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE plans(
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              course TEXT,
              course_name TEXT,
              group_id TEXT,
              due_date TEXT,
              from_time TEXT,
              description TEXT
            )''');
          await db.execute('''
            CREATE TABLE submissions(
              id TEXT PRIMARY KEY,
              plan_id TEXT NOT NULL,
              student_id TEXT NOT NULL,
              status TEXT NOT NULL,
              score REAL,
              feedback TEXT,
              file_name TEXT,
              submitted_at TEXT,
              graded_at TEXT
            )''');
          await db.execute('''
            CREATE TABLE school_profile(
              id INTEGER PRIMARY KEY CHECK (id = 1),
              school_name TEXT,
              motto TEXT,
              logo TEXT,
              contact_email TEXT,
              contact_number TEXT,
              website TEXT,
              address TEXT
            )''');
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // Seeding (only when the DB is empty)
  // ------------------------------------------------------------------
  static Future<void> _seedIfNeeded(Database db) async {
    final count = SqfliteUtils.firstInt(await db.rawQuery('SELECT COUNT(*) c FROM users'));
    if ((count ?? 0) > 0) return;
    await _seed(db);
  }

  static Future<void> _seed(Database db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    String d(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';

    // ---- School profile ----
    await db.insert('school_profile', {
      'id': 1,
      'school_name': 'Sunrise Public School',
      'motto': 'Learn. Teach. Grow. Together.',
      'logo': 'assets/images/school_logo.png',
      'contact_email': 'hello@springfield.edu',
      'contact_number': '+1 (555) 987-6543',
      'website': 'www.springfield.edu',
      'address': '12 Maple Avenue, Springfield, IL 62704',
    });

    // ---- Groups (3 realistic classes) ----
    const groups = [
      ('EDU-GRP-8B', 'Class 8 - B', 'Class 8'),
      ('EDU-GRP-9A', 'Class 9 - A', 'Class 9'),
      ('EDU-GRP-11C', 'Class 11 - C', 'Class 11'),
    ];
    for (final g in groups) {
      await db.insert('groups', {'id': g.$1, 'name': g.$2, 'program': g.$3});
    }

    // ---- Students (10 across the 3 classes, roll numbers 1..n) ----
    const students = [
      ('EDU-STU-0001', 'Alex Smith', 'alex.smith@school.com', 'EDU-GRP-8B', 1, 14, 'Male'),
      ('EDU-STU-0002', 'Emma Wilson', 'emma.wilson@school.com', 'EDU-GRP-8B', 2, 14, 'Female'),
      ('EDU-STU-0003', 'Michael Brown', 'michael.brown@school.com', 'EDU-GRP-8B', 3, 13, 'Male'),
      ('EDU-STU-0004', 'Sophia Taylor', 'sophia.taylor@school.com', 'EDU-GRP-8B', 4, 14, 'Female'),
      ('EDU-STU-0005', 'James Miller', 'james.miller@school.com', 'EDU-GRP-9A', 1, 15, 'Male'),
      ('EDU-STU-0006', 'Jessica Davis', 'jessica.davis@school.com', 'EDU-GRP-9A', 2, 15, 'Female'),
      ('EDU-STU-0007', 'Thomas Gonzalez', 'thomas.gonzalez@school.com', 'EDU-GRP-9A', 3, 14, 'Male'),
      ('EDU-STU-0008', 'Barbara Smith', 'barbara.smith@school.com', 'EDU-GRP-11C', 1, 16, 'Female'),
      ('EDU-STU-0009', 'Patricia Hernandez', 'patricia.hernandez@school.com', 'EDU-GRP-11C', 2, 17, 'Female'),
      ('EDU-STU-0010', 'David Garcia', 'david.garcia@school.com', 'EDU-GRP-11C', 3, 16, 'Male'),
    ];
    for (final s in students) {
      await db.insert('students', {
        'id': s.$1,
        'student_name': s.$2,
        'email': s.$3,
        'group_id': s.$4,
        'roll_number': s.$5,
        'age': s.$6,
        'gender': s.$7,
      });
    }

    // ---- Instructors ----
    const instructors = [
      ('EDU-INS-0001', 'Mr. Robert Johnson', 'robert.johnson@school.com'),
      ('EDU-INS-0002', 'Dr. Sarah Mitchell', 'sarah.mitchell@school.com'),
    ];
    for (final i in instructors) {
      await db.insert('instructors', {'id': i.$1, 'instructor_name': i.$2, 'email': i.$3});
    }

    // ---- Users (login accounts for every student + teacher) ----
    final users = <(String, String, String, String, String?, String?)>[
      for (final s in students)
        (s.$3, s.$2, 'Student', 'Student@123', s.$1, null),
      ('robert.johnson@school.com', 'Mr. Robert Johnson', 'Instructor', 'Teacher@123', null, 'EDU-INS-0001'),
      ('sarah.mitchell@school.com', 'Dr. Sarah Mitchell', 'Instructor', 'Teacher@123', null, 'EDU-INS-0002'),
    ];
    for (final u in users) {
      await db.insert('users', {
        'id': u.$1,
        'email': u.$1,
        'full_name': u.$2,
        'role': u.$3,
        'password': u.$4,
        'student_id': u.$5,
        'instructor_id': u.$6,
      });
    }

    // ---- Course schedules (one subject per class, Mon-Fri, 6 weeks) ----
    // (course, course_name, instructor_id, instructor_name, room, from, to)
    const courseByGroup = {
      'EDU-GRP-8B': ('MAT-101', 'Mathematics', 'EDU-INS-0001', 'Mr. Robert Johnson', 'Room 102', '09:00:00', '10:30:00'),
      'EDU-GRP-9A': ('MAT-201', 'Mathematics', 'EDU-INS-0001', 'Mr. Robert Johnson', 'Room 102', '09:00:00', '10:30:00'),
      'EDU-GRP-11C': ('PHY-101', 'Physics', 'EDU-INS-0002', 'Dr. Sarah Mitchell', 'Lab 1', '11:00:00', '12:30:00'),
    };
    int schedSeq = 0;
    final scheduleByGroupDate = <String, String>{}; // 'group|date' -> schedule id
    Future<void> addSchedules(String groupId) async {
      final c = courseByGroup[groupId]!;
      for (var weekOffset = 0; weekOffset < 6; weekOffset++) {
        for (var day = 1; day <= 5; day++) {
          final date = monday.subtract(Duration(days: 7 * weekOffset)).add(Duration(days: day - 1));
          schedSeq++;
          final id = 'EDU-CSH-DEMO-$schedSeq';
          await db.insert('schedules', {
            'id': id,
            'course': c.$1,
            'course_name': c.$2,
            'group_id': groupId,
            'instructor': c.$3,
            'instructor_name': c.$4,
            'room': c.$5,
            'from_time': c.$6,
            'to_time': c.$7,
            'schedule_date': d(date),
          });
          scheduleByGroupDate['$groupId|${d(date)}'] = id;
        }
      }
    }

    for (final g in groups) {
      await addSchedules(g.$1);
    }

    // ---- Attendance (past dates only, linked to the class schedule) ----
    int attSeq = 0;
    String statusFor(int weekOffset, int day, int studentIdx) {
      final n = weekOffset * 31 + day * 7 + studentIdx * 5;
      if (n % 23 == 0) return 'Absent';
      if (n % 19 == 0) return 'Leave';
      if (n % 17 == 0) return 'Half Day';
      return 'Present';
    }

    for (var si = 0; si < students.length; si++) {
      final st = students[si];
      for (var weekOffset = 0; weekOffset < 6; weekOffset++) {
        for (var day = 1; day <= 5; day++) {
          final date = monday.subtract(Duration(days: 7 * weekOffset)).add(Duration(days: day - 1));
          if (!date.isBefore(today)) continue; // never mark today or the future
          attSeq++;
          await db.insert('attendance', {
            'id': 'EDU-ATT-DEMO-$attSeq',
            'schedule_id': scheduleByGroupDate['${st.$4}|${d(date)}'],
            'student_id': st.$1,
            'date': d(date),
            'status': statusFor(weekOffset, day, si),
          });
        }
      }
    }

    // ---- Assignments (2 past, 1 due soon, 1 upcoming per class) ----
    const planTitles = {
      'EDU-GRP-8B': ['Quadratic Equations Worksheet', 'Chapter Test: Linear Equations', 'Algebra Homework (Ex 6.1-6.3)', 'Project: Geometry in Daily Life'],
      'EDU-GRP-9A': ['Polynomials Assignment', 'Coordinate Geometry Worksheet', 'Mensuration Homework', 'Quiz: Number Systems'],
      'EDU-GRP-11C': ["Newton's Laws Problem Set", 'Kinematics Lab Report', 'Work & Energy Worksheet', 'Project: Projectile Motion'],
    };
    const planDescriptions = {
      'EDU-GRP-8B': ['Factor & solve: exercises 4.1-4.5, 20 marks', 'Full chapter, 40 marks, covers graphing', 'Practice sheet from the textbook', 'Present a 2D geometry model with a write-up'],
      'EDU-GRP-9A': ['Long division & remainder theorem, 25 marks', 'Plot and verify: 10 questions', 'Surface area & volume problems', 'MCQ quiz, 20 questions'],
      'EDU-GRP-11C': ['Problems 1-12, show all working', 'Perform the lab, attach observations', 'Numericals on energy conservation', 'Simulate and document a projectile'],
    };
    final groupStudents = <String, List<(String, String)>>{};
    for (final st in students) {
      groupStudents.putIfAbsent(st.$4, () => []).add((st.$1, st.$2));
    }

    int planSeq = 0;
    int subSeq = 0;
    for (final g in groups) {
      final gid = g.$1;
      final c = courseByGroup[gid]!;
      final titles = planTitles[gid]!;
      final descs = planDescriptions[gid]!;
      const offsets = [-12, -4, 3, 10]; // days from this week's Monday
      final sList = groupStudents[gid] ?? [];
      for (var p = 0; p < 4; p++) {
        planSeq++;
        final planId = 'EDU-PLAN-DEMO-$planSeq';
        final due = monday.add(Duration(days: offsets[p]));
        await db.insert('plans', {
          'id': planId,
          'title': titles[p],
          'course': c.$1,
          'course_name': c.$2,
          'group_id': gid,
          'due_date': d(due),
          'from_time': c.$6,
          'description': descs[p],
        });

        // Submissions for the two past plans (most students, mixed grading)
        if (p < 2) {
          for (var si = 0; si < sList.length; si++) {
            final (sid, sName) = sList[si];
            if (p == 1 && si % 3 == 2) continue; // one student missed plan 2
            subSeq++;
            final graded = p == 0 || si % 3 != 1;
            final fileName =
                'hw_${sName.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '_')}.pdf';
            await db.insert('submissions', {
              'id': 'EDU-SUB-DEMO-$subSeq',
              'plan_id': planId,
              'student_id': sid,
              'status': graded ? 'Graded' : 'Submitted',
              'score': graded ? (62.0 + ((si * 7 + p * 5) % 36)) : null,
              'feedback': graded
                  ? 'Good work — keep practising! (out of 100)'
                  : null,
              'file_name': fileName,
              'submitted_at': d(due.subtract(const Duration(days: 2))),
              'graded_at': graded ? d(due.add(const Duration(days: 1))) : null,
            });
          }
        }
      }
    }
  }
}

/// Tiny helpers for reading row values.
class SqfliteUtils {
  static int? firstInt(List<Map<String, Object?>> rows, [String col = 'c']) {
    if (rows.isEmpty) return null;
    final v = rows.first[col];
    return v is int ? v : int.tryParse(v?.toString() ?? '');
  }
}
