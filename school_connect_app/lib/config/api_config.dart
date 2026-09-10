/// API Configuration for School Connect
///
/// Backend: Node.js + SQLite (sc_backend)
/// - School Admin backend: port 3000
/// - Super Admin backend: port 3001
///
/// When deployed to AWS, replace localhost with the static IP.
class ApiConfig {
  /// Backend server base URL (school admin + mobile app data).
  /// Replace with AWS static IP when deploying.
  static const String backendHost = 'http://localhost';
  static const int backendPort = 3000;

  /// Super admin backend URL.
  /// Replace with AWS static IP when deploying.
  static const String superAdminHost = 'http://localhost';
  static const int superAdminPort = 3001;

  /// Full backend base URL for the mobile app (school admin server).
  static String get backendBaseUrl => '$backendHost:$backendPort';

  /// Full super admin base URL.
  static String get superAdminBaseUrl => '$superAdminHost:$superAdminPort';

  /// Web admin dashboard URL (for redirect from mobile).
  static const String webAdminUrl = 'http://localhost:5173';

  /// Google Sheets scopes needed by the app (for Google Sign-In only).
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
    'email',
    'profile',
  ];

  /// Timeout settings.
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
