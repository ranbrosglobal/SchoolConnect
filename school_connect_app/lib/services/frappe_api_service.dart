import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
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
import 'export_service.dart' show ExportService;

/// Live backend data layer for the School Connect Flutter app.
///
/// Every endpoint is served by the repo's `sc_auth` Frappe custom app:
///
///   Auth:    /api/method/sc_auth.api.auth.{login, signup_student, me, logout, change_password}
///   Data:    /api/method/sc_auth.api.data.{my_classes, ...}
///   Super:   /api/method/sc_auth.api.superadmin.{public_schools, schools, ...}
///
/// Authentication is session-based (`Cookie: sid=...`) with an optional
/// `Authorization: Bearer <jwt>` header that `sc_auth` accepts via the
/// `before_request` hook. The app stores both the sid and the JWT in
/// `flutter_secure_storage` after login.
///
/// This is the single data layer the live build uses. The offline demo app
/// (`demoapp/`) uses `local_db.dart` instead — same models, same method
/// signatures, no HTTP calls.
class FrappeApiService {
  static final FrappeApiService _instance = FrappeApiService._internal();
  factory FrappeApiService() => _instance;
  FrappeApiService._internal();

  final _storage = const FlutterSecureStorage();
  final _http = http.Client();

  String? _sid;
  String? _jwt;
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  // --------------------------------------------------------------------------
  // HTTP helpers
  // --------------------------------------------------------------------------

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_sid != null) 'Cookie': 'sid=$_sid',
        if (_jwt != null) 'Authorization': 'Bearer $_jwt',
      };

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? params]) async {
    final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/method/$path')
        .replace(queryParameters: params);
    final response = await _http
        .get(uri, headers: _headers)
        .timeout(ApiConfig.connectionTimeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(String path,
      [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/method/$path');
    final response = await _http
        .post(uri, headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(ApiConfig.connectionTimeout);
    return _handleResponse(response);
  }

  /// Multipart upload for endpoints that accept a file (login still uses
  /// JSON; file uploads use form-data).
  Future<Map<String, dynamic>> _multipart(String path,
      Map<String, dynamic> fields, Map<String, List<int>> files) async {
    final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/method/$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';
    if (_sid != null) request.headers['Cookie'] = 'sid=$_sid';
    if (_jwt != null) request.headers['Authorization'] = 'Bearer $_jwt';
    for (final entry in fields.entries) {
      request.fields[entry.key] = entry.value.toString();
    }
    for (final entry in files.entries) {
      request.files.add(http.MultipartFile(
        entry.key,
        Stream.value(entry.value),
        entry.value.length,
        filename: entry.key == 'file' ? 'file' : entry.key,
      ));
    }
    final response = await request.send().timeout(ApiConfig.connectionTimeout);
    final bodyBytes = await response.stream.toBytes();
    return _handleResponse(
      http.Response.bytes(bodyBytes, response.statusCode,
          headers: Map.from(response.headers)),
    );
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final match = RegExp(r'sid=([^;]+)').firstMatch(setCookie);
      if (match != null) {
        _sid = match.group(1);
      }
    }

    final body = jsonDecode(response.body);
    if (response.statusCode == 404) {
      throw ApiException(
          'Server endpoint not found. Is the Frappe bench running?');
    }
    if (response.statusCode >= 400) {
      final message = body['message'] ??
          body['exc'] ??
          body['exc_type'] ??
          'Request failed (${response.statusCode})';
      throw ApiException(message.toString());
    }

    // Frappe / sc_auth wrap JSON-RPC responses in { message: ... }
    return body is Map<String, dynamic> ? (body['message'] ?? body) : body;
  }

  // --------------------------------------------------------------------------
  // Auth
  // --------------------------------------------------------------------------

  /// Email/password login against the school site that authenticates the user.
  /// The backend auto-detects the school when the app probes via the super site;
  /// this method just posts credentials to whichever base URL is active.
  Future<AuthResult> login(String email, String password) async {
    try {
      final result = await _post('sc_auth.api.auth.login', {
        'email': email.toLowerCase().trim(),
        'password': password,
      });
      final user = UserModel.fromJson(result);
      _currentUser = user;
      _jwt = result['token']?.toString();
      await _saveSession(user, _jwt);
      return AuthResult(success: true, user: user, token: _jwt);
    } catch (e) {
      debugPrint('Backend login error: $e');
      return _loginError(e);
    }
  }

  /// Login with auto school detection. The app should first fetch
  /// `public_schools` from the super site and then try each school's login
  /// endpoint; this helper runs one attempt against the current base URL.
  Future<AuthResult> loginAuto(String email, String password) async {
    return login(email, password);
  }

  AuthResult _loginError(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid email or password') ||
        msg.contains('AuthenticationError') ||
        msg.contains('Incorrect') ||
        msg.contains('password') && msg.toLowerCase().contains('incorrect')) {
      return AuthResult(success: false, error: 'Invalid email or password');
    }
    if (msg.contains('disabled') || msg.contains('disabled')) {
      return AuthResult(
          success: false, error: 'This account has been disabled. Contact your administrator.');
    }
    if (msg.contains('cannot') && msg.toLowerCase().contains('connect')) {
      return AuthResult(
          success: false, error: 'Cannot connect to server. Please check your connection.');
    }
    return AuthResult(success: false, error: 'Login failed: $msg');
  }

  /// Self-registration (student). Creates User + Student + enrollment and
  /// auto-logs the new student in.
  Future<AuthResult> signupStudent({
    required String fullName,
    required String email,
    required String password,
    String? gender,
    String? studentGroup,
    String? program,
    String? city,
    String? state,
    String? country,
  }) async {
    try {
      final result = await _post('sc_auth.api.auth.signup_student', {
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        if (gender != null) 'gender': gender,
        if (studentGroup != null) 'student_group': studentGroup,
        if (program != null) 'program': program,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (country != null) 'country': country,
      });
      final user = UserModel.fromJson(result);
      _currentUser = user;
      _jwt = result['token']?.toString();
      await _saveSession(user, _jwt);
      return AuthResult(success: true, user: user, token: _jwt);
    } catch (e) {
      debugPrint('Signup error: $e');
      final msg = e.toString();
      if (msg.contains('already exists')) {
        return AuthResult(
            success: false, error: 'An account with this email already exists. Try logging in.');
      }
      if (msg.contains('8 characters')) {
        return AuthResult(success: false, error: 'Password must be at least 8 characters long');
      }
      return AuthResult(success: false, error: 'Signup failed: $msg');
    }
  }

  /// Restore a stored session (sid + JWT + user) and verify it's still valid.
  Future<bool> restoreSession() async {
    try {
      final storedCookie = await _storage.read(key: 'sid');
      final storedJwt = await _storage.read(key: 'jwt');
      final storedUser = await _storage.read(key: 'user_data');

      if (storedCookie != null && storedUser != null) {
        _sid = storedCookie;
        _jwt = storedJwt;
        _currentUser = UserModel.fromJson(jsonDecode(storedUser));

        // Verify the session is still accepted by the backend.
        try {
          final result = await _get('sc_auth.api.auth.me');
          final user = UserModel.fromJson(result);
          _currentUser = user;
          await _saveSession(user, _jwt);
          return true;
        } catch (_) {
          // Session expired on the server.
        }
      }

      await _clearSession();
      return false;
    } catch (e) {
      debugPrint('Session restore error: $e');
      await _clearSession();
      return false;
    }
  }

  /// End the session on the server and clear local state.
  Future<void> logout() async {
    try {
      await _post('sc_auth.api.auth.logout', {});
    } catch (_) {}
    await _clearSession();
  }

  /// Change password (current -> new). The app enforces new != current and
  /// new >= 8 chars before calling this.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _post('sc_auth.api.auth.change_password', {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    } catch (e) {
      debugPrint('Change password error: $e');
      throw ApiException('Failed to change password: ${e.toString()}');
    }
  }

  Future<void> _saveSession(UserModel user, String? jwt) async {
    await _storage.write(key: 'user_data', value: jsonEncode(user.toJson()));
    await _storage.write(key: 'sid', value: _sid);
    if (jwt != null) {
      await _storage.write(key: 'jwt', value: jwt);
    }
  }

  Future<void> _clearSession() async {
    _sid = null;
    _jwt = null;
    _currentUser = null;
    await _storage.delete(key: 'user_data');
    await _storage.delete(key: 'sid');
    await _storage.delete(key: 'jwt');
  }

  // --------------------------------------------------------------------------
  // Student data
  // --------------------------------------------------------------------------

  Future<AttendanceSummary> getMyAttendanceSummary() async {
    final result = await _get('sc_auth.api.data.my_attendance_summary');
    return AttendanceSummary.fromJson(result);
  }

  Future<List<AttendanceModel>> getMyAttendance({String? course}) async {
    final result = await _get('sc_auth.api.data.my_attendance',
        course != null ? {'course': course} : null);
    final rows = result is List ? result : (result['records'] ?? []);
    return (rows as List).map((r) => AttendanceModel.fromJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getMyAttendanceForMonth(
      int year, int month) async {
    final result = await _get('sc_auth.api.data.my_attendance_month', {
      'year': year.toString(),
      'month': month.toString(),
    });
    final rows = result is List ? result : [];
    return (rows as List).map((r) => {
          'date': r['date']?.toString(),
          'status': r['status']?.toString(),
        }).toList();
  }

  Future<List<AssignmentModel>> getMyAssignments() async {
    final result = await _get('sc_auth.api.data.my_assignments');
    final list = result is List ? result : [];
    return (list as List).map((a) => AssignmentModel.fromJson(a)).toList();
  }

  Future<List<AssignmentModel>> getAssignmentsOnDate(DateTime date) async {
    final result = await _get('sc_auth.api.data.assignments_on_date', {
      'date': date.toIso8601String().split('T')[0],
    });
    final list = result is List ? result : [];
    return (list as List).map((a) => AssignmentModel.fromJson(a)).toList();
  }

  /// Submit a student assignment with an optional file. When [fileBytes] is
  /// provided, uploads the binary to Frappe's file store via
  /// `sc_auth.api.data.submit_with_file` and links the returned file_url.
  Future<AssignmentSubmissionModel> submitAssignment({
    required String assignment,
    required String fileName,
    List<int>? fileBytes,
  }) async {
    if (fileBytes != null && fileBytes.isNotEmpty) {
      final result = await _multipart('sc_auth.api.data.submit_with_file', {
        'assignment': assignment,
      }, {'file': fileBytes});
      return AssignmentSubmissionModel.fromJson(result);
    }
    final result = await _post('sc_auth.api.data.submit_assignment', {
      'assignment': assignment,
      'file_name': fileName,
    });
    return AssignmentSubmissionModel.fromJson(result);
  }

  Future<void> unsubmitSubmission(String submission) async {
    await _post('sc_auth.api.data.unsubmit_submission', {'submission': submission});
  }

  // --------------------------------------------------------------------------
  // Teacher data
  // --------------------------------------------------------------------------

  Future<List<CourseScheduleModel>> getMyClasses() async {
    final result = await _get('sc_auth.api.data.my_classes');
    final list = result is List ? result : [];
    return (list as List).map((c) => CourseScheduleModel.fromJson(c)).toList();
  }

  Future<List<StudentModel>> getClassStudents(String courseSchedule) async {
    final result = await _get('sc_auth.api.data.class_students', {
      'course_schedule': courseSchedule,
    });
    final list = result is List ? result : [];
    return (list as List).map((s) => StudentModel.fromJson(s)).toList();
  }

  Future<void> markAttendance({
    required String courseSchedule,
    required String studentGroup,
    required DateTime date,
    required List<AttendanceRecord> records,
  }) async {
    await _post('sc_auth.api.data.mark_attendance', {
      'course_schedule': courseSchedule,
      'student_group': studentGroup,
      'date': date.toIso8601String().split('T')[0],
      'records': records.map((r) => {
            'student': r.studentId,
            'status': r.statusString,
          }).toList(),
    });
  }

  Future<List<AssignmentModel>> getTeacherAssignments() async {
    final result = await _get('sc_auth.api.data.teacher_assignments');
    final list = result is List ? result : [];
    return (list as List).map((a) => AssignmentModel.fromJson(a)).toList();
  }

  Future<AssignmentModel> createAssignment({
    required String title,
    required String course,
    required String studentGroup,
    required DateTime dueDate,
    String? description,
  }) async {
    final result = await _post('sc_auth.api.data.create_assignment', {
      'title': title,
      'course': course,
      'student_group': studentGroup,
      'due_date': dueDate.toIso8601String().split('T')[0],
      if (description != null) 'description': description,
    });
    return AssignmentModel.fromJson(result);
  }

  Future<void> updateAssignment({
    required String name,
    String? title,
    String? course,
    String? studentGroup,
    DateTime? dueDate,
    String? description,
  }) async {
    await _post('sc_auth.api.data.update_assignment', {
      'name': name,
      if (title != null) 'title': title,
      if (course != null) 'course': course,
      if (studentGroup != null) 'student_group': studentGroup,
      if (dueDate != null)
        'due_date': dueDate.toIso8601String().split('T')[0],
      if (description != null) 'description': description,
    });
  }

  Future<void> deleteAssignment(String name) async {
    await _post('sc_auth.api.data.delete_assignment', {'name': name});
  }

  Future<List<AssignmentSubmissionModel>> getAssignmentSubmissions(
      String assignment) async {
    final result = await _get('sc_auth.api.data.assignment_submissions', {
      'assignment': assignment,
    });
    final list = result is List ? result : [];
    return (list as List)
        .map((s) => AssignmentSubmissionModel.fromJson(s))
        .toList();
  }

  Future<void> gradeSubmission({
    required String submission,
    required double grade,
    String? feedback,
  }) async {
    await _post('sc_auth.api.data.grade_submission', {
      'submission': submission,
      'score': grade,
      if (feedback != null) 'feedback': feedback,
    });
  }

  Future<void> deleteSubmission(String submission) async {
    await _post('sc_auth.api.data.delete_submission', {'submission': submission});
  }

  /// Download an uploaded file (submission file or attachment) by its Frappe
  /// file URL. The backend returns the file_url in the submission/assignment
  /// shape; this method fetches the public file and returns its bytes.
  Future<Uint8List> downloadFile(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    // Public Frappe files are served from the same origin; use the backend
    // base URL when the stored URL is a relative path.
    final resolved =
        uri.isAbsolute ? uri : Uri.parse('${ApiConfig.backendBaseUrl}$fileUrl');
    final response = await _http.get(resolved).timeout(ApiConfig.connectionTimeout);
    if (response.statusCode != 200) {
      throw ApiException('Could not download file (status ${response.statusCode})');
    }
    return response.bodyBytes;
  }

  /// Download a file and open the platform share sheet so the user can save
  /// it anywhere (Files, Drive, WhatsApp, …). Same behaviour as
  /// ExportService.shareBytes.
  Future<void> downloadAndShareFile(String fileUrl, String fileName) async {
    final bytes = await downloadFile(fileUrl);
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

  // --------------------------------------------------------------------------
  // Student detail (teacher view, optionally scoped to one course)
  // --------------------------------------------------------------------------

  Future<StudentDetailModel> getStudentDetail(String student, {String? course}) async {
    final result = await _get('sc_auth.api.data.student_detail', {
      'student': student,
      if (course != null) 'course': course,
    });
    return StudentDetailModel.fromJson(result);
  }

  // --------------------------------------------------------------------------
  // Timetable
  // --------------------------------------------------------------------------

  Future<TimetableModel> getMyTimetable({DateTime? weekStart}) async {
    final result = await _get('sc_auth.api.data.my_timetable', {
      if (weekStart != null) 'week_start': weekStart.toIso8601String().split('T')[0],
    });
    return TimetableModel.fromJson(result);
  }

  // --------------------------------------------------------------------------
  // School profile
  // --------------------------------------------------------------------------

  Future<SchoolProfileModel> getSchoolProfile() async {
    try {
      final result = await _get('sc_auth.api.data.school_profile');
      return SchoolProfileModel.fromJson(result);
    } catch (_) {
      return SchoolProfileModel.fromJson({});
    }
  }

  Future<SchoolProfileModel> updateSchoolProfile({
    String? schoolName,
    String? motto,
    String? contactEmail,
    String? contactNumber,
    String? website,
    String? address,
  }) async {
    final result = await _post('sc_auth.api.data.update_school_profile', {
      if (schoolName != null) 'school_name': schoolName,
      if (motto != null) 'motto': motto,
      if (contactEmail != null) 'contact_email': contactEmail,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (website != null) 'website': website,
      if (address != null) 'address': address,
    });
    return SchoolProfileModel.fromJson(result);
  }

  Future<String> uploadSchoolLogo({
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final result = await _multipart('sc_auth.api.data.upload_school_logo', {}, {
      'file': fileBytes,
    });
    return result['logo_url']?.toString() ?? '';
  }

  // --------------------------------------------------------------------------
  // Admin dashboard (school admin)
  // --------------------------------------------------------------------------

  Future<AdminDashboardData> getAdminDashboard() async {
    final result = await _get('sc_auth.api.data.admin_dashboard');
    return AdminDashboardData.fromJson(result);
  }

  Future<List<InstructorModel>> getAdminTeachers() async {
    final result = await _get('sc_auth.api.data.admin_dashboard');
    final teachers = result['teachers'] ?? [];
    return (teachers as List).map((t) => InstructorModel.fromJson(t)).toList();
  }

  Future<List<StudentModel>> getAdminStudents() async {
    final result = await _get('sc_auth.api.data.admin_dashboard');
    final students = result['students'] ?? [];
    return (students as List).map((s) => StudentModel.fromJson(s)).toList();
  }

  Future<List<StudentGroupModel>> getAdminClasses() async {
    final result = await _get('sc_auth.api.data.admin_dashboard');
    final classes = result['classes'] ?? [];
    return (classes as List).map((c) => StudentGroupModel.fromJson(c)).toList();
  }

  // --------------------------------------------------------------------------
  // Super admin (registry)
  // --------------------------------------------------------------------------

  Future<List<PublicSchoolEntry>> getPublicSchools() async {
    final result = await _get('sc_auth.api.superadmin.public_schools');
    final list = result is List ? result : [];
    return (list as List).map((s) => PublicSchoolEntry.fromJson(s)).toList();
  }

  Future<List<SuperSchoolModel>> getSuperSchools() async {
    final result = await _get('sc_auth.api.superadmin.schools');
    final list = result is List ? result : [];
    return (list as List).map((s) => SuperSchoolModel.fromJson(s)).toList();
  }

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
  }) async {
    final result = await _post('sc_auth.api.superadmin.create_school', {
      'school_name': schoolName,
      'site': site,
      'port': port,
      if (dbName != null) 'db_name': dbName,
      if (contactEmail != null) 'contact_email': contactEmail,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (website != null) 'website': website,
      if (motto != null) 'motto': motto,
      if (address != null) 'address': address,
      if (adminName != null) 'school_admin_name': adminName,
      if (adminEmail != null) 'school_admin_email': adminEmail,
      if (adminPassword != null) 'school_admin_password': adminPassword,
    });
    return SuperSchoolModel.fromJson(result);
  }

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
  }) async {
    final result = await _post('sc_auth.api.superadmin.update_school', {
      'name': name,
      if (schoolName != null) 'school_name': schoolName,
      if (site != null) 'site': site,
      if (port != null) 'port': port,
      if (contactEmail != null) 'contact_email': contactEmail,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (website != null) 'website': website,
      if (motto != null) 'motto': motto,
      if (address != null) 'address': address,
      if (adminName != null) 'school_admin_name': adminName,
      if (adminEmail != null) 'school_admin_email': adminEmail,
    });
    return SuperSchoolModel.fromJson(result);
  }

  Future<SuperSchoolModel> resetSuperAdminPassword({
    required String name,
    required String newPassword,
  }) async {
    final result = await _post(
        'sc_auth.api.superadmin.reset_school_admin_password', {
      'name': name,
      'new_password': newPassword,
    });
    return SuperSchoolModel.fromJson(result);
  }

  Future<void> deleteSuperSchool(String name) async {
    await _post('sc_auth.api.superadmin.delete_school', {'name': name});
  }

  // --------------------------------------------------------------------------
  // Signup pickers (guest)
  // --------------------------------------------------------------------------

  Future<List<StudentGroupModel>> getStudentGroups() async {
    final result = await _get('sc_auth.api.data.student_groups');
    final list = result is List ? result : [];
    return (list as List).map((g) => StudentGroupModel.fromJson(g)).toList();
  }

  Future<List<SchoolModel>> getPrograms() async {
    final result = await _get('sc_auth.api.data.programs');
    final list = result is List ? result : [];
    return (list as List).map((p) => SchoolModel.fromJson(p)).toList();
  }

  void dispose() {
    _http.close();
  }
}

/// Thin wrapper so call sites clearly distinguish success/failure without
/// catching exceptions everywhere.
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
        return 'Leave'; // v17 has no Half Day; map to Leave
      case AttendanceStatus.leave:
        return 'Leave';
    }
  }
}

/// Attendance summary for the student dashboard.
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

/// One day in the monthly attendance feed.
class MonthlyAttendance {
  final DateTime date;
  final String status;

  MonthlyAttendance({required this.date, required this.status});

  factory MonthlyAttendance.fromJson(Map<String, dynamic> json) {
    final d = json['date']?.toString();
    return MonthlyAttendance(
      date: d != null ? DateTime.tryParse(d) ?? DateTime.now() : DateTime.now(),
      status: json['status']?.toString() ?? 'Present',
    );
  }
}

/// Admin dashboard payload from `sc_auth.api.data.admin_dashboard`.
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

/// User-facing API error.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

