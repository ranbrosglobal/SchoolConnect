import 'dart:convert';
import 'dart:io' show File, Platform;
import 'dart:typed_data' show Uint8List;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'export_service.dart';
import '../models/user_model.dart';
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
import '../models/instructor_model.dart';
import '../models/school_model.dart';

/// Backend API service for School Connect.
///
/// Auth: Firebase Auth (Google/Apple/Email) → Backend session via social_login.
/// Data: All reads/writes go to the Node.js + SQLite backend.
///
/// No more Google Sheets API — the backend is the single source of truth.
class GoogleSheetsService {
  static final GoogleSheetsService _instance = GoogleSheetsService._internal();
  factory GoogleSheetsService() => _instance;
  GoogleSheetsService._internal();

  final _storage = const FlutterSecureStorage();
  final _firebaseAuth = fb.FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  String? _sessionCookie;
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  fb.User? get firebaseUser => _firebaseAuth.currentUser;

  // ─────────────────────────────────────────────────────────────────────
  // HTTP helpers
  // ─────────────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_sessionCookie != null) 'Cookie': 'sid=$_sessionCookie',
  };

  /// Make a GET request to the backend.
  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? params]) async {
    final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/method/$path')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers).timeout(ApiConfig.connectionTimeout);
    return _handleResponse(response);
  }

  /// Make a POST request to the backend.
  Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/method/$path');
    final response = await http.post(uri, headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(ApiConfig.connectionTimeout);
    return _handleResponse(response);
  }

  /// Handle HTTP response, extract session cookie, parse JSON.
  Map<String, dynamic> _handleResponse(http.Response response) {
    // Extract session cookie from Set-Cookie header
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final match = RegExp(r'sid=([^;]+)').firstMatch(setCookie);
      if (match != null) {
        _sessionCookie = match.group(1);
      }
    }

    if (response.statusCode == 404) {
      throw Exception('Server endpoint not found. Is the backend running?');
    }

    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = body['message'] ?? body['exc_type'] ?? 'Request failed (${response.statusCode})';
      throw Exception(message);
    }

    // Backend wraps responses in { message: ... }
    return body is Map<String, dynamic> ? (body['message'] ?? body) : body;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Auth
  // ─────────────────────────────────────────────────────────────────────

  /// Sign in with Google via Firebase Auth, then create a backend session.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult(success: false, error: 'Google sign-in was cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final fbUser = userCredential.user;
      if (fbUser == null || fbUser.email == null) {
        return AuthResult(success: false, error: 'Failed to get user info from Google');
      }

      // Create backend session
      return await _createBackendSession(fbUser.email!);
    } catch (e) {
      debugPrint('Firebase Google sign-in error: $e');
      return AuthResult(success: false, error: 'Sign-in failed: ${e.toString()}');
    }
  }

  /// Sign in with Apple via Firebase Auth, then create a backend session.
  Future<AuthResult> signInWithApple() async {
    try {
      final appleCredential = await apple.SignInWithApple.getAppleIDCredential(
        scopes: [
          apple.AppleIDAuthorizationScopes.email,
          apple.AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = fb.OAuthProvider('apple.com').credential(
        accessToken: appleCredential.authorizationCode,
        idToken: appleCredential.identityToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(oauthCredential);
      final fbUser = userCredential.user;

      String? email = fbUser?.email ?? appleCredential.email;
      if (email == null || email.isEmpty) {
        await signOut();
        return AuthResult(
          success: false,
          error: 'Could not determine email from Apple Sign-In. Please try Google or email login.',
        );
      }

      // Update display name from Apple if available
      if (appleCredential.givenName != null && fbUser != null) {
        await fbUser.updateDisplayName(
          '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim(),
        );
      }

      // Create backend session
      return await _createBackendSession(email);
    } catch (e) {
      debugPrint('Apple sign-in error: $e');
      if (e is apple.SignInWithAppleAuthorizationException) {
        if (e.code == apple.AuthorizationErrorCode.canceled) {
          return AuthResult(success: false, error: 'Apple sign-in was cancelled');
        }
      }
      return AuthResult(success: false, error: 'Apple sign-in failed: ${e.toString()}');
    }
  }

  /// Sign in with email/password via the backend.
  /// Uses direct backend login instead of Firebase Auth.
  Future<AuthResult> login(String email, String password) async {
    try {
      // Use direct backend login (email + password)
      final result = await _post('school_connect.api.mobile.login', {
        'email': email.toLowerCase().trim(),
        'password': password,
      });

      final user = UserModel.fromJson(result);
      _currentUser = user;
      await _saveSession(user);

      return AuthResult(success: true, user: user);
    } catch (e) {
      debugPrint('Backend login error: $e');
      String msg = 'Login failed';
      if (e.toString().contains('Invalid email or password')) {
        msg = 'Invalid email or password';
      } else if (e.toString().contains('No account found')) {
        msg = 'No account found with this email. Contact your administrator.';
      } else if (e.toString().contains('disabled')) {
        msg = 'This account has been disabled. Contact your administrator.';
      } else if (e.toString().contains('Cannot reach')) {
        msg = 'Cannot connect to server. Please check your connection.';
      } else {
        msg = e.toString();
      }
      return AuthResult(success: false, error: msg);
    }
  }

  /// Login with auto school detection (same as login for Firebase).
  Future<AuthResult> loginAnySchool(String email, String password) async {
    return login(email, password);
  }

  /// Create a backend session after Firebase Auth succeeds.
  Future<AuthResult> _createBackendSession(String email) async {
    try {
      final result = await _post('school_connect.api.auth.social_login', {
        'email': email.toLowerCase().trim(),
      });

      final user = UserModel.fromJson(result);
      _currentUser = user;
      await _saveSession(user);

      return AuthResult(success: true, user: user);
    } catch (e) {
      debugPrint('Backend session creation error: $e');
      return AuthResult(
        success: false,
        error: 'Email "$email" not found in the system. Ask your admin to create an account.',
      );
    }
  }

  /// Sign up student — creates backend user and logs in.
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
    try {
      // First, try to login with existing credentials (user might already exist)
      final loginResult = await login(email, password);
      if (loginResult.success) {
        return loginResult;
      }

      // If login failed with "not found", try to create the account
      if (loginResult.error?.contains('No account found') == true) {
        // Note: Account creation must be done by admin through the school admin portal
        return AuthResult(
          success: false, 
          error: 'Account not found. Please contact your school administrator to create an account.',
        );
      }

      return loginResult;
    } catch (e) {
      debugPrint('Signup error: $e');
      return AuthResult(success: false, error: 'Signup failed: ${e.toString()}');
    }
  }

  /// Restore session from stored backend cookie.
  Future<bool> restoreSession() async {
    try {
      final storedCookie = await _storage.read(key: 'session_cookie');
      final storedUser = await _storage.read(key: 'user_data');

      if (storedCookie != null && storedUser != null) {
        _sessionCookie = storedCookie;
        _currentUser = UserModel.fromJson(jsonDecode(storedUser));

        // Verify session is still valid
        try {
          final result = await _get('school_connect.api.auth.get_session');
          if (result['isLoggedIn'] == true) {
            _currentUser = UserModel.fromJson(result);
            await _saveSession(_currentUser!);
            return true;
          }
        } catch (_) {
          // Session expired, fall through
        }
      }

      // Clear invalid session data
      _sessionCookie = null;
      _currentUser = null;
      await _storage.delete(key: 'user_data');
      await _storage.delete(key: 'session_cookie');
      
      return false;
    } catch (e) {
      debugPrint('Session restore error: $e');
      return false;
    }
  }

  /// Sign out from Firebase + Google + clear local data.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
    _sessionCookie = null;
    _currentUser = null;
    await _storage.delete(key: 'user_data');
    await _storage.delete(key: 'session_cookie');
  }

  /// Clear session without server call.
  Future<void> clearSession() async {
    _sessionCookie = null;
    _currentUser = null;
    await _storage.delete(key: 'user_data');
  }

  /// Change password via backend.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _post('school_connect.api.auth.change_password', {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    } catch (e) {
      debugPrint('Change password error: $e');
      throw Exception('Failed to change password: ${e.toString()}');
    }
  }

  /// Logout.
  Future<void> logout() => signOut();

  // ─────────────────────────────────────────────────────────────────────
  // Session persistence
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _saveSession(UserModel user) async {
    await _storage.write(key: 'user_data', value: jsonEncode(user.toJson()));
    if (_sessionCookie != null) {
      await _storage.write(key: 'session_cookie', value: _sessionCookie!);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Admin Dashboard
  // ─────────────────────────────────────────────────────────────────────

  Future<AdminDashboardData> getAdminDashboard() async {
    final result = await _get('school_connect.api.admin.get_admin_dashboard');
    return AdminDashboardData.fromJson(result);
  }

  Future<List<InstructorModel>> getAdminTeachers() async {
    final result = await _get('school_connect.api.admin.get_admin_teachers');
    final list = result is List ? result : (result['teachers'] ?? []);
    return (list as List).map((t) => InstructorModel.fromJson(t)).toList();
  }

  Future<List<StudentGroupModel>> getAdminClasses() async {
    final result = await _get('school_connect.api.admin.get_admin_classes');
    final list = result is List ? result : (result['classes'] ?? []);
    return (list as List).map((c) => StudentGroupModel.fromJson(c)).toList();
  }

  Future<List<StudentModel>> getAdminStudents() async {
    final result = await _get('school_connect.api.admin.get_admin_students');
    final list = result is List ? result : (result['students'] ?? []);
    return (list as List).map((s) => StudentModel.fromJson(s)).toList();
  }

  Future<List<SchoolModel>> getSchools() async {
    final result = await _get('school_connect.api.admin.get_schools');
    final list = result is List ? result : (result['schools'] ?? []);
    return (list as List).map((s) => SchoolModel.fromJson(s)).toList();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Teacher: Classes, Students, Schedules
  // ─────────────────────────────────────────────────────────────────────

  Future<List<CourseScheduleModel>> getMyClasses() async {
    final result = await _get('school_connect.api.mobile.get_teacher_classes');
    final list = result is List ? result : [];
    return (list as List).map((c) => CourseScheduleModel.fromJson(c)).toList();
  }

  Future<List<StudentModel>> getClassStudents(String courseSchedule) async {
    final result = await _get('school_connect.api.mobile.get_class_students', {
      'class_id': courseSchedule,
    });
    final list = result is List ? result : (result['students'] ?? []);
    return (list as List).map((s) => StudentModel.fromJson(s)).toList();
  }

  Future<List<StudentModel>> getAllStudents() async {
    final result = await _get('school_connect.api.admin.get_admin_students');
    final list = result is List ? result : (result['students'] ?? []);
    return (list as List).map((s) => StudentModel.fromJson(s)).toList();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Attendance
  // ─────────────────────────────────────────────────────────────────────

  Future<void> markAttendance({
    required String courseSchedule,
    required String studentGroup,
    required DateTime date,
    required List<AttendanceRecord> records,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    await _post('school_connect.api.mobile.mark_attendance', {
      'class_id': studentGroup,
      'date': dateStr,
      'course': courseSchedule,
      'records': records.map((r) => {
        'student_id': r.studentId,
        'status': r.statusString,
      }).toList(),
    });
  }

  Future<List<AttendanceModel>> getAttendanceReport({
    String? courseSchedule,
    DateTime? date,
  }) async {
    final result = await _get('school_connect.api.mobile.get_my_attendance');
    final records = result['records'] is List ? result['records'] as List : [];
    return records.map((r) => AttendanceModel.fromJson(r)).toList();
  }

  Future<AttendanceSummary> getMyAttendanceSummary() async {
    final result = await _get('school_connect.api.mobile.get_my_attendance');
    final summary = result['summary'] ?? {};
    return AttendanceSummary(
      overallPercentage: (summary['overall'] ?? 0).toDouble(),
      courseWisePercentage: {},
      monthlyAttendance: [],
    );
  }

  Future<List<AttendanceModel>> getMyAttendance({String? course}) async {
    final result = await _get('school_connect.api.mobile.get_my_attendance');
    final records = result['records'] is List ? result['records'] as List : [];
    return records.map((r) => AttendanceModel.fromJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getMyAttendanceForMonth(int year, int month) async {
    final result = await _get('school_connect.api.mobile.get_my_attendance');
    final records = result['records'] is List ? result['records'] as List : [];
    final prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    return records
        .where((r) => (r['date'] ?? '').toString().startsWith(prefix))
        .map<Map<String, dynamic>>((r) => {'date': r['date'], 'status': r['status']})
        .toList();
  }

  Future<Map<String, dynamic>> getCourseAttendance(String courseSchedule) async {
    final result = await _get('school_connect.api.mobile.get_my_attendance');
    return {
      'course_schedule': courseSchedule,
      'students': result['records'] ?? [],
    };
  }

  // ─────────────────────────────────────────────────────────────────────
  // Assignments
  // ─────────────────────────────────────────────────────────────────────

  Future<List<AssignmentModel>> getMyAssignments() async {
    final result = await _get('school_connect.api.mobile.get_student_assignments');
    final list = result is List ? result : [];
    return (list as List).map((a) => AssignmentModel.fromJson(a)).toList();
  }

  Future<List<AssignmentModel>> getMyTeacherAssignments() async {
    final result = await _get('school_connect.api.mobile.get_teacher_assignments');
    final list = result is List ? result : [];
    return (list as List).map((a) => AssignmentModel.fromJson(a)).toList();
  }

  Future<AssignmentModel> createAssignment({
    required String title,
    required String course,
    required String studentGroup,
    required DateTime dueDate,
    String? description,
    String? filePath,
    List<int>? fileBytes,
  }) async {
    final payload = await _filePayload(filePath, fileBytes);
    final result = await _post('school_connect.api.mobile.create_assignment', {
      'title': title,
      'course': course,
      'class_id': studentGroup,
      'due_date': dueDate.toIso8601String().split('T')[0],
      'description': description ?? '',
      ...payload,
    });
    return AssignmentModel.fromJson(result);
  }

  /// Builds the base64 upload fields from in-memory bytes when available,
  /// falling back to reading the file from disk.
  Future<Map<String, String>> _filePayload(String? filePath, List<int>? fileBytes) async {
    if (fileBytes != null && fileBytes.isNotEmpty) {
      final name = (filePath ?? 'attachment').split(Platform.pathSeparator).last;
      return {'file_name': name, 'file_data': base64Encode(fileBytes)};
    }
    if (filePath == null || kIsWeb) return const {};
    try {
      final bytes = await File(filePath).readAsBytes();
      return {'file_name': filePath.split(Platform.pathSeparator).last, 'file_data': base64Encode(bytes)};
    } catch (e) {
      debugPrint('Failed to read attachment $filePath: $e');
      return const {};
    }
  }

  Future<void> updateAssignment({
    required String assignmentId,
    required String title,
    required String course,
    required String studentGroup,
    required DateTime dueDate,
    String? description,
    String? filePath,
    List<int>? fileBytes,
    bool clearAttachment = false,
  }) async {
    final payload = await _filePayload(filePath, fileBytes);
    await _post('school_connect.api.mobile.update_assignment', {
      'id': assignmentId,
      'title': title,
      'course': course,
      'class_id': studentGroup,
      'due_date': dueDate.toIso8601String().split('T')[0],
      'description': description ?? '',
      ...payload,
      'clear_attachment': clearAttachment,
    });
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _post('school_connect.api.mobile.delete_assignment', {'id': assignmentId});
  }

  /// Fetches an uploaded file (assignment attachment or submission) and
  /// returns its raw bytes.
  Future<Uint8List> downloadFile(String fileId) async {
    final result = await _get('school_connect.api.mobile.get_file', {'file_id': fileId});
    final data = result['data'] as String?;
    if (data == null || data.isEmpty) throw Exception('File has no content');
    return base64Decode(data);
  }

  /// Downloads a file and opens the platform share sheet so the user can
  /// save it anywhere (Files, Google Drive, WhatsApp, …).
  Future<void> downloadAndShareFile(String fileId, String fileName) async {
    final bytes = await downloadFile(fileId);
    await ExportService.instance.shareBytes(bytes, fileName, _mimeTypeFor(fileName));
  }

  String _mimeTypeFor(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'txt' || 'md' => 'text/plain',
      'csv' => 'text/csv',
      'zip' => 'application/zip',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      _ => 'application/octet-stream',
    };
  }

  Future<List<AssignmentModel>> getAssignmentsOnDate(DateTime date) async {
    final result = await _get('school_connect.api.mobile.get_student_assignments');
    final list = result is List ? result : [];
    final dateStr = date.toIso8601String().split('T')[0];
    return (list as List)
        .where((a) => a['due_date'] == dateStr)
        .map((a) => AssignmentModel.fromJson(a))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Submissions
  // ─────────────────────────────────────────────────────────────────────

  Future<List<AssignmentSubmissionModel>> getAssignmentSubmissions(String assignment) async {
    final result = await _get('school_connect.api.mobile.get_assignment_submissions', {
      'assignment_id': assignment,
    });
    final list = result is List ? result : (result['submissions'] ?? []);
    return (list as List)
        .map((s) => AssignmentSubmissionModel.fromJson(Map<String, dynamic>.from(s)))
        .toList();
  }

  Future<void> gradeSubmission({
    required String submission,
    required double grade,
    String? feedback,
  }) async {
    await _post('school_connect.api.mobile.grade_submission', {
      'submission_id': submission,
      'grade': grade,
      if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
    });
  }

  Future<void> submitAssignment({
    required String assignment,
    required String fileName,
    String? fileUrl,
  }) async {
    await _post('school_connect.api.mobile.submit_assignment', {
      'assignment_id': assignment,
      'file_name': fileName,
    });
  }

  Future<void> unsubmitSubmission(String submission) async {
    await _post('school_connect.api.mobile.unsubmit_submission', {'submission_id': submission});
  }

  Future<void> deleteSubmission(String submission) async {
    await _post('school_connect.api.mobile.delete_submission', {'submission_id': submission});
  }

  Future<void> submitAssignmentWithFile({
    required String assignment,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    await _post('school_connect.api.mobile.submit_assignment', {
      'assignment_id': assignment,
      'file_name': fileName,
      'file_data': base64Encode(fileBytes),
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // Student Detail
  // ─────────────────────────────────────────────────────────────────────

  Future<StudentDetailModel> getStudentDetail(String studentId, {String? course}) async {
    final result = await _get('school_connect.api.mobile.get_class_students', {
      'class_id': studentId,
    });
    final students = result['students'] is List ? result['students'] as List : [];
    if (students.isEmpty) throw Exception('Student not found');
    return StudentDetailModel.fromJson(students.first);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Teacher Management CRUD
  // ─────────────────────────────────────────────────────────────────────

  Future<void> createStudentGroup({String? name, String? program, String? school}) async {
    await _post('school_connect.api.admin.create_class', {
      'name': name ?? '',
      'program': program ?? '',
      'school': school ?? _currentUser?.schoolId ?? '',
    });
  }

  Future<void> updateStudentGroup({String? groupId, String? name, String? program}) async {
    await _post('school_connect.api.admin.update_class', {
      'id': groupId ?? '',
      if (name != null) 'name': name,
      if (program != null) 'program': program,
    });
  }

  Future<void> deleteStudentGroup(String groupId) async {
    await _post('school_connect.api.admin.delete_class', {'id': groupId});
  }

  Future<List<CourseScheduleModel>> getCourseSchedulesForGroup(String groupId) async {
    final result = await _get('school_connect.api.admin.get_timetable', {'class': groupId});
    final entries = result['entries'] is List ? result['entries'] as List : [];
    return entries.map((s) => CourseScheduleModel.fromJson(s)).toList();
  }

  Future<void> createCourseSchedule({
    String? course, String? courseName, required String groupId,
    String? room, String? fromTime, String? toTime,
  }) async {
    await _post('school_connect.api.admin.set_timetable_entry', {
      'class_id': groupId,
      'day': 'Monday',
      'period': 1,
      'teacher_id': _currentUser?.id ?? '',
      'subject': courseName ?? course ?? '',
    });
  }

  Future<void> updateCourseSchedule({
    required String scheduleId, String? course, String? courseName,
    String? groupId, String? room, String? fromTime, String? toTime,
  }) async {
    await _post('school_connect.api.admin.set_timetable_entry', {
      'class_id': groupId ?? '',
      'day': 'Monday',
      'period': 1,
      'teacher_id': _currentUser?.id ?? '',
      'subject': courseName ?? course ?? '',
    });
  }

  Future<void> deleteCourseSchedule(String scheduleId) async {
    await _post('school_connect.api.admin.remove_timetable_entry', {'id': scheduleId});
  }

  Future<void> createStudent({
    required String name, String? email, String? groupId,
    dynamic rollNumber, dynamic age, String? gender,
  }) async {
    await _post('school_connect.api.admin.create_student', {
      'name': name,
      'email': email ?? '',
      'class_id': groupId ?? '',
      'roll_number': rollNumber,
    });
  }

  Future<void> updateStudent({
    required String studentId, String? name, String? email,
    String? groupId, dynamic rollNumber, dynamic age, String? gender,
  }) async {
    await _post('school_connect.api.admin.update_student', {
      'id': studentId,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (groupId != null) 'class_id': groupId,
      if (rollNumber != null) 'roll_number': rollNumber,
    });
  }

  Future<void> deleteStudent(String studentId) async {
    await _post('school_connect.api.admin.delete_student', {'id': studentId});
  }

  // ─────────────────────────────────────────────────────────────────────
  // Timetable
  // ─────────────────────────────────────────────────────────────────────

  Future<TimetableModel> getMyTimetable({DateTime? weekStart}) async {
    final result = await _get('school_connect.api.mobile.get_student_schedule');
    final entries = result is List ? result : [];
    return TimetableModel.fromJson({
      'timetable': entries,
      'teachers': [],
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // School Profile
  // ─────────────────────────────────────────────────────────────────────

  Future<SchoolProfileModel> getSchoolProfile() async {
    try {
      final result = await _get('school_connect.api.mobile.get_school_profile');
      return SchoolProfileModel.fromJson(result);
    } catch (_) {
      return SchoolProfileModel.fromJson({});
    }
  }

  Future<SchoolProfileModel> updateSchoolProfile({
    String? schoolName, String? motto, String? contactEmail,
    String? contactNumber, String? website, String? address,
  }) async {
    return getSchoolProfile();
  }

  Future<String> uploadSchoolLogo({
    required String fileName, required List<int> fileBytes,
  }) async {
    return '';
  }

  // ─────────────────────────────────────────────────────────────────────
  // Super Admin
  // ─────────────────────────────────────────────────────────────────────

  Future<List<PublicSchoolEntry>> getPublicSchools() async {
    final result = await _get('school_connect.api.admin.get_schools');
    final list = result is List ? result : (result['schools'] ?? []);
    return (list as List).map((s) => PublicSchoolEntry.fromJson(s)).toList();
  }

  Future<List<SuperSchoolModel>> getSuperSchools() async {
    final result = await _get('school_connect.api.admin.get_schools');
    final list = result is List ? result : (result['schools'] ?? []);
    return (list as List).map((s) => SuperSchoolModel.fromJson(s)).toList();
  }

  Future<SuperSchoolModel> createSuperSchool({
    required String schoolName, required String site, required int port,
    String? dbName, String? motto, String? contactEmail,
    String? contactNumber, String? website, String? address,
    String? adminName, String? adminEmail, String? adminPassword,
  }) async {
    final result = await _post('school_connect.api.admin.create_school', {
      'name': schoolName,
      'location': site,
      'established': port,
    });
    final schoolId = result['id']?.toString();

    // Create the school admin if credentials are provided
    if (schoolId != null && adminName != null && adminName.isNotEmpty &&
        adminEmail != null && adminEmail.isNotEmpty &&
        adminPassword != null && adminPassword.isNotEmpty) {
      try {
        await _post('school_connect.api.admin.create_school_admin', {
          'name': adminName,
          'email': adminEmail,
          'password': adminPassword,
          'school': schoolId,
        });
      } catch (e) {
        debugPrint('Warning: school created but admin creation failed: $e');
      }
    }    return SuperSchoolModel.fromJson(result);
  }

  Future<SuperSchoolModel> updateSuperSchool({
    required String name, String? schoolName, String? site, int? port,
    String? contactEmail, String? contactNumber, String? website,
    String? motto, String? address, String? adminName, String? adminEmail,
  }) async {
    final result = await _post('school_connect.api.admin.update_school', {
      'id': name,
      if (schoolName != null) 'name': schoolName,
      if (site != null) 'location': site,
    });

    return SuperSchoolModel.fromJson(result);
  }

  Future<SuperSchoolModel> resetSuperAdminPassword({
    required String name, required String newPassword,
  }) async {
    // Find the school admin for this school and update their password
    final admins = await getSchoolAdmins();
    for (final admin in admins) {
      if (admin.schoolId == name) {
        await _post('school_connect.api.admin.update_school_admin', {
          'id': admin.id,
          'name': admin.fullName,
          'email': admin.email,
          'school': name,
          'password': newPassword,
        });
        break;
      }
    }
    return SuperSchoolModel.fromJson({'name': name});
  }

  Future<List<UserModel>> getSchoolAdmins() async {
    final result = await _get('school_connect.api.admin.get_school_admins');
    final list = result is List ? result : [];
    return (list as List).map((a) => UserModel.fromJson(a)).toList();
  }

  Future<void> deleteSuperSchool(String name) async {
    await _post('school_connect.api.admin.delete_school', {'id': name});
  }

  // ─────────────────────────────────────────────────────────────────────
  // Student Groups
  // ─────────────────────────────────────────────────────────────────────

  Future<List<StudentGroupModel>> getStudentGroups() async {
    final result = await _get('school_connect.api.admin.get_admin_classes');
    final list = result is List ? result : (result['classes'] ?? []);
    return (list as List).map((c) => StudentGroupModel.fromJson(c)).toList();
  }

  Future<List<SchoolModel>> getPrograms() => getSchools();
}

/// Auth result
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

/// Attendance record for marking attendance.
class AttendanceRecord {
  final String studentId;
  final AttendanceStatus status;

  AttendanceRecord({required this.studentId, required this.status});

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

/// Attendance summary for student dashboard.
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

/// Monthly attendance record.
class MonthlyAttendance {
  final DateTime date;
  final String status;

  MonthlyAttendance({required this.date, required this.status});

  factory MonthlyAttendance.fromJson(Map<String, dynamic> json) {
    return MonthlyAttendance(
      date: DateTime.parse(json['date'].toString()),
      status: json['status']?.toString() ?? 'Present',
    );
  }
}

/// Admin dashboard data.
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
