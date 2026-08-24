import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show Database;
import '../models/user_model.dart';
import '../models/school_model.dart';
import '../models/instructor_model.dart';
import '../models/student_model.dart';
import '../models/student_group_model.dart';
import '../models/course_schedule_model.dart';
import '../models/attendance_model.dart';
import '../models/assignment_model.dart';
import '../models/assignment_submission_model.dart';
import '../models/student_detail_model.dart';
import '../models/school_profile_model.dart';
import '../models/timetable_model.dart';
import '../models/super_school_model.dart';
import 'local_db.dart';

/// Demo build — offline API service backed by local SQLite.
///
/// Same public API as the production service so every screen works unchanged,
/// but reads/writes a local SQLite database on the device. There is no
/// network, no backend, no REST API — the database IS the backend.
class DemoApiService {
  static final DemoApiService _instance = DemoApiService._internal();
  factory DemoApiService() => _instance;
  DemoApiService._internal();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _storage async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  Future<Database> get _db => LocalDb.instance;

  // ------------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------------
  String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _today() => _d(DateTime.now());

  Map<String, dynamic> _userToJson(Map<String, Object?> u) {
    return {
      'name': u['id'],
      'email': u['email'],
      'full_name': u['full_name'],
      'role': u['role'],
      'student_id': u['student_id'],
      'instructor_id': u['instructor_id'],
    };
  }

  Future<UserModel?> _userByEmail(String email) async {
    final db = await _db;
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email.trim().toLowerCase()]);
    if (rows.isEmpty) return null;
    final u = rows.first;
    final json = _userToJson(u);
    if (u['student_id'] != null) {
      final students = await db.query('students', where: 'id = ?', whereArgs: [u['student_id']]);
      if (students.isNotEmpty) {
        json['student_groups'] = [students.first['group_id']];
      }
    }
    return UserModel.fromJson(json);
  }

  Future<String?> _studentGroupFor(String? studentId) async {
    if (studentId == null) return null;
    final db = await _db;
    final rows = await db.query('students', columns: ['group_id'], where: 'id = ?', whereArgs: [studentId]);
    return rows.isEmpty ? null : rows.first['group_id'] as String?;
  }

  Future<List<String>> _groupsForInstructor(String? instructorId) async {
    final db = await _db;
    final rows = await db.query(
      'schedules',
      columns: ['group_id'],
      where: 'instructor = ?',
      whereArgs: [instructorId],
    );
    return rows.map((r) => r['group_id'] as String).toSet().toList();
  }

  Future<String> _groupName(String? groupId) async {
    if (groupId == null) return '';
    final db = await _db;
    final rows = await db.query('groups', columns: ['name'], where: 'id = ?', whereArgs: [groupId]);
    return rows.isEmpty ? groupId : rows.first['name'] as String;
  }

  String? _studentId() => _currentUser?.studentId;
  String? _instructorId() => _currentUser?.instructorId;

  // ------------------------------------------------------------------
  // auth (local)
  // ------------------------------------------------------------------
  Future<AuthResult> login(String email, String password) async {
    final db = await _db;
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email.trim().toLowerCase()]);
    if (rows.isEmpty || rows.first['password'] != password) {
      return AuthResult(success: false, error: 'Invalid login credentials');
    }
    final user = await _userByEmail(email);
    if (user == null) {
      return AuthResult(success: false, error: 'Account not found');
    }
    _currentUser = user;
    final prefs = await _storage;
    await prefs.setString('user_data', jsonEncode(user.toJson()));
    return AuthResult(success: true, user: user, token: 'demo-local-token');
  }

  /// DEMO: no schools to probe — log in straight from the local database.
  Future<AuthResult> loginAnySchool(String email, String password) => login(email, password);

  Future<AuthResult> signupStudent({
    required String fullName,
    required String email,
    required String password,
    String? gender,
    String? studentGroup,
    String? city,
    String? state,
    String? country,
  }) async {
    final db = await _db;
    final existing = await db.query('users', where: 'email = ?', whereArgs: [email.trim().toLowerCase()]);
    if (existing.isNotEmpty) {
      return AuthResult(success: false, error: 'An account with this email already exists.');
    }
    if (password.length < 8) {
      return AuthResult(success: false, error: 'Password must be at least 8 characters long.');
    }

    final studentId = 'EDU-STU-DEMO-${DateTime.now().millisecondsSinceEpoch}';
    final group = studentGroup != null && studentGroup.isNotEmpty ? studentGroup : null;
    int? roll;
    if (group != null) {
      final rows = await db.query('students', columns: ['roll_number'], where: 'group_id = ?', whereArgs: [group]);
      roll = (rows.map((r) => r['roll_number'] as int? ?? 0).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
    }

    await db.transaction((txn) async {
      await txn.insert('users', {
        'id': email.trim().toLowerCase(),
        'email': email.trim().toLowerCase(),
        'full_name': fullName,
        'role': 'Student',
        'password': password,
        'student_id': studentId,
        'instructor_id': null,
      });
      await txn.insert('students', {
        'id': studentId,
        'student_name': fullName,
        'email': email.trim().toLowerCase(),
        'group_id': group,
        'roll_number': roll,
      });
    });

    final user = await _userByEmail(email);
    _currentUser = user;
    final prefs = await _storage;
    await prefs.setString('user_data', jsonEncode(user!.toJson()));
    return AuthResult(success: true, user: user, token: 'demo-local-token');
  }

  Future<bool> restoreSession() async {
    final prefs = await _storage;
    final userData = prefs.getString('user_data');
    if (userData == null || userData.isEmpty) return false;
    try {
      _currentUser = UserModel.fromJson(jsonDecode(userData));
      // confirm the user still exists locally
      final db = await _db;
      final rows = await db.query('users', where: 'email = ?', whereArgs: [_currentUser!.email]);
      if (rows.isEmpty) {
        _currentUser = null;
        await prefs.remove('user_data');
        return false;
      }
      return true;
    } catch (_) {
      _currentUser = null;
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await _storage;
    await prefs.remove('user_data');
  }

  Future<void> clearSession() async {
    _currentUser = null;
    final prefs = await _storage;
    await prefs.remove('user_data');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final db = await _db;
    final rows = await db.query('users', where: 'email = ?', whereArgs: [_currentUser?.email]);
    if (rows.isEmpty || rows.first['password'] != currentPassword) {
      throw DemoApiException(message: 'Current password is incorrect', statusCode: 401);
    }
    if (newPassword.length < 8) {
      throw DemoApiException(message: 'New password must be at least 8 characters long', statusCode: 400);
    }
    await db.update('users', {'password': newPassword}, where: 'email = ?', whereArgs: [_currentUser?.email]);
  }

  // ------------------------------------------------------------------
  // school profile (local)
  // ------------------------------------------------------------------
  Future<SchoolProfileModel> getSchoolProfile() async {
    final db = await _db;
    final rows = await db.query('school_profile', limit: 1);
    final r = rows.isEmpty ? <String, Object?>{} : rows.first;
    return SchoolProfileModel.fromJson({
      'school_name': r['school_name'],
      'motto': r['motto'],
      'logo_url': r['logo'],
      'contact_email': r['contact_email'],
      'contact_number': r['contact_number'],
      'website': r['website'],
      'address': r['address'],
    });
  }

  Future<SchoolProfileModel> updateSchoolProfile({
    String? schoolName,
    String? motto,
    String? contactEmail,
    String? contactNumber,
    String? website,
    String? address,
  }) async {
    final db = await _db;
    await db.update(
      'school_profile',
      {
        if (schoolName != null) 'school_name': schoolName,
        if (motto != null) 'motto': motto,
        if (contactEmail != null) 'contact_email': contactEmail,
        if (contactNumber != null) 'contact_number': contactNumber,
        if (website != null) 'website': website,
        if (address != null) 'address': address,
      },
      where: 'id = 1',
    );
    return getSchoolProfile();
  }

  /// DEMO: logo upload is not backed by a server — keep the seeded logo.
  Future<String> uploadSchoolLogo({
    required String fileName,
    required List<int> fileBytes,
  }) async {
    debugPrint('demo: logo upload skipped (offline) — $fileName');
    return '';
  }

  // ------------------------------------------------------------------
  // student data
  // ------------------------------------------------------------------
  Future<List<CourseScheduleModel>> getMyClasses() async {
    final db = await _db;
    final rows = await db.query('schedules');
    // One class box per (group, course) — use the most recent schedule date.
    final byKey = <String, Map<String, Object?>>{};
    for (final r in rows) {
      final key = '${r['group_id']}|${r['course']}';
      final cur = byKey[key];
      if (cur == null ||
          ((r['schedule_date'] as String? ?? '')
                  .compareTo(cur['schedule_date'] as String? ?? '') >
              0)) {
        byKey[key] = r;
      }
    }
    final sorted = byKey.values.toList()
      ..sort((a, b) => (a['course_name'] as String? ?? '')
          .compareTo(b['course_name'] as String? ?? ''));
    final out = <CourseScheduleModel>[];
    for (final r in sorted) {
      final json = _scheduleJson(r);
      json['student_group_name'] = await _groupName(r['group_id'] as String?);
      out.add(CourseScheduleModel.fromJson(json));
    }
    return out;
  }

  Map<String, dynamic> _scheduleJson(Map<String, Object?> r) => {
        'name': r['id'],
        'course': r['course'],
        'course_name': r['course_name'],
        'student_group': r['group_id'],
        'student_group_name': r['group_id'] == null ? null : r['group_id'],
        'instructor': r['instructor'],
        'instructor_name': r['instructor_name'],
        'schedule_date': r['schedule_date'],
        'from_time': r['from_time'],
        'to_time': r['to_time'],
        'room': r['room'],
        'is_completed': false,
      };

  Future<List<StudentModel>> getClassStudents(String courseSchedule) async {
    final db = await _db;
    final sched = await db.query('schedules', where: 'id = ?', whereArgs: [courseSchedule]);
    if (sched.isEmpty) return [];
    final groupId = sched.first['group_id'] as String;
    final rows = await db.query('students', where: 'group_id = ?', whereArgs: [groupId], orderBy: 'roll_number asc');
    final groupName = await _groupName(groupId);
    return rows.map((r) => StudentModel.fromJson({
          'name': r['id'],
          'student_name': r['student_name'],
          'student_email_id': r['email'],
          'student_group': groupId,
          'student_group_name': groupName,
          'roll_number': r['roll_number'],
          'group_roll_number': r['roll_number'],
        })).toList();
  }

  /// Every student in the local DB (across all classes), with their class
  /// name resolved — used by the teacher's student management screen.
  Future<List<StudentModel>> getAllStudents() async {
    final db = await _db;
    final rows = await db.query('students', orderBy: 'group_id asc, roll_number asc');
    final groups = await db.query('groups');
    final groupNames = {for (final g in groups) g['id']: g['name']};
    return rows.map((r) => StudentModel.fromJson({
          'name': r['id'],
          'student_name': r['student_name'],
          'student_email_id': r['email'],
          'student_group': r['group_id'],
          'student_group_name': r['group_id'] == null
              ? null
              : groupNames[r['group_id']],
          'roll_number': r['roll_number'],
          'group_roll_number': r['roll_number'],
          'age': r['age'],
          'gender': r['gender'],
        })).toList();
  }

  /// Adds a new student (and, when an email is given, a matching login
  /// account with the seeded student password so they can sign in too).
  Future<StudentModel> createStudent({
    required String name,
    String? email,
    String? groupId,
    int? rollNumber,
    int? age,
    String? gender,
  }) async {
    final db = await _db;
    final studentId = 'EDU-STU-DEMO-${DateTime.now().millisecondsSinceEpoch}';
    int? roll = rollNumber;
    if (roll == null && groupId != null) {
      final rows = await db.query(
        'students',
        columns: ['roll_number'],
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      roll = (rows
                  .map((r) => r['roll_number'] as int? ?? 0)
                  .fold<int>(0, (a, b) => a > b ? a : b)) +
              1;
    }
    final normalizedEmail = email?.trim().toLowerCase();

    await db.transaction((txn) async {
      await txn.insert('students', {
        'id': studentId,
        'student_name': name,
        'email': normalizedEmail,
        'group_id': groupId,
        'roll_number': roll,
        'age': age,
        'gender': gender,
      });
      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        final existing = await txn.query(
          'users',
          where: 'email = ?',
          whereArgs: [normalizedEmail],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert('users', {
            'id': normalizedEmail,
            'email': normalizedEmail,
            'full_name': name,
            'role': 'Student',
            'password': 'Student@123',
            'student_id': studentId,
            'instructor_id': null,
          });
        }
      }
    });

    final rows = await db.query('students', where: 'id = ?', whereArgs: [studentId]);
    return StudentModel.fromJson({
      'name': rows.first['id'],
      'student_name': rows.first['student_name'],
      'student_email_id': rows.first['email'],
      'student_group': rows.first['group_id'],
      'student_group_name': rows.first['group_id'] == null
          ? null
          : await _groupName(rows.first['group_id'] as String?),
      'roll_number': rows.first['roll_number'],
      'group_roll_number': rows.first['roll_number'],
      'age': rows.first['age'],
      'gender': rows.first['gender'],
    });
  }

  /// Updates a student's details and keeps their linked login account in
  /// sync (renamed / re-emailed) when one exists.
  Future<StudentModel> updateStudent({
    required String studentId,
    required String name,
    String? email,
    String? groupId,
    int? rollNumber,
    int? age,
    String? gender,
  }) async {
    final db = await _db;
    final normalizedEmail = email?.trim().toLowerCase();
    final oldRows = await db.query('students', where: 'id = ?', whereArgs: [studentId]);
    if (oldRows.isEmpty) {
      throw DemoApiException(message: 'Student not found', statusCode: 404);
    }

    await db.transaction((txn) async {
      await txn.update(
        'students',
        {
          'student_name': name,
          'email': normalizedEmail,
          'group_id': groupId,
          'roll_number': rollNumber,
          'age': age,
          'gender': gender,
        },
        where: 'id = ?',
        whereArgs: [studentId],
      );

      final userRows = await txn.query(
        'users',
        where: 'student_id = ?',
        whereArgs: [studentId],
        limit: 1,
      );
      if (userRows.isNotEmpty) {
        final oldUserEmail = userRows.first['email'] as String?;
        if (normalizedEmail == null || normalizedEmail.isEmpty) {
          // Email removed — drop the login account.
          if (oldUserEmail != null && oldUserEmail.isNotEmpty) {
            await txn.delete('users', where: 'id = ?', whereArgs: [oldUserEmail]);
          }
        } else if (oldUserEmail != null && oldUserEmail.isNotEmpty) {
          await txn.update(
            'users',
            {
              'id': normalizedEmail,
              'email': normalizedEmail,
              'full_name': name,
            },
            where: 'id = ?',
            whereArgs: [oldUserEmail],
          );
        } else {
          await txn.insert('users', {
            'id': normalizedEmail,
            'email': normalizedEmail,
            'full_name': name,
            'role': 'Student',
            'password': 'Student@123',
            'student_id': studentId,
            'instructor_id': null,
          });
        }
      }
    });

    return getAllStudents().then((all) => all.firstWhere((s) => s.id == studentId));
  }

  /// Removes a student together with their attendance, submissions and login
  /// account, so they disappear from rosters / reports everywhere.
  Future<void> deleteStudent(String studentId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('attendance', where: 'student_id = ?', whereArgs: [studentId]);
      await txn.delete('submissions', where: 'student_id = ?', whereArgs: [studentId]);
      await txn.delete('users', where: 'student_id = ?', whereArgs: [studentId]);
      await txn.delete('students', where: 'id = ?', whereArgs: [studentId]);
    });
  }

  Future<void> markAttendance({
    required String courseSchedule,
    required String studentGroup,
    required DateTime date,
    required List<AttendanceRecord> records,
  }) async {
    final db = await _db;
    final dateStr = _d(date);
    await db.transaction((txn) async {
      for (final rec in records) {
        final existing = await txn.query(
          'attendance',
          where: 'student_id = ? AND date = ?',
          whereArgs: [rec.studentId, dateStr],
          limit: 1,
        );
        final status = rec.status == AttendanceStatus.halfDay ? 'Leave' : rec.statusString;
        if (existing.isNotEmpty) {
          await txn.update('attendance', {'status': status},
              where: 'student_id = ? AND date = ?', whereArgs: [rec.studentId, dateStr]);
        } else {
          await txn.insert('attendance', {
            'id': 'EDU-ATT-${DateTime.now().microsecondsSinceEpoch}-${rec.studentId}',
            'schedule_id': courseSchedule,
            'student_id': rec.studentId,
            'date': dateStr,
            'status': status,
          });
        }
      }
    });
  }

  Future<List<AttendanceModel>> getAttendanceReport({
    String? courseSchedule,
    DateTime? date,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'attendance',
      where: courseSchedule != null && date != null
          ? 'schedule_id = ? AND date = ?'
          : courseSchedule != null
              ? 'schedule_id = ?'
              : date != null
                  ? 'date = ?'
                  : null,
      whereArgs: courseSchedule != null && date != null
          ? [courseSchedule, _d(date)]
          : courseSchedule != null
              ? [courseSchedule]
              : date != null
                  ? [_d(date)]
                  : null,
      orderBy: 'date asc',
    );
    final students = await db.query('students');
    final byId = {for (final s in students) s['id']: s['student_name']};
    return rows.map((r) => AttendanceModel.fromJson({
          'name': r['id'],
          'student': r['student_id'],
          'student_name': byId[r['student_id']],
          'course_schedule': r['schedule_id'],
          'student_attendance_date': r['date'],
          'status': r['status'],
        })).toList();
  }

  Future<AttendanceSummary> getMyAttendanceSummary() async {
    final db = await _db;
    final studentId = _studentId();
    final today = _today();
    final rows = await db.query('attendance',
        where: 'student_id = ? AND date <= ?', whereArgs: [studentId, today]);
    final total = rows.length;
    var attended = 0;
    final byCourse = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      if (r['status'] == 'Present' || r['status'] == 'Leave') attended++;
      String key = 'Other';
      if (r['schedule_id'] != null) {
        final s = await db.query('schedules', columns: ['course', 'course_name'], where: 'id = ?', whereArgs: [r['schedule_id']]);
        if (s.isNotEmpty) key = s.first['course_name'] as String? ?? (s.first['course'] as String? ?? 'Other');
      }
      byCourse.putIfAbsent(key, () => []).add(r);
    }
    final courseWise = {
      for (final e in byCourse.entries)
        e.key: (100 * e.value.where((r) => r['status'] == 'Present' || r['status'] == 'Leave').length / e.value.length)
            .clamp(0, 100)
            .toStringAsFixed(1)
      // keep as string in the map; convert below
    };
    final monthly = rows
        .map((r) => {'date': r['date'], 'status': r['status']})
        .toList();
    return AttendanceSummary(
      overallPercentage: total == 0 ? 0 : (100 * attended / total),
      courseWisePercentage: {
        for (final e in courseWise.entries) e.key: double.parse(e.value),
      },
      monthlyAttendance: monthly
          .map((m) => MonthlyAttendance(
                date: DateTime.parse(m['date'] as String),
                status: m['status'] as String,
              ))
          .toList(),
    );
  }

  Future<List<AttendanceModel>> getMyAttendance({String? course}) async {
    final db = await _db;
    final studentId = _studentId();
    final today = _today();
    final rows = await db.query('attendance',
        where: 'student_id = ? AND date <= ?', whereArgs: [studentId, today], orderBy: 'date asc');
    final students = await db.query('students', where: 'id = ?', whereArgs: [studentId]);
    final name = students.isEmpty ? '' : students.first['student_name'];
    return rows.map((r) => AttendanceModel.fromJson({
          'name': r['id'],
          'student': studentId,
          'student_name': name,
          'course_schedule': r['schedule_id'],
          'student_attendance_date': r['date'],
          'status': r['status'],
        })).toList();
  }

  Future<List<Map<String, dynamic>>> getMyAttendanceForMonth(int year, int month) async {
    final db = await _db;
    final studentId = _studentId();
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final rows = await db.query(
      'attendance',
      where: 'student_id = ? AND date LIKE ?',
      whereArgs: [studentId, '$prefix%'],
      orderBy: 'date asc',
    );
    return rows.map((r) => {'date': r['date'], 'status': r['status']}).toList();
  }

  Future<List<AssignmentModel>> getMyAssignments() async {
    final group = await _studentGroupFor(_studentId());
    if (group == null) return [];
    final db = await _db;
    final rows = await db.query('plans', where: 'group_id = ?', whereArgs: [group], orderBy: 'due_date asc');
    final out = <AssignmentModel>[];
    for (final p in rows) {
      out.add(await _planJson(p, db: db, studentView: true));
    }
    return out;
  }

  Future<List<AssignmentModel>> getAssignmentsOnDate(DateTime date) async {
    final group = await _studentGroupFor(_studentId());
    if (group == null) return [];
    final db = await _db;
    final rows = await db.query('plans',
        where: 'group_id = ? AND due_date = ?', whereArgs: [group, _d(date)], orderBy: 'from_time asc');
    final out = <AssignmentModel>[];
    for (final p in rows) {
      out.add(await _planJson(p, db: db, studentView: true));
    }
    return out;
  }

  Future<List<AssignmentModel>> getMyTeacherAssignments() async {
    final groups = await _groupsForInstructor(_instructorId());
    if (groups.isEmpty) return [];
    final db = await _db;
    final rows = await db.query('plans',
        where: 'group_id IN (${List.filled(groups.length, '?').join(',')})',
        whereArgs: groups,
        orderBy: 'due_date asc');
    final out = <AssignmentModel>[];
    for (final p in rows) {
      out.add(await _planJson(p, db: db));
    }
    return out;
  }

  Future<AssignmentModel> _planJson(Map<String, Object?> p, {required Database db, bool studentView = false}) async {
    final groupName = await _groupName(p['group_id'] as String?);
    final submissions = await db.query('submissions', where: 'plan_id = ?', whereArgs: [p['id']]);
    final studentsInGroup = await db.query('students', where: 'group_id = ?', whereArgs: [p['group_id']]);
    final mySub = studentView
        ? submissions.where((s) => s['student_id'] == _studentId()).toList()
        : <Map<String, Object?>>[];
    final graded = submissions.where((s) => s['status'] == 'Graded').length;

    return AssignmentModel.fromJson({
      'name': p['id'],
      'title': p['title'],
      'description': p['description'],
      'course': p['course'],
      'course_name': p['course_name'],
      'student_group': p['group_id'],
      'student_group_name': groupName,
      'instructor': _instructorId(),
      'instructor_name': _currentUser?.fullName,
      'due_date': p['due_date'],
      'from_time': p['from_time'],
      'creation': p['due_date'],
      'total_students': studentsInGroup.length,
      'submitted_count': submissions.where((s) => s['status'] == 'Submitted' || s['status'] == 'Graded').length,
      'submitted': mySub.isNotEmpty &&
          (mySub.first['status'] == 'Submitted' || mySub.first['status'] == 'Graded'),
      'submission': mySub.isNotEmpty
          ? {
              'grade': mySub.first['score'],
              'feedback': mySub.first['feedback'],
              'status': mySub.first['status'],
            }
          : null,
      'graded_count': graded,
    });
  }

  Future<AssignmentModel> createAssignment({
    required String title,
    required String course,
    required String studentGroup,
    required DateTime dueDate,
    String? description,
    String? filePath,
  }) async {
    final db = await _db;
    final id = 'EDU-PLAN-DEMO-${DateTime.now().millisecondsSinceEpoch}';
    final courseName = course; // local: course codes double as names unless mapped
    await db.insert('plans', {
      'id': id,
      'title': title,
      'course': course,
      'course_name': courseName,
      'group_id': studentGroup,
      'due_date': _d(dueDate),
      'from_time': '09:00:00',
      'description': description,
    });
    final rows = await db.query('plans', where: 'id = ?', whereArgs: [id]);
    return _planJson(rows.first, db: db);
  }

  Future<void> updateAssignment({
    required String assignmentId,
    required String title,
    required String course,
    required String studentGroup,
    required DateTime dueDate,
    String? description,
    String? filePath,
    bool clearAttachment = false,
  }) async {
    final db = await _db;
    await db.update(
      'plans',
      {
        'title': title,
        'course': course,
        'course_name': course,
        'group_id': studentGroup,
        'due_date': _d(dueDate),
        if (description != null) 'description': description,
      },
      where: 'id = ?',
      whereArgs: [assignmentId],
    );
  }

  Future<void> deleteAssignment(String assignmentId) async {
    final db = await _db;
    await db.delete('submissions', where: 'plan_id = ?', whereArgs: [assignmentId]);
    await db.delete('plans', where: 'id = ?', whereArgs: [assignmentId]);
  }

  Future<List<AssignmentSubmissionModel>> getAssignmentSubmissions(String assignment) async {
    final db = await _db;
    final rows = await db.query('submissions', where: 'plan_id = ?', whereArgs: [assignment], orderBy: 'submitted_at asc');
    final students = await db.query('students');
    final byId = {for (final s in students) s['id']: s['student_name']};
    final out = <AssignmentSubmissionModel>[];
    for (final s in rows) {
      out.add(AssignmentSubmissionModel.fromJson({
        'name': s['id'],
        'assignment': s['plan_id'],
        'student': s['student_id'],
        'student_name': byId[s['student_id']],
        'file': s['file_name'],
        'file_name': s['file_name'],
        'submitted_at': s['submitted_at'],
        'grade': s['score'],
        'feedback': s['feedback'],
        'status': s['status'],
      }));
    }
    return out;
  }

  Future<void> gradeSubmission({
    required String submission,
    required double grade,
    String? feedback,
  }) async {
    final db = await _db;
    await db.update(
      'submissions',
      {
        'status': 'Graded',
        'score': grade,
        'feedback': feedback,
        'graded_at': _today(),
      },
      where: 'id = ?',
      whereArgs: [submission],
    );
  }

  Future<void> unsubmitSubmission(String submission) async {
    final db = await _db;
    await db.update(
      'submissions',
      {'status': 'Not Submitted', 'file_name': null, 'score': null, 'graded_at': null},
      where: 'id = ?',
      whereArgs: [submission],
    );
  }

  Future<void> deleteSubmission(String submission) async {
    final db = await _db;
    await db.delete('submissions', where: 'id = ?', whereArgs: [submission]);
  }

  Future<void> submitAssignment({
    required String assignment,
    required String fileName,
    String? fileUrl,
  }) async {
    final db = await _db;
    final existing = await db.query('submissions',
        where: 'plan_id = ? AND student_id = ?', whereArgs: [assignment, _studentId()], limit: 1);
    final data = {
      'status': 'Submitted',
      'file_name': fileName,
      'submitted_at': _today(),
    };
    if (existing.isNotEmpty) {
      await db.update('submissions', data, where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      await db.insert('submissions', {
        'id': 'EDU-SUB-DEMO-${DateTime.now().microsecondsSinceEpoch}',
        'plan_id': assignment,
        'student_id': _studentId(),
        ...data,
      });
    }
  }

  Future<void> submitAssignmentWithFile({
    required String assignment,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    // DEMO: file bytes are not uploaded anywhere — store the file name so the
    // submission state is visible, fully offline.
    await submitAssignment(assignment: assignment, fileName: fileName);
  }

  Future<Map<String, dynamic>> getCourseAttendance(String courseSchedule) async {
    final db = await _db;
    final sched = await db.query('schedules', where: 'id = ?', whereArgs: [courseSchedule]);
    if (sched.isEmpty) return {'students': []};
    final s = sched.first;
    final groupId = s['group_id'] as String;
    final students = await db.query('students', where: 'group_id = ?', whereArgs: [groupId], orderBy: 'roll_number asc');
    final records = await db.query('attendance',
        where: 'student_id IN (${List.filled(students.length, '?').join(',')})',
        whereArgs: students.map((x) => x['id']).toList(),
        orderBy: 'date asc');
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final r in records) {
      grouped.putIfAbsent(r['student_id'] as String, () => []).add(r);
    }
    return {
      'course': s['course'],
      'course_name': s['course_name'],
      'student_group': groupId,
      'student_group_name': await _groupName(groupId),
      'instructor': s['instructor'],
      'instructor_name': s['instructor_name'],
      'room': s['room'],
      'from_time': s['from_time'],
      'to_time': s['to_time'],
      'students': students.map((st) {
        final recs = grouped[st['id']] ?? [];
        final present = recs.where((r) => r['status'] == 'Present' || r['status'] == 'Leave').length;
        return {
          'student': st['id'],
          'student_name': st['student_name'],
          'percentage': recs.isEmpty ? 0.0 : (100 * present / recs.length).toStringAsFixed(1),
          'records': recs.map((r) => {'date': r['date'], 'status': r['status']}).toList(),
        };
      }).toList(),
    };
  }

  Future<StudentDetailModel> getStudentDetail(String studentId, {String? course}) async {
    final db = await _db;
    final students = await db.query('students', where: 'id = ?', whereArgs: [studentId]);
    if (students.isEmpty) return StudentDetailModel.fromJson({'name': studentId});
    final st = students.first;
    final groupId = st['group_id'] as String?;
    final today = _today();

    final attRows = await db.query('attendance',
        where: 'student_id = ? AND date <= ?', whereArgs: [studentId, today], orderBy: 'date asc');
    var attended = 0;
    final byCourse = <String, List<Map<String, Object?>>>{};
    for (final r in attRows) {
      if (r['status'] == 'Present' || r['status'] == 'Leave') attended++;
      String key = 'Other';
      if (r['schedule_id'] != null) {
        final sc = await db.query('schedules', columns: ['course', 'course_name'], where: 'id = ?', whereArgs: [r['schedule_id']]);
        if (sc.isNotEmpty) key = sc.first['course_name'] as String? ?? (sc.first['course'] as String? ?? 'Other');
      }
      byCourse.putIfAbsent(key, () => []).add(r);
    }
    final courseWise = {
      for (final e in byCourse.entries)
        e.key: e.value.isEmpty
            ? 0.0
            : double.parse((100 * e.value.where((r) => r['status'] == 'Present' || r['status'] == 'Leave').length / e.value.length).toStringAsFixed(1)),
    };
    final overall = attRows.isEmpty ? 0.0 : (100 * attended / attRows.length);

    // grades (optionally course-filtered)
    final subRows = await db.query('submissions',
        where: 'student_id = ? AND status = ?', whereArgs: [studentId, 'Graded'], orderBy: 'graded_at desc');
    final grades = <Map<String, dynamic>>[];
    for (final sub in subRows) {
      final plans = await db.query('plans', where: 'id = ?', whereArgs: [sub['plan_id']]);
      if (plans.isEmpty) continue;
      final p = plans.first;
      if (course != null && p['course'] != course) continue;
      grades.add({
        'assignment': p['id'],
        'title': p['title'],
        'course_name': p['course_name'],
        'due_date': p['due_date'],
        'grade': sub['score'],
        'feedback': sub['feedback'],
        'status': 'Graded',
      });
    }

    return StudentDetailModel.fromJson({
      'name': studentId,
      'student_name': st['student_name'],
      'student_email_id': st['email'],
      'student_group': groupId,
      'student_group_name': groupId == null ? null : await _groupName(groupId),
      'roll_number': st['roll_number'],
      'group_roll_number': st['roll_number'],
      'course': course,
      'overall_attendance': overall,
      'course_wise_attendance': courseWise,
      'grades': grades,
    });
  }

  // ------------------------------------------------------------------
  // timetable
  // ------------------------------------------------------------------
  Future<TimetableModel> getMyTimetable({DateTime? weekStart}) async {
    final db = await _db;
    final groupId = await _studentGroupFor(_studentId());
    final ref = weekStart ?? DateTime.now();
    final mon = DateTime(ref.year, ref.month, ref.day).subtract(Duration(days: ref.weekday - 1));
    final end = mon.add(const Duration(days: 6));

    final rows = await db.query('schedules', where: 'group_id = ?', whereArgs: [groupId]);
    final entries = <Map<String, dynamic>>[];
    final teacherIds = <String>{};
    final subjectIds = <String>{};
    for (final r in rows) {
      final date = DateTime.tryParse(r['schedule_date'] as String? ?? '');
      if (date == null) continue;
      if (date.isBefore(mon) || date.isAfter(end)) continue;
      entries.add({
        'name': r['id'],
        'date': r['schedule_date'],
        'weekday': date.weekday,
        'from_time': r['from_time'],
        'to_time': r['to_time'],
        'course': r['course'],
        'course_name': r['course_name'],
        'room': r['room'],
        'instructor_name': r['instructor_name'],
        'student_group_name': await _groupName(groupId),
      });
      teacherIds.add(r['instructor'] as String);
      subjectIds.add(r['course'] as String);
    }
    entries.sort((a, b) {
      final cmp = (a['weekday'] as int).compareTo(b['weekday'] as int);
      if (cmp != 0) return cmp;
      return (a['from_time'] as String? ?? '').compareTo(b['from_time'] as String? ?? '');
    });

    final teachers = <Map<String, dynamic>>[];
    for (final tid in teacherIds) {
      final t = await db.query('instructors', where: 'id = ?', whereArgs: [tid]);
      if (t.isEmpty) continue;
      final courses = await db.query('schedules', columns: ['course'], where: 'instructor = ? AND group_id = ?', whereArgs: [tid, groupId]);
      teachers.add({
        'name': t.first['id'],
        'instructor_name': t.first['instructor_name'],
        'courses': courses.map((c) => c['course']).toSet().toList(),
      });
    }

    final courseNames = <String, String>{};
    for (final r in rows) {
      courseNames[r['course'] as String] =
          r['course_name'] as String? ?? r['course'] as String;
    }
    final subjects = [
      for (final sid in subjectIds)
        {'course': sid, 'course_name': courseNames[sid] ?? sid},
    ];

    return TimetableModel.fromJson({
      'week_start': _d(mon),
      'week_end': _d(end),
      'timetable': entries,
      'teachers': teachers,
      'subjects': subjects,
    });
  }

  // ------------------------------------------------------------------
  // signup pickers
  // ------------------------------------------------------------------
  Future<List<SchoolModel>> getPrograms() async {
    final db = await _db;
    final rows = await db.query('groups', columns: ['program'], distinct: true);
    return [
      for (final r in rows)
        if (r['program'] != null)
          SchoolModel.fromJson({'name': r['program'], 'school_name': r['program'], 'program': r['program']})
    ];
  }

  Future<List<StudentGroupModel>> getStudentGroups() async {
    final db = await _db;
    final rows = await db.query('groups', orderBy: 'name asc');
    return rows.map((r) => StudentGroupModel.fromJson({
          'name': r['id'],
          'student_group_name': r['name'],
          'program': r['program'],
        })).toList();
  }

  Future<StudentGroupModel> createStudentGroup({
    required String name,
    String? program,
  }) async {
    final db = await _db;
    final id = 'EDU-GRP-DEMO-${DateTime.now().millisecondsSinceEpoch}';
    await db.insert('groups', {
      'id': id,
      'name': name,
      'program': program,
    });
    return StudentGroupModel.fromJson({
      'name': id,
      'student_group_name': name,
      'program': program,
    });
  }

  Future<StudentGroupModel> updateStudentGroup({
    required String groupId,
    required String name,
    String? program,
  }) async {
    final db = await _db;
    await db.update(
      'groups',
      {
        'name': name,
        'program': program,
      },
      where: 'id = ?',
      whereArgs: [groupId],
    );
    return StudentGroupModel.fromJson({
      'name': groupId,
      'student_group_name': name,
      'program': program,
    });
  }

  Future<void> deleteStudentGroup(String groupId) async {
    final db = await _db;
    // Move students in this group to null group, delete schedules & plans
    await db.update('students', {'group_id': null}, where: 'group_id = ?', whereArgs: [groupId]);
    // Delete attendance linked to schedules of this group
    final scheds = await db.query('schedules', columns: ['id'], where: 'group_id = ?', whereArgs: [groupId]);
    for (final s in scheds) {
      await db.delete('attendance', where: 'schedule_id = ?', whereArgs: [s['id']]);
    }
    await db.delete('schedules', where: 'group_id = ?', whereArgs: [groupId]);
    // Delete assignments (plans) linked to this group
    final plans = await db.query('plans', columns: ['id'], where: 'group_id = ?', whereArgs: [groupId]);
    for (final p in plans) {
      await db.delete('submissions', where: 'plan_id = ?', whereArgs: [p['id']]);
    }
    await db.delete('plans', where: 'group_id = ?', whereArgs: [groupId]);
    await db.delete('groups', where: 'id = ?', whereArgs: [groupId]);
  }

  // ------------------------------------------------------------------
  // course schedules (subjects) CRUD
  // ------------------------------------------------------------------
  Future<List<CourseScheduleModel>> getCourseSchedulesForGroup(String groupId) async {
    final db = await _db;
    final rows = await db.query('schedules', where: 'group_id = ?', whereArgs: [groupId], orderBy: 'from_time asc');
    final groupName = await _groupName(groupId);
    return rows.map((r) => CourseScheduleModel.fromJson({
          'name': r['id'],
          'course': r['course'],
          'course_name': r['course_name'],
          'student_group': r['group_id'],
          'student_group_name': groupName,
          'instructor': r['instructor'],
          'instructor_name': r['instructor_name'],
          'room': r['room'],
          'from_time': r['from_time'],
          'to_time': r['to_time'],
          'schedule_date': r['schedule_date'],
        })).toList();
  }

  Future<List<CourseScheduleModel>> getAllCourseSchedules() async {
    final db = await _db;
    final rows = await db.query('schedules', orderBy: 'group_id asc, from_time asc');
    final groups = await db.query('groups');
    final groupNames = {for (final g in groups) g['id']: g['name']};
    return rows.map((r) => CourseScheduleModel.fromJson({
          'name': r['id'],
          'course': r['course'],
          'course_name': r['course_name'],
          'student_group': r['group_id'],
          'student_group_name': groupNames[r['group_id']],
          'instructor': r['instructor'],
          'instructor_name': r['instructor_name'],
          'room': r['room'],
          'from_time': r['from_time'],
          'to_time': r['to_time'],
          'schedule_date': r['schedule_date'],
        })).toList();
  }

  Future<CourseScheduleModel> createCourseSchedule({
    required String course,
    required String courseName,
    required String groupId,
    String? room,
    String? fromTime,
    String? toTime,
  }) async {
    final db = await _db;
    final id = 'EDU-CSH-DEMO-${DateTime.now().millisecondsSinceEpoch}';
    final instructorId = _instructorId();
    final instructorName = _currentUser?.fullName ?? '';
    // Use today's date as the schedule_date
    final today = _today();
    await db.insert('schedules', {
      'id': id,
      'course': course,
      'course_name': courseName,
      'group_id': groupId,
      'instructor': instructorId ?? '',
      'instructor_name': instructorName,
      'room': room,
      'from_time': fromTime ?? '09:00:00',
      'to_time': toTime ?? '10:00:00',
      'schedule_date': today,
    });
    final groupName = await _groupName(groupId);
    return CourseScheduleModel.fromJson({
      'name': id,
      'course': course,
      'course_name': courseName,
      'student_group': groupId,
      'student_group_name': groupName,
      'instructor': instructorId,
      'instructor_name': instructorName,
      'room': room,
      'from_time': fromTime ?? '09:00:00',
      'to_time': toTime ?? '10:00:00',
      'schedule_date': today,
    });
  }

  Future<void> updateCourseSchedule({
    required String scheduleId,
    required String course,
    required String courseName,
    String? room,
    String? fromTime,
    String? toTime,
  }) async {
    final db = await _db;
    await db.update(
      'schedules',
      {
        'course': course,
        'course_name': courseName,
        if (room != null) 'room': room,
        if (fromTime != null) 'from_time': fromTime,
        if (toTime != null) 'to_time': toTime,
      },
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  Future<void> deleteCourseSchedule(String scheduleId) async {
    final db = await _db;
    await db.delete('attendance', where: 'schedule_id = ?', whereArgs: [scheduleId]);
    await db.delete('schedules', where: 'id = ?', whereArgs: [scheduleId]);
  }

  Future<List<InstructorModel>> getInstructors() async {
    final db = await _db;
    final rows = await db.query('instructors', orderBy: 'instructor_name asc');
    return rows.map((r) => InstructorModel.fromJson({
          'name': r['id'],
          'instructor_name': r['instructor_name'],
          'email': r['email'],
        })).toList();
  }

  // ------------------------------------------------------------------
  // super admin / registry — NOT part of the offline demo
  // ------------------------------------------------------------------
  Future<List<PublicSchoolEntry>> getPublicSchools() async => const [];

  Future<List<SuperSchoolModel>> getSuperSchools() async => const [];

  Future<SuperSchoolModel> createSuperSchool({
    required String schoolName,
    required String site,
    required int port,
    String? dbName,
    String? motto,
    String? contactEmail,
    String? contactNumber,
    String? website,
    String? address,
    String? adminName,
    String? adminEmail,
    String? adminPassword,
  }) =>
      throw UnsupportedError('Super admin registry is not part of the offline demo app.');

  Future<SuperSchoolModel> updateSuperSchool({
    required String name,
    String? schoolName,
    String? site,
    int? port,
    String? contactEmail,
    String? contactNumber,
    String? website,
    String? motto,
    String? address,
    String? adminName,
    String? adminEmail,
  }) =>
      throw UnsupportedError('Super admin registry is not part of the offline demo app.');

  Future<SuperSchoolModel> resetSuperAdminPassword({
    required String name,
    required String newPassword,
  }) =>
      throw UnsupportedError('Super admin registry is not part of the offline demo app.');

  Future<void> deleteSuperSchool(String name) =>
      throw UnsupportedError('Super admin registry is not part of the offline demo app.');

  // ------------------------------------------------------------------
  // admin dashboard — web app territory; demo returns empty data
  // ------------------------------------------------------------------
  Future<AdminDashboardData> getAdminDashboard() async => AdminDashboardData();
  Future<List<SchoolModel>> getSchools() async => [];
  Future<List<InstructorModel>> getAdminTeachers() async => [];
  Future<List<StudentGroupModel>> getAdminClasses() async => [];
  Future<List<StudentModel>> getAdminStudents() async => [];

  // ------------------------------------------------------------------
  // generic network stubs — never used by the offline demo screens
  // ------------------------------------------------------------------
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async =>
      throw UnsupportedError('Offline demo: no network available.');
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async =>
      throw UnsupportedError('Offline demo: no network available.');
  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async =>
      throw UnsupportedError('Offline demo: no network available.');
  Future<dynamic> delete(String endpoint) async =>
      throw UnsupportedError('Offline demo: no network available.');
  Future<dynamic> callMethod(String method, {Map<String, dynamic>? args}) async =>
      throw UnsupportedError('Offline demo: no network available.');
  Future<List<dynamic>> getList(String doctype,
          {List<String>? fields, Map<String, dynamic>? filters, String? orderBy, int? limit}) async =>
      [];
  Future<Map<String, dynamic>> getDoc(String doctype, String name) async => {};
  Future<Map<String, dynamic>> createDoc(String doctype, Map<String, dynamic> data) async => {};
  Future<Map<String, dynamic>> updateDoc(String doctype, String name, Map<String, dynamic> data) async => {};
  Future<void> deleteDoc(String doctype, String name) async {}
}

/// Auth result from login
class AuthResult {
  final bool success;
  final UserModel? user;
  final String? token;
  final String? error;

  AuthResult({
    required this.success,
    this.user,
    this.token,
    this.error,
  });
}

/// API exception for local service errors.
class DemoApiException implements Exception {
  final String message;
  final int? statusCode;

  DemoApiException({required this.message, this.statusCode});

  @override
  String toString() => 'DemoApiException: $message (Status: $statusCode)';
}

/// Attendance record for marking attendance
class AttendanceRecord {
  final String studentId;
  final AttendanceStatus status;

  AttendanceRecord({
    required this.studentId,
    required this.status,
  });

  String get statusString {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.leave:
        return 'Leave';
    }
  }
}

/// Attendance summary for student dashboard
class AttendanceSummary {
  final double overallPercentage;
  final Map<String, double> courseWisePercentage;
  final List<MonthlyAttendance> monthlyAttendance;

  AttendanceSummary({
    required this.overallPercentage,
    required this.courseWisePercentage,
    required this.monthlyAttendance,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      overallPercentage: (json['overall_percentage'] ?? 0).toDouble(),
      courseWisePercentage: Map<String, double>.from(
        (json['course_wise_percentage'] as Map? ?? {}).map(
          (key, value) => MapEntry(key.toString(), (value ?? 0).toDouble()),
        ),
      ),
      monthlyAttendance: (json['monthly_attendance'] as List? ?? [])
          .map<MonthlyAttendance>(
            (m) => MonthlyAttendance.fromJson((m as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

/// Monthly attendance record
class MonthlyAttendance {
  final DateTime date;
  final String status;

  MonthlyAttendance({
    required this.date,
    required this.status,
  });

  factory MonthlyAttendance.fromJson(Map<String, dynamic> json) {
    return MonthlyAttendance(
      date: DateTime.parse(json['date'].toString()),
      status: json['status']?.toString() ?? 'Present',
    );
  }
}

/// Admin dashboard data model
class AdminDashboardData {
  final SchoolModel? school;
  final List<SchoolModel> schools;
  final List<InstructorModel> teachers;
  final List<StudentModel> students;
  final List<StudentGroupModel> classes;

  AdminDashboardData({
    this.school,
    this.schools = const [],
    this.teachers = const [],
    this.students = const [],
    this.classes = const [],
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    return AdminDashboardData(
      school: json['school'] is Map<String, dynamic>
          ? SchoolModel.fromJson(json['school'])
          : null,
      schools: (json['schools'] ?? [])
          .map<SchoolModel>((s) => SchoolModel.fromJson(s))
          .toList(),
      teachers: (json['teachers'] ?? [])
          .map<InstructorModel>((t) => InstructorModel.fromJson(t))
          .toList(),
      students: (json['students'] ?? [])
          .map<StudentModel>((s) => StudentModel.fromJson(s))
          .toList(),
      classes: (json['classes'] ?? [])
          .map<StudentGroupModel>((c) => StudentGroupModel.fromJson(c))
          .toList(),
    );
  }
}
