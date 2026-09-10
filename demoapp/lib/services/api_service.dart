import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../models/school_model.dart';
import '../models/student_model.dart';
import '../models/instructor_model.dart';
import '../models/course_schedule_model.dart';
import '../models/attendance_model.dart';
import '../models/assignment_model.dart';
import '../models/assignment_submission_model.dart';
import '../models/student_group_model.dart';
import '../models/student_detail_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();
  String? _authToken;
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _authToken != null;

  // Set auth token for API calls
  void setAuthToken(String? token) {
    _authToken = token;
  }

  // Get auth headers
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      // JWT issued by the FastAPI bridge.
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // Handle API response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      return body;
    } else {
      final body = jsonDecode(response.body);
      throw ApiException(
        // FastAPI errors come back as {"detail": ...}, Frappe as message/exc.
        message: body['message'] ?? body['exc'] ?? body['detail'] ?? 'Unknown error',
        statusCode: response.statusCode,
      );
    }
  }

  // Auth endpoints
  Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final result = _handleResponse(response);
    final message = result['message'];
    
    if (message != null && message['token'] != null) {
      _authToken = message['token'];
      _currentUser = UserModel.fromJson(message);
      
      // Store token securely
      await _storage.write(key: 'auth_token', value: _authToken);
      await _storage.write(key: 'user_data', value: jsonEncode(_currentUser!.toJson()));
      
      return AuthResult(
        success: true,
        user: _currentUser!,
        token: _authToken!,
      );
    }
    
    return AuthResult(
      success: false,
      error: message?['message'] ?? 'Login failed',
    );
  }

  Future<AuthResult> signupStudent({
    required String fullName,
    required String email,
    required String password,
    int? age,
    String? gender,
    String? city,
    String? state,
    String? country,
    required String school,
    String? studentGroup,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacySignupEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
        'age': age,
        'gender': gender,
        'city': city,
        'state': state,
        'country': country,
        'school': school,
        'student_group': studentGroup,
      }),
    );

    final result = _handleResponse(response);
    
    if (result['message'] != null) {
      return AuthResult(
        success: true,
        message: result['message'],
      );
    }
    
    return AuthResult(
      success: false,
      error: result['exc'] ?? 'Signup failed',
    );
  }

  Future<void> logout() async {
    // Best-effort: end the Frappe session through the bridge.
    try {
      if (_authToken != null) {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.logoutEndpoint}'),
          headers: _headers,
        );
      }
    } catch (_) {
      // Ignore network errors — always clear the local session.
    }
    _authToken = null;
    _currentUser = null;
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
  }

  Future<bool> restoreSession() async {
    final token = await _storage.read(key: 'auth_token');
    final userData = await _storage.read(key: 'user_data');
    
    if (token != null && userData != null) {
      _authToken = token;
      _currentUser = UserModel.fromJson(jsonDecode(userData));
      return true;
    }
    return false;
  }

  // School search
  Future<List<SchoolModel>> searchSchools({
    String? state,
    String? city,
    String? query,
  }) async {
    final queryParams = <String, String>{};
    if (state != null) queryParams['state'] = state;
    if (city != null) queryParams['city'] = city;
    if (query != null) queryParams['q'] = query;

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacySearchSchoolsEndpoint}')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _headers);
    final result = _handleResponse(response);
    
    final schools = (result['message'] ?? result['data'] ?? []) as List;
    return schools.map((s) => SchoolModel.fromJson(s)).toList();
  }

  // Teacher endpoints
  Future<List<CourseScheduleModel>> getMyClasses() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetMyClassesEndpoint}'),
      headers: _headers,
    );

    final result = _handleResponse(response);
    final classes = (result['message'] ?? result['data'] ?? []) as List;
    return classes.map((c) => CourseScheduleModel.fromJson(c)).toList();
  }

  Future<List<StudentModel>> getClassStudents(String courseSchedule) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetClassStudentsEndpoint}')
          .replace(queryParameters: {'course_schedule': courseSchedule}),
      headers: _headers,
    );

    final result = _handleResponse(response);
    final students = (result['message'] ?? result['data'] ?? []) as List;
    return students.map((s) => StudentModel.fromJson(s)).toList();
  }

  Future<void> markAttendance({
    required String courseSchedule,
    required String studentGroup,
    required DateTime date,
    required List<AttendanceRecord> records,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.markAttendanceEndpoint}'),
      headers: _headers,
      body: jsonEncode({
        'course_schedule': courseSchedule,
        'student_group': studentGroup,
        'date': date.toIso8601String().split('T')[0],
        'attendance': records.map((r) => {
          'student': r.studentId,
          'status': r.statusString,
        }).toList(),
      }),
    );

    _handleResponse(response);
  }

  Future<List<AttendanceModel>> getAttendanceReport({
    String? courseSchedule,
    DateTime? date,
  }) async {
    final queryParams = <String, String>{};
    if (courseSchedule != null) queryParams['course_schedule'] = courseSchedule;
    if (date != null) queryParams['date'] = date.toIso8601String().split('T')[0];

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetAttendanceReportEndpoint}')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _headers);
    final result = _handleResponse(response);
    
    final attendance = (result['message'] ?? result['data'] ?? []) as List;
    return attendance.map((a) => AttendanceModel.fromJson(a)).toList();
  }

  // Student endpoints
  Future<AttendanceSummary> getMyAttendanceSummary() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetMyAttendanceSummaryEndpoint}'),
      headers: _headers,
    );

    final result = _handleResponse(response);
    final message = result['message'] ?? result['data'];
    
    return AttendanceSummary.fromJson(message);
  }

  Future<List<AttendanceModel>> getMyAttendance({String? course}) async {
    final queryParams = <String, String>{};
    if (course != null) queryParams['course'] = course;

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetMyAttendanceEndpoint}')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _headers);
    final result = _handleResponse(response);
    
    final attendance = (result['message'] ?? result['data'] ?? []) as List;
    return attendance.map((a) => AttendanceModel.fromJson(a)).toList();
  }

  Future<List<AssignmentModel>> getMyAssignments() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetMyAssignmentsEndpoint}'),
      headers: _headers,
    );

    final result = _handleResponse(response);
    final assignments = (result['message'] ?? result['data'] ?? []) as List;
    return assignments.map((a) => AssignmentModel.fromJson(a)).toList();
  }

  // Assignment submission (student)
  Future<void> submitAssignment({
    required String assignment,
    required String filePath,
  }) async {
    // First upload the file
    final fileResponse = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyFileUploadEndpoint}'),
    );

    fileResponse.headers.addAll(_headers);
    fileResponse.files.add(await http.MultipartFile.fromPath('file', filePath));

    final fileResult = await fileResponse.send();
    final fileBody = await fileResult.stream.bytesToString();
    final fileData = jsonDecode(fileBody);
    final fileMessage = fileData['message'] ?? fileData;

    // Then create the submission through the whitelisted endpoint
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacySubmitAssignmentEndpoint}'),
      headers: _headers,
      body: jsonEncode({
        'assignment': assignment,
        'file': fileMessage['file_url'],
      }),
    );

    _handleResponse(response);
  }

  // Teacher - assignment management
  Future<List<AssignmentModel>> getMyTeacherAssignments() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetMyTeacherAssignmentsEndpoint}'),
      headers: _headers,
    );

    final result = _handleResponse(response);
    final assignments = (result['message'] ?? result['data'] ?? []) as List;
    return assignments.map((a) => AssignmentModel.fromJson(a)).toList();
  }

  Future<AssignmentModel> createAssignment({
    required String title,
    required String course,
    required String studentGroup,
    required DateTime dueDate,
    String? description,
    String? filePath,
  }) async {
    String? attachmentUrl;
    String? attachmentName;

    if (filePath != null) {
      final fileResponse = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyFileUploadEndpoint}'),
      );
      fileResponse.headers.addAll(_headers);
      fileResponse.files.add(await http.MultipartFile.fromPath('file', filePath));

      final fileResult = await fileResponse.send();
      final fileBody = await fileResult.stream.bytesToString();
      final fileData = jsonDecode(fileBody);
      final fileMessage = fileData['message'] ?? fileData;
      attachmentUrl = fileMessage['file_url'];
      attachmentName = filePath.split('/').last;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyCreateAssignmentEndpoint}'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'course': course,
        'student_group': studentGroup,
        'due_date': dueDate.toIso8601String().split('T')[0],
        'description': description,
        'attachment': attachmentUrl,
        'attachment_name': attachmentName,
      }),
    );

    final result = _handleResponse(response);
    final message = result['message'] ?? result['data'];
    if (message is Map && message['name'] != null) {
      return AssignmentModel.fromJson(Map<String, dynamic>.from(message));
    }
    return AssignmentModel(id: '', title: title);
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
    String? attachmentUrl;
    String? attachmentName;

    if (filePath != null) {
      final fileResponse = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyFileUploadEndpoint}'),
      );
      fileResponse.headers.addAll(_headers);
      fileResponse.files.add(await http.MultipartFile.fromPath('file', filePath));

      final fileResult = await fileResponse.send();
      final fileBody = await fileResult.stream.bytesToString();
      final fileData = jsonDecode(fileBody);
      final fileMessage = fileData['message'] ?? fileData;
      attachmentUrl = fileMessage['file_url'];
      attachmentName = filePath.split('/').last;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyUpdateAssignmentEndpoint}'),
      headers: _headers,
      body: jsonEncode({
        'name': assignmentId,
        'title': title,
        'course': course,
        'student_group': studentGroup,
        'due_date': dueDate.toIso8601String().split('T')[0],
        'description': description,
        // Empty string signals the backend to clear a previously-set file.
        'attachment': clearAttachment ? '' : attachmentUrl,
        'attachment_name': clearAttachment ? '' : attachmentName,
      }),
    );

    _handleResponse(response);
  }

  Future<void> deleteAssignment(String assignmentId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyDeleteAssignmentEndpoint}'),
      headers: _headers,
      body: jsonEncode({'name': assignmentId}),
    );

    _handleResponse(response);
  }

  Future<List<AssignmentSubmissionModel>> getAssignmentSubmissions(
    String assignment,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetAssignmentSubmissionsEndpoint}')
          .replace(queryParameters: {'assignment': assignment}),
      headers: _headers,
    );

    final result = _handleResponse(response);
    final submissions = (result['message'] ?? result['data'] ?? []) as List;
    return submissions.map((s) => AssignmentSubmissionModel.fromJson(s)).toList();
  }

  Future<void> gradeSubmission({
    required String submission,
    required double grade,
    String? feedback,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGradeSubmissionEndpoint}'),
      headers: _headers,
      body: jsonEncode({
        'submission': submission,
        'grade': grade,
        'feedback': feedback,
      }),
    );

    _handleResponse(response);
  }

  Future<void> unsubmitSubmission(String submission) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyUnsubmitSubmissionEndpoint}'),
      headers: _headers,
      body: jsonEncode({'submission': submission}),
    );

    _handleResponse(response);
  }

  Future<void> deleteSubmission(String submission) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyDeleteSubmissionEndpoint}'),
      headers: _headers,
      body: jsonEncode({'submission': submission}),
    );

    _handleResponse(response);
  }

  Future<StudentDetailModel> getStudentDetails({
    required String student,
    String? studentGroup,
  }) async {
    final queryParams = <String, String>{
      'student': student,
    };
    if (studentGroup != null && studentGroup.isNotEmpty) {
      queryParams['student_group'] = studentGroup;
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetStudentDetailsEndpoint}')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _headers);
    final result = _handleResponse(response);
    final message = result['message'] ?? result['data'];
    return StudentDetailModel.fromJson(Map<String, dynamic>.from(message));
  }

  // Admin endpoints
  Future<AdminDashboardData> getAdminDashboard() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetAdminDashboardEndpoint}'),
      headers: _headers,
    );

    final result = _handleResponse(response);
    final message = result['message'] ?? result['data'] ?? {};
    return AdminDashboardData.fromJson(message);
  }

  Future<List<InstructorModel>> getAdminTeachers() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetAdminTeachersEndpoint}'),
      headers: _headers,
    );

    final result = _handleResponse(response);
    final teachers = (result['message'] ?? result['data'] ?? []) as List;
    return teachers.map((t) => InstructorModel.fromJson(t)).toList();
  }

  Future<List<StudentGroupModel>> getAdminClasses() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetAdminClassesEndpoint}'),
      headers: _headers,
    );

    final result = _handleResponse(response);
    final classes = (result['message'] ?? result['data'] ?? []) as List;
    return classes.map((c) => StudentGroupModel.fromJson(c)).toList();
  }

  Future<List<StudentModel>> getAdminStudents() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetAdminStudentsEndpoint}'),
      headers: _headers,
    );

    final result = _handleResponse(response);
    final students = (result['message'] ?? result['data'] ?? []) as List;
    return students.map((s) => StudentModel.fromJson(s)).toList();
  }
  Future<List<SchoolModel>> getSchools() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.legacyGetSchoolsEndpoint}'),
      headers: _headers,
    );

    final result = _handleResponse(response);
    final schools = (result['data'] ?? []) as List;
    return schools.map((s) => SchoolModel.fromJson(s)).toList();
  }

  // Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.frappeProxyPrefix}/api/method/frappe.client.change_password'),
      headers: _headers,
      body: jsonEncode({
        'old_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    _handleResponse(response);
  }
}

// Helper classes
class AuthResult {
  final bool success;
  final UserModel? user;
  final String? token;
  final String? message;
  final String? error;

  AuthResult({
    required this.success,
    this.user,
    this.token,
    this.message,
    this.error,
  });
}

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
        json['course_wise_percentage'] ?? {},
      ),
      monthlyAttendance: (json['monthly_attendance'] ?? [])
          .map((m) => MonthlyAttendance.fromJson(m))
          .toList(),
    );
  }
}

class MonthlyAttendance {
  final DateTime date;
  final String status;

  MonthlyAttendance({
    required this.date,
    required this.status,
  });

  factory MonthlyAttendance.fromJson(Map<String, dynamic> json) {
    return MonthlyAttendance(
      date: DateTime.parse(json['date']),
      status: json['status'],
    );
  }
}

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

class AdminDashboardData {
  final SchoolModel? school;
  final List<InstructorModel> teachers;
  final List<StudentModel> students;
  final List<StudentGroupModel> classes;

  AdminDashboardData({
    this.school,
    this.teachers = const [],
    this.students = const [],
    this.classes = const [],
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    return AdminDashboardData(
      school: json['school'] is Map<String, dynamic>
          ? SchoolModel.fromJson(json['school'])
          : null,
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

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
