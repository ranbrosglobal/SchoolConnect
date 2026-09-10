/// API Configuration for School Connect
///
/// Legacy config — the demo app uses local SQLite, not a remote API.
class ApiConfig {
  // =====================================================================
  // BASE URL — Direct Frappe Education connection (no FastAPI bridge)
  // 
  // Multi-tenant: every school runs on its own Frappe site + database, and
  // the super admin runs the registry site. Each site is served on its own
  // port locally (8000 = library/sunrise, 8001 = oakridge, 8002 = super
  // admin). `activeBaseUrl` is switched by the login screen's school picker.
  // =====================================================================
  static const String defaultBaseUrl = 'http://localhost:8000';

  /// Super-admin registry site (its own database; manages all schools).
  static const String superBaseUrl = 'http://localhost:8002';

  /// The site the app is currently talking to. Switched when the user picks
  /// a school on the login screen; cleared of any stale session on switch.
  static String activeBaseUrl = defaultBaseUrl;

  /// The web admin dashboard (schooladmin app). Admin users are redirected
  /// here from mobile.
  static const String webAdminUrl = 'http://localhost:5173';
  
  // Legacy base URL (for compatibility - now points to same Frappe instance)
  static const String baseUrl = defaultBaseUrl;

  /// A registered school as seen by the app (from `public_schools` on the
  /// super site, with a local fallback list for offline/dev bootstrapping).
  static const List<Map<String, String>> knownSchools = [
    {
      'name': 'Sunrise Public School',
      'baseUrl': 'http://localhost:8000',
      'role': 'school',
    },
    {
      'name': 'Oakridge International School',
      'baseUrl': 'http://localhost:8001',
      'role': 'school',
    },
    {
      'name': 'Super Admin Portal',
      'baseUrl': 'http://localhost:8002',
      'role': 'super',
    },
  ];

  /// Build the base URL for a school from the registry fields
  /// (site/port — local dev uses `http://localhost:<port>`).
  static String schoolBaseUrl(int port, {String? site}) =>
      'http://localhost:$port';

  // =====================================================================
  // Frappe Education REST API Endpoints
  // =====================================================================
  
  // Authentication
  static const String loginEndpoint = '/api/method/login';
  static const String logoutEndpoint = '/api/method/logout';
  static const String meEndpoint = '/api/method/auth.get_logged_user';
  
  // ── Our own auth (sc_auth custom app) ─────────────────────────────────
  // Custom email/password login + signup. Returns profile + sid + JWT.
  static const String customLoginEndpoint = '/api/method/sc_auth.api.auth.login';
  static const String customSignupEndpoint = '/api/method/sc_auth.api.auth.signup_student';
  static const String customMeEndpoint = '/api/method/sc_auth.api.auth.me';
  static const String customLogoutEndpoint = '/api/method/sc_auth.api.auth.logout';
  static const String customChangePasswordEndpoint = '/api/method/sc_auth.api.auth.change_password';
  
  // Education API methods
  static const String getUserInfoEndpoint = '/api/method/education.education.api.get_user_info';
  static const String getStudentInfoEndpoint = '/api/method/education.education.api.get_student_info';
  static const String markAttendanceEndpoint = '/api/method/education.education.api.mark_attendance';
  
  // Resource endpoints (RESTful)
  static const String studentsEndpoint = '/api/resource/Student';
  static const String instructorsEndpoint = '/api/resource/Instructor';
  static const String coursesEndpoint = '/api/resource/Course';
  static const String studentGroupsEndpoint = '/api/resource/Student Group';
  static const String courseSchedulesEndpoint = '/api/resource/Course Schedule';
  static const String attendanceEndpoint = '/api/resource/Student Attendance';
  static const String assessmentPlansEndpoint = '/api/resource/Assessment Plan';
  static const String assessmentResultsEndpoint = '/api/resource/Assessment Result';
  
  // Generic client methods
  static const String getListEndpoint = '/api/method/client.get_list';
  static const String getCountEndpoint = '/api/method/client.get_count';
  static const String getDocEndpoint = '/api/method/client.get_value';
  
  // File upload
  static const String uploadFileEndpoint = '/api/method/upload_file';
  
  // =====================================================================
  // Legacy endpoints (for backward compatibility with existing screens)
  // These will need to be migrated to use Frappe's native endpoints
  // =====================================================================
  
  // Signup (uses Frappe's user creation)
  static const String legacySignupEndpoint = '/api/method/client.add_user';
  
  // School search (will need to be implemented via Frappe filters)
  static const String legacySearchSchoolsEndpoint = '/api/resource/School';
  static const String legacyGetSchoolsEndpoint = '/api/resource/School';
  
  // Teacher endpoints (will be migrated to Frappe resource calls)
  static const String legacyGetMyClassesEndpoint = '/api/method/education.education.api.get_my_classes';
  static const String legacyGetClassStudentsEndpoint = '/api/method/education.education.api.get_class_students';
  static const String legacyGetAttendanceReportEndpoint = '/api/method/education.education.api.get_attendance_report';
  
  // Assignment endpoints (using Assessment Plan/Result)
  static const String legacyGetMyTeacherAssignmentsEndpoint = '/api/resource/Assessment Plan';
  static const String legacyCreateAssignmentEndpoint = '/api/resource/Assessment Plan';
  static const String legacyUpdateAssignmentEndpoint = '/api/resource/Assessment Plan';
  static const String legacyDeleteAssignmentEndpoint = '/api/resource/Assessment Plan';
  static const String legacyGetAssignmentSubmissionsEndpoint = '/api/resource/Assessment Result';
  static const String legacyGradeSubmissionEndpoint = '/api/resource/Assessment Result';
  static const String legacyUnsubmitSubmissionEndpoint = '/api/resource/Assessment Result';
  static const String legacyDeleteSubmissionEndpoint = '/api/resource/Assessment Result';
  static const String legacyGetStudentDetailsEndpoint = '/api/resource/Student';
  
  // Student endpoints
  static const String legacyGetMyAttendanceSummaryEndpoint = '/api/method/education.education.api.get_my_attendance_summary';
  static const String legacyGetMyAttendanceEndpoint = '/api/resource/Student Attendance';
  static const String legacyGetMyAssignmentsEndpoint = '/api/resource/Assessment Plan';
  static const String legacyGetMyProfileEndpoint = '/api/method/education.education.api.get_student_info';
  static const String legacySubmitAssignmentEndpoint = '/api/resource/Assessment Result';
  
  // Admin endpoints
  static const String legacyGetAdminDashboardEndpoint = '/api/method/education.education.api.get_admin_dashboard';
  static const String legacyGetAdminTeachersEndpoint = '/api/resource/Instructor';
  static const String legacyGetAdminClassesEndpoint = '/api/resource/Student Group';
  static const String legacyGetAdminStudentsEndpoint = '/api/resource/Student';
  
  // File upload endpoint (direct Frappe)
  static const String legacyFileUploadEndpoint = '/api/method/upload_file';
  
  // Timeout settings
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // =====================================================================
  // Helper methods
  // =====================================================================
  
  /// Build resource URL with filters
  static String buildResourceUrl(String doctype, {Map<String, dynamic>? filters, int? limit}) {
    final queryParams = <String, String>{};
    
    if (filters != null && filters.isNotEmpty) {
      final filterList = filters.entries.map((e) => '["${e.key}","=","${e.value}"]').toList();
      queryParams['filters'] = '[${filterList.join(",")}]';
    }
    
    if (limit != null) {
      queryParams['limit_page_length'] = limit.toString();
    }
    
    final uri = Uri.parse('$defaultBaseUrl/api/resource/$doctype');
    return uri.replace(queryParameters: queryParams).toString();
  }
  
  /// Build method URL with parameters
  static String buildMethodUrl(String method, {Map<String, String>? params}) {
    final uri = Uri.parse('$defaultBaseUrl/api/method/$method');
    return uri.replace(queryParameters: params).toString();
  }
}
