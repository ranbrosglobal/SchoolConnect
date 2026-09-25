/// API Configuration for School Connect.
///
/// Live backend: Frappe v17 + Education + the `sc_auth` custom app.
/// Each school runs its own Frappe site + MariaDB; the app talks to the
/// school site that authenticates the user (auto-detected at login).
///
/// URLs are driven by environment variables so the same app binary runs
/// against localhost dev benches and against deployed hosts:
///   SC_BACKEND_URL     - schooladmin API base URL (default http://13.205.212.64)
///   SC_SUPERADMIN_URL  - super-admin registry site (default http://13.205.212.64)
///   SC_WEB_ADMIN_URL   - school admin web dashboard (default http://localhost:5173)
/// No plaintext secrets live in this file. The JWT signing key is a Frappe
/// site-config value (`sc_auth_jwt_secret`), set per site — never shipped
/// in the app bundle.
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// Explicit override, e.g. `--dart-define=SC_BACKEND_URL=http://10.0.2.2:5173`.
  static const String _explicitBackendUrl =
      String.fromEnvironment('SC_BACKEND_URL', defaultValue: '');

  static String get backendHost {
    return (_explicitBackendUrl.isEmpty
            ? 'http://13.205.212.64'
            : _explicitBackendUrl)
        .replaceAll('\\', '/');
  }

  static int get backendPort {
    return int.tryParse(
        const String.fromEnvironment('SC_BACKEND_PORT', defaultValue: '5173')) ?? 5173;
  }

  /// Full backend base URL for the mobile app (the school site that
  /// authenticated the current user).
  ///
  /// On the web the API is served from the app's own origin, which keeps the
  /// session cookie first-party; mobile builds fall back to the configured
  /// host. An explicit `SC_BACKEND_URL` always wins.
  static String get backendBaseUrl {
    if (kIsWeb && _explicitBackendUrl.isEmpty) {
      return Uri.base.origin;
    }
    final uri = Uri.tryParse(backendHost);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return uri.hasPort ? backendHost : '$backendHost:$backendPort';
    }
    return '$backendHost:$backendPort';
  }

  static String get superAdminHost {
    return const String.fromEnvironment('SC_SUPERADMIN_URL',
      defaultValue: 'http://13.205.212.64')
        .replaceAll('\\', '/');
  }

  static int get superAdminPort {
    return int.tryParse(
        const String.fromEnvironment('SC_SUPERADMIN_PORT', defaultValue: '5175')) ?? 5175;
  }

  static String get superAdminBaseUrl {
    final uri = Uri.tryParse(superAdminHost);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return uri.hasPort ? superAdminHost : '$superAdminHost:$superAdminPort';
    }
    return '$superAdminHost:$superAdminPort';
  }

  /// Web admin dashboard URL (for the mobile redirect screen).
  static String get webAdminUrl {
    return const String.fromEnvironment('SC_WEB_ADMIN_URL',
        defaultValue: 'http://localhost:5173');
  }

  /// Timeout settings.
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ─── Demo shortcuts ────────────────────────────────────────────────
  // The login screen's "Try Demo Account" chips are only shown when real
  // credentials are configured at build time, so we never offer accounts that
  // do not exist on the server the app is pointing at:
  //
  //   flutter build apk \
  //     --dart-define=SC_DEMO_TEACHER_EMAIL=teacher@school.com \
  //     --dart-define=SC_DEMO_TEACHER_PASSWORD=secret \
  //     --dart-define=SC_DEMO_STUDENT_EMAIL=student@school.com \
  //     --dart-define=SC_DEMO_STUDENT_PASSWORD=secret
  static const String demoTeacherEmail =
      String.fromEnvironment('SC_DEMO_TEACHER_EMAIL', defaultValue: '');
  static const String demoTeacherPassword =
      String.fromEnvironment('SC_DEMO_TEACHER_PASSWORD', defaultValue: '');
  static const String demoStudentEmail =
      String.fromEnvironment('SC_DEMO_STUDENT_EMAIL', defaultValue: '');
  static const String demoStudentPassword =
      String.fromEnvironment('SC_DEMO_STUDENT_PASSWORD', defaultValue: '');

  static bool get hasDemoTeacher =>
      demoTeacherEmail.isNotEmpty && demoTeacherPassword.isNotEmpty;
  static bool get hasDemoStudent =>
      demoStudentEmail.isNotEmpty && demoStudentPassword.isNotEmpty;
  static bool get hasDemoAccounts => hasDemoTeacher || hasDemoStudent;
}
